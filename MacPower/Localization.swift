import Foundation

enum Localization {
    static func string(_ key: String, language: AppLanguage) -> String {
        bundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    static func string(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        let template = string(key, language: language)
            .replacingOccurrences(of: "%", with: "%%")
            .replacingOccurrences(of: "%%lld", with: "%lld")
            .replacingOccurrences(of: "%%@", with: "%@")
        return String(format: template, locale: language.resolvedLocale, arguments: arguments)
    }

    static func bundle(for language: AppLanguage) -> Bundle {
        let names: [String]
        if language == .system {
            names = bundleNames(for: .autoupdatingCurrent)
        } else if let identifier = language.localeIdentifier {
            names = [identifier]
        } else {
            names = []
        }
        for name in names {
            if let path = Bundle.main.path(forResource: name, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .main
    }

    private static func bundleNames(for locale: Locale) -> [String] {
        var names: [String] = []
        names.append(locale.identifier.replacingOccurrences(of: "_", with: "-"))
        if let language = locale.language.languageCode?.identifier {
            if let script = locale.language.script?.identifier {
                names.append("\(language)-\(script)")
            }
            if let region = locale.region?.identifier {
                names.append("\(language)-\(region)")
            }
            names.append(language)
        }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}
