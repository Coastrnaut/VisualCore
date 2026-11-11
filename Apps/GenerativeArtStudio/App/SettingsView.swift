// SettingsView.swift — accessibility choices and About (feature 016 T-A01-504, T-A01-511; FR-A01-501). The settings
// section, storage keys and resolution are VisualCore's (AccessibilitySettingsSection, AccessibilityPreferences); the
// app supplies only its key prefix, identifiers and About text.
import SwiftUI
import VisualCoreSimulation
import VisualCoreUI

/// The app's `UserDefaults` key prefix for accessibility choices (`gas.a11y.reduceMotion`, `gas.a11y.reduceFlashing`).
enum AppAccessibility {
    static let keyPrefix = "gas.a11y"
    static let keys = AccessibilityPreferences.keys(prefix: keyPrefix)

    /// Preferences from the two stored raw values.
    static func preferences(motion: String, flashing: String) -> AccessibilityPreferences {
        AccessibilityPreferences(reduceMotion: AccessibilityChoice(storedValue: motion),
                                 reduceFlashing: AccessibilityChoice(storedValue: flashing))
    }
}

struct SettingsView: View {
    @AppStorage(AppAccessibility.keys.reduceMotion) private var motion = AccessibilityChoice.system.rawValue
    @AppStorage(AppAccessibility.keys.reduceFlashing) private var flashing = AccessibilityChoice.system.rawValue
    @Environment(SystemAccessibilityObserver.self) private var system
    @Environment(\.dismiss) private var dismiss

    private var preferences: Binding<AccessibilityPreferences> {
        Binding(get: { AppAccessibility.preferences(motion: motion, flashing: flashing) },
                set: { motion = $0.reduceMotion.rawValue; flashing = $0.reduceFlashing.rawValue })
    }

    var body: some View {
        NavigationStack {
            Form {
                AccessibilitySettingsSection(preferences: preferences, system: system.current, identifierPrefix: "gas.settings")
                Section("About") {
                    Text("Works offline. No account, no tracking.")
                        .accessibilityIdentifier("gas.settings.about")
                }
            }
            .headerProminence(.increased)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("gas.settings.done")
                }
            }
        }
        .accessibilityIdentifier("gas.settings")
    }
}
