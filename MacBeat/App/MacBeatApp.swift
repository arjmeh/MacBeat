import SwiftUI

@main
struct MacBeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(viewModel: viewModel)
                .frame(width: 530)
                .preferredColorScheme(.light)
        } label: {
            MenuBarIconView(
                isEnabled: viewModel.drumsEnabled,
                isConnected: viewModel.sensorManager.connectionState == .connected
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel, isStandalone: true)
                .frame(width: 460, height: 560)
                .preferredColorScheme(.light)
        }
    }
}
