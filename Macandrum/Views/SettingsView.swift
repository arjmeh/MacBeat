import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    let isStandalone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            controlsCard
            if isStandalone {
                sampleCard
                aboutCard
            }
        }
        .padding(isStandalone ? 20 : 0)
        .background(isStandalone ? Color.black.opacity(0.92) : Color.clear)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.volume * 100))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.volume, in: 0...1)

                HStack {
                    Text("Tap sensitivity")
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.sensitivity * 100))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.sensitivity, in: 0.15...0.95)

                HStack {
                    Text("Cooldown")
                    Spacer()
                    Text(String(format: "%.0f ms", viewModel.cooldown * 1000))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.cooldown, in: 0.04...0.35, step: 0.01)

                Toggle("Microphone assist", isOn: $viewModel.microphoneAssistEnabled)
            }

            if isStandalone {
                Divider().overlay(.white.opacity(0.06))

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Keep monitoring in background", isOn: $viewModel.monitorInBackground)

                    Toggle(
                        "Open at login",
                        isOn: Binding(
                            get: { viewModel.loginItemManager.opensAtLogin },
                            set: { viewModel.loginItemManager.setEnabled($0) }
                        )
                    )

                    Picker("Shortcut mapper", selection: $viewModel.shortcutMapping) {
                        ForEach(ShortcutMapping.allCases) { mapping in
                            Text(mapping.title).tag(mapping)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text("Mic assist helps when you are lightly tapping while typing or thinking. macOS may ask for microphone access the first time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Placeholder Samples")
                .font(.headline)
            Text("Drop real WAV files into the sample folders listed in the project comments to replace the synthesized fallback sounds without changing code.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Meme mode: `meme_thunk.wav`, `office_clack.wav`, `halo_zing.wav`, `asmr_fizz.wav`.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Electronic: `808_kick.wav`, `hat.wav`, `stab.wav`, `clap.wav`.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Acoustic: `kick.wav`, `shaker.wav`, `tom.wav`, `snare.wav`.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline)
            Text("Made with love — now tuned for fidgeters and desk drummers.")
                .font(.body.weight(.semibold))
            Text("Macandrum listens to the Apple Silicon accelerometer over IOKit HID, nudges the SPU driver awake for live reporting, and blends in microphone-assisted tap detection so soft finger rhythms still feel immediate.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.sensorManager.connectionMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
