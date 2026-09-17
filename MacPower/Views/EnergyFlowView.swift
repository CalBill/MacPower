import SwiftUI

struct EnergyFlowView: View {
    var snapshot: PowerSnapshot
    var theme: AppTheme
    var phase: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            diagram
            footer
        }
    }

    private var diagram: some View {
        GeometryReader { geo in
            let layout = layout(in: geo.size)
            ZStack {
                Color.clear
                    .frame(width: geo.size.width, height: geo.size.height)
                    .glassEffect(
                        .regular.tint(layout.fill.opacity(FlowRibbon.glassTintOpacity)).interactive(),
                        in: FlowRibbonShape(path: layout.body)
                    )
                Canvas { context, size in
                    context.drawLayer { powder in
                        powder.clip(to: layout.body, style: FillStyle(eoFill: false, antialiased: true))
                        for lane in layout.lanes {
                            drawPowder(context: &powder, lane: lane)
                        }
                    }
                    for lane in layout.lanes {
                        drawWattLabel(context: &context, lane: lane)
                    }
                }
                ForEach(layout.bubbles) { bubble in
                    flowNode(bubble.symbol, pulse: bubble.pulse)
                        .position(bubble.point)
                }
            }
        }
        .frame(height: diagramHeight)
    }

    private var diagramHeight: CGFloat {
        let trunk = FlowRibbon.trunkWidth(totalWatts: 1)
        return splitOrMerge ? trunk + 24 : trunk
    }

    private var splitOrMerge: Bool {
        snapshot.flowMode == .charging || snapshot.flowMode == .underpowered
    }

    private func flowNode(_ symbol: String, pulse: Bool) -> some View {
        let wave = sin(phase * .pi * 2)
        return Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: FlowRibbon.nodeDiameter, height: FlowRibbon.nodeDiameter)
            .scaleEffect(pulse && wave > 0.2 ? 1.04 : 1.0)
    }

    private struct Bubble: Identifiable {
        var id: String
        var symbol: String
        var point: CGPoint
        var pulse: Bool
    }

    private struct Lane {
        var id: String
        var cubic: FlowCubic
        var width: CGFloat
        var watts: Double
        var color: Color
    }

    private struct Layout {
        var body: Path
        var fill: Color
        var lanes: [Lane]
        var bubbles: [Bubble]
    }

    private func layout(in size: CGSize) -> Layout {
        let trunk = FlowRibbon.trunkWidth(totalWatts: 1)
        let midY = size.height / 2
        let inset = FlowRibbon.nodeDiameter / 2
        let logo = FlowRibbon.logoInset
        let left = CGPoint(x: inset, y: midY)
        let right = CGPoint(x: size.width - inset, y: midY)
        let leftLogo = CGPoint(x: logo, y: midY)
        let rightLogo = CGPoint(x: size.width - logo, y: midY)

        switch snapshot.flowMode {
        case .charging:
            let charge = max(snapshot.chargeWatts, 0.01)
            let load = max(snapshot.systemLoadWatts, 0.01)
            let widths = FlowRibbon.splitWidths(first: charge, second: load, trunk: trunk)
            let top = CGPoint(x: size.width - inset, y: widths.0 / 2)
            let bot = CGPoint(x: size.width - inset, y: size.height - widths.1 / 2)
            let topLane = ForkOutline.stackedLane(
                from: left,
                to: top,
                startY: left.y - trunk / 2 + widths.0 / 2,
                endY: top.y,
                holdT: FlowRibbon.forkT
            )
            let botLane = ForkOutline.stackedLane(
                from: left,
                to: bot,
                startY: left.y + trunk / 2 - widths.1 / 2,
                endY: bot.y,
                holdT: FlowRibbon.forkT
            )
            return Layout(
                body: ForkOutline.splitPath(left: left, top: top, bot: bot, topW: widths.0, botW: widths.1),
                fill: theme.charging,
                lanes: [
                    Lane(id: "to-battery", cubic: topLane, width: widths.0, watts: snapshot.chargeWatts, color: theme.charging),
                    Lane(id: "to-system", cubic: botLane, width: widths.1, watts: snapshot.systemLoadWatts, color: theme.charging)
                ],
                bubbles: [
                    Bubble(id: "supply", symbol: "bolt.fill", point: leftLogo, pulse: true),
                    Bubble(id: "battery", symbol: "battery.100percent.bolt", point: CGPoint(x: size.width - logo, y: top.y), pulse: true),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: CGPoint(x: size.width - logo, y: bot.y), pulse: false)
                ]
            )
        case .adapterHold:
            let watts = max(snapshot.systemLoadWatts, snapshot.adapterInWatts)
            return Layout(
                body: ForkOutline.capsule(from: left, to: right, width: trunk),
                fill: theme.adapterHold,
                lanes: [
                    Lane(
                        id: "adapter-system",
                        cubic: straightCubic(from: left, to: right),
                        width: trunk,
                        watts: watts,
                        color: theme.adapterHold
                    )
                ],
                bubbles: [
                    Bubble(id: "supply", symbol: "powerplug.fill", point: leftLogo, pulse: false),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: rightLogo, pulse: false)
                ]
            )
        case .discharging:
            let watts = max(snapshot.dischargeWatts, snapshot.systemLoadWatts)
            return Layout(
                body: ForkOutline.capsule(from: left, to: right, width: trunk),
                fill: theme.discharging,
                lanes: [
                    Lane(
                        id: "battery-system",
                        cubic: straightCubic(from: left, to: right),
                        width: trunk,
                        watts: watts,
                        color: theme.discharging
                    )
                ],
                bubbles: [
                    Bubble(id: "battery", symbol: "battery.100percent", point: leftLogo, pulse: true),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: rightLogo, pulse: true)
                ]
            )
        case .underpowered:
            let adapter = max(snapshot.adapterInWatts, 0.01)
            let battery = max(snapshot.dischargeWatts, 0.01)
            let widths = FlowRibbon.splitWidths(first: adapter, second: battery, trunk: trunk)
            let leftTop = CGPoint(x: inset, y: widths.0 / 2)
            let leftBot = CGPoint(x: inset, y: size.height - widths.1 / 2)
            let topLane = ForkOutline.stackedLane(
                from: leftTop,
                to: right,
                startY: leftTop.y,
                endY: right.y - trunk / 2 + widths.0 / 2,
                holdT: 1 - FlowRibbon.forkT
            )
            let botLane = ForkOutline.stackedLane(
                from: leftBot,
                to: right,
                startY: leftBot.y,
                endY: right.y + trunk / 2 - widths.1 / 2,
                holdT: 1 - FlowRibbon.forkT
            )
            return Layout(
                body: ForkOutline.mergePath(top: leftTop, bot: leftBot, right: right, topW: widths.0, botW: widths.1),
                fill: theme.underpowered,
                lanes: [
                    Lane(id: "adapter-system", cubic: topLane, width: widths.0, watts: snapshot.adapterInWatts, color: theme.underpowered),
                    Lane(id: "battery-system", cubic: botLane, width: widths.1, watts: snapshot.dischargeWatts, color: theme.discharging)
                ],
                bubbles: [
                    Bubble(id: "supply", symbol: "powerplug.fill", point: CGPoint(x: logo, y: leftTop.y), pulse: false),
                    Bubble(id: "battery", symbol: "battery.100percent", point: CGPoint(x: logo, y: leftBot.y), pulse: true),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: rightLogo, pulse: true)
                ]
            )
        }
    }

    private func straightCubic(from start: CGPoint, to end: CGPoint) -> FlowCubic {
        let dx = end.x - start.x
        return FlowCubic(
            p0: start,
            c1: CGPoint(x: start.x + dx * 0.45, y: start.y),
            c2: CGPoint(x: start.x + dx * 0.55, y: end.y),
            p1: end
        )
    }

    private func drawPowder(context: inout GraphicsContext, lane: Lane) {
        let seed = fnv(lane.id)
        let count = max(96, Int(lane.width * 7.2))

        context.drawLayer { blurred in
            blurred.addFilter(.blur(radius: 0.45))
            for index in 0..<count {
                drawGrain(context: &blurred, index: index, seed: seed, lane: lane, sharp: false)
            }
        }
        for index in 0..<count where index % 2 == 0 {
            drawGrain(context: &context, index: index, seed: seed, lane: lane, sharp: true)
        }
    }

    private func drawGrain(
        context: inout GraphicsContext,
        index: Int,
        seed: UInt64,
        lane: Lane,
        sharp: Bool
    ) {
        var rng = SplitMix64(seed: seed &+ UInt64(index) &* 0xD1B54A32D192ED03)
        let offset = rng.unit()
        let speed = FlowRibbon.particleSpeed(watts: lane.watts) * (0.82 + rng.unit() * 0.36)
        let radius = sharp ? rng.cg(0.55, 1.15) : rng.cg(0.7, 1.85)
        let maxOff = max(0.4, lane.width * 0.5 - radius - 0.6)
        let lateral = min(max(CGFloat(gaussian(rng.unit(), rng.unit())) * (maxOff * 0.82), -maxOff), maxOff)
        let wobbleAmp = rng.cg(0.2, min(1.1, maxOff * 0.22))
        let wobbleFreq = 5.0 + rng.unit() * 9.0
        let brightness = 0.55 + rng.unit() * 0.45

        var t = (phase * speed + offset).truncatingRemainder(dividingBy: 1)
        if t < 0 { t += 1 }
        let fade = pow(sin(t * .pi), 0.65)
        guard fade > 0.04 else { return }

        let pointOnCurve = lane.cubic.point(CGFloat(t))
        let normal = lane.cubic.normal(CGFloat(t))
        let wobble = sin((phase + offset) * wobbleFreq) * wobbleAmp
        let spread = min(max(lateral + wobble, -maxOff), maxOff)
        let x = pointOnCurve.x + normal.x * spread
        let y = pointOnCurve.y + normal.y * spread
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        let traveling = travelingColor(base: lane.color, t: t)
        let alpha = fade * brightness * (sharp ? 1.0 : 0.78)
        if sharp {
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.mix(with: traveling, by: 0.35).opacity(alpha)))
        } else {
            context.fill(Path(ellipseIn: rect), with: .color(traveling.opacity(alpha)))
            context.fill(
                Path(ellipseIn: rect.insetBy(dx: radius * 0.35, dy: radius * 0.35)),
                with: .color(Color.white.opacity(alpha * 0.45))
            )
        }
    }

    private func travelingColor(base: Color, t: Double) -> Color {
        let head = Color.white.mix(with: base, by: 0.32)
        let tail = base.mix(with: .black, by: 0.22)
        if t < 0.45 {
            return head.mix(with: base, by: t / 0.45)
        }
        return base.mix(with: tail, by: (t - 0.45) / 0.55)
    }

    private func drawWattLabel(context: inout GraphicsContext, lane: Lane) {
        let t: CGFloat = 0.52
        let point = lane.cubic.offsetPoint(t, distance: 0)
        let text = Text(String(format: "%.1f W", lane.watts))
            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.primary)
        context.draw(text, at: point, anchor: .center)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            labeled(String(localized: "energy.supplyPower"), value: supplyText)
            if snapshot.adapterCeilingWatts > 0, snapshot.externalConnected {
                labeled(String(localized: "energy.chargerRating"), value: String(format: "%.0f W", snapshot.adapterCeilingWatts))
            }
        }
        .font(.caption)
    }

    private var supplyText: String {
        switch snapshot.flowMode {
        case .charging, .adapterHold:
            return String(format: "%.1f W", snapshot.adapterInWatts)
        case .discharging:
            return String(format: "%.1f W", max(snapshot.dischargeWatts, snapshot.systemLoadWatts))
        case .underpowered:
            return String(format: "%.1f W", snapshot.adapterInWatts + snapshot.dischargeWatts)
        }
    }

    private func labeled(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
        }
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func cg(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        min + CGFloat(unit()) * (max - min)
    }
}

private func gaussian(_ u1: Double, _ u2: Double) -> Double {
    let a = max(u1, 1e-9)
    return sqrt(-2 * log(a)) * cos(2 * .pi * u2)
}

private func fnv(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}
