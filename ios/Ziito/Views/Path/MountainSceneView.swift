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

/// A Duolingo-style milestone node sitting on a subject's trail.
struct MountainTrailNode: Identifiable, Equatable {
    let id: UUID
    let subjectIndex: Int
    let altitude: Double    // 0..1 along the slope
    let completed: Bool
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
    /// Duolingo-style milestone nodes laid along each subject's trail.
    let trail: [MountainTrailNode]
    /// 0..1 global unlock progress; the candy-crush fog recedes upward as this grows.
    let fogReveal: Double
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
            trail: trail,
            fogReveal: fogReveal,
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
        c.refreshAltar(flags)
        c.refreshMonuments(monuments)
        c.refreshGear(gear)
        c.refreshTrail(trail)
        c.refreshProgressFog(reveal: fogReveal, animated: true)
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
    /// Static landscape: grass floor, wooden base, trees, camp (left) and flag altar (right).
    /// Never rotates — it buries the mountain's rotation pivot completely.
    private let groundParent = SCNNode()
    /// The ONLY node that rotates on the Y-axis when the user swipes horizontally.
    private let mountainPivot = SCNNode()
    private let flagsRoot = SCNNode()
    private let monumentsRoot = SCNNode()
    private let labelsRoot = SCNNode()
    private let trailRoot = SCNNode()
    private let progressFog = SCNNode()
    private let gearRoot = SCNNode()
    /// Static flag altar anchored to the RIGHT of the diorama; mirrors planted flags.
    private let altarRoot = SCNNode()
    private var currentAltarCount: Int = -1
    private var currentTrailSignature: String = ""
    private var currentFogReveal: Double = -1
    private let sun = SCNNode()
    private let ambient = SCNNode()
    private let campfire = SCNNode()

    private var faceMaterials: [SCNMaterial] = []
    private var faceCount: Int = 4
    private var currentColors: [UIColor] = []
    private var currentNames: [String] = []

    // Geometry constants
    private let baseRadius: Float = 4.2
    private let summit: Float = 8.4
    // Uniform footprint so the peak reads equally wide & robust from every side.
    private let stretchX: Float = 1.18
    private let stretchZ: Float = 1.18

    func attach(view: SCNView, scene: SCNScene) {
        self.sceneView = view
        self.scene = scene
        build(scene: scene)
    }

    private func build(scene: SCNScene) {
        scene.rootNode.addChildNode(pivot)
        // Static landscape and the rotating mountain are SIBLINGS, so only the
        // mountain spins while the grass/camp/altar stay locked in place.
        pivot.addChildNode(groundParent)
        pivot.addChildNode(mountainPivot)
        mountainPivot.addChildNode(flagsRoot)
        mountainPivot.addChildNode(monumentsRoot)
        mountainPivot.addChildNode(labelsRoot)
        mountainPivot.addChildNode(trailRoot)
        mountainPivot.addChildNode(progressFog)
        groundParent.addChildNode(gearRoot)
        groundParent.addChildNode(altarRoot)

        // Camera — anchored at human eye-level on the grass, looking slightly up.
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zNear = 0.1
        cam.zFar = 200
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 1.2, 20)
        cameraNode.look(at: SCNVector3(0, 4.0, 0))
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

        // STATIC diorama base — a round wooden platform with a grass apron and a
        // couple of low-poly pine trees. Lives on rootNode (never rotates), so it
        // buries the mountain's rotation pivot completely.
        buildDioramaBase(scene: scene)

        // Soft atmospheric fog, kept distant so the diorama stays crisp & bright.
        scene.fogStartDistance = 40
        scene.fogEndDistance = 120
        scene.fogColor = UIColor(white: 0.92, alpha: 1)
        scene.fogDensityExponent = 1.4

        // Build initial mountain with placeholder colors
        rebuildMountainGeometry(colors: [UIColor.systemIndigo, .systemTeal, .systemOrange, .systemPink], names: ["", "", "", ""])
    }

    // MARK: - Diorama base (static, never rotates)

    private func buildDioramaBase(scene: SCNScene) {
        let platformRadius = CGFloat(baseRadius) + 1.9

        // Wooden platform (top surface flush with y = 0).
        let wood = SCNCylinder(radius: platformRadius, height: 0.55)
        wood.radialSegmentCount = 64
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1)
        woodMat.lightingModel = .physicallyBased
        woodMat.roughness.contents = 0.7
        woodMat.metalness.contents = 0.0
        wood.materials = [woodMat]
        let woodNode = SCNNode(geometry: wood)
        woodNode.position.y = -0.275
        groundParent.addChildNode(woodNode)

        // Darker rim ring beneath for a grounded, layered look.
        let rim = SCNCylinder(radius: platformRadius + 0.04, height: 0.18)
        rim.radialSegmentCount = 64
        let rimMat = SCNMaterial()
        rimMat.diffuse.contents = UIColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 1)
        rimMat.lightingModel = .physicallyBased
        rimMat.roughness.contents = 0.8
        rim.materials = [rimMat]
        let rimNode = SCNNode(geometry: rim)
        rimNode.position.y = -0.64
        groundParent.addChildNode(rimNode)

        // Grass apron — a low green dome hugging the foot of the mountain.
        let grass = SCNSphere(radius: CGFloat(baseRadius) + 1.5)
        grass.segmentCount = 64
        let grassMat = SCNMaterial()
        grassMat.diffuse.contents = UIColor(red: 0.42, green: 0.62, blue: 0.30, alpha: 1)
        grassMat.lightingModel = .physicallyBased
        grassMat.roughness.contents = 0.95
        grassMat.metalness.contents = 0.0
        grass.materials = [grassMat]
        let grassNode = SCNNode(geometry: grass)
        grassNode.scale = SCNVector3(1, 0.16, 1)
        grassNode.position.y = -Float(grass.radius) * 0.16 + 0.12
        groundParent.addChildNode(grassNode)

        // A few low-poly pine trees scattered on the grass apron near the front.
        let treeSpots: [(x: Float, z: Float, s: Float)] = [
            (-2.7, 2.9, 1.0),
            (-3.3, 2.0, 0.78),
            (2.9, 2.7, 0.62)
        ]
        for spot in treeSpots {
            let tree = buildPineTree(scale: spot.s)
            tree.position = SCNVector3(spot.x, 0.05, spot.z)
            groundParent.addChildNode(tree)
        }

        // Static stone altar to the RIGHT that collects a replica of every planted flag.
        buildAltarStructure()
    }

    /// A low stone plinth on the right edge of the grass where flag replicas are planted.
    private func buildAltarStructure() {
        let baseX: Float = baseRadius + 1.25
        altarRoot.position = SCNVector3(baseX, 0.02, 2.4)

        let plinth = SCNCylinder(radius: 0.62, height: 0.34)
        plinth.radialSegmentCount = 28
        let pm = SCNMaterial()
        pm.diffuse.contents = UIColor(white: 0.55, alpha: 1)
        pm.lightingModel = .physicallyBased
        pm.roughness.contents = 0.8
        plinth.materials = [pm]
        let plinthNode = SCNNode(geometry: plinth)
        plinthNode.position.y = 0.17
        altarRoot.addChildNode(plinthNode)

        let cap = SCNCylinder(radius: 0.68, height: 0.08)
        cap.radialSegmentCount = 28
        let cm = SCNMaterial()
        cm.diffuse.contents = UIColor(white: 0.66, alpha: 1)
        cm.lightingModel = .physicallyBased
        cm.roughness.contents = 0.7
        cap.materials = [cm]
        let capNode = SCNNode(geometry: cap)
        capNode.position.y = 0.38
        altarRoot.addChildNode(capNode)
    }

    /// A stylized low-poly pine: a short trunk topped with two stacked green cones.
    private func buildPineTree(scale: Float) -> SCNNode {
        let root = SCNNode()

        let trunk = SCNCylinder(radius: 0.08, height: 0.34)
        trunk.radialSegmentCount = 6
        let trunkMat = SCNMaterial()
        trunkMat.diffuse.contents = UIColor(red: 0.40, green: 0.27, blue: 0.16, alpha: 1)
        trunkMat.lightingModel = .physicallyBased
        trunkMat.roughness.contents = 0.9
        trunk.materials = [trunkMat]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position.y = 0.17
        root.addChildNode(trunkNode)

        let foliageMat = SCNMaterial()
        foliageMat.diffuse.contents = UIColor(red: 0.24, green: 0.46, blue: 0.26, alpha: 1)
        foliageMat.lightingModel = .physicallyBased
        foliageMat.roughness.contents = 0.95

        let lower = SCNCone(topRadius: 0, bottomRadius: 0.38, height: 0.6)
        lower.radialSegmentCount = 7
        lower.materials = [foliageMat]
        let lowerNode = SCNNode(geometry: lower)
        lowerNode.position.y = 0.6
        root.addChildNode(lowerNode)

        let upper = SCNCone(topRadius: 0, bottomRadius: 0.28, height: 0.5)
        upper.radialSegmentCount = 7
        upper.materials = [foliageMat]
        let upperNode = SCNNode(geometry: upper)
        upperNode.position.y = 0.95
        root.addChildNode(upperNode)

        root.scale = SCNVector3(scale, scale, scale)
        return root
    }

    // MARK: - Rebuild

    func rebuild(subjectColors: [UIColor], subjectNames: [String], flags: [MountainFlag], monuments: [MountainMonument], gear: [MountainGear], trail: [MountainTrailNode], fogReveal: Double, dayPhase: DayPhase, fogMode: Bool) {
        let colors = subjectColors.isEmpty ? [UIColor.systemIndigo, .systemTeal, .systemOrange, .systemPink] : subjectColors
        let names = subjectNames.isEmpty ? Array(repeating: "", count: colors.count) : subjectNames
        rebuildMountainGeometry(colors: colors, names: names)
        refreshFlags(flags)
        refreshAltar(flags)
        refreshMonuments(monuments)
        refreshGear(gear)
        refreshTrail(trail)
        refreshProgressFog(reveal: fogReveal, animated: false)
        refreshLighting(dayPhase: dayPhase, fogMode: fogMode)
    }

    private func rebuildMountainGeometry(colors: [UIColor], names: [String]) {
        currentColors = colors
        currentNames = names
        // Dynamic N-faced mountain, one smooth colored wedge per subject.
        faceCount = max(3, colors.count)

        // Remove old mountain nodes (children of mountainPivot except special roots)
        for child in mountainPivot.childNodes where child !== flagsRoot && child !== monumentsRoot && child !== labelsRoot {
            child.removeFromParentNode()
        }
        faceMaterials = []

        // One single smooth-shaded snowy-rock mountain mesh (premium matte porcelain).
        let mesh = porcelainMountainGeometry()
        let meshNode = SCNNode(geometry: mesh)
        meshNode.name = "mountainMesh"
        mountainPivot.addChildNode(meshNode)

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
            let pos = SCNVector3(r * cos(centerAngle) * stretchX, 0.85, r * sin(centerAngle) * stretchZ)

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

    // MARK: - Mountain profile

    /// Craggy radius profile that tapers sharply to a single peak (diorama silhouette).
    private func radiusAt(_ t: Float) -> Float {
        let tc = max(0, min(1, t))
        return baseRadius * pow(1 - tc, 1.32) + 0.04
    }

    private func heightAt(_ t: Float) -> Float {
        max(0, min(1, t)) * summit
    }

    /// Deterministic hash noise in 0..1 for a given grid cell (repeatable across rebuilds).
    private func hashNoise(_ i: Int, _ j: Int) -> Float {
        let s = sin(Float(i) * 127.1 + Float(j) * 311.7) * 43758.5453
        return s - floor(s)
    }

    private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    /// Smooth 2D value noise in 0..1 (bilinear-interpolated hash lattice).
    private func valueNoise(_ x: Float, _ z: Float) -> Float {
        let xi = floor(x), zi = floor(z)
        let xf = x - xi, zf = z - zi
        let i = Int(xi), j = Int(zi)
        let v00 = hashNoise(i, j)
        let v10 = hashNoise(i + 1, j)
        let v01 = hashNoise(i, j + 1)
        let v11 = hashNoise(i + 1, j + 1)
        let u = xf * xf * (3 - 2 * xf)
        let v = zf * zf * (3 - 2 * zf)
        let a = v00 * (1 - u) + v10 * u
        let b = v01 * (1 - u) + v11 * u
        return a * (1 - v) + b * v
    }

    /// Fractal Brownian motion (~0..1) sampled on a point — periodic when fed circle coords.
    private func fbm(_ x: Float, _ z: Float) -> Float {
        var sum: Float = 0, amp: Float = 0.5, freq: Float = 1, norm: Float = 0
        for _ in 0..<4 {
            sum += valueNoise(x * freq, z * freq) * amp
            norm += amp
            freq *= 2.07
            amp *= 0.5
        }
        return sum / max(0.0001, norm)
    }

    /// Sharp ridged noise in 0..1 — produces crisp mountain spines instead of blobs.
    private func ridged(_ x: Float, _ z: Float) -> Float {
        let n = fbm(x, z)
        let r = 1 - abs(2 * n - 1)
        return r * r
    }

    /// Number of major ridge spurs radiating from the peak.
    private let ridgeCount: Float = 7

    /// Relief multiplier applied to the silhouette radius: ridge spurs push outward,
    /// eroded gullies pull inward. Relief is strong at the base and tapers near the
    /// summit so the peak stays defined but craggy (never a smooth cone).
    private func reliefMultiplier(t: Float, angle: Float) -> Float {
        // Periodic sample coords (wrap seam automatically).
        let sx = cos(angle), sz = sin(angle)
        // Major spurs: a few dominant ridges around the silhouette.
        let spurs = ridged(sx * ridgeCount * 0.5 + 3.1, sz * ridgeCount * 0.5 + 7.7)
        // Mid + fine detail crags.
        let crag = fbm(sx * 4.3 + 11.0, sz * 4.3 + 2.0)
        let fine = fbm(sx * 9.1 + 21.0, sz * 9.1 + 6.0)
        // Combine: spurs dominate the form, crags + fine noise add ruggedness.
        let relief = (spurs - 0.45) * 0.72 + (crag - 0.5) * 0.42 + (fine - 0.5) * 0.20
        // More relief low down, fading (but not vanishing) near the apex.
        let fade = 0.4 + 0.6 * (1 - t)
        return 1 + relief * fade
    }

    /// Vertical jitter so ring layers aren't perfectly flat discs — gives crag shelves.
    private func heightJitter(t: Float, angle: Float) -> Float {
        let sx = cos(angle), sz = sin(angle)
        let n = fbm(sx * 3.0 + 5.0, sz * 3.0 + 9.0) - 0.5
        let fine = fbm(sx * 8.0 + 17.0, sz * 8.0 + 4.0) - 0.5
        return (n * 0.09 + fine * 0.04) * summit * (1 - t * 0.4)
    }

    /// Natural alpine color for a point on the surface, by normalized height `t`.
    /// Green forested foothills → earthy/mossy rock → grey crags → snowy cap, with
    /// per-point noise so each facet varies slightly (rugged, hand-painted feel).
    private func mountainColorAt(t: Float, angle: Float) -> SIMD3<Float> {
        let grass     = SIMD3<Float>(0.30, 0.50, 0.24)
        let grassDark = SIMD3<Float>(0.22, 0.40, 0.18)
        let earth     = SIMD3<Float>(0.46, 0.40, 0.27)
        let rock      = SIMD3<Float>(0.52, 0.50, 0.49)
        let rockDark  = SIMD3<Float>(0.38, 0.36, 0.37)
        let snow      = SIMD3<Float>(0.96, 0.97, 1.0)

        // Per-facet variation so the surface doesn't read as flat bands.
        let sx = cos(angle), sz = sin(angle)
        let n = fbm(sx * 6.0 + t * 5.0 + 13.0, sz * 6.0 + 7.0)

        var c: SIMD3<Float>
        if t < 0.22 {
            c = mix(grassDark, grass, t: smoothstep(0.0, 0.22, t))
        } else if t < 0.42 {
            c = mix(grass, earth, t: smoothstep(0.22, 0.42, t))
        } else if t < 0.62 {
            c = mix(earth, rock, t: smoothstep(0.42, 0.62, t))
        } else if t < 0.78 {
            c = mix(rock, rockDark, t: smoothstep(0.62, 0.78, t))
        } else {
            c = mix(rockDark, snow, t: smoothstep(0.78, 0.92, t))
        }
        // Darken/lighten each facet a touch by noise for rugged shading.
        let shade = 0.86 + 0.28 * n
        return c * shade
    }

    /// Builds a RUGGED, FLAT-SHADED mountain: each triangle gets unshared vertices and
    /// a single face normal, producing crisp faceted crags (not a smooth cone). Colors
    /// follow a natural alpine palette: green foothills → earth/rock → snowy peak.
    private func porcelainMountainGeometry() -> SCNGeometry {
        let angular = 64
        let rings = 20
        let pi2 = Float.pi * 2
        let rf = Float(rings)

        func point(_ ring: Int, _ col: Int) -> SCNVector3 {
            let t = Float(ring) / rf
            let a = Float(col) / Float(angular) * pi2
            let radial = radiusAt(t) * reliefMultiplier(t: t, angle: a)
            let y = heightAt(t) + heightJitter(t: t, angle: a)
            return SCNVector3(radial * cos(a) * stretchX, y, radial * sin(a) * stretchZ)
        }

        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colorComps: [Float] = []
        var indices: [Int32] = []

        // Emit a flat-shaded triangle: 3 fresh vertices sharing one face normal and
        // a color sampled at the triangle's centroid height/angle.
        func emitTri(_ p0: SCNVector3, _ p1: SCNVector3, _ p2: SCNVector3) {
            let u = SIMD3<Float>(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z)
            let v = SIMD3<Float>(p2.x - p0.x, p2.y - p0.y, p2.z - p0.z)
            var n = SIMD3<Float>(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)
            let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
            n = len > 1e-5 ? n / len : SIMD3<Float>(0, 1, 0)

            let cy = (p0.y + p1.y + p2.y) / 3
            let cx = (p0.x + p1.x + p2.x) / 3
            let cz = (p0.z + p1.z + p2.z) / 3
            let t = max(0, min(1, cy / summit))
            let ang = atan2(cz, cx)
            let c = mountainColorAt(t: t, angle: ang)

            let base = Int32(positions.count)
            for p in [p0, p1, p2] {
                positions.append(p)
                normals.append(SCNVector3(n.x, n.y, n.z))
                colorComps.append(contentsOf: [c.x, c.y, c.z, 1])
            }
            indices.append(contentsOf: [base, base + 1, base + 2])
        }

        for ring in 0..<rings {
            for col in 0..<angular {
                let a = point(ring, col)
                let b = point(ring, col + 1)
                let topRing = ring + 1
                if topRing == rings {
                    // Collapse to apex.
                    let apex = SCNVector3(0, summit, 0)
                    emitTri(a, b, apex)
                } else {
                    let c = point(topRing, col)
                    let d = point(topRing, col + 1)
                    emitTri(a, c, b)
                    emitTri(b, c, d)
                }
            }
        }

        let vSource = SCNGeometrySource(vertices: positions)
        let nSource = SCNGeometrySource(normals: normals)
        let colorData = Data(bytes: colorComps, count: colorComps.count * MemoryLayout<Float>.size)
        let cSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: positions.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 4
        )
        let data = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let elem = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: indices.count / 3, bytesPerIndex: MemoryLayout<Int32>.size)

        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.lightingModel = .physicallyBased
        // Matte natural rock: high roughness, no metalness.
        mat.roughness.contents = 0.92
        mat.metalness.contents = 0.0
        mat.isDoubleSided = false
        faceMaterials = [mat]

        let geo = SCNGeometry(sources: [vSource, nSource, cSource], elements: [elem])
        geo.materials = [mat]
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

    // MARK: - Trail (Duolingo milestone nodes)

    /// Rebuilds the curved milestone trail with flat, polished circular nodes per face.
    /// Earth-tone, no glow/neon, integrated naturally into the slope.
    func refreshTrail(_ nodes: [MountainTrailNode]) {
        let signature = nodes.map { "\($0.subjectIndex):\(String(format: "%.2f", $0.altitude)):\($0.completed ? 1 : 0)" }.joined(separator: ",")
        guard signature != currentTrailSignature else { return }
        currentTrailSignature = signature
        trailRoot.childNodes.forEach { $0.removeFromParentNode() }

        // Group by face so we can draw connectors between consecutive nodes.
        let byFace = Dictionary(grouping: nodes, by: { $0.subjectIndex })
        for (face, faceNodes) in byFace {
            let sorted = faceNodes.sorted { $0.altitude < $1.altitude }
            var previous: SCNVector3? = nil
            for n in sorted {
                // Gentle zig-zag so the path curves naturally up the slope.
                let wobble = Float(sin(n.altitude * 9.0)) * 0.16
                let pos = surfacePoint(angleIndex: face, altitude: n.altitude, angleOffset: wobble)
                if let prev = previous {
                    trailRoot.addChildNode(buildTrailConnector(from: prev, to: pos.position))
                }
                trailRoot.addChildNode(buildTrailNode(n, at: pos))
                previous = pos.position
            }
        }
    }

    private func buildTrailNode(_ node: MountainTrailNode, at pos: SurfacePoint) -> SCNNode {
        let disc = SCNCylinder(radius: 0.2, height: 0.05)
        disc.radialSegmentCount = 24
        let mat = SCNMaterial()
        let earthDone = currentColors.isEmpty
            ? UIColor(red: 0.78, green: 0.62, blue: 0.40, alpha: 1)
            : currentColors[node.subjectIndex % currentColors.count].mixed(with: UIColor(red: 0.55, green: 0.43, blue: 0.28, alpha: 1), t: 0.45)
        mat.diffuse.contents = node.completed ? earthDone : UIColor(white: 0.62, alpha: 1)
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = 0.7
        mat.metalness.contents = 0.0
        disc.materials = [mat]
        let discNode = SCNNode(geometry: disc)
        // Lay the disc flat against the slope, facing outward.
        discNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        let root = SCNNode()
        root.position = pos.position
        root.eulerAngles.y = pos.outwardYaw
        root.addChildNode(discNode)

        // A subtle raised rim ring for a polished, integrated finish.
        let ring = SCNTorus(ringRadius: 0.2, pipeRadius: 0.025)
        let rm = SCNMaterial()
        rm.diffuse.contents = UIColor(white: node.completed ? 0.95 : 0.5, alpha: 1)
        rm.lightingModel = .physicallyBased
        rm.roughness.contents = 0.6
        ring.materials = [rm]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        ringNode.position.z = 0.03
        root.addChildNode(ringNode)
        return root
    }

    private func buildTrailConnector(from a: SCNVector3, to b: SCNVector3) -> SCNNode {
        let dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z
        let dist = sqrt(dx * dx + dy * dy + dz * dz)
        let path = SCNCylinder(radius: 0.05, height: CGFloat(max(0.001, dist)))
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.62, green: 0.50, blue: 0.34, alpha: 0.92)
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.85
        path.materials = [m]
        let n = SCNNode(geometry: path)
        n.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
        // Orient the cylinder (default +Y) along the segment direction.
        n.look(at: b, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return n
    }

    // MARK: - Candy-Crush progress fog

    /// White soft fog covering the upper portion of the mountain; recedes upward as
    /// `reveal` (0..1) grows. At reveal 0 it covers roughly the upper third.
    func refreshProgressFog(reveal: Double, animated: Bool) {
        let r = max(0, min(1, reveal))
        guard r != currentFogReveal else { return }
        currentFogReveal = r
        progressFog.childNodes.forEach { $0.removeFromParentNode() }

        // Bottom of the fog band climbs from ~0.62 (upper third) up to the summit.
        let fogBottomT = Float(0.62 + 0.38 * r)
        guard fogBottomT < 0.985 else { return } // fully revealed

        let bottomY = heightAt(fogBottomT)
        let height = (summit + 1.4) - bottomY
        let bottomRadius = CGFloat(radiusAt(fogBottomT) * 1.25 + 0.5)
        let cone = SCNCone(topRadius: 0.04, bottomRadius: bottomRadius, height: CGFloat(max(0.2, height)))
        cone.radialSegmentCount = 40
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.97, alpha: 0.5)
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.blendMode = .alpha
        cone.materials = [mat]
        let coneNode = SCNNode(geometry: cone)
        coneNode.scale = SCNVector3(stretchX, 1, stretchZ)
        coneNode.position.y = bottomY + Float(max(0.2, height)) / 2
        coneNode.opacity = 0
        progressFog.addChildNode(coneNode)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.9 : 0
        coneNode.opacity = 1
        SCNTransaction.commit()
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

    /// Mirrors every planted flag onto the static altar on the right (dual-spawn).
    func refreshAltar(_ flags: [MountainFlag]) {
        guard flags.count != currentAltarCount else { return }
        currentAltarCount = flags.count
        // Keep the plinth/cap (the first two children) and rebuild only the planted flags.
        for child in altarRoot.childNodes where child.name == "altarFlag" {
            child.removeFromParentNode()
        }
        let capped = Array(flags.prefix(16))
        let cols = 4
        for (i, f) in capped.enumerated() {
            let row = i / cols
            let colIdx = i % cols
            let x = (Float(colIdx) - 1.5) * 0.26
            let z = (Float(row) - 1.5) * 0.26
            let mini = buildAltarFlag(flag: f)
            mini.name = "altarFlag"
            mini.position = SCNVector3(x, 0.42, z)
            mini.scale = SCNVector3(0.55, 0.55, 0.55)
            altarRoot.addChildNode(mini)
        }
    }

    private func buildAltarFlag(flag: MountainFlag) -> SCNNode {
        let node = SCNNode()
        let pole = SCNCylinder(radius: 0.04, height: 0.7)
        let poleMat = SCNMaterial()
        poleMat.diffuse.contents = UIColor(white: 0.15, alpha: 1)
        poleMat.lightingModel = .lambert
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(0, 0.35, 0)
        node.addChildNode(poleNode)

        let cloth = SCNPlane(width: 0.42, height: 0.28)
        let m = SCNMaterial()
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
        return node
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
            root.position = SCNVector3(r * cos(centerAngle) * stretchX, 0, r * sin(centerAngle) * stretchZ)
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
        // Base camp lives as a static anchor on the LEFT-front of the grass apron.
        let angle = 2.35 + Float(slot) * 0.32
        let r: Float = baseRadius + 1.35
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
        // Camera is anchored at ground/eye-level on the grass and climbs gently as the
        // user ascends. It never traverses the rock and stays world-static during rotation.
        let camY = 1.2 + Float(altClamped) * 5.4
        let camDistance: Float = 20 - Float(altClamped) * 2
        let lookY = camY + 2.6 // look slightly upward toward the active ladera

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.18 : 0
        // ONLY the mountain rotates on its internal Y-axis. The grass floor, base camp
        // (left) and flag altar (right) stay locked, so the user feels planted on the
        // ground watching the laderas spin in front of them.
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
    private func surfacePoint(angleIndex: Int, altitude: Double, angleOffset: Float = 0) -> SurfacePoint {
        let segs = max(1, faceCount)
        let centerAngle = (Float(angleIndex) + 0.5) / Float(segs) * Float.pi * 2 + angleOffset
        let a = max(0, min(1, Float(altitude)))
        // Match the craggy mountain profile so flags/monuments hug the real surface.
        let radius = radiusAt(a) * reliefMultiplier(t: a, angle: centerAngle)
        let y = heightAt(a) + heightJitter(t: a, angle: centerAngle)
        // Offset slightly outward so flags sit on the surface
        let r = radius + 0.08
        let pos = SCNVector3(r * cos(centerAngle) * stretchX, y, r * sin(centerAngle) * stretchZ)
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
