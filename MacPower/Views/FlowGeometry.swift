import SwiftUI

enum FlowRibbon {
    /// Diameter of the settings button, and the horizontal slot reserved for end logos.
    static let nodeDiameter: CGFloat = 32

    /// Corner radius of a ribbon end. Thick ribbons stay rounded-rect;
    /// once thickness drops to the node size they degenerate to a semicircle.
    static func capRadius(for width: CGFloat) -> CGFloat {
        min(width / 2, nodeDiameter / 2)
    }

    /// Distance from the visual outer edge to the spine.
    static func endInset(for width: CGFloat) -> CGFloat {
        capRadius(for: width)
    }

    /// Icons sit a bit inward of the rounded end, toward the ribbon middle.
    static let logoInset: CGFloat = 26

    /// Shared Liquid Glass tint so the battery bar and energy ribbon match.
    static let glassTintOpacity: Double = 0.42

    /// Split/merge along the spine: keep a short trunk, then long fingers.
    static let forkT: CGFloat = 0.22

    /// Particle travel speed in phase-cycles. Higher watts move faster.
    static func particleSpeed(watts: Double) -> Double {
        let w = max(watts, 1)
        return 0.32 + min(pow(w / 14.0, 0.5), 2.6)
    }

    /// Visual thickness of the energy-flow trunk/capsule.
    /// Triple the node diameter so logos sit inside the ribbon.
    static func trunkWidth(totalWatts _: Double) -> CGFloat {
        nodeDiameter * 3
    }

    static func splitWidths(first: Double, second: Double, trunk: CGFloat) -> (CGFloat, CGFloat) {
        let a = max(first, 0.01)
        let b = max(second, 0.01)
        let sum = a + b
        var firstW = trunk * CGFloat(a / sum)
        var secondW = trunk * CGFloat(b / sum)
        let minW = min(FlowRibbon.nodeDiameter, trunk * 0.33)
        if firstW < minW {
            firstW = minW
            secondW = trunk - minW
        } else if secondW < minW {
            secondW = minW
            firstW = trunk - minW
        }
        return (firstW, secondW)
    }
}

struct FlowRibbonShape: Shape {
    var path: Path

    func path(in rect: CGRect) -> Path {
        path
    }
}

struct FlowCubic {
    var p0: CGPoint
    var c1: CGPoint
    var c2: CGPoint
    var p1: CGPoint

    func point(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p1.x
        let y = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p1.y
        return CGPoint(x: x, y: y)
    }

    func derivative(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = 3 * u * u * (c1.x - p0.x) + 6 * u * t * (c2.x - c1.x) + 3 * t * t * (p1.x - c2.x)
        let y = 3 * u * u * (c1.y - p0.y) + 6 * u * t * (c2.y - c1.y) + 3 * t * t * (p1.y - c2.y)
        return CGPoint(x: x, y: y)
    }

    func normal(_ t: CGFloat) -> CGPoint {
        let d = derivative(t)
        let len = max(0.001, hypot(d.x, d.y))
        return CGPoint(x: -d.y / len, y: d.x / len)
    }

    func offsetPoint(_ t: CGFloat, distance: CGFloat) -> CGPoint {
        let p = point(t)
        let n = normal(t)
        return CGPoint(x: p.x + n.x * distance, y: p.y + n.y * distance)
    }
}

enum ForkOutline {
    enum Cap {
        case round
        case butt
    }

    /// Hairline overlap at a butt join so antialiasing does not leave a seam.
    /// Kept far smaller than a round cap so it cannot refill the crotch.
    private static let seam: CGFloat = 0.8

    static func stackedLane(
        from start: CGPoint,
        to end: CGPoint,
        startY: CGFloat,
        endY: CGFloat,
        holdT: CGFloat
    ) -> FlowCubic {
        let dx = end.x - start.x
        let hold = min(max(holdT, 0.05), 0.95)
        let turn = min(hold + 0.16, 0.95)
        return FlowCubic(
            p0: CGPoint(x: start.x, y: startY),
            c1: CGPoint(x: start.x + dx * hold, y: startY),
            c2: CGPoint(x: start.x + dx * turn, y: endY),
            p1: CGPoint(x: end.x, y: endY)
        )
    }

    static func splitPath(
        left: CGPoint,
        top: CGPoint,
        bot: CGPoint,
        topW: CGFloat,
        botW: CGFloat,
        splitT: CGFloat = FlowRibbon.forkT
    ) -> Path {
        let trunk = topW + botW
        let splitX = left.x + (top.x - left.x) * splitT
        let topY = left.y - trunk / 2 + topW / 2
        let botY = left.y + trunk / 2 - botW / 2
        var path = Path()
        path.addPath(capsule(
            from: left,
            to: CGPoint(x: splitX + seam, y: left.y),
            width: trunk,
            startCap: .round,
            endCap: .butt
        ))
        path.addPath(capsule(
            from: CGPoint(x: splitX - seam, y: topY),
            to: top,
            width: topW,
            startCap: .butt,
            endCap: .round
        ))
        path.addPath(capsule(
            from: CGPoint(x: splitX - seam, y: botY),
            to: bot,
            width: botW,
            startCap: .butt,
            endCap: .round
        ))
        return path
    }

    static func mergePath(
        top: CGPoint,
        bot: CGPoint,
        right: CGPoint,
        topW: CGFloat,
        botW: CGFloat,
        mergeT: CGFloat = 1 - FlowRibbon.forkT
    ) -> Path {
        let trunk = topW + botW
        let mergeX = top.x + (right.x - top.x) * mergeT
        let topY = right.y - trunk / 2 + topW / 2
        let botY = right.y + trunk / 2 - botW / 2
        var path = Path()
        path.addPath(capsule(
            from: top,
            to: CGPoint(x: mergeX + seam, y: topY),
            width: topW,
            startCap: .round,
            endCap: .butt
        ))
        path.addPath(capsule(
            from: bot,
            to: CGPoint(x: mergeX + seam, y: botY),
            width: botW,
            startCap: .round,
            endCap: .butt
        ))
        path.addPath(capsule(
            from: CGPoint(x: mergeX - seam, y: right.y),
            to: right,
            width: trunk,
            startCap: .butt,
            endCap: .round
        ))
        return path
    }

    static func capsule(from start: CGPoint, to end: CGPoint, width: CGFloat) -> Path {
        capsule(from: start, to: end, width: width, startCap: .round, endCap: .round)
    }

    static func capsule(
        from start: CGPoint,
        to end: CGPoint,
        width: CGFloat,
        startCap: Cap,
        endCap: Cap
    ) -> Path {
        var spine = Path()
        spine.move(to: start)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let c1 = CGPoint(x: start.x + dx * 0.42, y: start.y + dy * 0.08)
        let c2 = CGPoint(x: start.x + dx * 0.58, y: start.y + dy * 0.92)
        spine.addCurve(to: end, control1: c1, control2: c2)
        var path = spine.strokedPath(StrokeStyle(lineWidth: width, lineCap: .butt, lineJoin: .round))
        if startCap == .round {
            addRoundedEndCap(&path, at: start, outward: CGPoint(x: start.x - c1.x, y: start.y - c1.y), width: width)
        }
        if endCap == .round {
            addRoundedEndCap(&path, at: end, outward: CGPoint(x: end.x - c2.x, y: end.y - c2.y), width: width)
        }
        return path
    }

    /// Rounded-rect cap on a butt end. Degenerates to a semicircle when the
    /// ribbon is no thicker than the node diameter.
    private static func addRoundedEndCap(
        _ path: inout Path,
        at center: CGPoint,
        outward: CGPoint,
        width: CGFloat
    ) {
        let len = max(0.001, hypot(outward.x, outward.y))
        let ux = outward.x / len
        let uy = outward.y / len
        let nx = -uy
        let ny = ux
        let radius = FlowRibbon.capRadius(for: width)
        let half = width / 2
        let leading = CGPoint(x: center.x + nx * half, y: center.y + ny * half)
        let trailing = CGPoint(x: center.x - nx * half, y: center.y - ny * half)
        let cA = CGPoint(x: center.x + nx * (half - radius), y: center.y + ny * (half - radius))
        let cB = CGPoint(x: center.x - nx * (half - radius), y: center.y - ny * (half - radius))
        let outerA = CGPoint(x: cA.x + ux * radius, y: cA.y + uy * radius)
        let outerB = CGPoint(x: cB.x + ux * radius, y: cB.y + uy * radius)
        let throughA = CGPoint(x: cA.x + (nx + ux) * radius, y: cA.y + (ny + uy) * radius)
        let throughB = CGPoint(x: cB.x + (ux - nx) * radius, y: cB.y + (uy - ny) * radius)

        path.move(to: leading)
        addShortArc(&path, center: cA, radius: radius, from: leading, to: outerA, through: throughA)
        path.addLine(to: outerB)
        addShortArc(&path, center: cB, radius: radius, from: outerB, to: trailing, through: throughB)
        path.closeSubpath()
    }

    private static func addShortArc(
        _ path: inout Path,
        center: CGPoint,
        radius: CGFloat,
        from start: CGPoint,
        to end: CGPoint,
        through mid: CGPoint
    ) {
        let startAngle = Angle(radians: atan2(start.y - center.y, start.x - center.x))
        let endAngle = Angle(radians: atan2(end.y - center.y, end.x - center.x))
        let midAngle = atan2(mid.y - center.y, mid.x - center.x)
        var delta = endAngle.radians - startAngle.radians
        while delta <= 0 { delta += 2 * .pi }
        var midDelta = midAngle - startAngle.radians
        while midDelta < 0 { midDelta += 2 * .pi }
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: midDelta > delta
        )
    }
}
