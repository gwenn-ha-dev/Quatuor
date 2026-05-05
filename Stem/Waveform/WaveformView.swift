import SwiftUI

/// Symmetric waveform rendered with SwiftUI Canvas.
///
/// When `playbackProgress` is set, the waveform splits into a bright "played" region
/// and a dimmed "unplayed" region, with a white playhead line at the current position.
struct WaveformView: View {
    let peaks: [Float]
    let tint: Color
    /// Fraction of playback completed, in [0, 1]. `nil` hides the playhead.
    var playbackProgress: Double? = nil

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard !peaks.isEmpty else { return }
                let midY = size.height / 2
                let count = peaks.count
                let step = size.width / CGFloat(count)
                let halfH = size.height / 2

                let playedGradient = Gradient(colors: [
                    tint.opacity(0.95),
                    tint.opacity(0.55),
                    tint.opacity(0.95)
                ])

                let dimGradient = Gradient(colors: [
                    tint.opacity(0.3),
                    tint.opacity(0.15),
                    tint.opacity(0.3)
                ])

                let playX = playbackProgress.map { CGFloat($0) * size.width }

                var playedPath = Path()
                var unplayedPath = Path()

                for (i, p) in peaks.enumerated() {
                    let x = CGFloat(i) * step + step / 2
                    let h = CGFloat(p) * halfH * 0.95
                    let segment = Path { sp in
                        sp.move(to: CGPoint(x: x, y: midY - h))
                        sp.addLine(to: CGPoint(x: x, y: midY + h))
                    }
                    if let px = playX, x > px {
                        unplayedPath.addPath(segment)
                    } else {
                        playedPath.addPath(segment)
                    }
                }

                let lineStyle = StrokeStyle(
                    lineWidth: max(1.0, step * 0.8),
                    lineCap: .round
                )

                context.stroke(
                    playedPath,
                    with: .linearGradient(
                        playedGradient,
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    style: lineStyle
                )

                if playX != nil {
                    context.stroke(
                        unplayedPath,
                        with: .linearGradient(
                            dimGradient,
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        style: lineStyle
                    )
                }

                if let px = playX {
                    var playhead = Path()
                    playhead.move(to: CGPoint(x: px, y: 0))
                    playhead.addLine(to: CGPoint(x: px, y: size.height))
                    context.stroke(
                        playhead,
                        with: .color(.white.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 1.5)
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

#Preview {
    WaveformView(
        peaks: (0..<400).map { i in
            let t = Float(i) / 400
            return abs(sin(t * .pi * 6)) * (1 - t * 0.3)
        },
        tint: .accentColor
    )
    .frame(width: 600, height: 120)
    .padding()
}
