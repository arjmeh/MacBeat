import AudioToolbox
import Foundation

final class ShortcutActionManager {
    private let queue = DispatchQueue(label: "Macandrum.Shortcuts", qos: .utility)
    private var lastImpactTime: TimeInterval = 0

    func register(hit: HitEvent, mapping: ShortcutMapping, completion: @escaping (String) -> Void) {
        queue.async {
            guard mapping != .none else { return }

            let delta = hit.timestamp - self.lastImpactTime
            self.lastImpactTime = hit.timestamp
            guard delta > 0, delta < 0.35 else { return }

            let status: String
            switch mapping {
            case .none:
                status = ""
            case .screenshot:
                self.takeScreenshot()
                status = "Double-slap triggered a screenshot."
            case .mute:
                self.muteOutput()
                status = "Double-slap muted the Mac."
            case .screenshotAndMute:
                self.takeScreenshot()
                self.muteOutput()
                status = "Double-slap captured a screenshot and muted the Mac."
            }

            DispatchQueue.main.async {
                completion(status)
            }
        }
    }

    private func takeScreenshot() {
        let screenshotsFolder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Macandrum Shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: screenshotsFolder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let destination = screenshotsFolder.appendingPathComponent("Shot-\(formatter.string(from: Date())).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", destination.path]
        try? process.run()
        process.waitUntilExit()
    }

    private func muteOutput() {
        var defaultDeviceID = AudioDeviceID(0)
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceAddress,
            0,
            nil,
            &deviceSize,
            &defaultDeviceID
        ) == noErr else {
            return
        }

        var muted: UInt32 = 1
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(defaultDeviceID, &muteAddress, 0, nil, muteSize, &muted)
    }
}
