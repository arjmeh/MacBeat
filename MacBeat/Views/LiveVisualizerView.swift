import SwiftUI

struct LiveVisualizerView: View {
    @ObservedObject var sensorManager: SensorManager
    var isAmbient: Bool = false

    private var normalizedWaveform: [Double] {
        let samples = sensorManager.recentMagnitudes
        let peak = max(samples.max() ?? 1, 0.01)
        return samples.map { $0 / peak }
    }

    var body: some View {
        waveformPanel
    }

    private var waveformPanel: some View {
        ZStack {
            if isAmbient == false {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color(red: 0.79, green: 0.89, blue: 0.98).opacity(0.10),
                                Color(red: 0.90, green: 0.79, blue: 0.98).opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.18),
                                Color.pink.opacity(0.18),
                                Color.yellow.opacity(0.14),
                                Color.green.opacity(0.18)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Canvas { context, size in
                let rowCount = 4
                let colCount = 6
                let gridColor = Color.black.opacity(isAmbient ? 0.03 : 0.07)

                for row in 1..<rowCount {
                    let y = size.height * CGFloat(row) / CGFloat(rowCount)
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(gridColor), lineWidth: 1)
                }

                for column in 1..<colCount {
                    let x = size.width * CGFloat(column) / CGFloat(colCount)
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(line, with: .color(gridColor), lineWidth: 1)
                }

                let points = normalizedWaveform
                guard points.isEmpty == false else { return }

                var path = Path()
                for (index, point) in points.enumerated() {
                    let x = size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                    let centered = (point * 0.90) - 0.45
                    let y = size.height * (0.58 - CGFloat(centered))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                    context.stroke(path, with: .color(Color.cyan.opacity(isAmbient ? 0.14 : 0.24)), lineWidth: isAmbient ? 8 : 12)
                    context.stroke(path, with: .color(Color.pink.opacity(isAmbient ? 0.10 : 0.16)), lineWidth: isAmbient ? 14 : 18)
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [.cyan, .pink, .orange, .yellow, .green]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        lineWidth: isAmbient ? 2.5 : 3.5
                    )
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, minHeight: isAmbient ? 176 : 152)
        .overlay {
            if isAmbient == false {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
        }
        .mask {
            if isAmbient {
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.75),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle().fill(.black)
            }
        }
    }
}
