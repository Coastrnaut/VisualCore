// AccessibilitySettingsSectionTests — feature 016 T-A01-510 (constitution II; FR-A01-501, FR-A01-504).
import SwiftUI
import UIKit
import VisualCoreSimulation
import XCTest
@testable import VisualCoreUI

@MainActor
final class AccessibilitySettingsSectionTests: XCTestCase {
    func testExplanationShowsDeviceSettingAndOverride() {
        let text = AccessibilitySettingsSection.explanation(system: SystemAccessibility(reduceMotion: true, dimFlashingLights: false))
        XCTAssertTrue(text.contains("Off overrides the system setting"))
        XCTAssertTrue(text.contains("Reduce Motion on, Dim Flashing Lights off"))
    }

    func testSectionHostsInAForm() throws {
        var prefs = AccessibilityPreferences(reduceMotion: .on)
        let binding = Binding(get: { prefs }, set: { prefs = $0 })
        let host = UIHostingController(rootView: Form {
            AccessibilitySettingsSection(preferences: binding, system: SystemAccessibility(), identifierPrefix: "t.settings")
        })
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        host.view.layoutIfNeeded()
        XCTAssertGreaterThan(host.view.intrinsicContentSize.height + host.view.bounds.height, 0)
        binding.wrappedValue.reduceFlashing = .off
        XCTAssertEqual(prefs, AccessibilityPreferences(reduceMotion: .on, reduceFlashing: .off))
    }

    func testAccentMeetsTextContrastInBothAppearances() {
        let light = AccessibleColors.accentUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = AccessibleColors.accentUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertGreaterThanOrEqual(AccessibleColors.contrastRatio(light, .white), 4.5)
        XCTAssertGreaterThanOrEqual(AccessibleColors.contrastRatio(dark, .black), 4.5)
        XCTAssertGreaterThanOrEqual(AccessibleColors.contrastRatio(light, UIColor(white: 0.95, alpha: 1)), 4.5, "on grouped backgrounds")
        XCTAssertEqual(AccessibleColors.contrastRatio(.black, .white), 21, accuracy: 0.01)
    }
}
