import SwiftUI

struct EnergyFlowView: View {
    var snapshot: PowerSnapshot
    var theme: AppTheme
    var isAnimating: Bool
    var motion: EnergyMotionStyle
    var motionFrameRate: EnergyMotionFrameRate = .hz60
    var pulseFlowIcons: Bool
    var language: AppLanguage
    var showsFooter: Bool = true

    @State private var outgoingSnapshot: PowerSnapshot?
    @State private var transitionProgress = 1.0
    @State private var cleanupTask: Task<Void, Never>?

    var body: some View {
        diagram(
            for: snapshot,
            morph: outgoingSnapshot.map { FlowMorph(from: $0, progress: transitionProgress) }
        )
        .onChange(of: snapshot) { previous, current in
            guard previous.flowMode != current.flowMode else { return }
            beginTransition(from: previous)
        }
        .onDisappear {
            cleanupTask?.cancel()
        }
    }

    private func diagram(for snapshot: PowerSnapshot, morph: FlowMorph? = nil) -> some View {
        EnergyFlowDiagram(
            snapshot: snapshot,
            theme: theme,
            isAnimating: isAnimating,
            motion: motion,
            motionFrameRate: motionFrameRate,
            pulseFlowIcons: pulseFlowIcons,
            language: language,
            showsFooter: showsFooter,
            morph: morph
        )
    }

    private func beginTransition(from previous: PowerSnapshot) {
        cleanupTask?.cancel()
        outgoingSnapshot = previous
        transitionProgress = 0
        withAnimation(.easeInOut(duration: 1.05)) {
            transitionProgress = 1
        }
        cleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_120))
            guard !Task.isCancelled else { return }
            outgoingSnapshot = nil
        }
    }
}

private struct FlowMorph {
    var from: PowerSnapshot
    var progress: Double
}

private struct EnergyFlowDiagram: View {
    var snapshot: PowerSnapshot
    var theme: AppTheme
    var isAnimating: Bool
    var motion: EnergyMotionStyle
    var motionFrameRate: EnergyMotionFrameRate = .hz60
    var pulseFlowIcons: Bool
    var language: AppLanguage
    var showsFooter: Bool = true
    /// During a mode change, the ribbon geometry and pigment interpolate from
    /// the old telemetry reading to the new one.
    var morph: FlowMorph?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            diagram
            if showsFooter {
                footer
            }
        }
    }

    private var diagram: some View {
        GeometryReader { geo in
            let layout = layout(in: geo.size, morph: morph)
            // Glass is Equatable and only depends on shape/tint. Motion lives in an
            // overlay rasterized with drawingGroup so 60 fps Canvas ticks do not
            // resample glassEffect.
            RibbonGlassSlot(
                size: geo.size,
                mode: snapshot.flowMode,
                fill: layout.fill,
                splitOrMerge: splitOrMerge || layout.isMorphing,
                bodyPath: layout.body,
                laneSignature: laneSignature(layout)
            )
            .equatable()
            .overlay {
                ZStack {
                    motionOverlay(layout: layout)
                    wattLabels(layout: layout)
                    iconLayer(layout: layout, size: geo.size)
                }
            }
        }
        .frame(height: diagramHeight)
    }

    @ViewBuilder
    private func motionOverlay(layout: Layout) -> some View {
        if isAnimating, motion.usesCanvasTimeline {
            TimelineView(.periodic(from: .now, by: 1.0 / motionFrameRate.framesPerSecond)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate / 4.6
                Canvas { context, _ in
                    context.clip(to: layout.body, style: FillStyle(eoFill: false, antialiased: true))
                    switch motion {
                    case .sheen:
                        drawSheen(context: &context, layout: layout, phase: phase)
                    case .filaments, .filamentsSolid, .filamentsWhite:
                        for lane in layout.lanes {
                            drawFilaments(
                                context: &context,
                                lane: lane,
                                phase: phase,
                                pigment: motion.pigment ?? .gradient,
                                baseColor: layout.fill
                            )
                        }
                    case .particles, .particlesSolid, .particlesWhite:
                        for lane in layout.lanes {
                            drawPowder(
                                context: &context,
                                lane: lane,
                                phase: phase,
                                pigment: motion.pigment ?? .gradient,
                                baseColor: layout.fill
                            )
                        }
                    case .off:
                        break
                    }
                }
                .drawingGroup(opaque: false)
            }
            .allowsHitTesting(false)
        }
    }

    private func wattLabels(layout: Layout) -> some View {
        Canvas { context, _ in
            for lane in layout.lanes {
                drawWattLabel(context: &context, lane: lane)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func iconLayer(layout: Layout, size: CGSize) -> some View {
        if isAnimating, pulseFlowIcons {
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                let breath = iconBreath(at: timeline.date)
                ZStack {
                    if let outgoing = layout.outgoingBubbles,
                       let progress = layout.morphProgress {
                        bubbleStack(outgoing, breath: breath)
                            .opacity(1 - progress)
                        bubbleStack(layout.bubbles, breath: breath)
                            .opacity(progress)
                    } else {
                        bubbleStack(layout.bubbles, breath: breath)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        } else {
            ZStack {
                if let outgoing = layout.outgoingBubbles,
                   let progress = layout.morphProgress {
                    bubbleStack(outgoing, breath: 0)
                        .opacity(1 - progress)
                    bubbleStack(layout.bubbles, breath: 0)
                        .opacity(progress)
                } else {
                    bubbleStack(layout.bubbles, breath: 0)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func bubbleStack(_ bubbles: [Bubble], breath: CGFloat) -> some View {
        ForEach(bubbles) { bubble in
            flowNode(bubble, breath: breath)
                .position(bubble.point)
        }
    }

    private func laneSignature(_ layout: Layout) -> Int {
        var hasher = Hasher()
        for lane in layout.lanes {
            hasher.combine(Int((lane.width * 10).rounded()))
            hasher.combine(Int((lane.watts * 10).rounded()))
            for point in [lane.cubic.p0, lane.cubic.c1, lane.cubic.c2, lane.cubic.p1] {
                hasher.combine(Int((point.x * 10).rounded()))
                hasher.combine(Int((point.y * 10).rounded()))
            }
        }
        return hasher.finalize()
    }

    /// Liquid Glass for the ribbon. Equality ignores animation phase so SwiftUI
    /// can skip resampling when only the particle overlay ticks.
    private struct RibbonGlassSlot: View, @MainActor Equatable {
        var size: CGSize
        var mode: EnergyFlowMode
        var fill: Color
        var splitOrMerge: Bool
        var bodyPath: Path
        var laneSignature: Int

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.size == rhs.size
                && lhs.mode == rhs.mode
                && lhs.fill == rhs.fill
                && lhs.splitOrMerge == rhs.splitOrMerge
                && lhs.laneSignature == rhs.laneSignature
        }

        var body: some View {
            let tint = fill.opacity(FlowRibbon.glassTintOpacity)
            let stadium = RoundedRectangle(
                cornerRadius: FlowRibbon.capRadius(for: FlowRibbon.trunkWidth(totalWatts: 1)),
                style: .continuous
            )
            let sampled = Color.clear
                .frame(width: size.width, height: size.height)
                .glassEffect(.regular.tint(tint), in: stadium)
            ZStack {
                FlowRibbonShape(path: bodyPath)
                    .fill(tint)
                if splitOrMerge {
                    // Light a system stadium SDF, then mask to the Y. Sampling glass
                    // in the custom fork path plants a vertex specular on each round
                    // finger cap (the blob next to the laptop).
                    sampled.mask { FlowRibbonShape(path: bodyPath) }
                } else {
                    sampled
                }
            }
        }
    }

    private var diagramHeight: CGFloat {
        let trunk = FlowRibbon.trunkWidth(totalWatts: 1)
        // Reserve fork headroom in every power state so connecting, charging,
        // and unplugging never resize the surrounding popover.
        return trunk + 24
    }

    private var splitOrMerge: Bool {
        snapshot.flowMode == .charging || snapshot.flowMode == .underpowered
    }

    @ViewBuilder
    private func flowNode(_ bubble: Bubble, breath: CGFloat) -> some View {
        Group {
            if let asset = bubble.asset {
                Image(asset)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 16, height: 24)
            } else if let symbol = bubble.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(.primary)
        .scaleEffect(1 + 0.16 * breath)
        .opacity(1 - 0.32 * breath)
        .frame(width: FlowRibbon.nodeDiameter, height: FlowRibbon.nodeDiameter)
    }

    private func iconBreath(at date: Date) -> CGFloat {
        let period = 2.1
        let turns = date.timeIntervalSinceReferenceDate / period
        return CGFloat(0.5 - 0.5 * cos(turns * 2 * .pi))
    }

    private struct Bubble: Identifiable {
        var id: String
        var symbol: String?
        var asset: String?
        var point: CGPoint
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
        var outgoingBubbles: [Bubble]? = nil
        var morphProgress: Double? = nil
        var isMorphing = false
    }

    private func layout(in size: CGSize, morph: FlowMorph?) -> Layout {
        guard let morph else {
            return layout(in: size, snapshot: snapshot)
        }

        let progress = min(max(morph.progress, 0), 1)
        let from = layout(in: size, snapshot: morph.from)
        let to = layout(in: size, snapshot: snapshot)
        guard progress > 0.001, progress < 0.999 else {
            return progress <= 0.001 ? from : to
        }

        let lanes = interpolateLanes(from.lanes, to.lanes, progress: progress)
        return Layout(
            body: bodyPath(for: lanes),
            fill: from.fill.mix(with: to.fill, by: progress),
            lanes: lanes,
            bubbles: to.bubbles,
            outgoingBubbles: from.bubbles,
            morphProgress: progress,
            isMorphing: true
        )
    }

    private func layout(in size: CGSize, snapshot: PowerSnapshot) -> Layout {
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
                    Bubble(id: "supply", asset: "ChargeMark", point: leftLogo),
                    Bubble(id: "battery", symbol: "battery.100percent.bolt", point: CGPoint(x: size.width - logo, y: top.y)),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: CGPoint(x: size.width - logo, y: bot.y))
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
                    Bubble(id: "supply", asset: "ChargeMark", point: leftLogo),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: rightLogo)
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
                    Bubble(id: "battery", symbol: "battery.100percent", point: leftLogo),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: rightLogo)
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
                    Bubble(id: "supply", asset: "ChargeMark", point: CGPoint(x: logo, y: leftTop.y)),
                    Bubble(id: "battery", symbol: "battery.100percent", point: CGPoint(x: logo, y: leftBot.y)),
                    Bubble(id: "mac", symbol: "laptopcomputer", point: rightLogo)
                ]
            )
        }
    }

    private func interpolateLanes(_ from: [Lane], _ to: [Lane], progress: Double) -> [Lane] {
        let start = expandedLanes(from)
        let end = expandedLanes(to)
        return zip(start, end).enumerated().map { index, pair in
            let (a, b) = pair
            return Lane(
                id: "morph-\(index)",
                cubic: interpolate(a.cubic, b.cubic, progress: progress),
                width: interpolate(a.width, b.width, progress: progress),
                watts: interpolate(a.watts, b.watts, progress: progress),
                color: a.color.mix(with: b.color, by: progress)
            )
        }
    }

    /// Every state is expressed as two channels while morphing. A single path
    /// temporarily becomes two coincident paths, which can then peel apart or
    /// converge without ever snapping to a new diagram.
    private func expandedLanes(_ lanes: [Lane]) -> [Lane] {
        guard let first = lanes.first else { return [] }
        return lanes.count == 1 ? [first, first] : Array(lanes.prefix(2))
    }

    private func interpolate(_ from: FlowCubic, _ to: FlowCubic, progress: Double) -> FlowCubic {
        FlowCubic(
            p0: interpolate(from.p0, to.p0, progress: progress),
            c1: interpolate(from.c1, to.c1, progress: progress),
            c2: interpolate(from.c2, to.c2, progress: progress),
            p1: interpolate(from.p1, to.p1, progress: progress)
        )
    }

    private func interpolate(_ from: CGPoint, _ to: CGPoint, progress: Double) -> CGPoint {
        CGPoint(
            x: interpolate(from.x, to.x, progress: progress),
            y: interpolate(from.y, to.y, progress: progress)
        )
    }

    private func interpolate(_ from: CGFloat, _ to: CGFloat, progress: Double) -> CGFloat {
        from + (to - from) * CGFloat(progress)
    }

    private func interpolate(_ from: Double, _ to: Double, progress: Double) -> Double {
        from + (to - from) * progress
    }

    private func bodyPath(for lanes: [Lane]) -> Path {
        var silhouette = Path()
        for lane in lanes {
            var centerline = Path()
            centerline.move(to: lane.cubic.p0)
            centerline.addCurve(to: lane.cubic.p1, control1: lane.cubic.c1, control2: lane.cubic.c2)
            silhouette.addPath(
                centerline.strokedPath(
                    StrokeStyle(lineWidth: lane.width, lineCap: .round, lineJoin: .round)
                )
            )
        }
        return silhouette
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

    /// Full-height wash across the capsule; a soft peak travels left → right.
    private func drawSheen(context: inout GraphicsContext, layout: Layout, phase: Double) {
        let watts = layout.lanes.map(\.watts).max() ?? 1
        let speed = FlowRibbon.sheenSpeed(watts: watts)
        var t = (phase * speed).truncatingRemainder(dividingBy: 1)
        if t < 0 { t += 1 }

        let bounds = layout.body.boundingRect
        guard bounds.width > 1, bounds.height > 1 else { return }

        let color = layout.fill
        let halo = Color.white.mix(with: color, by: 0.42)
        let core = Color.white.mix(with: color, by: 0.08)
        // Peak covers about a third of the capsule so it reads as a band, not a speck.
        let stops = sheenStops(peak: t, half: 0.18, halo: halo, core: core)

        context.fill(
            Path(bounds),
            with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: bounds.minX, y: bounds.midY),
                endPoint: CGPoint(x: bounds.maxX, y: bounds.midY)
            )
        )
    }

    private func sheenStops(peak: Double, half: Double, halo: Color, core: Color) -> [Gradient.Stop] {
        var raw: [(CGFloat, Color)] = [(0, .clear), (1, .clear)]
        func add(_ location: Double, _ color: Color) {
            raw.append((CGFloat(min(1, max(0, location))), color))
        }
        add(peak - half, .clear)
        add(peak - half * 0.55, halo.opacity(0.28))
        add(peak - half * 0.18, core.opacity(0.52))
        add(peak, core.opacity(0.70))
        add(peak + half * 0.18, core.opacity(0.52))
        add(peak + half * 0.55, halo.opacity(0.28))
        add(peak + half, .clear)

        let merged = Dictionary(raw, uniquingKeysWith: { _, last in last })
            .sorted { $0.key < $1.key }
        var stops: [Gradient.Stop] = []
        for (location, color) in merged {
            if let last = stops.last, last.location == location { continue }
            stops.append(.init(color: color, location: location))
        }
        return stops
    }

    private func drawFilaments(
        context: inout GraphicsContext,
        lane: Lane,
        phase: Double,
        pigment: FlowMotionPigment,
        baseColor: Color
    ) {
        let seed = fnv(lane.id)
        let count = FlowRibbon.filamentCount(laneWidth: lane.width)
        for index in 0..<count {
            var rng = SplitMix64(seed: seed &+ UInt64(index) &* 0x9E3779B97F4A7C15)
            let offset = rng.unit()
            let speed = FlowRibbon.filamentSpeed(watts: lane.watts) * (0.72 + rng.unit() * 0.40)
            let length = 0.18 + rng.unit() * 0.22
            let thickness = rng.cg(0.8, 1.4)
            let maxOff = max(0.6, lane.width * 0.42)
            let lateral = rng.cg(-maxOff, maxOff)
            var t = (phase * speed + offset).truncatingRemainder(dividingBy: 1)
            if t < 0 { t += 1 }
            for (from, to) in wrappedRanges(center: t + length / 2, span: length) where to - from > 0.02 {
                fillFilament(
                    context: &context,
                    lane: lane,
                    from: from,
                    to: to,
                    lateral: lateral,
                    thickness: thickness,
                    pigment: pigment,
                    baseColor: baseColor
                )
            }
        }
    }

    /// Spindle fill, not a constant-width stroke: sides converge to a needle at both tips
    /// so the bright mid-span cannot read as two parallel edges.
    private func fillFilament(
        context: inout GraphicsContext,
        lane: Lane,
        from: Double,
        to: Double,
        lateral: CGFloat,
        thickness: CGFloat,
        pigment: FlowMotionPigment,
        baseColor: Color
    ) {
        let start = lane.cubic.offsetPoint(CGFloat(from), distance: lateral)
        let end = lane.cubic.offsetPoint(CGFloat(to), distance: lateral)
        let body = filamentSpindle(lane: lane, from: from, to: to, lateral: lateral, thickness: thickness)
        switch pigment {
        case .gradient:
            let head = travelingColor(base: baseColor, t: from)
            let mid = travelingColor(base: baseColor, t: (from + to) / 2)
            let tail = travelingColor(base: baseColor, t: to)
            context.fill(
                body,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: head.opacity(0), location: 0),
                        .init(color: head.opacity(0.88), location: 0.16),
                        .init(color: mid.opacity(0.96), location: 0.5),
                        .init(color: tail.opacity(0.88), location: 0.84),
                        .init(color: tail.opacity(0), location: 1)
                    ]),
                    startPoint: start,
                    endPoint: end
                )
            )
            context.fill(
                filamentSpindle(lane: lane, from: from, to: to, lateral: lateral, thickness: thickness * 0.36),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.white.opacity(0.55), location: 0.28),
                        .init(color: Color.white.opacity(0.88), location: 0.5),
                        .init(color: Color.white.opacity(0.55), location: 0.72),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: start,
                    endPoint: end
                )
            )
        case .solid, .white:
            let color: Color = pigment == .white ? .white : baseColor.mix(with: .black, by: 0.42)
            context.fill(
                body,
                with: .linearGradient(tipFade(color), startPoint: start, endPoint: end)
            )
        }
    }

    private func tipFade(_ color: Color) -> Gradient {
        Gradient(stops: [
            .init(color: color.opacity(0), location: 0),
            .init(color: color.opacity(0.82), location: 0.16),
            .init(color: color.opacity(0.96), location: 0.5),
            .init(color: color.opacity(0.82), location: 0.84),
            .init(color: color.opacity(0), location: 1)
        ])
    }

    private func filamentSpindle(
        lane: Lane,
        from: Double,
        to: Double,
        lateral: CGFloat,
        thickness: CGFloat
    ) -> Path {
        let steps = max(8, Int(((to - from) * 36).rounded(.up)))
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        upper.reserveCapacity(steps + 1)
        lower.reserveCapacity(steps + 1)
        for index in 0...steps {
            let frac = Double(index) / Double(steps)
            let u = from + (to - from) * frac
            let half = thickness * 0.5 * filamentEnvelope(frac)
            let point = lane.cubic.offsetPoint(CGFloat(u), distance: lateral)
            let normal = lane.cubic.normal(CGFloat(u))
            upper.append(CGPoint(x: point.x + normal.x * half, y: point.y + normal.y * half))
            lower.append(CGPoint(x: point.x - normal.x * half, y: point.y - normal.y * half))
        }
        var path = Path()
        path.move(to: upper[0])
        for point in upper.dropFirst() { path.addLine(to: point) }
        for point in lower.reversed() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    /// 0 at both tips, 1 at mid-span. No plateau, so sides never run parallel.
    private func filamentEnvelope(_ fraction: Double) -> CGFloat {
        let tip = min(max(min(fraction, 1 - fraction) * 2, 0), 1)
        return CGFloat(pow(tip, 1.35))
    }

    private func wrappedRanges(center: Double, span: Double) -> [(Double, Double)] {
        var start = center - span / 2
        start = start.truncatingRemainder(dividingBy: 1)
        if start < 0 { start += 1 }
        let end = start + span
        if end <= 1 {
            return [(start, end)]
        }
        return [(start, 1), (0, end - 1)]
    }

    private func drawPowder(
        context: inout GraphicsContext,
        lane: Lane,
        phase: Double,
        pigment: FlowMotionPigment,
        baseColor: Color
    ) {
        let seed = fnv(lane.id)
        let count = FlowRibbon.particleCount(laneWidth: lane.width)
        for index in 0..<count {
            drawGrain(
                context: &context,
                index: index,
                seed: seed,
                lane: lane,
                phase: phase,
                pigment: pigment,
                baseColor: baseColor
            )
        }
    }

    private func drawGrain(
        context: inout GraphicsContext,
        index: Int,
        seed: UInt64,
        lane: Lane,
        phase: Double,
        pigment: FlowMotionPigment,
        baseColor: Color
    ) {
        var rng = SplitMix64(seed: seed &+ UInt64(index) &* 0xD1B54A32D192ED03)
        let offset = rng.unit()
        let speed = FlowRibbon.filamentSpeed(watts: lane.watts) * 0.42 * (0.82 + rng.unit() * 0.36)
        let radius = rng.cg(0.7, 1.55)
        let maxOff = max(0.4, lane.width * 0.5 - radius - 0.6)
        let lateral = min(max(CGFloat(gaussian(rng.unit(), rng.unit())) * (maxOff * 0.82), -maxOff), maxOff)
        let brightness = 0.62 + rng.unit() * 0.38

        var t = (phase * speed + offset).truncatingRemainder(dividingBy: 1)
        if t < 0 { t += 1 }
        let fade = pow(sin(t * .pi), 0.65)
        guard fade > 0.04 else { return }

        let pointOnCurve = lane.cubic.point(CGFloat(t))
        let normal = lane.cubic.normal(CGFloat(t))
        let x = pointOnCurve.x + normal.x * lateral
        let y = pointOnCurve.y + normal.y * lateral
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        let alpha = fade * brightness
        switch pigment {
        case .gradient:
            let traveling = travelingColor(base: baseColor, t: t)
            context.fill(Path(ellipseIn: rect), with: .color(traveling.opacity(alpha)))
            let spark = t < 0.28 ? 0.92 : 0.55
            context.fill(
                Path(ellipseIn: rect.insetBy(dx: radius * 0.32, dy: radius * 0.32)),
                with: .color(Color.white.opacity(alpha * spark))
            )
        case .solid:
            let color = baseColor.mix(with: .black, by: 0.42)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
        case .white:
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
        }
    }

    private func travelingColor(base: Color, t: Double) -> Color {
        let head = Color.white.mix(with: base, by: 0.06)
        let tail = base.mix(with: .black, by: 0.18)
        if t < 0.22 {
            return Color.white.mix(with: head, by: t / 0.22)
        }
        if t < 0.48 {
            return head.mix(with: base, by: (t - 0.22) / 0.26)
        }
        return base.mix(with: tail, by: (t - 0.48) / 0.52)
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
            labeled(Localization.string("energy.supplyPower", language: language), value: supplyText)
            if snapshot.adapterCeilingWatts > 0, snapshot.externalConnected {
                labeled(Localization.string("energy.chargerRating", language: language), value: String(format: "%.0f W", snapshot.adapterCeilingWatts))
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
                .autoFittingCaption(minimumScale: 0.7)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .autoFittingCaption(minimumScale: 0.7)
                .layoutPriority(1)
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
