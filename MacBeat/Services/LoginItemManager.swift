import Combine
import Foundation
import ServiceManagement

final class LoginItemManager: ObservableObject {
    @Published private(set) var opensAtLogin = false
    @Published private(set) var statusMessage = "Launch at login is available."

    init() {
        refresh()
    }

    func refresh() {
        if #available(macOS 13.0, *) {
            opensAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            opensAtLogin = false
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            statusMessage = "Launch at login requires macOS 13 or newer."
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
                statusMessage = "MacBeat will launch at login."
            } else {
                try SMAppService.mainApp.unregister()
                statusMessage = "Launch at login disabled."
            }
            refresh()
        } catch {
            statusMessage = "Could not update login item: \(error.localizedDescription)"
            refresh()
        }
    }
}
