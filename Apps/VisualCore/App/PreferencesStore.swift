// PreferencesStore — feature 190 T-U04-011 (FR-U04-060; research R4; data-model section 1). The shell's
// preferences as one JSON value under `ShellPreferences.storageKey` in a `UserDefaults`. Reading never fails:
// damaged or newer data gives the defaults and a note for the diagnostics.
import Foundation
import VisualCoreExperience

/// Reads and writes the shell's preferences in a `UserDefaults`.
final class PreferencesStore {
    private let defaults: UserDefaults

    /// Creates a store on `defaults` (the standard defaults in the app, a private suite in tests).
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The stored preferences, or the defaults with a note when the value is unreadable or newer.
    func load() -> (preferences: ShellPreferences, note: String?) {
        ShellPreferences.decode(defaults.data(forKey: ShellPreferences.storageKey))
    }

    /// Stores `preferences`, replacing the value that was there.
    func save(_ preferences: ShellPreferences) {
        defaults.set(preferences.encoded(), forKey: ShellPreferences.storageKey)
    }

    /// Removes the stored value; the next `load()` gives the defaults.
    func remove() {
        defaults.removeObject(forKey: ShellPreferences.storageKey)
    }
}
