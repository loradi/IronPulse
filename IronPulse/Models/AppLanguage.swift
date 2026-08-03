import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"
    case french = "fr"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        case .french: return "Français"
        }
    }

    var speechLanguageCode: String {
        switch self {
        case .spanish: return "es-ES"
        case .english: return "en-US"
        case .french: return "fr-FR"
        }
    }

    static func resolve(storedRawValue: String?, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        if let storedRawValue, let stored = AppLanguage(rawValue: storedRawValue) {
            return stored
        }
        for preferred in preferredLanguages {
            if preferred.hasPrefix("en") { return .english }
            if preferred.hasPrefix("fr") { return .french }
        }
        return .spanish
    }

    static var current: AppLanguage {
        resolve(storedRawValue: UserDefaults.standard.string(forKey: "appLanguage"))
    }
}
