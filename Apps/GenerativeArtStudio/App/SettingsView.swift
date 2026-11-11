// SettingsView.swift — accessibility choices and About (feature 016 T-A01-504; FR-A01-501). The choices are stored in
// the app's own UserDefaults only; VisualCore's AccessibilityPreferences turns them into effective settings.
import SwiftUI
import VisualCoreSimulation
import VisualCoreUI

/// UserDefaults keys for the two stored choices (raw `AccessibilityChoice` values).
enum AccessibilityStorage {
    static let reduceMotionKey = "gas.a11y.reduceMotion"
    static let reduceFlashingKey = "gas.a11y.reduceFlashing"

    /// The preferences for stored raw values (absent or unknown → System).
    static func preferences(motion: String, flashing: String) -> AccessibilityPreferences {
        AccessibilityPreferences(reduceMotion: AccessibilityChoice(storedValue: motion),
                                 reduceFlashing: AccessibilityChoice(storedValue: flashing))
    }
}

struct SettingsView: View {
    @AppStorage(AccessibilityStorage.reduceMotionKey) private var motion = AccessibilityChoice.system.rawValue
    @AppStorage(AccessibilityStorage.reduceFlashingKey) private var flashing = AccessibilityChoice.system.rawValue
    @Environment(SystemAccessibilityObserver.self) private var system
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Motion and flashing") {
                    choicePicker("Reduce Motion", selection: $motion, id: "gas.settings.reduceMotion")
                    choicePicker("Reduce Flashing", selection: $flashing, id: "gas.settings.reduceFlashing")
                    // A normal row rather than a section footer, so the text keeps full contrast (feature 016 audit).
                    Text("Reduce Motion plays scenes at half speed. Reduce Flashing limits sudden brightness changes. "
                         + "System follows your device setting; Off overrides the system setting. "
                         + "Device setting now: Reduce Motion \(system.current.reduceMotion ? "on" : "off"), "
                         + "Dim Flashing Lights \(system.current.dimFlashingLights ? "on" : "off").")
                        .font(.footnote)
                        .accessibilityIdentifier("gas.settings.footer")
                }
                Section("About") {
                    Text("Works offline. No account, no tracking.")
                        .accessibilityIdentifier("gas.settings.about")
                }
            }
            .headerProminence(.increased)   // prominent primary-color headers (feature 016 audit)
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

    private func choicePicker(_ title: String, selection: Binding<String>, id: String) -> some View {
        let current = AccessibilityChoice(storedValue: selection.wrappedValue)
        return Picker(title, selection: Binding(get: { AccessibilityChoice(storedValue: selection.wrappedValue) },
                                                set: { selection.wrappedValue = $0.rawValue })) {
            ForEach(AccessibilityChoice.allCases) { choice in
                Text(choice.title).tag(choice)
            }
        }
        .accessibilityIdentifier(id)
        .accessibilityValue(Text(current.title))
    }
}
