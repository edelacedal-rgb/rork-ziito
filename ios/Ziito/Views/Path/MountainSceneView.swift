import SwiftUI
import SceneKit

// MARK: - Public types

struct MountainFlag: Identifiable, Equatable {
    let id: UUID
    let subjectIndex: Int   // which face
    let altitude: Double    // 0..1 along the slope
    let isMastery: Bool     // gold flag if true, gray otherwise
}

struct MountainMonument: Identifiable, Equatable {
    let id: UUID
    let subjectIndex: Int
    let altitude: Double    // 0..1 (ignored when atBase = true)
    let subjectName: String
    let atBase: Bool        // when true, placed around the foot of the mountain
}

struct MountainGear: Identifiable, Equatable {
    let id: String
    let kind: GearKind
    enum GearKind { case boots, axe, rope, tent, fire }
}

enum DayPhase {
    case night, dawn, day, goldenHour, dusk

    static func current(date: Date = Date()) -> DayPhase {
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case 0..<5: return .night
        case 5..<7: return .dawn
        case 7..<17: return .day
        case 17..<19: return .goldenHour
        case 19..<21: return .dusk
        default: return .night
        }
    }
}

// MARK: - SwiftUI bridge

struct MountainSceneView: UIViewRepresentable {
    let subjectColors: [UIColor]
    let subjectNames: [String]
    let flags: [MountainFlag]
    let monuments: [MountainMonument]
    let gear: [MountainGear]
    let dayPhase: DayPhase
    /// 0..1 where 0 = base camp, 1 = zenit. Controls camera vertical position.
    let altitude: Double
    /// In radians: free rotation around the mountain (no snap).
    let rotation: Double
    let fogMode: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.isOpaque = false
        view.allowsCameraControl = false
        let scene = SCNScene()
        view.scene = scene
        context.coordinator.attach(view: view, scene: scene)
        context.coordinator.rebuild(
            subjectColors: subjectColors,
            subjectNames: subjectNames,
            flags: flags,
            monuments: monuments,
            gear: gear,
            dayPhase: dayPhase,
            fogMode: fogMode
        )
        context.coordinator.updateCamera(altitude: altitude, rotation: rotation, animated: false)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.refreshFaces(subjectColors: subjectColors, subjectNames: subjectNames)
        c.refreshFlags(flags)
        c.refreshMonuments(monuments)
        c.refreshGear(gear)
        c.refreshLighting(dayPhase: dayPhase, fogMode: fogMode)
        c.updateCamera(altitude: altitude, rotation: rotation, animated: true)
    }

    func makeCoordinator() -> MountainSceneCoordinator { MountainSceneCoordinator() }
}

// MARK: - Coordinator (owns scene)

final class MountainSceneCoordinator: NSObject {
    private weak var sceneView: SCNView?
    private var scene: SCNScene?

    private let cameraNode = SCNNode()
    private let pivot = SCNNode()
    private let mountainPivot = SCNNode()
    private let flagsRoot = SCNNode()
    private let monumentsRoot = SCNNode()
    private let labelsRoot = SCNNode()
    private let gearRoot = SCNNode()
    private let sun = SCNNode()
    private let ambient = SCNNode()
    private let campfire = SCNNode()

    private var faceMaterials: [SCNMaterial] = []
    private var faceCount: Int = 4
    private var currentColors: [UIColor] = []
    private var currentNames: [String] = []

    // Geometry constants
    private let baseRadius: Float = 3.6
    private let summit: Float = 10.0

    func attach(view: SCNView, scene: SCNScene) {
        self.sceneView = view
        self.scene = scene
        build(scene: scene)
    }

    private func build(scene: SCNScene) {
        scene.rootNode.addChildNode(pivot)
        pivot.addChildNode(mountainPivot)
        mountainPivot.addChildNode(flagsRoot)
        mountainPivot.addChildNode(monumentsRoot)
        mountainPivot.addChildNode(labelsRoot)
        pivot.addChildNode(gearRoot)

        // Camera
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zNear = 0.1
        cam.zFar = 200
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 4, 16)
        cameraNode.look(at: SCNVector3(0, 4, 0))
        pivot.addChildNode(cameraNode)

        // Sun (directional)
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.intensity = 900
        sunLight.castsShadow = false
        sun.light = sunLight
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sun)

        // Ambient
        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 280
        amb.color = UIColor(white: 0.7, alpha: 1)
        ambient.light = amb
        scene.rootNode.addChildNode(ambient)

        // Ground
        let ground = SCNFloor()
        ground.reflectivity = 0
        let groundMat = SCNMaterial()
        groundMat.diffuse.contents = UIColor(red: 0.20, green: 0.22, blue: 0.24, alpha: 1)
        groundMat.lightingModel = .lambert
        ground.materials = [groundMat]
        let groundNode = SCNNode(geometry: ground)
        groundNode.position.y = 0
        scene.rootNode.addChildNode(groundNode)

        // Fog
        scene.fogStartDistance = 25
        scene.fogEndDistance = 80
        scene.fogColor = UIColor(white: 0.85, alpha: 1)
        scene.fogDensityExponent = 1.6

        // Build initial mountain with placeholder colors
        rebuildMountainGeometry(colors: [UIColor.systemIndigo, .systemTeal, .systemOrange, .systemPink], names: ["", "", "", ""])
    }

    // MARK: - Rebuild

    func rebuild(subjectColors: [UIColor], subjectNames: [String], flags: [MountainFlag], monuments: [MountainMonument], gear: [MountainGear], dayPhase: DayPhase, fogMode: Bool) {
        let colors = subjectColors.isEmpty ? [UIColor.systemIndigo, .systemTeal, .systemOrange, .systemPink] : subjectColors
        let names = subjectNames.isEmpty ? Array(repeating: "", count: colors.count) : subjectNames
        rebuildMountainGeometry(colors: colors, names: names)
        refreshFlags(flags)
        refreshMonuments(monuments)
        refreshGear(gear)
        refreshLighting(dayPhase: dayPhase, fogMode: fogMode)
    }

    private func rebuildMountainGeometry(colors: [UIColor], names: [String]) {
        currentColors = colors
        currentNames = names
        // Dynamic N-faced prism, one face per subject (clamped to a sane minimum).
        faceCount = max(3, colors.count)

        // Remove old mountain nodes (children of mountainPivot except special roots)
        for child in mountainPivot.childNodes where child !== flagsRoot && child !== monumentsRoot {
            child.removeFromParentNode()
        }

        // Build the mountain as a stack of low-poly frustums for a chunky, sculpted look.
        let layers = 7
        var bottomRadius: Float = baseRadius
        let totalHeight = summit
        let layerHeight = totalHeight / Float(layers)
        faceMaterials = []

        for i in 0..<layers {
            let t = Float(i) / Float(layers)
            let topRadius = baseRadius * (1 - Float(i + 1) / Float(layers) * 0.92)
            // Jitter for organic look
            let jitter = Float.random(in: 0.92...1.05)
            let layerNode = SCNNode()

            let geometry = lowPolyFrustum(
                bottomRadius: bottomRadius * jitter,
                topRadius: max(0.05, topRadius),
                height: layerHeight,
                segments: faceCount,
                colors: colors,
                shadeFactor: 0.65 + 0.35 * Double(t)
            )
            let n = SCNNode(geometry: geometry)
            n.position.y = Float(i) * layerHeight
            layerNode.addChildNode(n)
            mountainPivot.addChildNode(layerNode)

            bottomRadius = topRadius
        }

        // Snow cap (small white cone on top)
        let cap = SCNCone(topRadius: 0.05, bottomRadius: CGFloat(bottomRadius * 1.05), height: 0.8)
        let snow = SCNMaterial()
        snow.diffuse.contents = UIColor(white: 0.96, alpha: 1)
        snow.lightingModel = .lambert
        cap.materials = [snow]
        let capNode = SCNNode(geometry: cap)
        capNode.position.y = summit + 0.4
        mountainPivot.addChildNode(capNode)

        // Beacon at zenit
        let beacon = SCNNode(geometry: SCNSphere(radius: 0.18))
        let beaconMat = SCNMaterial()
        beaconMat.diffuse.contents = UIColor(white: 1, alpha: 1)
        beaconMat.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1)
        beacon.geometry?.materials = [beaconMat]
        beacon.position.y = summit + 1.2
        beacon.name = "beacon"
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.6
        pulse.toValue = 1.0
        pulse.duration = 1.4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        beacon.addAnimation(pulse, forKey: "beaconPulse")
        mountainPivot.addChildNode(beacon)

        // Soft halo light at summit
        let halo = SCNLight()
        halo.type = .omni
        halo.color = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1)
        halo.intensity = 350
        halo.attenuationStartDistance = 0.5
        halo.attenuationEndDistance = 6
        let haloNode = SCNNode()
        haloNode.light = halo
        haloNode.position.y = summit + 1.0
        mountainPivot.addChildNode(haloNode)

        // 3D billboard labels per face (subject names).
        rebuildFaceLabels(names: names)
    }

    /// Floating low-relief subject sign anchored to each face's base, billboarded to camera.
    private func rebuildFaceLabels(names: [String]) {
        labelsRoot.childNodes.forEach { $0.removeFromParentNode() }
        let segs = max(1, faceCount)
        for s in 0..<segs {
            let raw = s < names.count ? names[s] : ""
            let label = raw.trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty else { continue }
            let centerAngle = (Float(s) + 0.5) / Float(segs) * Float.pi * 2
            let r: Float = baseRadius + 1.55
            let pos = SCNVector3(r * cos(centerAngle), 0.85, r * sin(centerAngle))

            let text = SCNText(string: label.uppercased(), extrusionDepth: 0.04)
            text.font = UIFont.systemFont(ofSize: 0.42, weight: .heavy)
            text.flatness = 0.05
            text.chamferRadius = 0.01
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.white
            mat.emission.contents = UIColor(white: 0.95, alpha: 1)
            mat.lightingModel = .lambert
            text.materials = [mat]

            let textNode = SCNNode(geometry: text)
            let (minB, maxB) = text.boundingBox
            let w = maxB.x - minB.x
            let h = maxB.y - minB.y
            textNode.position = SCNVector3(-w / 2, -h / 2, 0)

            // A backing plaque so the label is legible against any sky.
            let plaque = SCNPlane(width: CGFloat(w) + 0.5, height: CGFloat(h) + 0.3)
            let pm = SCNMaterial()
            pm.diffuse.contents = UIColor(white: 0.08, alpha: 0.55)
            pm.lightingModel = .constant
            pm.isDoubleSided = true
            plaque.materials = [pm]
            let plaqueNode = SCNNode(geometry: plaque)
            plaqueNode.position = SCNVector3(0, 0, -0.06)

            let billboardRoot = SCNNode()
            billboardRoot.position = pos
            billboardRoot.addChildNode(plaqueNode)
            billboardRoot.addChildNode(textNode)
            // Always face the camera around Y so labels stay readable as the mountain rotates.
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.Y]
            billboardRoot.constraints = [billboard]
            labelsRoot.addChildNode(billboardRoot)
        }
    }

    /// Builds a low-poly prism-like frustum with one material per radial face.
    private func lowPolyFrustum(bottomRadius: Float, topRadius: Float, height: Float, segments: Int, colors: [UIColor], shadeFactor: Double) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [[Int32]] = Array(repeating: [], count: segments)
        let pi2 = Float.pi * 2

        for s in 0..<segments {
            let a0 = Float(s) / Float(segments) * pi2
            let a1 = Float(s + 1) / Float(segments) * pi2
            // Slight ridgeline jitter so the silhouette feels carved
            let j: Float = Float.random(in: 0.95...1.04)
            let br = bottomRadius * j
            let tr = topRadius * j

            let p0 = SCNVector3(br * cos(a0), 0, br * sin(a0))
            let p1 = SCNVector3(br * cos(a1), 0, br * sin(a1))
            let p2 = SCNVector3(tr * cos(a1), height, tr * sin(a1))
            let p3 = SCNVector3(tr * cos(a0), height, tr * sin(a0))

            // Outward-pointing normal computed from the face center angle so
            // shading is consistent across all faces (independent of winding).
            let am = (a0 + a1) * 0.5
            let n = SCNVector3(cos(am), 0, sin(am))

            let base = Int32(vertices.count)
            vertices.append(contentsOf: [p0, p1, p2, p3])
            normals.append(contentsOf: [n, n, n, n])
            // CCW winding when viewed from OUTSIDE (front-facing).
            indices[s].append(contentsOf: [base, base + 2, base + 1, base, base + 3, base + 2])
        }

        let vSource = SCNGeometrySource(vertices: vertices)
        let nSource = SCNGeometrySource(normals: normals)

        var elements: [SCNGeometryElement] = []
        var materials: [SCNMaterial] = []
        for s in 0..<segments {
            let data = Data(bytes: indices[s], count: indices[s].count * MemoryLayout<Int32>.size)
            let elem = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: indices[s].count / 3, bytesPerIndex: MemoryLayout<Int32>.size)
            elements.append(elem)

            let mat = SCNMaterial()
            let baseColor = colors[s % colors.count]
            mat.diffuse.contents = baseColor.mixed(with: .black, t: 1 - shadeFactor)
            mat.lightingModel = .lambert
            mat.locksAmbientWithDiffuse = true
            mat.isDoubleSided = true
            materials.append(mat)
            faceMaterials.append(mat)
        }
        let geo = SCNGeometry(sources: [vSource, nSource], elements: elements)
        geo.materials = materials
        return geo
    }

    func refreshFaces(subjectColors: [UIColor], subjectNames: [String]) {
        guard !subjectColors.isEmpty else { return }
        let colorsChanged = subjectColors.count != currentColors.count || zip(subjectColors, currentColors).contains(where: { $0 != $1 })
        let namesChanged = subjectNames != currentNames
        if colorsChanged {
            rebuildMountainGeometry(colors: subjectColors, names: subjectNames)
        } else if namesChanged {
            currentNames = subjectNames
            rebuildFaceLabels(names: subjectNames)
        }
    }

    // MARK: - Flags / Monuments / Gear

    func refreshFlags(_ flags: [MountainFlag]) {
        let existingIds = Set(flagsRoot.childNodes.compactMap { $0.name })
        let newIds = Set(flags.map { $0.id.uuidString })

        // Remove stale
        for child in flagsRoot.childNodes where !newIds.contains(child.name ?? "") {
            child.removeFromParentNode()
        }
        // Add new
        for f in flags where !existingIds.contains(f.id.uuidString) {
            let node = buildFlagNode(flag: f)
            node.name = f.id.uuidString
            flagsRoot.addChildNode(node)
            // Animate the plant: drop in + flutter
            let dropY = node.position.y
            node.position.y = dropY + 1.2
            node.opacity = 0
            let plant = SCNAction.group([
                SCNAction.move(by: SCNVector3(0, -1.2, 0), duration: 0.4),
                SCNAction.fadeIn(duration: 0.3)
            ])
            plant.timingMode = .easeOut
            node.runAction(plant)
        }
    }

    private func buildFlagNode(flag: MountainFlag) -> SCNNode {
        let pos = surfacePoint(angleIndex: flag.subjectIndex, altitude: flag.altitude)
        let node = SCNNode()
        node.position = pos.position

        // Pole
        let pole = SCNCylinder(radius: 0.04, height: 0.7)
        let poleMat = SCNMaterial()
        poleMat.diffuse.contents = UIColor(white: 0.15, alpha: 1)
        poleMat.lightingModel = .lambert
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(0, 0.35, 0)
        node.addChildNode(poleNode)

        // Flag cloth (triangular)
        let cloth = SCNPlane(width: 0.42, height: 0.28)
        let m = SCNMaterial()
        // Each subject (mountain face) gets a unique flag color.
        let subjectColor: UIColor = {
            guard !currentColors.isEmpty else { return UIColor(white: 0.78, alpha: 1) }
            return currentColors[flag.subjectIndex % currentColors.count]
        }()
        m.diffuse.contents = flag.isMastery ? UIColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 1) : subjectColor
        m.emission.contents = flag.isMastery ? UIColor(red: 0.6, green: 0.5, blue: 0.1, alpha: 1) : subjectColor.mixed(with: .black, t: 0.7)
        m.isDoubleSided = true
        m.lightingModel = .lambert
        cloth.materials = [m]
        let clothNode = SCNNode(geometry: cloth)
        clothNode.position = SCNVector3(0.22, 0.55, 0)
        node.addChildNode(clothNode)

        // Orient outward from the mountain
        node.eulerAngles.y = pos.outwardYaw

        // Subtle flutter
        let flutter = CABasicAnimation(keyPath: "eulerAngles.y")
        flutter.fromValue = pos.outwardYaw - 0.08
        flutter.toValue = pos.outwardYaw + 0.08
        flutter.duration = 1.6
        flutter.autoreverses = true
        flutter.repeatCount = .infinity
        clothNode.addAnimation(flutter, forKey: "flutter")
        return node
    }

    func refreshMonuments(_ monuments: [MountainMonument]) {
        let existingIds = Set(monumentsRoot.childNodes.compactMap { $0.name })
        let newIds = Set(monuments.map { $0.id.uuidString })
        for child in monumentsRoot.childNodes where !newIds.contains(child.name ?? "") {
            child.removeFromParentNode()
        }
        for m in monuments where !existingIds.contains(m.id.uuidString) {
            let node = buildMonumentNode(m)
            node.name = m.id.uuidString
            monumentsRoot.addChildNode(node)
        }
    }

    private func buildMonumentNode(_ m: MountainMonument) -> SCNNode {
        let root = SCNNode()
        let outwardYaw: Float

        if m.atBase {
            // Place around the foot of the mountain, evenly spaced per subject
            let segs = max(1, faceCount)
            let centerAngle = (Float(m.subjectIndex) + 0.5) / Float(segs) * Float.pi * 2
            let r: Float = baseRadius + 1.05
            root.position = SCNVector3(r * cos(centerAngle), 0, r * sin(centerAngle))
            outwardYaw = atan2(root.position.x, root.position.z)
        } else {
            let pos = surfacePoint(angleIndex: m.subjectIndex, altitude: m.altitude)
            root.position = pos.position
            outwardYaw = pos.outwardYaw
        }
        root.eulerAngles.y = outwardYaw

        // A monument: 3 stacked low-poly stones forming a small obelisk-cairn
        let stoneColors: [UIColor] = [
            UIColor(white: 0.55, alpha: 1),
            UIColor(white: 0.62, alpha: 1),
            UIColor(white: 0.48, alpha: 1)
        ]
        var y: Float = 0
        let plinthHeight: Float = 0.55
        for (i, h) in [plinthHeight, Float(0.36), 0.24].enumerated() {
            let radius = CGFloat(0.42 - Float(i) * 0.08)
            let box = SCNBox(width: radius * 2, height: CGFloat(h), length: radius * 2, chamferRadius: 0.05)
            let mat = SCNMaterial()
            mat.diffuse.contents = stoneColors[i]
            mat.lightingModel = .lambert
            box.materials = [mat]
            let n = SCNNode(geometry: box)
            n.position.y = y + h / 2
            n.eulerAngles.y = Float.random(in: -0.2...0.2)
            root.addChildNode(n)
            y += h
        }

        // Engraved subject name on the plinth
        let label = SCNText(string: m.subjectName.uppercased(), extrusionDepth: 0.015)
        label.font = UIFont.systemFont(ofSize: 0.16, weight: .heavy)
        label.flatness = 0.05
        label.chamferRadius = 0.005
        let textMat = SCNMaterial()
        textMat.diffuse.contents = UIColor(white: 0.20, alpha: 1)
        textMat.emission.contents = UIColor(white: 0.08, alpha: 1)
        textMat.lightingModel = .lambert
        label.materials = [textMat]
        let textNode = SCNNode(geometry: label)
        // Center the text on the plinth front face
        let (minBound, maxBound) = label.boundingBox
        let textWidth = maxBound.x - minBound.x
        let textHeight = maxBound.y - minBound.y
        textNode.position = SCNVector3(-textWidth / 2, plinthHeight * 0.5 - textHeight / 2, 0.43)
        root.addChildNode(textNode)

        return root
    }

    func refreshGear(_ gear: [MountainGear]) {
        let existingIds = Set(gearRoot.childNodes.compactMap { $0.name })
        let newIds = Set(gear.map { $0.id })
        for child in gearRoot.childNodes where !newIds.contains(child.name ?? "") {
            child.removeFromParentNode()
        }
        for (i, g) in gear.enumerated() where !existingIds.contains(g.id) {
            let n = buildGearNode(g, slot: i)
            n.name = g.id
            gearRoot.addChildNode(n)
        }

        // Update campfire intensity based on whether fire gear is present
        let hasFire = gear.contains { $0.kind == .fire }
        updateCampfire(active: hasFire)
    }

    private func buildGearNode(_ gear: MountainGear, slot: Int) -> SCNNode {
        // Arrange around base camp in an arc
        let angle = -Float.pi / 2 + Float(slot) * 0.4
        let r: Float = baseRadius + 1.6
        let pos = SCNVector3(r * cos(angle), 0, r * sin(angle))
        let node = SCNNode()
        node.position = pos

        switch gear.kind {
        case .boots:
            for dx in [Float(-0.18), 0.18] {
                let b = SCNBox(width: 0.28, height: 0.18, length: 0.5, chamferRadius: 0.05)
                let m = SCNMaterial()
                m.diffuse.contents = UIColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 1)
                m.lightingModel = .lambert
                b.materials = [m]
                let n = SCNNode(geometry: b)
                n.position = SCNVector3(dx, 0.09, 0)
                node.addChildNode(n)
            }
        case .axe:
            let shaft = SCNCylinder(radius: 0.025, height: 0.7)
            let sm = SCNMaterial(); sm.diffuse.contents = UIColor.brown; sm.lightingModel = .lambert
            shaft.materials = [sm]
            let sn = SCNNode(geometry: shaft)
            sn.eulerAngles.z = .pi / 3
            sn.position.y = 0.25
            node.addChildNode(sn)
            let head = SCNBox(width: 0.22, height: 0.06, length: 0.08, chamferRadius: 0.01)
            let hm = SCNMaterial(); hm.diffuse.contents = UIColor(white: 0.7, alpha: 1); hm.lightingModel = .lambert
            head.materials = [hm]
            let hn = SCNNode(geometry: head)
            hn.position = SCNVector3(0.3, 0.55, 0)
            node.addChildNode(hn)
        case .rope:
            let torus = SCNTorus(ringRadius: 0.22, pipeRadius: 0.05)
            let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.85, green: 0.65, blue: 0.25, alpha: 1); m.lightingModel = .lambert
            torus.materials = [m]
            let n = SCNNode(geometry: torus)
            n.eulerAngles.x = .pi / 2
            n.position.y = 0.06
            node.addChildNode(n)
        case .tent:
            let tent = SCNPyramid(width: 0.9, height: 0.6, length: 0.9)
            let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.85, green: 0.35, blue: 0.25, alpha: 1); m.lightingModel = .lambert
            tent.materials = [m]
            let n = SCNNode(geometry: tent)
            n.position.y = 0
            node.addChildNode(n)
        case .fire:
            // Logs
            for ang in stride(from: 0, to: Float.pi, by: .pi / 4) {
                let log = SCNCylinder(radius: 0.04, height: 0.4)
                let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1); m.lightingModel = .lambert
                log.materials = [m]
                let n = SCNNode(geometry: log)
                n.eulerAngles.z = .pi / 2
                n.eulerAngles.y = ang
                n.position.y = 0.04
                node.addChildNode(n)
            }
            campfire.position = SCNVector3(pos.x, 0.2, pos.z)
            if campfire.parent == nil { gearRoot.addChildNode(campfire) }
            let fireLight = SCNLight()
            fireLight.type = .omni
            fireLight.color = UIColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1)
            fireLight.intensity = 600
            fireLight.attenuationStartDistance = 0.2
            fireLight.attenuationEndDistance = 6
            campfire.light = fireLight
            // Flicker
            let flick = CABasicAnimation(keyPath: "light.intensity")
            flick.fromValue = 450
            flick.toValue = 720
            flick.duration = 0.32
            flick.autoreverses = true
            flick.repeatCount = .infinity
            campfire.addAnimation(flick, forKey: "flicker")
        }
        return node
    }

    private func updateCampfire(active: Bool) {
        campfire.isHidden = !active
    }

    // MARK: - Lighting

    func refreshLighting(dayPhase: DayPhase, fogMode: Bool) {
        guard let scene else { return }
        let (sunColor, ambColor, fogColor, fogStart, fogEnd, sunIntensity, ambIntensity) = lightingParams(for: dayPhase, fogMode: fogMode)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        sun.light?.color = sunColor
        sun.light?.intensity = sunIntensity
        ambient.light?.color = ambColor
        ambient.light?.intensity = ambIntensity
        scene.fogColor = fogColor
        scene.fogStartDistance = fogStart
        scene.fogEndDistance = fogEnd
        SCNTransaction.commit()
    }

    private func lightingParams(for phase: DayPhase, fogMode: Bool) -> (UIColor, UIColor, UIColor, CGFloat, CGFloat, CGFloat, CGFloat) {
        if fogMode {
            return (UIColor(white: 0.6, alpha: 1), UIColor(white: 0.5, alpha: 1), UIColor(white: 0.78, alpha: 1), 3, 18, 500, 220)
        }
        switch phase {
        case .night:
            return (UIColor(red: 0.5, green: 0.55, blue: 0.85, alpha: 1), UIColor(red: 0.2, green: 0.25, blue: 0.5, alpha: 1), UIColor(red: 0.06, green: 0.08, blue: 0.18, alpha: 1), 18, 70, 320, 180)
        case .dawn:
            return (UIColor(red: 1.0, green: 0.75, blue: 0.55, alpha: 1), UIColor(red: 0.85, green: 0.7, blue: 0.7, alpha: 1), UIColor(red: 0.95, green: 0.78, blue: 0.7, alpha: 1), 22, 80, 800, 260)
        case .day:
            return (UIColor.white, UIColor(white: 0.75, alpha: 1), UIColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1), 30, 95, 1000, 320)
        case .goldenHour:
            return (UIColor(red: 1.0, green: 0.7, blue: 0.35, alpha: 1), UIColor(red: 1.0, green: 0.78, blue: 0.55, alpha: 1), UIColor(red: 1.0, green: 0.78, blue: 0.55, alpha: 1), 25, 85, 950, 300)
        case .dusk:
            return (UIColor(red: 0.85, green: 0.55, blue: 0.7, alpha: 1), UIColor(red: 0.45, green: 0.4, blue: 0.6, alpha: 1), UIColor(red: 0.4, green: 0.35, blue: 0.55, alpha: 1), 22, 75, 600, 240)
        }
    }

    // MARK: - Camera

    func updateCamera(altitude: Double, rotation: Double, animated: Bool) {
        let altClamped = max(0, min(1, altitude))
        let camY = Float(altClamped) * (summit + 2) - 1.5
        let camDistance: Float = 16 - Float(altClamped) * 4 // farther so we always render OUTSIDE the rock
        let lookY = camY + 1.5

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.18 : 0
        // Only the mountain (and flags/monuments attached to it) physically rotates.
        // The camera and lights stay world-static so the rotation truly reveals lit/shadowed faces.
        mountainPivot.eulerAngles.y = Float(rotation)
        cameraNode.position = SCNVector3(0, camY, camDistance)
        cameraNode.look(at: SCNVector3(0, lookY, 0))
        SCNTransaction.commit()
    }

    // MARK: - Helpers

    private struct SurfacePoint {
        let position: SCNVector3
        let outwardYaw: Float
    }

    /// Returns a position on the lateral surface for a given subject index + normalized altitude (0..1).
    private func surfacePoint(angleIndex: Int, altitude: Double) -> SurfacePoint {
        let segs = max(1, faceCount)
        let centerAngle = (Float(angleIndex) + 0.5) / Float(segs) * Float.pi * 2
        let a = max(0, min(1, Float(altitude)))
        // Linear taper from baseRadius to ~0
        let radius = baseRadius * (1 - a * 0.95) + 0.1
        let y = a * summit
        // Offset slightly outward so flags sit on the surface
        let r = radius + 0.05
        let pos = SCNVector3(r * cos(centerAngle), y, r * sin(centerAngle))
        // Outward yaw: face away from center
        let yaw = atan2(pos.x, pos.z)
        return SurfacePoint(position: pos, outwardYaw: yaw)
    }
}

// MARK: - UIColor helpers

extension UIColor {
    func mixed(with other: UIColor, t: Double) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let tt = CGFloat(max(0, min(1, t)))
        return UIColor(
            red: r1 * (1 - tt) + r2 * tt,
            green: g1 * (1 - tt) + g2 * tt,
            blue: b1 * (1 - tt) + b2 * tt,
            alpha: a1 * (1 - tt) + a2 * tt
        )
    }
}
