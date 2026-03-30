import SwiftUI

struct LiveVisualizerView: View {
    @ObservedObject var sensorManager: SensorManager

    private var normalizedWaveform: [Double] {
        let samples = sensorManager.recentMagnitudes
        let peak = max(samples.max() ?? 1, 0.01)
        return samples.map { $0 / peak }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live Hit Visualizer")
                    .font(.headline)
                Spacer()
                Text(sensorManager.lastHit?.region.title ?? "Listening")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sensorManager.lastHit?.region.accent ?? .secondary)
            }

            HStack(spacing: 12) {
                waveformCard
                hitMap
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var waveformCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                Canvas { context, size in
                    var path = Path()
                    let points = normalizedWaveform
                    guard points.isEmpty == false else { return }

                    for (index, point) in points.enumerated() {
                        let x = size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                        let centered = (point * 0.85) - 0.425
                        let y = size.height * (0.5 - CGFloat(centered))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [.cyan, .pink, .green]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        ),
                        lineWidth: 2.5
                    )
                }
            }
            .frame(height: 90)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(tileBackground)
    }

    private var hitMap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hit Map")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                let hitRegion = sensorManager.lastHit?.region
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))

                    VStack(spacing: 8) {
                        regionTile(.top, selected: hitRegion == .top)
                        HStack(spacing: 8) {
                            regionTile(.left, selected: hitRegion == .left)
                            regionTile(.center, selected: hitRegion == .center)
                            regionTile(.right, selected: hitRegion == .right)
                        }
                        regionTile(.bottom, selected: hitRegion == .bottom)
                    }
                    .padding(10)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(width: 132, height: 132)
        }
        .padding(12)
        .background(tileBackground)
    }

    private func regionTile(_ region: ChassisRegion, selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(selected ? region.accent.opacity(0.9) : Color.white.opacity(0.07))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                Image(systemName: region.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(selected ? .black : .white.opacity(0.65))
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}
