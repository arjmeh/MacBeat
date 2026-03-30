import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    let isStandalone: Bool

    private var macAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                hotKeyBadge
                Spacer(minLength: 12)
                Button(action: viewModel.toggleDrumsEnabled) {
                    VStack(spacing: 3) {
                        Text(viewModel.drumsEnabled ? "Drums On" : "Drums Off")
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.drumsEnabled ? "Live response enabled" : "No hits will play")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill((viewModel.drumsEnabled ? macAccent : Color.white).opacity(viewModel.drumsEnabled ? 0.20 : 0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder((viewModel.drumsEnabled ? macAccent : Color.white).opacity(viewModel.drumsEnabled ? 0.92 : 0.14), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                sliderDeck(
                    title: "Master Volume",
                    valueText: String(format: "%.0f%%", viewModel.volume * 100),
                    systemImage: "speaker.wave.3.fill",
                    tint: macAccent,
                    slider: AnyView(Slider(value: $viewModel.volume, in: 0...1))
                )

                sliderDeck(
                    title: "Tap Sensitivity",
                    valueText: String(format: "%.0f%%", viewModel.sensitivity * 100),
                    systemImage: "hand.tap.fill",
                    tint: Color(red: 0.98, green: 0.58, blue: 0.22),
                    slider: AnyView(Slider(value: $viewModel.sensitivity, in: 0.15...0.95))
                )

                sliderDeck(
                    title: "Cooldown",
                    valueText: String(format: "%.0f ms", viewModel.cooldown * 1000),
                    systemImage: "timer",
                    tint: Color(red: 0.64, green: 0.49, blue: 0.98),
                    slider: AnyView(Slider(value: $viewModel.cooldown, in: 0.04...0.35, step: 0.01))
                )
            }

            HStack(spacing: 10) {
                toggleChip(
                    title: "Microphone Assist",
                    systemImage: "mic.fill",
                    isOn: viewModel.microphoneAssistEnabled,
                    tint: macAccent
                ) {
                    viewModel.microphoneAssistEnabled.toggle()
                }
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
            }
        }
        .padding(14)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Placeholder Samples")
                .font(.headline)
            Text("Drop real WAV files into the sample folders listed in the project comments to replace the synthesized fallback sounds without changing code.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Electronic: `housekick.wav`, `househihat.wav`, `houseclap.wav`.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Acoustic: `acoustickick.wav`, `acousticsnare.wav`, `acoustichihat.wav`.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline)
            Text("Made with love — now tuned for fidgeters and desk drummers.")
                .font(.body.weight(.semibold))
            Text("MacBeat listens to the Apple Silicon accelerometer over IOKit HID, nudges the SPU driver awake for live reporting, and blends in microphone-assisted tap detection so soft finger rhythms still feel immediate.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.sensorManager.connectionMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                macAccent.opacity(0.10),
                                Color.white.opacity(0.035),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    private var hotKeyBadge: some View {
        Text("Hotkey: \(viewModel.hotKeyDescription)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
    }

    private func sliderDeck(title: String, valueText: String, systemImage: String, tint: Color, slider: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(valueText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            slider
                .tint(tint)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
                )
        )
    }

    private func toggleChip(title: String, systemImage: String, isOn: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn ? tint : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((isOn ? tint : Color.white).opacity(isOn ? 0.14 : 0.05))
                    )

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isOn ? tint : .secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill((isOn ? tint : Color.white).opacity(isOn ? 0.12 : 0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder((isOn ? tint : Color.white).opacity(isOn ? 0.36 : 0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
