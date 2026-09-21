import SwiftUI

struct StatusRingView: View {
    var percent: Double
    var fillLeft: Color
    var fillRight: Color
    var caption: String
    var accessibilityName: String
    var glyph: GlyphSlot
    @Environment(\.colorScheme) private var colorScheme

    private let diameter: CGFloat = 58
    private let lineWidth: CGFloat = 7

    /// Match caption ink; hierarchical SF battery fills go white on glass.
    private var glyphInk: Color {
        colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.14)
    }

    var body: some View {
        let clamped = min(100, max(0, percent))
        let progress = clamped / 100
        let scale = CGFloat(glyph.normalizedScale)
        VStack(spacing: 6) {
            ZStack {
                glassTrack

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringStroke(progress: progress),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter - lineWidth, height: diameter - lineWidth)
                    .animation(.smooth(duration: 0.85), value: progress)
                    .animation(.smooth(duration: 0.85), value: fillLeft)
                    .animation(.smooth(duration: 0.85), value: fillRight)

                GlyphSlotView(
                    slot: glyph,
                    systemPointSize: 17 * scale,
                    assetSide: 20 * scale,
                    prefersMonochrome: true,
                    ink: glyphInk
                )
            }
            .frame(width: diameter, height: diameter)

            Text(caption)
                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .autoFittingCaption()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(accessibilityName) \(Int(clamped.rounded()))%"))
    }

    private func ringStroke(progress: Double) -> AnyShapeStyle {
        if fillLeft == fillRight {
            return AnyShapeStyle(fillLeft)
        }
        let sweep = max(progress, 0.002)
        return AnyShapeStyle(
            AngularGradient(
                colors: [fillLeft, fillRight],
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360 * sweep)
            )
        )
    }

    private var glassTrack: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .glassEffect(.regular, in: Circle())
            .mask {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .frame(width: diameter - lineWidth, height: diameter - lineWidth)
            }
    }
}

extension View {
    func autoFittingCaption(minimumScale: CGFloat = 0.6) -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(minimumScale)
            .allowsTightening(true)
    }
}
