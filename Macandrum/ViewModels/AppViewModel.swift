import Combine
import Foundation
import Carbon

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
    @Published var drumsEnabled: Bool {
        didSet {
            defaults.set(drumsEnabled, forKey: Keys.drumsEnabled)
            transientStatus = drumsEnabled ? "Drums are on." : "Drums are off."
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
    private let hotKeyMonitor = GlobalToggleHotKey()
    private var cancellables = Set<AnyCancellable>()
    private var lastAcceptedTapTime = 0.0

    private enum Keys {
        static let selectedKitID = "app.selectedKitID"
        static let sensitivity = "app.sensitivity"
        static let cooldown = "app.cooldown"
        static let volume = "app.volume"
        static let drumsEnabled = "app.drumsEnabled"
        static let background = "app.backgroundMonitoring"
        static let shortcutMapping = "app.shortcutMapping"
        static let microphoneAssist = "app.microphoneAssist"
    }

    init() {
        let storedKitID = defaults.string(forKey: Keys.selectedKitID)
        let fallbackKitID = audioEngine.kits.first?.id ?? "electronic"
        let kitID = audioEngine.kits.contains(where: { $0.id == storedKitID }) ? storedKitID! : fallbackKitID
        selectedKitID = kitID
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.92
        drumsEnabled = defaults.object(forKey: Keys.drumsEnabled) as? Bool ?? true
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
        hotKeyMonitor.onPress = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleDrumsEnabled()
            }
        }
        hotKeyMonitor.register()
        if monitorInBackground {
            sensorManager.start()
            surfaceTapMonitor.start()
        }
    }

    deinit {
        hotKeyMonitor.unregister()
    }

    var kits: [DrumKit] {
        audioEngine.kits
    }

    var menuBarSymbol: String {
        if drumsEnabled == false {
            return "pause.circle.fill"
        }
        return sensorManager.connectionState == .connected ? "waveform.path.ecg.rectangle" : "hand.tap.fill"
    }

    var hotKeyDescription: String {
        "Ctrl + Option + Command + D"
    }

    func toggleDrumsEnabled() {
        drumsEnabled.toggle()
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
        guard drumsEnabled else { return }
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

private final class GlobalToggleHotKey {
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4D434452), id: 1)

    func register() {
        unregister()

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard
                    let userData,
                    let event,
                    GetEventClass(event) == OSType(kEventClassKeyboard),
                    GetEventKind(event) == UInt32(kEventHotKeyPressed)
                else {
                    return OSStatus(eventNotHandledErr)
                }

                let hotKey = Unmanaged<GlobalToggleHotKey>.fromOpaque(userData).takeUnretainedValue()
                var pressedID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )

                guard status == noErr, pressedID.signature == hotKey.hotKeyID.signature, pressedID.id == hotKey.hotKeyID.id else {
                    return OSStatus(eventNotHandledErr)
                }

                hotKey.onPress?()
                return noErr
            },
            1,
            &eventSpec,
            selfPointer,
            &handlerRef
        )

        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
