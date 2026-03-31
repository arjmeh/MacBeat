import AppKit
import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var viewModel: AppViewModel

    private var macAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

    private var sortedKits: [DrumKit] {
        let preferredOrder = ["electronic", "acoustic"]
        return viewModel.kits.sorted { lhs, rhs in
            (preferredOrder.firstIndex(of: lhs.id) ?? .max) < (preferredOrder.firstIndex(of: rhs.id) ?? .max)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBar
                Divider().overlay(Color.black.opacity(0.10))
                kitSelectionSection
                controlsSection
                routingSection
                footerSection
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(backgroundWash)
    }

    private var headerBar: some View {
        HStack {
            Text("MacBeat")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))

            Spacer()

            HStack(spacing: 10) {
                Text(viewModel.drumsEnabled ? "On" : "Off")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.78))

                Toggle("", isOn: Binding(
                    get: { viewModel.drumsEnabled },
                    set: { viewModel.drumsEnabled = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(macAccent)
            }
        }
    }

    private var kitSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kit Selection")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.80))

            HStack(spacing: 10) {
                ForEach(sortedKits) { kit in
                    KitCardView(
                        kit: kit,
                        isSelected: viewModel.selectedKitID == kit.id
                    ) {
                        viewModel.selectedKitID = kit.id
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                metricCard(
                    title: "Master Volume",
                    systemImage: "speaker.wave.2.fill",
                    valueText: String(format: "%.0f%%", viewModel.volume * 100),
                    tint: macAccent,
                    slider: AnyView(Slider(value: $viewModel.volume, in: 0...1))
                )

                metricCard(
                    title: "Tap Sensitivity",
                    systemImage: "hand.tap.fill",
                    valueText: String(format: "%.0f%%", viewModel.sensitivity * 100),
                    tint: Color(red: 0.98, green: 0.56, blue: 0.18),
                    slider: AnyView(Slider(value: $viewModel.sensitivity, in: 0.15...0.95))
                )
            }

            HStack(alignment: .top, spacing: 10) {
                metricCard(
                    title: "Cooldown",
                    systemImage: "timer",
                    valueText: String(format: "%.0f ms", viewModel.cooldown * 1000),
                    tint: Color(red: 0.68, green: 0.39, blue: 0.92),
                    slider: AnyView(Slider(value: $viewModel.cooldown, in: 0.04...0.35, step: 0.01))
                )

                micAssistPill
            }
        }
    }

    private var routingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tap Mapping")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.80))
            }

            HStack(alignment: .top, spacing: 10) {
                ForEach(SurfaceZone.allCases) { zone in
                    routingCard(for: zone)
                }
            }
        }
    }

    private var micAssistPill: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(viewModel.microphoneAssistEnabled ? macAccent : Color.black.opacity(0.62))

                Text("Microphone Assist")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.78))

                Spacer()

                Toggle("", isOn: $viewModel.microphoneAssistEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(macAccent)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricCard(title: String, systemImage: String, valueText: String, tint: Color, slider: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.70))

                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.78))

                Spacer()

                Text(valueText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.76))
            }

            slider
                .tint(tint)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func routingCard(for zone: SurfaceZone) -> some View {
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: zone.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.54))

                VStack(alignment: .leading, spacing: 1) {
                    Text(zone.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.80))

                    Text(zone.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
            }

            VStack(spacing: 7) {
                ForEach(PadRole.mappableCases, id: \.rawValue) { role in
                    roleChoiceButton(role: role, zone: zone, isSelected: viewModel.role(for: zone) == role)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    viewModel.role(for: zone).accentColor.opacity(0.10),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
                )
        )
    }

    private func roleChoiceButton(role: PadRole, zone: SurfaceZone, isSelected: Bool) -> some View {
        Button {
            viewModel.assign(role: role, to: zone)
        } label: {
            HStack(spacing: 8) {
                PadRoleIcon(role: role, tint: isSelected ? role.accentColor : Color.black.opacity(0.46))
                    .frame(width: 14, height: 14)

                Text(role.shortTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(isSelected ? 0.82 : 0.58))

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(role.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? role.accentColor.opacity(0.14) : Color.white.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? role.accentColor.opacity(0.42) : Color.black.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            Text("Hotkey: \(viewModel.hotKeyDescription)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.44))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Button {
                viewModel.quitApp()
            } label: {
                Text("Quit MacBeat")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.top, 2)
    }

    private var backgroundWash: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.80, green: 0.93, blue: 0.98).opacity(0.96),
                                Color(red: 0.86, green: 0.92, blue: 0.98).opacity(0.88),
                                Color(red: 0.90, green: 0.84, blue: 0.97).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                macAccent.opacity(0.18),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 20,
                            endRadius: 520
                        )
                    )
            )
            .overlay(
                Rectangle()
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

private struct PadRoleIcon: View {
    let role: PadRole
    let tint: Color

    var body: some View {
        Group {
            switch role {
            case .kick:
                roleImage(named: "kickdrum")
            case .snare:
                roleImage(named: "snare")
            case .hat:
                roleImage(named: "hihat")
            case .accent:
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
    }

    private func roleImage(named name: String) -> some View {
        Image(nsImage: NSImage(contentsOfFile: "/Users/arjunmehrotra/Downloads/Tappy/Tappy/MacBeat/Assets/PadIcons/\(name).png") ?? NSImage())
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(tint)
    }
}
