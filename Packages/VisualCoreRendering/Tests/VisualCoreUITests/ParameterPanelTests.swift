// ParameterPanelTests — feature 013 T-A01-203 (FR-A01-201, FR-A01-207).
import SwiftUI
import UIKit
import XCTest
import VisualCoreParameters
@testable import VisualCoreUI

@MainActor
final class ParameterPanelTests: XCTestCase {
    private func editor() throws -> ParameterEditor {
        try ParameterEditor(schema: ParameterSchema([
            ParameterDefinition(name: "count", title: "Particles per second", unit: "/s", range: 50...2000, defaultValue: 600, transform: .logarithmic),
            ParameterDefinition(name: "spread", title: "Spread", unit: "rad", range: 0.05...3.14, defaultValue: 0.6),
            ParameterDefinition(name: "drag", title: "Drag", range: 0...2, defaultValue: 0.3),
        ]))
    }

    func testRowsShowEveryParameterInOrderWithFormattedValues() throws {
        var e = try editor()
        var rows = ParameterPanelModel.rows(e)
        XCTAssertEqual(rows.map(\.id), ["count", "spread", "drag"])
        XCTAssertEqual(rows.map(\.title), ["Particles per second", "Spread", "Drag"])
        XCTAssertEqual(rows.map(\.value), ["600 /s", "0.6 rad", "0.3"])
        XCTAssertEqual(rows.filter(\.isModified).count, 0)
        e.set("drag", to: 1.5)
        rows = ParameterPanelModel.rows(e)
        XCTAssertTrue(rows[2].isModified)
        XCTAssertEqual(rows[2].value, "1.5")
        XCTAssertEqual(rows[2].position, 0.75, accuracy: 1e-12)
    }

    func testVoiceOverAdjustStaysInRange() throws {
        var e = try editor()
        let start = e.normalized("spread")
        ParameterPanelModel.adjust(&e, "spread", up: true)
        XCTAssertEqual(e.normalized("spread"), start + 0.05, accuracy: 1e-9)
        for _ in 0..<40 { ParameterPanelModel.adjust(&e, "spread", up: true) }
        XCTAssertEqual(e.values["spread"], 3.14)
        for _ in 0..<40 { ParameterPanelModel.adjust(&e, "count", up: false) }
        XCTAssertEqual(e.values["count"]!, 50, accuracy: 1e-9)
    }

    func testPanelRendersInAHostingController() throws {
        struct Host: View {
            @State var editor: ParameterEditor
            var body: some View { Form { ParameterPanel(editor: $editor) } }
        }
        let controller = UIHostingController(rootView: Host(editor: try editor()))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        XCTAssertGreaterThan(controller.view.subviews.count, 0)
        window.isHidden = true
    }
}
