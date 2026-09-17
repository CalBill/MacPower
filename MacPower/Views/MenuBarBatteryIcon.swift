import CoreText
import AppKit

enum MenuBarBatteryRenderer {
    static func image(
        snapshot: PowerSnapshot,
        style: MenuBarIconStyle,
        fillColor: NSColor,
        appearance: NSAppearance,
        showChargeGlyphs: Bool
    ) -> NSImage {
        let percent = Int(snapshot.percent.rounded(.towardZero))
        let charging = snapshot.flowMode == .charging
        let plugged = snapshot.flowMode == .adapterHold || snapshot.flowMode == .underpowered
        let glyph: MenuBarGlyph? = {
            guard showChargeGlyphs else { return nil }
            if charging { return .bolt }
            if plugged { return .plug }
            return nil
        }()

        let height: CGFloat = 13
        let metrics = layout(percent: percent, style: style, glyph: glyph, height: height)
        let size = NSSize(width: metrics.totalWidth, height: height)
        let image = rasterImage(size: size, appearance: appearance) { rect in
            drawBattery(
                in: rect,
                metrics: metrics,
                percent: snapshot.percent / 100,
                style: style,
                fillColor: fillColor,
                glyph: glyph
            )
        }
        image.isTemplate = true
        return image
    }

    /// Draw at 2x so the terminal gap stays a real hole after template scaling.
    private static func rasterImage(
        size: NSSize,
        appearance: NSAppearance,
        draw: @escaping (NSRect) -> Void
    ) -> NSImage {
        let scale: CGFloat = 2
        let image = NSImage(size: size)
        let pixelsWide = max(1, Int((size.width * scale).rounded(.up)))
        let pixelsHigh = max(1, Int((size.height * scale).rounded(.up)))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size, flipped: false) { rect in
                appearance.performAsCurrentDrawingAppearance { draw(rect) }
                return true
            }
        }
        rep.size = size
        image.addRepresentation(rep)
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            appearance.performAsCurrentDrawingAppearance {
                draw(NSRect(origin: .zero, size: size))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        return image
    }

    private enum MenuBarGlyph {
        case bolt
        case plug
    }

    private struct Metrics {
        var totalWidth: CGFloat
        var body: NSRect
        var cap: NSRect
        var digitBox: NSRect
        var font: NSFont
        var text: String
        var glyphBox: NSRect
    }

    private static func percentFont(size: CGFloat) -> NSFont {
        if let pingfang = NSFont(name: "PingFangSC-Medium", size: size) {
            return pingfang
        }
        let base = NSFont.systemFont(ofSize: size, weight: .semibold)
        let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return NSFont(descriptor: rounded, size: size) ?? base
    }

    private static func layout(
        percent: Int,
        style: MenuBarIconStyle,
        glyph: MenuBarGlyph?,
        height: CGFloat
    ) -> Metrics {
        let bodyHeight: CGFloat = 12
        let bodyY = (height - bodyHeight) / 2
        let capWidth: CGFloat = 1.6
        let capHeight: CGFloat = 5.4
        let capGap: CGFloat = 1.22
        let showsText = style == .systemPercentInside
        let text = showsText ? "\(percent)" : ""
        let digits = text.count
        let font = percentFont(size: digits >= 3 ? 8.6 : 9.4)
        let textSize = text.isEmpty
            ? NSSize.zero
            : (text as NSString).size(withAttributes: [.font: font])
        let glyphAdvance: CGFloat
        switch glyph {
        case .bolt: glyphAdvance = showsText ? 3.6 : 7.2
        case .plug: glyphAdvance = showsText ? 4.0 : 7.6
        case nil: glyphAdvance = 0
        }
        let gap: CGFloat = (showsText && glyph != nil) ? 0.2 : 0
        let groupWidth = (showsText ? textSize.width : 0) + gap + glyphAdvance
        let bodyWidth: CGFloat = {
            if !showsText { return 21.5 }
            return digits >= 3 ? 22.0 : 21.5
        }()
        let body = NSRect(x: 0.35, y: bodyY, width: bodyWidth, height: bodyHeight)
        let cap = NSRect(
            x: body.maxX + capGap,
            y: body.midY - capHeight / 2,
            width: capWidth,
            height: capHeight
        )
        let groupX = body.midX - groupWidth / 2
        let digitBox = NSRect(
            x: groupX,
            y: body.minY,
            width: showsText ? textSize.width : body.width,
            height: body.height
        )
        let glyphBox = NSRect(
            x: groupX + (showsText ? textSize.width + gap : 0),
            y: body.minY,
            width: max(glyphAdvance, showsText ? 0 : body.width),
            height: body.height
        )
        return Metrics(
            totalWidth: cap.maxX + 1.0,
            body: body,
            cap: cap,
            digitBox: digitBox,
            font: font,
            text: text,
            glyphBox: glyphBox
        )
    }

    private static func drawBattery(
        in rect: NSRect,
        metrics: Metrics,
        percent: CGFloat,
        style: MenuBarIconStyle,
        fillColor: NSColor,
        glyph: MenuBarGlyph?
    ) {
        let body = metrics.body
        let radius: CGFloat = 3.8
        drawChargeLevel(
            body: body,
            cap: metrics.cap,
            percent: percent,
            fillColor: fillColor,
            radius: radius
        )

        guard style != .classicBeside || glyph != nil else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.black.setFill()
        NSColor.black.setStroke()

        if style == .systemPercentInside, !metrics.text.isEmpty {
            punchCenteredText(metrics.text, font: metrics.font, in: metrics.digitBox)
        }

        if let glyph {
            let target = style == .systemPercentInside ? metrics.glyphBox : body
            switch glyph {
            case .bolt: punchBolt(in: target)
            case .plug: punchPlug(in: target)
            }
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawChargeLevel(
        body: NSRect,
        cap: NSRect,
        percent: CGFloat,
        fillColor: NSColor,
        radius: CGFloat
    ) {
        let clamped = min(1, max(0, percent))
        let bodyPath = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
        let capRadius = min(cap.width, cap.height) / 2
        let capPath = NSBezierPath(roundedRect: cap, xRadius: capRadius, yRadius: capRadius)

        fillColor.withAlphaComponent(0.62).setFill()
        bodyPath.fill()
        capPath.fill()

        NSGraphicsContext.saveGraphicsState()
        bodyPath.addClip()
        fillColor.setFill()
        NSRect(x: body.minX, y: body.minY, width: body.width * clamped, height: body.height).fill()
        NSGraphicsContext.restoreGraphicsState()

        if clamped >= 0.995 {
            fillColor.setFill()
            capPath.fill()
        }

        // Template rendering blends anti-aliased edges; cut the gap so the terminal stays detached.
        let gap = NSRect(
            x: body.maxX,
            y: 0,
            width: max(0, cap.minX - body.maxX),
            height: max(body.maxY, cap.maxY) + 2
        )
        if gap.width > 0 {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSColor.black.setFill()
            gap.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private static func punchCenteredText(_ text: String, font: NSFont, in box: NSRect) {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: NSColor.black
            ])
        )
        let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.textPosition = CGPoint(
            x: box.midX - bounds.midX,
            y: box.midY - bounds.midY
        )
        CTLineDraw(line, cg)
        cg.restoreGState()
    }

    private static func punchBolt(in box: NSRect) {
        let h: CGFloat = min(6.8, box.height - 3.0)
        let w = h * 0.54
        let midX = box.midX
        let midY = box.midY
        let path = NSBezierPath()
        path.move(to: NSPoint(x: midX + w * 0.18, y: midY + h * 0.50))
        path.line(to: NSPoint(x: midX - w * 0.50, y: midY + 0.08))
        path.line(to: NSPoint(x: midX + w * 0.08, y: midY + 0.08))
        path.line(to: NSPoint(x: midX - w * 0.18, y: midY - h * 0.50))
        path.line(to: NSPoint(x: midX + w * 0.50, y: midY - 0.08))
        path.line(to: NSPoint(x: midX - w * 0.08, y: midY - 0.08))
        path.close()
        path.fill()
    }

    private static func punchPlug(in box: NSRect) {
        let cx = box.midX
        let cy = box.midY - 0.12
        let path = NSBezierPath()
        path.appendRoundedRect(
            NSRect(x: cx - 1.62, y: cy - 1.52, width: 3.24, height: 2.7),
            xRadius: 0.72,
            yRadius: 0.72
        )
        path.appendRect(NSRect(x: cx - 0.98, y: cy + 1.08, width: 0.82, height: 1.52))
        path.appendRect(NSRect(x: cx + 0.16, y: cy + 1.08, width: 0.82, height: 1.52))
        path.fill()
    }
}
