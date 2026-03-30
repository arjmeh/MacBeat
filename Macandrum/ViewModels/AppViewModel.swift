import Combine
import Foundation

final class AppViewModel: ObservableObject {
    @Published var selectedKitID: String {
        didSet {
            defaults.set(selectedKitID, forKey: Keys.selectedKitID)
            audioEngine.selectKit(id: selectedKitID)
        }
    }
    @Published var sensitivity: Double {
        didSet {
            defaults.set(sensitivity, forKey: Keys.sensitivity)
            sensorManager.sensitivity = sensitivity
            surfaceTapMonitor.sensitivity = sensitivity
        }
    }
    @Published var cooldown: Double {
        didSet {
            defaults.set(cooldown, forKey: Keys.cooldown)
            sensorManager.cooldown = cooldown
            surfaceTapMonitor.cooldown = cooldown
        }
    }
    @Published var volume: Double {
        didSet {
            defaults.set(volume, forKey: Keys.volume)
            audioEngine.setMasterVolume(volume)
        }
    }
    @Published var monitorInBackground: Bool {
        didSet {
            defaults.set(monitorInBackground, forKey: Keys.background)
            if monitorInBackground {
                sensorManager.start()
                surfaceTapMonitor.start()
            } else {
                sensorManager.stop()
                surfaceTapMonitor.stop()
            }
        }
    }
    @Published var microphoneAssistEnabled: Bool {
        didSet {
            defaults.set(microphoneAssistEnabled, forKey: Keys.microphoneAssist)
            surfaceTapMonitor.isEnabled = microphoneAssistEnabled
        }
    }
    @Published var shortcutMapping: ShortcutMapping {
        didSet {
            defaults.set(shortcutMapping.rawValue, forKey: Keys.shortcutMapping)
        }
    }
    @Published private(set) var transientStatus = "Ready to make your laptop groove."
    @Published private(set) var lastTapSource = "Accelerometer + Mic"

    let sensorManager = SensorManager()
    let surfaceTapMonitor = SurfaceTapMonitor()
    let audioEngine = AudioEngine()
    let loginItemManager = LoginItemManager()

    private let defaults = UserDefaults.standard
    private let shortcuts = ShortcutActionManager()
    private var cancellables = Set<AnyCancellable>()
    private var lastAcceptedTapTime = 0.0

    private enum Keys {
        static let selectedKitID = "app.selectedKitID"
        static let sensitivity = "app.sensitivity"
        static let cooldown = "app.cooldown"
        static let volume = "app.volume"
        static let background = "app.backgroundMonitoring"
        static let shortcutMapping = "app.shortcutMapping"
        static let microphoneAssist = "app.microphoneAssist"
    }

    init() {
        let kitID = defaults.string(forKey: Keys.selectedKitID) ?? audioEngine.kits.first?.id ?? "meme-mode"
        selectedKitID = kitID
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.92
        sensitivity = defaults.object(forKey: Keys.sensitivity) as? Double ?? 0.72
        cooldown = defaults.object(forKey: Keys.cooldown) as? Double ?? 0.12
        monitorInBackground = defaults.object(forKey: Keys.background) as? Bool ?? true
        microphoneAssistEnabled = false
        shortcutMapping = .none

        audioEngine.setMasterVolume(volume)
        sensorManager.sensitivity = sensitivity
        sensorManager.cooldown = cooldown
        surfaceTapMonitor.sensitivity = sensitivity
        surfaceTapMonitor.cooldown = cooldown
        surfaceTapMonitor.isEnabled = microphoneAssistEnabled
        defaults.set(microphoneAssistEnabled, forKey: Keys.microphoneAssist)
        defaults.set(shortcutMapping.rawValue, forKey: Keys.shortcutMapping)
        audioEngine.selectKit(id: kitID)

        bindServices()
        if monitorInBackground {
            sensorManager.start()
            surfaceTapMonitor.start()
        }
    }

    var kits: [DrumKit] {
        audioEngine.kits
    }

    var menuBarSymbol: String {
        sensorManager.connectionState == .connected ? "waveform.path.ecg.rectangle" : "hand.tap.fill"
    }

    private func bindServices() {
        sensorManager.onHit = { [weak self] hit in
            self?.accept(hit: hit, source: "Accelerometer")
        }

        surfaceTapMonitor.onTap = { [weak self] hit in
            self?.accept(hit: hit, source: "Mic Assist")
        }

        surfaceTapMonitor.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.transientStatus = $0 }
            .store(in: &cancellables)

        loginItemManager.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.transientStatus = $0 }
            .store(in: &cancellables)
    }

    private func accept(hit: HitEvent, source: String) {
        guard monitorInBackground else { return }
        guard hit.timestamp - lastAcceptedTapTime > 0.035 else { return }

        lastAcceptedTapTime = hit.timestamp
        lastTapSource = source
        processHit(hit)
    }

    private func processHit(_ hit: HitEvent) {
        if let played = audioEngine.play(region: hit.region, intensity: hit.intensity) {
            transientStatus = "\(lastTapSource) played \(played.role.rawValue) at \(String(format: "%.2f", hit.intensity))."
        }

        shortcuts.register(hit: hit, mapping: shortcutMapping) { [weak self] message in
            guard message.isEmpty == false else { return }
            self?.transientStatus = message
        }
    }
}
