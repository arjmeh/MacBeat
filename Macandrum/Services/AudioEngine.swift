import AVFoundation
import Combine
import SwiftUI

final class AudioEngine: ObservableObject {
    @Published private(set) var kits: [DrumKit] = []
    @Published private(set) var selectedKitID: String = ""

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let sampleRate = 44_100.0
    private let audioQueue = DispatchQueue(label: "Macandrum.AudioQueue", qos: .userInteractive)

    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private var kitVoices: [String: [String: AVAudioPCMBuffer]] = [:]
    private var masterVolume: Float = 0.92

    init() {
        configureEngine()
        buildKits()
        startEngine()
    }

    func selectKit(id: String) {
        guard kits.contains(where: { $0.id == id }) else { return }
        DispatchQueue.main.async {
            self.selectedKitID = id
        }
    }

    func currentKit() -> DrumKit? {
        kits.first(where: { $0.id == selectedKitID })
    }

    func setMasterVolume(_ value: Double) {
        let clamped = Float(min(1.0, max(0.0, value)))
        audioQueue.async {
            self.masterVolume = clamped
            self.mixer.outputVolume = 1.0
        }
    }

    func play(region: ChassisRegion, intensity: Double) -> PlayedPad? {
        audioQueue.sync {
            guard let kit = currentKit() ?? kits.first else { return nil }
            let pad = choosePad(in: kit, for: region)
            guard let buffer = kitVoices[kit.id]?[pad.id] else { return nil }

            let node = playerPool[nextPlayerIndex]
            nextPlayerIndex = (nextPlayerIndex + 1) % playerPool.count

            node.stop()
            let intensityGain = Float(min(1.15, max(0.18, intensity * 0.95)))
            node.volume = intensityGain * self.masterVolume
            node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            if node.isPlaying == false {
                node.play()
            }

            return PlayedPad(
                padID: pad.id,
                kitID: kit.id,
                region: pad.region,
                role: pad.role,
                intensity: intensity,
                timestamp: CACurrentMediaTime()
            )
        }
    }

    func buffer(for playedPad: PlayedPad) -> AVAudioPCMBuffer? {
        kitVoices[playedPad.kitID]?[playedPad.padID]
    }

    private func configureEngine() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))

        for _ in 0..<12 {
            let player = AVAudioPlayerNode()
            playerPool.append(player)
            engine.attach(player)
            engine.connect(player, to: mixer, format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        }
        mixer.outputVolume = 1.0
    }

    private func buildKits() {
        let electronicPads = [
            DrumPad(id: "elec-kick", name: "House Kick", region: .bottom, role: .kick, color: .green, placeholderFileName: "housekick.wav", sampleFolder: "Electronic"),
            DrumPad(id: "elec-hat", name: "House Hat", region: .top, role: .hat, color: .cyan, placeholderFileName: "househihat.wav", sampleFolder: "Electronic"),
            DrumPad(id: "elec-stab", name: "House Alt", region: .right, role: .accent, color: .pink, placeholderFileName: "househihat.wav", sampleFolder: "Electronic"),
            DrumPad(id: "elec-clap", name: "House Clap", region: .left, role: .snare, color: .orange, placeholderFileName: "houseclap.wav", sampleFolder: "Electronic")
        ]
        let acousticPads = [
            DrumPad(id: "ac-kick", name: "Acoustic Kick", region: .bottom, role: .kick, color: .green, placeholderFileName: "acoustickick.wav", sampleFolder: "Acoustic"),
            DrumPad(id: "ac-hat", name: "Acoustic Hat", region: .top, role: .hat, color: .cyan, placeholderFileName: "acoustichihat.wav", sampleFolder: "Acoustic"),
            DrumPad(id: "ac-tom", name: "Tom", region: .right, role: .accent, color: .pink, placeholderFileName: "tom.wav", sampleFolder: "Acoustic"),
            DrumPad(id: "ac-snare", name: "Acoustic Snare", region: .left, role: .snare, color: .orange, placeholderFileName: "acousticsnare.wav", sampleFolder: "Acoustic")
        ]

        let allKits = [
            DrumKit(
                id: "electronic",
                name: "Electronic",
                subtitle: "Punchy kick, clap, and bright hats",
                systemImage: "waveform.badge.plus",
                gradient: [Color(red: 0.07, green: 0.55, blue: 0.56), Color(red: 0.13, green: 0.84, blue: 0.56)],
                pads: electronicPads
            ),
            DrumKit(
                id: "acoustic",
                name: "Acoustic",
                subtitle: "Real kick, snare, and hi-hat",
                systemImage: "music.mic",
                gradient: [Color(red: 0.36, green: 0.23, blue: 0.17), Color(red: 0.82, green: 0.55, blue: 0.22)],
                pads: acousticPads
            )
        ]

        kits = allKits
        selectedKitID = allKits.first?.id ?? ""

        for kit in allKits {
            var voices: [String: AVAudioPCMBuffer] = [:]
            for pad in kit.pads {
                voices[pad.id] = loadOrSynthesizeSample(for: pad)
            }
            kitVoices[kit.id] = voices
        }

    }

    private func loadOrSynthesizeSample(for pad: DrumPad) -> AVAudioPCMBuffer {
        if let loaded = loadBundleSample(named: pad.placeholderFileName, folder: pad.sampleFolder) {
            return loaded
        }

        switch pad.id {
        case "elec-kick":
            return makeKickBuffer(duration: 0.52, startFrequency: 128, endFrequency: 38, punch: 1.45)
        case "elec-hat":
            return makeHatBuffer(duration: 0.12)
        case "elec-stab":
            return makeSynthStab(duration: 0.36, rootFrequency: 293.66, detune: 1.334)
        case "elec-clap":
            return makeClapBuffer(duration: 0.28)
        case "ac-kick":
            return makeKickBuffer(duration: 0.48, startFrequency: 100, endFrequency: 48, punch: 1.0)
        case "ac-hat":
            return makeHatBuffer(duration: 0.16)
        case "ac-tom":
            return makeTomBuffer(duration: 0.34, frequency: 168)
        case "ac-snare":
            return makeSnareBuffer(duration: 0.25)
        default:
            return makeClickBuffer(frequency: 880, duration: 0.08)
        }
    }

    private func loadBundleSample(named fileName: String, folder: String) -> AVAudioPCMBuffer? {
        let resourceName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let candidates: [String?] = [
            nil,
            "Resources/Samples/\(folder)",
            "Samples/\(folder)",
            folder
        ]

        for subdirectory in candidates {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: ext, subdirectory: subdirectory) else {
                continue
            }

            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let frameCount = AVAudioFrameCount(file.length)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { continue }
                try file.read(into: buffer)
                return convertedToEngineFormat(buffer)
            } catch {
                continue
            }
        }

        return nil
    }

    private func convertedToEngineFormat(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard input.format != targetFormat else { return input }

        guard
            let converter = AVAudioConverter(from: input.format, to: targetFormat),
            let output = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(Double(input.frameLength) * (sampleRate / input.format.sampleRate) + 1)
            )
        else {
            return input
        }

        var error: NSError?
        converter.convert(to: output, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return input
        }
        return output
    }

    private func choosePad(in kit: DrumKit, for region: ChassisRegion) -> DrumPad {
        let preferredRole = preferredRole(for: region)

        if let exactRoleMatch = kit.pads.first(where: { $0.role == preferredRole && $0.region == region }) {
            return exactRoleMatch
        }
        if let roleMatch = kit.pads.first(where: { $0.role == preferredRole }) {
            return roleMatch
        }
        if let exactRegion = kit.pads.first(where: { $0.region == region }) {
            return exactRegion
        }
        return kit.pads.first ?? DrumPad(id: "fallback", name: "Fallback", region: .center, role: .kick, color: .white, placeholderFileName: "", sampleFolder: "")
    }

    private func preferredRole(for region: ChassisRegion) -> PadRole {
        switch region {
        case .right:
            return .kick
        case .left:
            return .snare
        case .top, .bottom, .center:
            return .hat
        }
    }

    private func startEngine() {
        audioQueue.async {
            self.engine.prepare()
            if self.engine.isRunning == false {
                try? self.engine.start()
            }
        }
    }

    private func makePCMBuffer(duration: Double, generator: (_ time: Double, _ progress: Double) -> Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = Double(frame) / Double(max(1, Int(frameCount) - 1))
            channel[frame] = generator(time, progress)
        }
        return buffer
    }

    private func makeKickBuffer(duration: Double, startFrequency: Double, endFrequency: Double, punch: Double) -> AVAudioPCMBuffer {
        var phase = 0.0
        return makePCMBuffer(duration: duration) { _, progress in
            let freq = startFrequency * pow(endFrequency / startFrequency, progress)
            phase += 2.0 * .pi * freq / sampleRate
            let envelope = pow(max(0, 1.0 - progress), 3.3)
            let click = exp(-progress * 42.0) * 0.2
            return Float((sin(phase) * envelope * punch) + click)
        }
    }

    private func makeTomBuffer(duration: Double, frequency: Double) -> AVAudioPCMBuffer {
        var phase = 0.0
        return makePCMBuffer(duration: duration) { _, progress in
            phase += 2.0 * .pi * frequency / sampleRate
            let envelope = pow(max(0, 1.0 - progress), 2.6)
            return Float(sin(phase) * envelope)
        }
    }

    private func makeSnareBuffer(duration: Double) -> AVAudioPCMBuffer {
        var phase = 0.0
        var rng = SeededGenerator(seed: 0x51A9)
        return makePCMBuffer(duration: duration) { _, progress in
            phase += 2.0 * .pi * 220.0 / sampleRate
            let tone = sin(phase) * pow(max(0, 1.0 - progress), 3.0) * 0.35
            let noise = (Double.random(in: -1...1, using: &rng)) * pow(max(0, 1.0 - progress), 2.2) * 0.9
            return Float(tone + noise)
        }
    }

    private func makeHatBuffer(duration: Double) -> AVAudioPCMBuffer {
        var rng = SeededGenerator(seed: 0x88F1)
        var last = 0.0
        return makePCMBuffer(duration: duration) { _, progress in
            let white = Double.random(in: -1...1, using: &rng)
            let highPassed = white - (last * 0.85)
            last = white
            return Float(highPassed * pow(max(0, 1.0 - progress), 5.5) * 0.7)
        }
    }

    private func makeShakerBuffer(duration: Double, brightness: Double) -> AVAudioPCMBuffer {
        var rng = SeededGenerator(seed: 0xBEEF)
        var lowpass = 0.0
        return makePCMBuffer(duration: duration) { _, progress in
            let white = Double.random(in: -1...1, using: &rng)
            lowpass += (white - lowpass) * (0.08 + (1.0 - brightness) * 0.3)
            let bright = white - lowpass
            let envelope = pow(max(0, 1.0 - progress), 2.7)
            return Float(bright * envelope * 0.8)
        }
    }

    private func makeClapBuffer(duration: Double) -> AVAudioPCMBuffer {
        var rng = SeededGenerator(seed: 0xFACE)
        let taps = [0.0, 0.018, 0.039]
        return makePCMBuffer(duration: duration) { time, progress in
            let white = Double.random(in: -1...1, using: &rng)
            let burst = taps.reduce(0.0) { partial, tap in
                let delta = max(0.0, time - tap)
                return partial + exp(-delta * 45.0)
            }
            let envelope = pow(max(0, 1.0 - progress), 2.2)
            return Float(white * burst * envelope * 0.55)
        }
    }

    private func makeSynthStab(duration: Double, rootFrequency: Double, detune: Double) -> AVAudioPCMBuffer {
        var phase1 = 0.0
        var phase2 = 0.0
        var phase3 = 0.0
        return makePCMBuffer(duration: duration) { _, progress in
            phase1 += 2.0 * .pi * rootFrequency / sampleRate
            phase2 += 2.0 * .pi * (rootFrequency * detune) / sampleRate
            phase3 += 2.0 * .pi * (rootFrequency * 2.0) / sampleRate
            let saw1 = ((phase1 / .pi).truncatingRemainder(dividingBy: 2.0)) - 1.0
            let saw2 = ((phase2 / .pi).truncatingRemainder(dividingBy: 2.0)) - 1.0
            let sine = sin(phase3)
            let envelope = exp(-progress * 4.8)
            return Float((saw1 * 0.28 + saw2 * 0.18 + sine * 0.22) * envelope)
        }
    }

    private func makeClackBuffer(duration: Double) -> AVAudioPCMBuffer {
        var rng = SeededGenerator(seed: 0x4C41434B)
        return makePCMBuffer(duration: duration) { _, progress in
            let body = sin(progress * 300.0) * exp(-progress * 18.0)
            let noise = Double.random(in: -1...1, using: &rng) * exp(-progress * 42.0) * 0.3
            return Float(body + noise)
        }
    }

    private func makeClickBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer {
        var phase = 0.0
        return makePCMBuffer(duration: duration) { _, progress in
            phase += 2.0 * .pi * frequency / sampleRate
            let env = exp(-progress * 10.0)
            return Float(sin(phase) * env * 0.45)
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}
