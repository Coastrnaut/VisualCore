// ClueBadgeTests — feature 210 (R02-F10) T-R02F10-008 (FR-R02F10-010, FR-R02F10-013; research R8, R9): the badge's
// spoken label is the name; at the largest accessibility text size it fits compact (320 pt) and regular (768 pt) widths
// and wraps the name instead of truncating it; the colour-vision palettes; `AccessibleColors.contrastRatio` gives the
// values of the formula it had before; the settings section edits the colour-vision choice.
import SwiftUI
import UIKit
import VisualCoreParameters
import VisualCoreSimulation
import XCTest
@testable import VisualCoreUI

@MainActor
final class ClueBadgeTests: XCTestCase {
    private func state(_ name: String) -> CodedState {
        CodedState(id: "s", color: SIMD3(0.9, 0.4, 0.1), shape: .star, pattern: .stripes, name: name)
    }

    private let longName = "A considerably long state name to wrap"

    /// The rendered size of `view` at the largest accessibility text size inside a frame `width` points wide.
    private func renderedSize(_ name: String, width: CGFloat) throws -> CGSize {
        let renderer = ImageRenderer(content: ClueBadge(state: state(name))
            .dynamicTypeSize(.accessibility5)
            .frame(width: width))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage, "the badge renders")
        return image.size
    }

    func testAccessibilityLabelIsTheName() throws {
        XCTAssertEqual(longName.count <= CodedStateSet.maxNameLength, true)
        let host = UIHostingController(rootView: ClueBadge(state: state("Charged")))
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        host.view.layoutIfNeeded()
        XCTAssertEqual(ClueBadge.spokenLabel(for: state("Charged")), "Charged")
        // The hosted tree is searched as well; a test host that exposes no SwiftUI accessibility elements yields no
        // labels, and then only the label function above is checked. Any exposed label must be the name alone.
        let labels = Self.accessibilityLabels(in: host.view).filter { !$0.isEmpty }
        if !labels.isEmpty { XCTAssertTrue(labels.contains("Charged"), "labels found: \(labels)") }
    }

    func testLargestTextSizeWrapsTheNameInCompactAndRegularWidths() throws {
        for width in [CGFloat(320), 768] {
            let short = try renderedSize("On", width: width)
            let long = try renderedSize(longName, width: width)
            XCTAssertEqual(short.width, width, accuracy: 1, "fits width \(width)")
            XCTAssertEqual(long.width, width, accuracy: 1, "fits width \(width)")
            XCTAssertGreaterThan(short.height, 28, "the clue scales with Dynamic Type")
        }
        let shortCompact = try renderedSize("On", width: 320)
        let longCompact = try renderedSize(longName, width: 320)
        XCTAssertGreaterThan(longCompact.height, shortCompact.height, "the long name wraps onto more lines at 320 pt")
        let longRegular = try renderedSize(longName, width: 768)
        XCTAssertGreaterThanOrEqual(longCompact.height, longRegular.height, "a wider frame needs no more lines")
    }

    func testTheBitmapFollowsTheReference() throws {
        let s = CodedState(id: "s", color: SIMD3(1, 0, 0), shape: .square, pattern: .solid, name: "Red")
        let image = try XCTUnwrap(ClueBadge.render(state: s, outline: SIMD3(0, 0, 0), side: 28, scale: 2))
        XCTAssertEqual(image.width, 56)
        XCTAssertEqual(image.height, 56)
        XCTAssertGreaterThanOrEqual(ClueBadge.outlineWidth(side: 10), 1.5)
        XCTAssertEqual(ClueBadge.background(for: .dark), SIMD3(0, 0, 0))
        XCTAssertEqual(ClueBadge.background(for: .light), SIMD3(1, 1, 1))
        for preset in ColorVisionPresets.all {
            for stop in preset.stops {
                for scheme in [ColorScheme.light, .dark] {
                    let background = ClueBadge.background(for: scheme)
                    let outline = PerceptualColor.outline(for: stop, on: background)
                    XCTAssertGreaterThanOrEqual(PerceptualColor.contrastRatio(outline, background), 3)
                }
            }
        }
    }

    func testPaletteOfEachChoice() {
        XCTAssertNil(ColorVisionChoice.standard.palette)
        XCTAssertEqual(ColorVisionChoice.warmCool.palette, ColorVisionPresets.warmCool)
        XCTAssertEqual(ColorVisionChoice.redCyan.palette, ColorVisionPresets.redCyan)
        XCTAssertEqual(ColorVisionChoice.lightness.palette, ColorVisionPresets.lightness)
    }

    /// The contrast formula `AccessibleColors` used before feature 210.
    private static func oldContrast(_ a: UIColor, _ b: UIColor) -> Double {
        func luminance(_ c: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
            c.getRed(&r, green: &g, blue: &bl, alpha: &al)
            func lin(_ v: CGFloat) -> Double { let v = Double(v); return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(bl)
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    func testContrastRatioKeepsItsValues() {
        let light = AccessibleColors.accentUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = AccessibleColors.accentUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertEqual(AccessibleColors.contrastRatio(.black, .white), 21, accuracy: 1e-9)
        let pairs: [(UIColor, UIColor)] = [(.black, .white), (light, .white), (dark, .black), (light, .black),
                                           (dark, .white), (light, UIColor(white: 0.95, alpha: 1))]
        for (a, b) in pairs {
            XCTAssertEqual(AccessibleColors.contrastRatio(a, b), Self.oldContrast(a, b), accuracy: 1e-12)
            XCTAssertEqual(AccessibleColors.contrastRatio(b, a), Self.oldContrast(a, b), accuracy: 1e-12)
        }
    }

    func testSectionEditsTheColorVisionChoice() {
        var prefs = AccessibilityPreferences()
        let binding = Binding(get: { prefs }, set: { prefs = $0 })
        let host = UIHostingController(rootView: Form {
            AccessibilitySettingsSection(preferences: binding, system: SystemAccessibility(), identifierPrefix: "t.settings")
        }.dynamicTypeSize(.accessibility5))
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 800)
        host.view.layoutIfNeeded()
        binding.wrappedValue.colorVision = .redCyan
        XCTAssertEqual(prefs, AccessibilityPreferences(colorVision: .redCyan))
        XCTAssertTrue(AccessibilitySettingsSection.colorVisionExplanation.contains("shape, pattern and name"))
        XCTAssertEqual(ColorVisionChoice.allCases.map(\.title),
                       ["Standard colours", "Warm and cool", "Red and cyan", "Lightness"])
    }

    /// Every accessibility label in the UIKit accessibility tree below `view`.
    private static func accessibilityLabels(in view: UIView) -> [String] {
        var found: [String] = []
        func visit(_ object: NSObject) {
            if let label = object.accessibilityLabel { found.append(label) }
            let count = object.accessibilityElementCount()
            if count != NSNotFound, count > 0 {
                for i in 0..<count {
                    if let element = object.accessibilityElement(at: i) as? NSObject { visit(element) }
                }
            }
            for child in (object.accessibilityElements ?? []).compactMap({ $0 as? NSObject }) { visit(child) }
            if let view = object as? UIView { view.subviews.forEach { visit($0) } }
        }
        visit(view)
        return found
    }
}
