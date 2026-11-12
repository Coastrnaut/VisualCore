// AppStrings — feature 190 T-U04-011 (FR-U04-021 to FR-U04-024, FR-U04-040, FR-U04-053, FR-U04-054). Every text
// the shell shows, read from the app's string catalog (Resources/Localizable.xcstrings), so that the texts live
// in one place and can be localized later.
import Foundation

/// The texts of the app shell.
enum AppStrings {
    /// The keys of the string catalog.
    enum Key: String, CaseIterable, Sendable {
        case appName = "vc.app.name"
        case catalogTitle = "vc.catalog.title"
        case catalogSearch = "vc.catalog.search"
        case catalogSearchClear = "vc.catalog.search.clear"
        case catalogEmpty = "vc.catalog.empty"
        case catalogNoMatch = "vc.catalog.nomatch"
        case catalogError = "vc.catalog.error"
        case catalogChoose = "vc.catalog.choose"
        case navSettings = "vc.nav.settings"
        case navAbout = "vc.nav.about"
        case navDone = "vc.nav.done"
        case tileLabel = "vc.tile.label"
        case experienceBack = "vc.experience.back"
        case welcomeTitle = "vc.welcome.title"
        case welcomeBody = "vc.welcome.body"
        case welcomeStart = "vc.welcome.start"
        case premiumTitle = "vc.premium.title"
        case premiumBody = "vc.premium.body"
        case premiumDismiss = "vc.premium.dismiss"
        case settingsTitle = "vc.settings.title"
        case settingsQualityHeader = "vc.settings.quality.header"
        case settingsQuality = "vc.settings.quality"
        case settingsQualityAutomatic = "vc.settings.quality.automatic"
        case settingsQualityNote = "vc.settings.quality.note"
        case settingsDataHeader = "vc.settings.data.header"
        case settingsResetOne = "vc.settings.reset.one"
        case settingsResetAll = "vc.settings.reset.all"
        case settingsResetOneQuestion = "vc.settings.reset.one.question"
        case settingsResetAllQuestion = "vc.settings.reset.all.question"
        case settingsResetWarning = "vc.settings.reset.warning"
        case settingsResetConfirm = "vc.settings.reset.confirm"
        case settingsResetCancel = "vc.settings.reset.cancel"
        case settingsDiagnosticsHeader = "vc.settings.diagnostics.header"
        case settingsPrivacyHeader = "vc.settings.privacy.header"
        case settingsPrivacy = "vc.settings.privacy"
        case unreadableTitle = "vc.unreadable.title"
        case unreadableDamaged = "vc.unreadable.damaged"
        case unreadableNewer = "vc.unreadable.newer"
        case unreadableResetNote = "vc.unreadable.reset.note"
        case unreadableReset = "vc.unreadable.reset"
        case unreadableBack = "vc.unreadable.back"
        case aboutTitle = "vc.about.title"
        case aboutSummary = "vc.about.summary"
        case aboutVersion = "vc.about.version"
        case aboutAcknowledgements = "vc.about.acknowledgements"
    }

    /// The text for `key` in the current language.
    static func text(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue))
    }

    /// The text for `key` with each `%@` replaced by the next argument, in order.
    static func text(_ key: Key, _ arguments: String...) -> String {
        var result = ""
        var remaining = arguments[...]
        var rest = text(key)[...]
        while let range = rest.range(of: "%@") {
            result += rest[..<range.lowerBound]
            result += remaining.first ?? ""
            remaining = remaining.dropFirst()
            rest = rest[range.upperBound...]
        }
        return result + rest
    }
}
