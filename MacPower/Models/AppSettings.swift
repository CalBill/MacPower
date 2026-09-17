import Foundation
import Observation

@Observable
final class AppSettings {
    private enum Keys {
        static let iconStyle = "iconStyle"
        static let palette = "palette"
        static let lowBatteryTintEnabled = "lowBatteryTintEnabled"
        static let showChargeGlyphs = "showChargeGlyphs"
    }

    var iconStyle: MenuBarIconStyle {
        didSet { UserDefaults.standard.set(iconStyle.rawValue, forKey: Keys.iconStyle) }
    }

    var palette: ThemePalette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: Keys.palette) }
    }

    var lowBatteryTintEnabled: Bool {
        didSet { UserDefaults.standard.set(lowBatteryTintEnabled, forKey: Keys.lowBatteryTintEnabled) }
    }

    var showChargeGlyphs: Bool {
        didSet { UserDefaults.standard.set(showChargeGlyphs, forKey: Keys.showChargeGlyphs) }
    }

    init(defaults: UserDefaults = .standard) {
        let iconRaw = defaults.string(forKey: Keys.iconStyle) ?? MenuBarIconStyle.systemPercentInside.rawValue
        iconStyle = MenuBarIconStyle(rawValue: iconRaw) ?? .systemPercentInside

        let paletteRaw = defaults.string(forKey: Keys.palette) ?? ThemePalette.semantic.rawValue
        palette = ThemePalette(rawValue: paletteRaw) ?? .semantic

        if defaults.object(forKey: Keys.lowBatteryTintEnabled) == nil {
            lowBatteryTintEnabled = true
        } else {
            lowBatteryTintEnabled = defaults.bool(forKey: Keys.lowBatteryTintEnabled)
        }

        if defaults.object(forKey: Keys.showChargeGlyphs) == nil {
            showChargeGlyphs = true
        } else {
            showChargeGlyphs = defaults.bool(forKey: Keys.showChargeGlyphs)
        }
    }
}
