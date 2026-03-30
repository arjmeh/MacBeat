import SwiftUI

@main
struct MacandrumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("Macandrum", systemImage: viewModel.menuBarSymbol) {
            MenuBarRootView(viewModel: viewModel)
                .frame(width: 440)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel, isStandalone: true)
                .frame(width: 460, height: 560)
                .preferredColorScheme(.dark)
        }
    }
}
