// AccessibilitySettingsSection.swift — the shared Reduce Motion / Reduce Flashing settings for animated apps, plus an
// increased-contrast accent (feature 016 T-A01-510; constitution II; FR-A01-501, FR-A01-504). Built to pass the
// accessibility audit: prominent primary-colored header, plain picker values that are never clipped, and the
// explanation in a full-contrast row instead of a secondary-colored footer.
import SwiftUI
import UIKit
import VisualCoreSimulation

/// A form section with System/On/Off pickers for Reduce Motion and Reduce Flashing, and a row that explains the
/// choices and shows the current device setting. Identifiers: `<prefix>.reduceMotion`, `<prefix>.reduceFlashing`
/// and `<prefix>.footer`; each picker's accessibility value is the choice title.
public struct AccessibilitySettingsSection: View {
    @Binding var preferences: AccessibilityPreferences
    let system: SystemAccessibility
    let identifierPrefix: String

    /// Edits `preferences`; `system` is shown in the explanation row; identifiers start with `identifierPrefix`.
    public init(preferences: Binding<AccessibilityPreferences>, system: SystemAccessibility, identifierPrefix: String) {
        _preferences = preferences
        self.system = system
        self.identifierPrefix = identifierPrefix
    }

    /// The explanation row text (also used by tests).
    public static func explanation(system: SystemAccessibility) -> String {
        "Reduce Motion plays scenes at half speed. Reduce Flashing limits sudden brightness changes. "
            + "System follows your device setting; Off overrides the system setting. "
            + "Device setting now: Reduce Motion \(system.reduceMotion ? "on" : "off"), "
            + "Dim Flashing Lights \(system.dimFlashingLights ? "on" : "off")."
    }

    /// The section: two pickers and the explanation row, with a prominent header.
    public var body: some View {
        Section("Motion and flashing") {
            picker("Reduce Motion", choice: $preferences.reduceMotion, id: "\(identifierPrefix).reduceMotion")
            picker("Reduce Flashing", choice: $preferences.reduceFlashing, id: "\(identifierPrefix).reduceFlashing")
            Text(Self.explanation(system: system))
                .font(.footnote)
                .accessibilityIdentifier("\(identifierPrefix).footer")
        }
        .headerProminence(.increased)
    }

    private func picker(_ title: String, choice: Binding<AccessibilityChoice>, id: String) -> some View {
        Picker(title, selection: choice) {
            ForEach(AccessibilityChoice.allCases) { Text($0.title).tag($0) }
        }
        .accessibilityIdentifier(id)
        .accessibilityValue(Text(choice.wrappedValue.title))
    }
}

/// Colors that keep tinted text at ≥ 4.5:1 contrast.
public enum AccessibleColors {
    /// Apple's increased-contrast blue: #0040DD in light appearance, #409CFF in dark.
    public static let accentUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x40 / 255.0, green: 0x9C / 255.0, blue: 0xFF / 255.0, alpha: 1)
            : UIColor(red: 0x00 / 255.0, green: 0x40 / 255.0, blue: 0xDD / 255.0, alpha: 1)
    }
    /// SwiftUI form of `accentUIColor`, for `.tint(_:)`.
    public static let accent = Color(uiColor: accentUIColor)

    /// WCAG contrast ratio between two opaque sRGB colors (1…21).
    public static func contrastRatio(_ a: UIColor, _ b: UIColor) -> Double {
        func luminance(_ c: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
            c.getRed(&r, green: &g, blue: &bl, alpha: &al)
            func lin(_ v: CGFloat) -> Double { let v = Double(v); return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(bl)
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}
