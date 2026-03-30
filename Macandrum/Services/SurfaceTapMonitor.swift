import AVFoundation
import Combine
import Foundation
import QuartzCore
import simd

final class SurfaceTapMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "Microphone assist is off."
    @Published private(set) var currentLevel = 0.0

    var onTap: ((HitEvent) -> Void)?
    var sensitivity: Double = 0.72
    var cooldown: Double = 0.12
    var isEnabled = false {
        didSet {
            isEnabled ? start() : stop()
        }
    }

    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "Macandrum.SurfaceTapMonitor", qos: .userInteractive)

    private var noiseFloor = 0.002
    private var previousEnvelope = 0.0
    private var previousSample = 0.0
    private var lastTapTime = 0.0
    private var quietFrames = 0
    private var warmupFrames = 0

    func start() {
        guard isEnabled else {
            publishStatus("Microphone assist is off.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            installTapIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.installTapIfNeeded()
                    } else {
                        self.publishStatus("Mic access denied. Using accelerometer only.")
                    }
                }
            }
        case .denied, .restricted:
            publishStatus("Mic access denied. Using accelerometer only.")
        @unknown default:
            publishStatus("Mic permission state is unknown.")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        noiseFloor = 0.002
        previousEnvelope = 0
        previousSample = 0
        lastTapTime = 0
        quietFrames = 0
        warmupFrames = 0
        DispatchQueue.main.async {
            self.isRunning = false
            self.currentLevel = 0
            self.statusMessage = self.isEnabled ? "Microphone assist stopped." : "Microphone assist is off."
        }
    }

    private func installTapIfNeeded() {
        guard isRunning == false else { return }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.analyze(buffer: buffer)
        }

        do {
            try engine.start()
            DispatchQueue.main.async {
                self.isRunning = true
                self.statusMessage = "Mic assist is listening for deliberate taps."
            }
        } catch {
            publishStatus("Mic assist failed to start: \(error.localizedDescription)")
        }
    }

    private func analyze(buffer: AVAudioPCMBuffer) {
        analysisQueue.async {
            guard self.isEnabled, let channel = buffer.floatChannelData?.pointee else { return }

            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            var energy = 0.0
            var transient = 0.0
            var peak = 0.0

            for index in 0..<frameCount {
                let sample = Double(channel[index])
                let absSample = abs(sample)
                energy += sample * sample
                transient += abs(sample - self.previousSample)
                peak = max(peak, absSample)
                self.previousSample = sample
            }

            let rms = sqrt(energy / Double(frameCount))
            let transientEnvelope = transient / Double(frameCount)
            let envelope = (rms * 0.75) + (transientEnvelope * 2.4)
            let delta = max(0, envelope - self.previousEnvelope)
            self.previousEnvelope = (self.previousEnvelope * 0.55) + (envelope * 0.45)
            self.warmupFrames += 1

            if envelope < self.noiseFloor * 1.35 {
                self.quietFrames += 1
                self.noiseFloor = (self.noiseFloor * 0.992) + (envelope * 0.008)
            } else {
                self.quietFrames = 0
            }

            DispatchQueue.main.async {
                self.currentLevel = min(1.0, envelope * 10)
            }

            guard self.warmupFrames >= 24 else { return }
            guard self.quietFrames >= 3 else { return }

            let now = CACurrentMediaTime()
            let dynamicThreshold = max(0.010, self.noiseFloor * (4.6 - self.sensitivity * 1.3))
            let deltaThreshold = max(0.004, dynamicThreshold * 0.45)
            let peakThreshold = max(0.06, dynamicThreshold * 3.2)

            guard envelope > dynamicThreshold else { return }
            guard delta > deltaThreshold else { return }
            guard peak > peakThreshold else { return }
            guard now - self.lastTapTime >= self.cooldown else { return }

            self.lastTapTime = now
            self.quietFrames = 0

            let intensity = min(1.0, max(0.18, peak * 2.8))
            let confidence = min(1.0, max(0.3, peak / max(peakThreshold, 0.0001)))
            let hit = HitEvent(
                timestamp: now,
                intensity: intensity,
                confidence: confidence,
                vector: SIMD3<Double>(0, 0, 0),
                region: .center
            )

            DispatchQueue.main.async {
                self.onTap?(hit)
            }
        }
    }

    private func publishStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
        }
    }
}
