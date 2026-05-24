import Foundation
import AVFoundation
import UIKit
import AudioToolbox

/// Plays the "clac" feedback when a flag is planted on the mountain:
/// metallic impact + cloth flutter + heavy haptic.
@MainActor
final class FlagFXService {
    static let shared = FlagFXService()

    private var engine: AVAudioEngine?
    private var clacPlayer: AVAudioPlayerNode?
    private var flutterPlayer: AVAudioPlayerNode?
    private var clacBuffer: AVAudioPCMBuffer?
    private var flutterBuffer: AVAudioPCMBuffer?

    private init() {
        prepare()
    }

    private func prepare() {
        let engine = AVAudioEngine()
        let clac = AVAudioPlayerNode()
        let flutter = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        engine.attach(clac)
        engine.attach(flutter)
        engine.connect(clac, to: engine.mainMixerNode, format: format)
        engine.connect(flutter, to: engine.mainMixerNode, format: format)

        clacBuffer = makeClacBuffer(format: format)
        flutterBuffer = makeFlutterBuffer(format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            try engine.start()
        } catch {
            // Silently fail - haptics still work
        }

        self.engine = engine
        self.clacPlayer = clac
        self.flutterPlayer = flutter
    }

    /// Heavy "clac" + flutter + haptic.
    func playFlagPlant(mastery: Bool = false) {
        // Audio
        if let player = clacPlayer, let buf = clacBuffer {
            if !player.isPlaying { player.play() }
            player.scheduleBuffer(buf, at: nil, options: [.interrupts], completionHandler: nil)
        }
        if let player = flutterPlayer, let buf = flutterBuffer {
            if !player.isPlaying { player.play() }
            // Slight delay using a future audio time
            let when = AVAudioTime(hostTime: mach_absolute_time() + nanosToHost(120_000_000))
            player.scheduleBuffer(buf, at: when, options: [.interrupts], completionHandler: nil)
        }

        // Haptic
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred(intensity: mastery ? 1.0 : 0.85)
        if mastery {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                let g = UINotificationFeedbackGenerator()
                g.notificationOccurred(.success)
            }
        }
    }

    /// Soft chime for monument carving on Content 100%.
    func playMonumentSculpt() {
        AudioServicesPlaySystemSound(1057) // gentle chime
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }

    /// Wind ambience toggle - used by Fog Mode.
    private var windEngine: AVAudioEngine?
    private var windPlayer: AVAudioPlayerNode?

    func startWind(intensity: Float = 0.3) {
        stopWind()
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        guard let buffer = makeWindLoopBuffer(format: format, intensity: intensity) else { return }
        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
            player.play()
            self.windEngine = engine
            self.windPlayer = player
        } catch {}
    }

    func stopWind() {
        windPlayer?.stop()
        windEngine?.stop()
        windPlayer = nil
        windEngine = nil
    }

    func transitionToBlizzard() {
        stopWind()
        startWind(intensity: 0.9)
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.warning)
    }

    // MARK: - Procedural buffer generators

    private func makeClacBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Double = 0.22
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        guard let ch = buf.floatChannelData?[0] else { return nil }
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Two-tone metallic ring with fast decay
            let envelope = exp(-t * 22.0)
            let body = sin(2 * .pi * 1850 * t) * 0.55
            let overtone = sin(2 * .pi * 2740 * t) * 0.35
            let click = (i < 80) ? Double.random(in: -0.6...0.6) : 0
            ch[i] = Float((body + overtone + click) * envelope * 0.7)
        }
        return buf
    }

    private func makeFlutterBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Double = 0.6
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        guard let ch = buf.floatChannelData?[0] else { return nil }
        var lastNoise: Double = 0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Filtered noise burst with low-frequency modulation
            let noise = Double.random(in: -1...1)
            lastNoise = lastNoise * 0.85 + noise * 0.15
            let envelope = sin(.pi * t / duration)
            ch[i] = Float(lastNoise * envelope * 0.25)
        }
        return buf
    }

    private func makeWindLoopBuffer(format: AVAudioFormat, intensity: Float) -> AVAudioPCMBuffer? {
        let duration: Double = 2.0
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        guard let ch = buf.floatChannelData?[0] else { return nil }
        var last: Double = 0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let noise = Double.random(in: -1...1)
            last = last * 0.92 + noise * 0.08
            let lfo = 0.7 + 0.3 * sin(2 * .pi * 0.4 * t)
            ch[i] = Float(last * lfo * Double(intensity))
        }
        return buf
    }

    private func nanosToHost(_ nanos: UInt64) -> UInt64 {
        var info = mach_timebase_info(numer: 0, denom: 0)
        mach_timebase_info(&info)
        return nanos * UInt64(info.denom) / UInt64(info.numer)
    }
}
