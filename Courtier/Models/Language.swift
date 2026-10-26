import Foundation

/// In-app language, independent of the iPhone's system language. English by default.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, id

    static let storageKey = "appLanguage"

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var locale: Locale { Locale(identifier: self == .id ? "id_ID" : "en_US") }

    /// Read from UserDefaults on every call so model types (formats, scoring hints) can translate
    /// without being tied to the main actor. The root view rebuilds its content when this changes.
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .en
    }
}

/// Picks the English or Indonesian copy for the current app language.
func tr(_ en: String, _ id: String) -> String {
    AppLanguage.current == .id ? id : en
}
