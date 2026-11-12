// PreferencesStore — feature 190 T-U04-011 (FR-U04-060; research R4; data-model section 1). The shell's
// preferences as one JSON value under `ShellPreferences.storageKey` in a `UserDefaults`. Reading never fails:
// damaged or newer data gives the defaults and a note for the diagnostics, and one copy of that value is kept
// under `ShellPreferences.unreadableCopyKey` before anything overwrites it (feature 191, FR-U05-052).
import Foundation
import VisualCoreExperience

/// Reads and writes the shell's preferences in a `UserDefaults`.
final class PreferencesStore {
    private let defaults: UserDefaults

    /// Creates a store on `defaults` (the standard defaults in the app, a private suite in tests).
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The stored preferences, or the defaults with a note when the value is unreadable or newer. The first
    /// time such a value is met it is copied to `ShellPreferences.unreadableCopyKey`; a copy that exists is
    /// never replaced, so the oldest unreadable value is the one that is kept.
    func load() -> (preferences: ShellPreferences, note: String?) {
        let stored = defaults.data(forKey: ShellPreferences.storageKey)
        let result = ShellPreferences.decode(stored)
        if result.note != nil, let stored, defaults.object(forKey: ShellPreferences.unreadableCopyKey) == nil {
            defaults.set(stored, forKey: ShellPreferences.unreadableCopyKey)
        }
        return result
    }

    /// Stores `preferences`, replacing the value that was there.
    func save(_ preferences: ShellPreferences) {
        defaults.set(preferences.encoded(), forKey: ShellPreferences.storageKey)
    }

    /// Removes the stored value and the copy of an unreadable one; the next `load()` gives the defaults.
    /// Returns the keys that existed and were removed, sorted.
    @discardableResult
    func remove() -> [String] {
        var removed: [String] = []
        for key in [ShellPreferences.storageKey, ShellPreferences.unreadableCopyKey]
        where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            removed.append(key)
        }
        return removed
    }
}
