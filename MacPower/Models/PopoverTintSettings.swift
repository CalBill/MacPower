import AppKit
import Foundation
import SwiftUI

/// Percent-banded tint without menu-bar on-battery gating.
struct ValueTintScheme: Codable, Equatable, Sendable {
    var bands: [MenuBarTintBand]

    var sortedBands: [MenuBarTintBand] {
        bands.sorted { $0.throughPercent < $1.throughPercent }
    }

    func fillSwatches(percent: Double) -> (left: MenuBarTintSwatch, right: MenuBarTintSwatch) {
        let value = Double(Int(min(100, max(0, percent)).rounded(.towardZero)))
        let ordered = sortedBands
        guard let index = ordered.firstIndex(where: { value <= Double($0.throughPercent) }) else {
            let last = ordered.last?.highRight ?? .menuBar
            return (last, last)
        }
        let band = ordered[index]
        let lower = index == 0 ? 0 : ordered[index - 1].throughPercent
        let t = MenuBarTintMix.t(percent: value, lower: lower, upper: band.throughPercent)
        return MenuBarTintMix.swatches(band: band, t: t)
    }

    func colors(percent: Double) -> (left: Color, right: Color) {
        let pair = fillSwatches(percent: percent)
        return (pair.left.color, pair.right.color)
    }

    func replacingBand(
        id: UUID,
        throughPercent: Int? = nil,
        blend: MenuBarTintBlend? = nil,
        highRight: MenuBarTintSwatch? = nil,
        highLeft: MenuBarTintSwatch? = nil,
        lowRight: MenuBarTintSwatch? = nil,
        lowLeft: MenuBarTintSwatch? = nil,
        swatch: MenuBarTintSwatch? = nil
    ) -> ValueTintScheme {
        var copy = self
        copy.bands = copy.bands.map { band in
            guard band.id == id else { return band }
            var next = band
            if let throughPercent { next.throughPercent = throughPercent }
            if let blend { next.blend = blend }
            if let swatch {
                next.highRight = swatch
                if next.blend == .constant {
                    next.highLeft = swatch
                    next.lowRight = swatch
                    next.lowLeft = swatch
                }
            }
            if let highRight { next.highRight = highRight }
            if let highLeft { next.highLeft = highLeft }
            if let lowRight { next.lowRight = lowRight }
            if let lowLeft { next.lowLeft = lowLeft }
            return next
        }
        return copy.normalized()
    }

    func replacingBand(at index: Int, mutate: (inout MenuBarTintBand) -> Void) -> ValueTintScheme {
        var ordered = sortedBands
        guard ordered.indices.contains(index) else { return self }
        mutate(&ordered[index])
        var copy = self
        copy.bands = ordered
        return copy.normalized()
    }

    func removingBand(id: UUID) -> ValueTintScheme {
        guard bands.count > 1 else { return self }
        var copy = self
        copy.bands.removeAll { $0.id == id }
        return copy.normalized()
    }

    func removingBand(at index: Int) -> ValueTintScheme {
        var ordered = sortedBands
        guard ordered.count > 1, ordered.indices.contains(index) else { return self }
        ordered.remove(at: index)
        var copy = self
        copy.bands = ordered
        return copy.normalized()
    }

    func addingBand() -> ValueTintScheme {
        guard bands.count < 8 else { return self }
        var copy = self
        let ordered = sortedBands
        let last = ordered.last?.throughPercent ?? 100
        let previous = ordered.dropLast().last?.throughPercent ?? 0
        let inserted = max(previous + 1, min(last - 1, (previous + last) / 2))
        copy.bands.append(MenuBarTintBand(throughPercent: inserted, swatch: .systemGreen))
        return copy.normalized()
    }

    func normalized() -> ValueTintScheme {
        var ordered = sortedBands
        if ordered.isEmpty {
            ordered = [MenuBarTintBand(throughPercent: 100, swatch: .menuBar)]
        }
        var unique: [MenuBarTintBand] = []
        var seen = Set<Int>()
        for band in ordered {
            var next = band
            if seen.contains(next.throughPercent) {
                next.throughPercent = min(100, next.throughPercent + 1)
            }
            seen.insert(next.throughPercent)
            unique.append(next)
        }
        unique[unique.count - 1].throughPercent = 100
        var copy = self
        copy.bands = unique
        return copy
    }

    func percentRange(for id: UUID) -> ClosedRange<Int> {
        let ordered = sortedBands
        guard let index = ordered.firstIndex(where: { $0.id == id }) else { return 1...100 }
        return percentRange(at: index)
    }

    func percentRange(at index: Int) -> ClosedRange<Int> {
        let ordered = sortedBands
        guard ordered.indices.contains(index) else { return 1...100 }
        if index == ordered.count - 1 { return 100...100 }
        let lower = index == 0 ? 1 : ordered[index - 1].throughPercent + 1
        let upper = ordered[index + 1].throughPercent - 1
        if lower > upper { return upper...upper }
        return lower...upper
    }

    func replacingStops(_ old: [Int], with newStops: [Int]) -> ValueTintScheme {
        let ordered = sortedBands
        guard ordered.map(\.throughPercent) == old, old.count == newStops.count else { return self }
        var copy = self
        copy.bands = zip(ordered, newStops).map { band, stop in
            var next = band
            next.throughPercent = stop
            return next
        }
        return copy.normalized()
    }

    static func constant(_ swatch: MenuBarTintSwatch) -> ValueTintScheme {
        ValueTintScheme(bands: [MenuBarTintBand(throughPercent: 100, swatch: swatch)])
    }

    /// Battery ring defaults: ≤10 red, ≤25 orange, ≤40 yellow, else green.
    static func batteryLevel(red: MenuBarTintSwatch, orange: MenuBarTintSwatch, yellow: MenuBarTintSwatch, green: MenuBarTintSwatch) -> ValueTintScheme {
        ValueTintScheme(bands: [
            MenuBarTintBand(throughPercent: 10, swatch: red),
            MenuBarTintBand(throughPercent: 25, swatch: orange),
            MenuBarTintBand(throughPercent: 40, swatch: yellow),
            MenuBarTintBand(throughPercent: 100, swatch: green)
        ]).normalized()
    }

    /// Load ring defaults: ≤60 green, ≤75 yellow, ≤90 orange, else red.
    static func loadLevel(green: MenuBarTintSwatch, yellow: MenuBarTintSwatch, orange: MenuBarTintSwatch, red: MenuBarTintSwatch) -> ValueTintScheme {
        ValueTintScheme(bands: [
            MenuBarTintBand(throughPercent: 60, swatch: green),
            MenuBarTintBand(throughPercent: 75, swatch: yellow),
            MenuBarTintBand(throughPercent: 90, swatch: orange),
            MenuBarTintBand(throughPercent: 100, swatch: red)
        ]).normalized()
    }

    /// Showcase: slide through battery stops.
    static let slidingBattery = ValueTintScheme(bands: [
        MenuBarTintBand(throughPercent: 10, swatch: .systemRed, blend: .slide, lowRight: .systemRed),
        MenuBarTintBand(throughPercent: 25, swatch: .systemOrange, blend: .slide, lowRight: .systemRed),
        MenuBarTintBand(throughPercent: 40, swatch: .systemYellow, blend: .slide, lowRight: .systemOrange),
        MenuBarTintBand(throughPercent: 100, swatch: .systemGreen, blend: .slide, lowRight: .systemYellow)
    ]).normalized()

    static let slidingLoad = ValueTintScheme(bands: [
        MenuBarTintBand(throughPercent: 60, swatch: .systemGreen, blend: .slide, lowRight: .systemGreen),
        MenuBarTintBand(throughPercent: 75, swatch: .systemYellow, blend: .slide, lowRight: .systemGreen),
        MenuBarTintBand(throughPercent: 90, swatch: .systemOrange, blend: .slide, lowRight: .systemYellow),
        MenuBarTintBand(throughPercent: 100, swatch: .systemRed, blend: .slide, lowRight: .systemOrange)
    ]).normalized()

    /// Showcase: circumferential / left-right gradient on each band.
    static let gradientBattery = ValueTintScheme(bands: [
        MenuBarTintBand(
            throughPercent: 100,
            swatch: .systemGreen,
            blend: .gradient,
            highLeft: .systemRed
        )
    ]).normalized()

    static let gradientLoad = ValueTintScheme(bands: [
        MenuBarTintBand(
            throughPercent: 100,
            swatch: .systemRed,
            blend: .gradient,
            highLeft: .systemGreen
        )
    ]).normalized()

    /// Showcase: gradient that also slides with the value.
    static let glideBattery = ValueTintScheme(bands: [
        MenuBarTintBand(
            throughPercent: 40,
            swatch: .systemOrange,
            blend: .slideGradient,
            highLeft: .systemRed,
            lowRight: .systemRed,
            lowLeft: .systemRed
        ),
        MenuBarTintBand(
            throughPercent: 100,
            swatch: .systemGreen,
            blend: .slideGradient,
            highLeft: .systemYellow,
            lowRight: .systemOrange,
            lowLeft: .systemRed
        )
    ]).normalized()

    static let glideLoad = ValueTintScheme(bands: [
        MenuBarTintBand(
            throughPercent: 60,
            swatch: .systemYellow,
            blend: .slideGradient,
            highLeft: .systemGreen,
            lowRight: .systemGreen,
            lowLeft: .systemGreen
        ),
        MenuBarTintBand(
            throughPercent: 100,
            swatch: .systemRed,
            blend: .slideGradient,
            highLeft: .systemOrange,
            lowRight: .systemYellow,
            lowLeft: .systemGreen
        )
    ]).normalized()
}

enum RingKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case battery, cpu, gpu, memory

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .battery: "ring.battery"
        case .cpu: "ring.cpu"
        case .gpu: "ring.gpu"
        case .memory: "ring.memory"
        }
    }
}

enum RingEditorTarget: String, CaseIterable, Identifiable, Sendable {
    case battery, cpu, gpu, memory, all

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .battery: "ring.battery"
        case .cpu: "ring.cpu"
        case .gpu: "ring.gpu"
        case .memory: "ring.memory"
        case .all: "settings.tint.selection.all"
        }
    }

    var ring: RingKind? {
        switch self {
        case .battery: .battery
        case .cpu: .cpu
        case .gpu: .gpu
        case .memory: .memory
        case .all: nil
        }
    }
}

enum PopoverTintPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case semantic
    case system
    case highContrast
    case glassMono
    case smooth
    case gradient
    case glide
    case custom

    var id: String { rawValue }

    static var pickerCases: [PopoverTintPreset] {
        allCases
    }

    var localizationKey: String {
        switch self {
        case .semantic: "settings.palette.semantic"
        case .system: "settings.palette.system"
        case .highContrast: "settings.palette.highContrast"
        case .glassMono: "settings.palette.glassMono"
        case .smooth: "settings.popover.tint.smooth"
        case .gradient: "settings.popover.tint.gradient"
        case .glide: "settings.popover.tint.glide"
        case .custom: "settings.icon.tint.custom"
        }
    }

    init(palette: ThemePalette) {
        switch palette {
        case .semantic: self = .semantic
        case .system: self = .system
        case .highContrast: self = .highContrast
        case .glassMono: self = .glassMono
        }
    }

    var themePalette: ThemePalette? {
        switch self {
        case .semantic: .semantic
        case .system: .system
        case .highContrast: .highContrast
        case .glassMono: .glassMono
        case .smooth, .gradient, .glide, .custom: nil
        }
    }
}

struct RingTintSettings: Codable, Equatable, Sendable {
    var preset: PopoverTintPreset
    var battery: ValueTintScheme
    var cpu: ValueTintScheme
    var gpu: ValueTintScheme
    var memory: ValueTintScheme

    static let semantic = RingTintSettings.preset(.semantic)
    static let system = RingTintSettings.preset(.system)
    static let highContrast = RingTintSettings.preset(.highContrast)
    static let glassMono = RingTintSettings.preset(.glassMono)
    static let smooth = RingTintSettings.preset(.smooth)
    static let gradient = RingTintSettings.preset(.gradient)
    static let glide = RingTintSettings.preset(.glide)

    static func preset(_ preset: PopoverTintPreset) -> RingTintSettings {
        switch preset {
        case .custom:
            return semantic.markedCustom()
        case .semantic, .system, .highContrast, .glassMono:
            let theme = AppTheme.resolved(palette: preset.themePalette!, colorScheme: .light)
            let red = MenuBarTintSwatch.from(color: theme.lowBatteryRed)
            let orange = MenuBarTintSwatch.from(color: theme.discharging)
            let yellow = MenuBarTintSwatch.from(color: theme.lowBatteryYellow)
            let green = MenuBarTintSwatch.from(color: theme.charging)
            let battery = ValueTintScheme.batteryLevel(red: red, orange: orange, yellow: yellow, green: green)
            let load = ValueTintScheme.loadLevel(green: green, yellow: yellow, orange: orange, red: red)
            return RingTintSettings(
                preset: preset,
                battery: battery,
                cpu: load,
                gpu: load,
                memory: load
            )
        case .smooth:
            return RingTintSettings(
                preset: .smooth,
                battery: .slidingBattery,
                cpu: .slidingLoad,
                gpu: .slidingLoad,
                memory: .slidingLoad
            )
        case .gradient:
            return RingTintSettings(
                preset: .gradient,
                battery: .gradientBattery,
                cpu: .gradientLoad,
                gpu: .gradientLoad,
                memory: .gradientLoad
            )
        case .glide:
            return RingTintSettings(
                preset: .glide,
                battery: .glideBattery,
                cpu: .glideLoad,
                gpu: .glideLoad,
                memory: .glideLoad
            )
        }
    }

    func scheme(for kind: RingKind) -> ValueTintScheme {
        switch kind {
        case .battery: battery
        case .cpu: cpu
        case .gpu: gpu
        case .memory: memory
        }
    }

    func markedCustom() -> RingTintSettings {
        var copy = self
        copy.preset = .custom
        return copy
    }

    func replacing(_ kind: RingKind, with scheme: ValueTintScheme) -> RingTintSettings {
        var copy = markedCustom()
        switch kind {
        case .battery: copy.battery = scheme.normalized()
        case .cpu: copy.cpu = scheme.normalized()
        case .gpu: copy.gpu = scheme.normalized()
        case .memory: copy.memory = scheme.normalized()
        }
        return copy
    }

    func replacingAll(with scheme: ValueTintScheme) -> RingTintSettings {
        let normalized = scheme.normalized()
        var copy = markedCustom()
        copy.battery = normalized
        copy.cpu = normalized
        copy.gpu = normalized
        copy.memory = normalized
        return copy
    }

    func mapAll(_ transform: (ValueTintScheme) -> ValueTintScheme) -> RingTintSettings {
        var copy = markedCustom()
        copy.battery = transform(battery).normalized()
        copy.cpu = transform(cpu).normalized()
        copy.gpu = transform(gpu).normalized()
        copy.memory = transform(memory).normalized()
        return copy
    }

    var allSchemes: [ValueTintScheme] { [battery, cpu, gpu, memory] }

    /// Older defaults used 9/24/39 and 59/74/89 so `<=` matched half-open AppTheme bands.
    /// Remap those exact stop lists to round fives without touching custom schemes.
    func withRoundedDefaultStops() -> RingTintSettings {
        var copy = self
        copy.battery = copy.battery.replacingStops([9, 24, 39, 100], with: [10, 25, 40, 100])
        for keyPath in [\RingTintSettings.cpu, \RingTintSettings.gpu, \RingTintSettings.memory] {
            copy[keyPath: keyPath] = copy[keyPath: keyPath].replacingStops([59, 74, 89, 100], with: [60, 75, 90, 100])
        }
        return copy
    }
}

enum FlowEditorTarget: String, CaseIterable, Identifiable, Sendable {
    case charging, discharging, adapterHold, underpowered, all

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .charging: "settings.flow.tint.charging"
        case .discharging: "settings.flow.tint.discharging"
        case .adapterHold: "settings.flow.tint.hold"
        case .underpowered: "settings.flow.tint.underpowered"
        case .all: "settings.tint.selection.all"
        }
    }

    var mode: EnergyFlowMode? {
        switch self {
        case .charging: .charging
        case .discharging: .discharging
        case .adapterHold: .adapterHold
        case .underpowered: .underpowered
        case .all: nil
        }
    }
}

struct FlowTintSettings: Codable, Equatable, Sendable {
    var preset: PopoverTintPreset
    var charging: ValueTintScheme
    var discharging: ValueTintScheme
    var adapterHold: ValueTintScheme
    var underpowered: ValueTintScheme
    /// `nil` keeps the motion style’s built-in gradient / solid / white pigment.
    var motionColor: MenuBarTintSwatch?

    static let semantic = FlowTintSettings.preset(.semantic)
    static let system = FlowTintSettings.preset(.system)
    static let highContrast = FlowTintSettings.preset(.highContrast)
    static let glassMono = FlowTintSettings.preset(.glassMono)
    static let smooth = FlowTintSettings.preset(.smooth)
    static let gradient = FlowTintSettings.preset(.gradient)
    static let glide = FlowTintSettings.preset(.glide)

    static func preset(_ preset: PopoverTintPreset) -> FlowTintSettings {
        switch preset {
        case .custom:
            return semantic.markedCustom()
        case .semantic, .system, .highContrast, .glassMono:
            let theme = AppTheme.resolved(palette: preset.themePalette!, colorScheme: .light)
            return FlowTintSettings(
                preset: preset,
                charging: .constant(.from(color: theme.charging)),
                discharging: .constant(.from(color: theme.discharging)),
                adapterHold: .constant(.from(color: theme.adapterHold)),
                underpowered: .constant(.from(color: theme.underpowered)),
                motionColor: nil
            )
        case .smooth:
            // Per-mode slide across battery percent with vivid endpoints.
            return FlowTintSettings(
                preset: .smooth,
                charging: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.20, 0.92, 0.55),
                        blend: .slide,
                        lowRight: .rgb(0.10, 0.55, 0.95)
                    )
                ]),
                discharging: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.98, 0.72, 0.18),
                        blend: .slide,
                        lowRight: .rgb(0.95, 0.25, 0.18)
                    )
                ]),
                adapterHold: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.55, 0.78, 1.00),
                        blend: .slide,
                        lowRight: .rgb(0.22, 0.38, 0.95)
                    )
                ]),
                underpowered: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.70, 0.55, 1.00),
                        blend: .slide,
                        lowRight: .rgb(0.95, 0.35, 0.55)
                    )
                ]),
                motionColor: nil
            )
        case .gradient:
            // Strong left→right contrast so charging forks stay readable on the right.
            return FlowTintSettings(
                preset: .gradient,
                charging: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.15, 0.95, 0.85),
                        blend: .gradient,
                        highLeft: .rgb(0.12, 0.72, 0.28)
                    )
                ]),
                discharging: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(1.00, 0.82, 0.20),
                        blend: .gradient,
                        highLeft: .rgb(0.92, 0.22, 0.12)
                    )
                ]),
                adapterHold: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.55, 0.88, 1.00),
                        blend: .gradient,
                        highLeft: .rgb(0.18, 0.32, 0.92)
                    )
                ]),
                underpowered: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.95, 0.55, 0.95),
                        blend: .gradient,
                        highLeft: .rgb(0.45, 0.20, 0.95)
                    )
                ]),
                motionColor: nil
            )
        case .glide:
            return FlowTintSettings(
                preset: .glide,
                charging: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.25, 0.98, 0.70),
                        blend: .slideGradient,
                        highLeft: .rgb(0.10, 0.85, 0.35),
                        lowRight: .rgb(0.10, 0.45, 0.95),
                        lowLeft: .rgb(0.08, 0.28, 0.72)
                    )
                ]),
                discharging: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(1.00, 0.78, 0.22),
                        blend: .slideGradient,
                        highLeft: .rgb(0.98, 0.45, 0.10),
                        lowRight: .rgb(0.90, 0.15, 0.20),
                        lowLeft: .rgb(0.70, 0.08, 0.20)
                    )
                ]),
                adapterHold: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.65, 0.90, 1.00),
                        blend: .slideGradient,
                        highLeft: .rgb(0.30, 0.55, 0.98),
                        lowRight: .rgb(0.20, 0.30, 0.85),
                        lowLeft: .rgb(0.12, 0.18, 0.65)
                    )
                ]),
                underpowered: ValueTintScheme(bands: [
                    MenuBarTintBand(
                        throughPercent: 100,
                        swatch: .rgb(0.98, 0.65, 0.90),
                        blend: .slideGradient,
                        highLeft: .rgb(0.70, 0.35, 0.98),
                        lowRight: .rgb(0.92, 0.25, 0.45),
                        lowLeft: .rgb(0.55, 0.12, 0.55)
                    )
                ]),
                motionColor: nil
            )
        }
    }

    func scheme(for mode: EnergyFlowMode) -> ValueTintScheme {
        switch mode {
        case .charging: charging
        case .discharging: discharging
        case .adapterHold: adapterHold
        case .underpowered: underpowered
        }
    }

    func markedCustom() -> FlowTintSettings {
        var copy = self
        copy.preset = .custom
        return copy
    }

    func replacing(_ mode: EnergyFlowMode, with scheme: ValueTintScheme) -> FlowTintSettings {
        var copy = markedCustom()
        switch mode {
        case .charging: copy.charging = scheme.normalized()
        case .discharging: copy.discharging = scheme.normalized()
        case .adapterHold: copy.adapterHold = scheme.normalized()
        case .underpowered: copy.underpowered = scheme.normalized()
        }
        return copy
    }

    func mapAll(_ transform: (ValueTintScheme) -> ValueTintScheme) -> FlowTintSettings {
        var copy = markedCustom()
        copy.charging = transform(charging).normalized()
        copy.discharging = transform(discharging).normalized()
        copy.adapterHold = transform(adapterHold).normalized()
        copy.underpowered = transform(underpowered).normalized()
        return copy
    }

    var allSchemes: [ValueTintScheme] { [charging, discharging, adapterHold, underpowered] }
}

/// Field-wise merge for "select all" editors. `nil` means mixed → show "-".
struct MergedTintBand: Identifiable, Equatable {
    var id: Int
    var throughPercent: Int?
    var blend: MenuBarTintBlend?
    var highRight: MenuBarTintSwatch?
    var highLeft: MenuBarTintSwatch?
    var lowRight: MenuBarTintSwatch?
    var lowLeft: MenuBarTintSwatch?
    var presentInAll: Bool
}

enum TintSchemeMerge {
    static func bands(from schemes: [ValueTintScheme]) -> [MergedTintBand] {
        guard let first = schemes.first else { return [] }
        let count = schemes.map(\.sortedBands.count).max() ?? 0
        return (0..<count).map { index in
            let bands: [MenuBarTintBand] = schemes.compactMap { scheme in
                let ordered = scheme.sortedBands
                guard ordered.indices.contains(index) else { return nil }
                return ordered[index]
            }
            let presentInAll = bands.count == schemes.count
            return MergedTintBand(
                id: index,
                throughPercent: common(bands.map(\.throughPercent)),
                blend: common(bands.map(\.blend)),
                highRight: common(bands.map(\.highRight)),
                highLeft: common(bands.map(\.highLeft)),
                lowRight: common(bands.map(\.lowRight)),
                lowLeft: common(bands.map(\.lowLeft)),
                presentInAll: presentInAll
            )
        }
    }

    private static func common<T: Equatable>(_ values: [T]) -> T? {
        guard let first = values.first else { return nil }
        return values.allSatisfy { $0 == first } ? first : nil
    }
}
