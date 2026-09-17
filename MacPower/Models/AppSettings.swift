import Foundation
import Observation

@Observable
final class AppSettings {
    private enum Keys {
        static let iconStyle = "iconStyle"
        static let palette = "palette"
        static let lowBatteryTintEnabled = "lowBatteryTintEnabled"
        static let showChargeGlyphs = "showChargeGlyphs"
        static let motionStyle = "motionStyle"
        static let motionFrameRate = "motionFrameRate"
        static let pulseFlowIcons = "pulseFlowIcons"
        static let showPopoverArrow = "showPopoverArrow"
        static let language = "appLanguage"
        static let appleLanguages = "AppleLanguages"
        static let legacyEnergyMotion = "energyMotion"
    }

    @ObservationIgnored
    private let store: UserDefaults

    var iconStyle: MenuBarIconStyle {
        didSet { store.set(iconStyle.rawValue, forKey: Keys.iconStyle) }
    }

    var palette: ThemePalette {
        didSet { store.set(palette.rawValue, forKey: Keys.palette) }
    }

    var lowBatteryTintEnabled: Bool {
        didSet { store.set(lowBatteryTintEnabled, forKey: Keys.lowBatteryTintEnabled) }
    }

    var showChargeGlyphs: Bool {
        didSet { store.set(showChargeGlyphs, forKey: Keys.showChargeGlyphs) }
    }

    var motionStyle: EnergyMotionStyle {
        didSet { store.set(motionStyle.rawValue, forKey: Keys.motionStyle) }
    }

    var motionFrameRate: EnergyMotionFrameRate {
        didSet { store.set(motionFrameRate.rawValue, forKey: Keys.motionFrameRate) }
    }

    var pulseFlowIcons: Bool {
        didSet { store.set(pulseFlowIcons, forKey: Keys.pulseFlowIcons) }
    }

    var showPopoverArrow: Bool {
        didSet { store.set(showPopoverArrow, forKey: Keys.showPopoverArrow) }
    }

    var language: AppLanguage {
        didSet {
            store.set(language.rawValue, forKey: Keys.language)
            clearLegacyAppleLanguages()
        }
    }

    var resolvedLocale: Locale { language.resolvedLocale }

    init(defaults: UserDefaults = .standard) {
        store = defaults
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

        if defaults.object(forKey: Keys.pulseFlowIcons) == nil {
            pulseFlowIcons = true
        } else {
            pulseFlowIcons = defaults.bool(forKey: Keys.pulseFlowIcons)
        }

        if defaults.object(forKey: Keys.showPopoverArrow) == nil {
            showPopoverArrow = true
        } else {
            showPopoverArrow = defaults.bool(forKey: Keys.showPopoverArrow)
        }

        let storedMotion = defaults.string(forKey: Keys.motionStyle)
            ?? defaults.string(forKey: Keys.legacyEnergyMotion)
        let resolvedMotion = EnergyMotionStyle.resolved(stored: storedMotion)
        motionStyle = resolvedMotion
        if defaults.object(forKey: Keys.motionFrameRate) == nil {
            motionFrameRate = .hz60
        } else {
            motionFrameRate = EnergyMotionFrameRate.resolved(stored: defaults.integer(forKey: Keys.motionFrameRate))
        }
        language = AppLanguage.resolved(stored: defaults.string(forKey: Keys.language))

        store.set(resolvedMotion.rawValue, forKey: Keys.motionStyle)
        if defaults.object(forKey: Keys.legacyEnergyMotion) != nil {
            store.removeObject(forKey: Keys.legacyEnergyMotion)
        }
        clearLegacyAppleLanguages()
    }

    /// In-app language is resolved from `*.lproj` at runtime. Writing
    /// `AppleLanguages` only takes effect on the next launch and fights live switching.
    private func clearLegacyAppleLanguages() {
        store.removeObject(forKey: Keys.appleLanguages)
    }
}
