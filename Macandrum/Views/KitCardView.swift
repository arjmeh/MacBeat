import SwiftUI

struct KitCardView: View {
    let kit: DrumKit
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: kit.systemImage)
                        .font(.body.weight(.bold))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }

                Text(kit.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(kit.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    ForEach(kit.pads) { pad in
                        Circle()
                            .fill(pad.color)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: kit.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(isSelected ? 0.7 : 0.15), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: isSelected ? 16 : 10, y: 6)
        }
        .buttonStyle(.plain)
    }
}
