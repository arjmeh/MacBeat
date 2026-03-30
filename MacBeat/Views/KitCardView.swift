import AppKit
import SwiftUI

struct KitCardView: View {
    let kit: DrumKit
    let isSelected: Bool
    let action: () -> Void

    private var macAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: kit.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(macAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(kit.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(kit.subtitle)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 122, maxHeight: 122, alignment: .leading)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? macAccent.opacity(0.92) : Color.white.opacity(0.10), lineWidth: isSelected ? 1.6 : 1)
            )
            .shadow(color: isSelected ? macAccent.opacity(0.45) : .black.opacity(0.12), radius: isSelected ? 18 : 10, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.54),
                        Color.black.opacity(0.44)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                isSelected ? macAccent.opacity(0.18) : Color.white.opacity(0.02),
                                kit.gradient.last?.opacity(0.08) ?? .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}
