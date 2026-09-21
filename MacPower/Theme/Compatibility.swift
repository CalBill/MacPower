import AppKit
import SwiftUI

// MARK: - Liquid Glass (macOS 26+) with material fallback for 14/15

enum MacPowerGlassStyle {
    case regular
    case regularInteractive
    case regularTint(Color)
}

extension View {
    /// On macOS 26+ uses the real Liquid Glass path unchanged; on 14/15 uses
    /// ultra-thin material so the app still builds and runs without glass APIs.
    ///
    /// Prefer this for unmasked chrome (e.g. settings buttons). Ring tracks and
    /// the energy ribbon use dedicated `< macOS 26` branches — material in a
    /// `.background` then masked often samples nothing and disappears.
    @ViewBuilder
    func macPowerGlassEffect<S: Shape>(_ style: MacPowerGlassStyle, in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            switch style {
            case .regular:
                self.glassEffect(.regular, in: shape)
            case .regularInteractive:
                self.glassEffect(.regular.interactive(), in: shape)
            case .regularTint(let tint):
                self.glassEffect(.regular.tint(tint), in: shape)
            }
        } else {
            self.background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if case .regularTint(let tint) = style {
                        shape.fill(tint)
                    }
                }
            }
        }
    }
}

// MARK: - Color.mix (macOS 15+) polyfill for macOS 14

extension Color {
    /// Matches `Color.mix(with:by:)` on macOS 15+; linear sRGB blend on 14.
    func mixed(with other: Color, by fraction: Double) -> Color {
        if #available(macOS 15.0, *) {
            return mix(with: other, by: fraction)
        }
        let t = min(1, max(0, fraction))
        let a = rgbaComponents(self)
        let b = rgbaComponents(other)
        return Color(
            .sRGB,
            red: Double(a.r + (b.r - a.r) * t),
            green: Double(a.g + (b.g - a.g) * t),
            blue: Double(a.b + (b.b - a.b) * t),
            opacity: Double(a.a + (b.a - a.a) * t)
        )
    }

    private func rgbaComponents(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let ns = NSColor(color)
        if let rgb = ns.usingColorSpace(.sRGB) ?? ns.usingColorSpace(.deviceRGB) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b, a)
        }
        if let converted = ns.cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ), let c = converted.components, c.count >= 3 {
            return (c[0], c[1], c[2], c.count > 3 ? c[3] : 1)
        }
        return (0, 0, 0, 1)
    }
}
