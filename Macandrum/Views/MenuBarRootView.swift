import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var viewModel: AppViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LiveVisualizerView(sensorManager: viewModel.sensorManager)
                kitsSection
                SettingsView(viewModel: viewModel, isStandalone: false)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.08), Color(red: 0.10, green: 0.12, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        Text("Macandrum")
            .font(.system(size: 24, weight: .bold, design: .rounded))
    }

    private var kitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kits")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.kits) { kit in
                    KitCardView(
                        kit: kit,
                        isSelected: viewModel.selectedKitID == kit.id
                    ) {
                        viewModel.selectedKitID = kit.id
                    }
                }
            }
        }
    }
}
