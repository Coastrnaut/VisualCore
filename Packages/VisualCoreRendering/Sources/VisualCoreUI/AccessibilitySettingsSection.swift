// AccessibilitySettingsSection.swift — the shared Reduce Motion / Reduce Flashing settings for animated apps, plus an
// increased-contrast accent (feature 016 T-A01-510; constitution II; FR-A01-501, FR-A01-504). Built to pass the
// accessibility audit: prominent primary-colored header, plain picker values that are never clipped, and the
// explanation in a full-contrast row instead of a secondary-colored footer. Feature 210 (R02-F10) T-R02F10-008
// (FR-R02F10-010, research R8): a colour-vision picker after the two rows, and `AccessibleColors.contrastRatio`
// computed by `PerceptualColor.contrastRatio`, the one WCAG formula of the package.
import SwiftUI
import UIKit
import VisualCoreParameters
import VisualCoreSimulation

/// A form section with System/On/Off pickers for Reduce Motion and Reduce Flashing, a row that explains the
/// choices and shows the current device setting, and a colour-vision picker with its own explanation row.
/// Identifiers: `<prefix>.reduceMotion`, `<prefix>.reduceFlashing`, `<prefix>.footer`, `<prefix>.colorVision` and
/// `<prefix>.colorVisionFooter`; each picker's accessibility value is the choice title.
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

    /// The one-sentence explanation of the colour-vision picker (also used by tests).
    public static let colorVisionExplanation = "Colours replaces the colours of colour-coded states with a preset that "
        + "stays distinct with colour blindness; each state also keeps its shape, pattern and name."

    /// The section: two pickers and the explanation row, then the colour-vision picker and its sentence, with a
    /// prominent header.
    public var body: some View {
        Section("Motion and flashing") {
            picker("Reduce Motion", choice: $preferences.reduceMotion, id: "\(identifierPrefix).reduceMotion")
            picker("Reduce Flashing", choice: $preferences.reduceFlashing, id: "\(identifierPrefix).reduceFlashing")
            Text(Self.explanation(system: system))
                .font(.footnote)
                .accessibilityIdentifier("\(identifierPrefix).footer")
            Picker("Colours", selection: $preferences.colorVision) {
                ForEach(ColorVisionChoice.allCases) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("\(identifierPrefix).colorVision")
            .accessibilityValue(Text(preferences.colorVision.title))
            Text(Self.colorVisionExplanation)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(identifierPrefix).colorVisionFooter")
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

    /// WCAG contrast ratio between two opaque sRGB colors (1…21): both are read as sRGB components and passed to
    /// `PerceptualColor.contrastRatio` (feature 210 T-R02F10-008, research R8).
    public static func contrastRatio(_ a: UIColor, _ b: UIColor) -> Double {
        PerceptualColor.contrastRatio(sRGB(a), sRGB(b))
    }

    /// The sRGB components of `color` as `UIColor.getRed` gives them (extended sRGB).
    static func sRGB(_ color: UIColor) -> SIMD3<Double> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(Double(r), Double(g), Double(b))
    }
}
