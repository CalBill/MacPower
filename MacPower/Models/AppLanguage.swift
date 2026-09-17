import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case brazilianPortuguese = "pt-BR"
    case italian = "it"
    case russian = "ru"

    var id: String { rawValue }

    var localeIdentifier: String? {
        self == .system ? nil : rawValue
    }

    var resolvedLocale: Locale {
        if let localeIdentifier {
            return Locale(identifier: localeIdentifier)
        }
        return .autoupdatingCurrent
    }

    var nativeName: String {
        switch self {
        case .system: ""
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .brazilianPortuguese: "Português (Brasil)"
        case .italian: "Italiano"
        case .russian: "Русский"
        }
    }

    static func resolved(stored raw: String?) -> AppLanguage {
        guard let raw, !raw.isEmpty else { return .system }
        return AppLanguage(rawValue: raw) ?? .system
    }
}
