import SwiftUI

struct StatusRingView: View {
    var percent: Double
    var color: Color
    var caption: String
    var showsBolt: Bool
    var accessibilityName: String
    var systemImage: String?
    var assetImage: String?

    private let diameter: CGFloat = 58
    private let lineWidth: CGFloat = 7

    var body: some View {
        let clamped = min(100, max(0, percent))
        let progress = clamped / 100
        VStack(spacing: 6) {
            ZStack {
                glassTrack

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter - lineWidth, height: diameter - lineWidth)

                glyph
                    .foregroundStyle(.primary)

                if showsBolt {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(color)
                        .offset(y: -(diameter / 2) + 1)
                }
            }
            .frame(width: diameter, height: diameter)

            Text(caption)
                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(accessibilityName) \(Int(clamped.rounded()))%"))
    }

    /// Liquid Glass is sampled as a circle, then masked to a stroke so the center stays hollow.
    private var glassTrack: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .glassEffect(.regular.interactive(), in: Circle())
            .mask {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .frame(width: diameter - lineWidth, height: diameter - lineWidth)
            }
    }

    @ViewBuilder
    private var glyph: some View {
        if let assetImage {
            // 20pt frame makes the inner die match cpu.fill at 17pt (~13.7pt square).
            Image(assetImage)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 20, height: 20)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
        }
    }
}
