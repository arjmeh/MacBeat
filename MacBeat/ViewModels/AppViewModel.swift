import Combine
import Foundation
import Carbon
import AppKit

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
    @Published var leftZoneRole: PadRole {
        didSet {
            defaults.set(leftZoneRole.rawValue, forKey: Keys.leftZoneRole)
            applySurfaceRouting()
        }
    }
    @Published var centerZoneRole: PadRole {
        didSet {
            defaults.set(centerZoneRole.rawValue, forKey: Keys.centerZoneRole)
            applySurfaceRouting()
        }
    }
    @Published var rightZoneRole: PadRole {
        didSet {
            defaults.set(rightZoneRole.rawValue, forKey: Keys.rightZoneRole)
            applySurfaceRouting()
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
        static let leftZoneRole = "app.leftZoneRole"
        static let centerZoneRole = "app.centerZoneRole"
        static let rightZoneRole = "app.rightZoneRole"
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
        leftZoneRole = AppViewModel.loadStoredRole(defaults.string(forKey: Keys.leftZoneRole), fallback: .snare)
        centerZoneRole = AppViewModel.loadStoredRole(defaults.string(forKey: Keys.centerZoneRole), fallback: .hat)
        rightZoneRole = AppViewModel.loadStoredRole(defaults.string(forKey: Keys.rightZoneRole), fallback: .kick)

        normalizeSurfaceRouting()

        audioEngine.setMasterVolume(volume)
        sensorManager.sensitivity = sensitivity
        sensorManager.cooldown = cooldown
        surfaceTapMonitor.sensitivity = sensitivity
        surfaceTapMonitor.cooldown = cooldown
        surfaceTapMonitor.isEnabled = microphoneAssistEnabled
        defaults.set(microphoneAssistEnabled, forKey: Keys.microphoneAssist)
        defaults.set(shortcutMapping.rawValue, forKey: Keys.shortcutMapping)
        audioEngine.selectKit(id: kitID)
        applySurfaceRouting()

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

    var hotKeyDescription: String {
        "Ctrl + Option + Command + D"
    }

    func toggleDrumsEnabled() {
        drumsEnabled.toggle()
    }

    func role(for zone: SurfaceZone) -> PadRole {
        switch zone {
        case .left:
            return leftZoneRole
        case .center:
            return centerZoneRole
        case .right:
            return rightZoneRole
        }
    }

    func assign(role: PadRole, to zone: SurfaceZone) {
        guard PadRole.mappableCases.contains(role) else { return }

        let previous = self.role(for: zone)
        guard previous != role else { return }

        if let existingZone = SurfaceZone.allCases.first(where: { self.role(for: $0) == role }) {
            setRole(previous, for: existingZone)
        }

        setRole(role, for: zone)
        transientStatus = "\(zone.title) now plays \(role.shortTitle.lowercased())."
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private static func loadStoredRole(_ rawValue: String?, fallback: PadRole) -> PadRole {
        guard let rawValue, let role = PadRole(rawValue: rawValue), PadRole.mappableCases.contains(role) else {
            return fallback
        }
        return role
    }

    private func setRole(_ role: PadRole, for zone: SurfaceZone) {
        switch zone {
        case .left:
            leftZoneRole = role
        case .center:
            centerZoneRole = role
        case .right:
            rightZoneRole = role
        }
    }

    private func normalizeSurfaceRouting() {
        var used: Set<PadRole> = []
        for zone in SurfaceZone.allCases {
            let currentRole = role(for: zone)
            if used.contains(currentRole) {
                if let replacement = PadRole.mappableCases.first(where: { used.contains($0) == false }) {
                    setRole(replacement, for: zone)
                    used.insert(replacement)
                }
            } else {
                used.insert(currentRole)
            }
        }
    }

    private func applySurfaceRouting() {
        audioEngine.setSurfaceRouting(left: leftZoneRole, center: centerZoneRole, right: rightZoneRole)
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
