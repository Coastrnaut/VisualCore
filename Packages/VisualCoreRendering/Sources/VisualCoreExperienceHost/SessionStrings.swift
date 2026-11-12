// SessionStrings — feature 189 T-U03-001 (FR-U03-063). Every text of the session's own views, read from the
// module's string catalog (Resources/Localizable.xcstrings), so that the texts live in one place and can be
// localized later.
import Foundation

/// The texts of the session's own views.
public enum SessionStrings {
    /// The keys of the string catalog.
    public enum Key: String, CaseIterable, Sendable {
        case preparing = "session.preparing"
        case cancel = "session.cancel"
        case failureTitle = "session.failure.title"
        case retry = "session.retry"
        case back = "session.back"
        case memoryMessage = "session.message.memory"
        case canvasHint = "session.canvas.hint"
    }

    /// The text for `key` in the current language.
    public static func text(_ key: Key) -> String {
        Bundle.module.localizedString(forKey: key.rawValue, value: nil, table: nil)
    }
}
