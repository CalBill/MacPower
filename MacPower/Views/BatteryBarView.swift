import SwiftUI

struct BatteryBarView: View {
    var percent: Double
    var fill: Color
    var sheenPhase: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let clamped = min(100, max(0, percent))
            let fillWidth = max(height, width * clamped / 100)
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: width, height: height)
                    .glassEffect(.regular.interactive(), in: .capsule)
                Color.clear
                    .frame(width: fillWidth, height: height)
                    .glassEffect(
                        .regular.tint(fill.opacity(FlowRibbon.glassTintOpacity)).interactive(),
                        in: .capsule
                    )
                sheen(width: width, height: height)
                    .frame(width: fillWidth, height: height)
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                Text("\(Int(clamped.rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: FlowRibbon.nodeDiameter)
        .accessibilityLabel(Text("battery.percent \(Int(percent.rounded()))"))
    }

    private func sheen(width: CGFloat, height: CGFloat) -> some View {
        let travel = width + 48
        let x = CGFloat(sheenPhase.truncatingRemainder(dividingBy: 1)) * travel - 24
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 36, height: height)
            .offset(x: x)
            .blendMode(.plusLighter)
    }
}
