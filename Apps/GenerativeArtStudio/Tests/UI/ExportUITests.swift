// ExportUITests — feature 015 T-A01-407 (US1; FR-A01-401, FR-A01-403, FR-A01-407, FR-A01-409).
import XCTest

final class ExportUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// LabeledContent rows read "<title>, <value>", so labels are matched by suffix.
    private func waitForLabel(_ e: XCUIElement, _ expected: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !e.label.hasSuffix(expected), Date() < deadline { usleep(200_000) }
        return e.label.hasSuffix(expected)
    }

    private func choose(_ app: XCUIApplication, picker id: String, option: String) {
        let picker = element(app, id)
        XCTAssertTrue(picker.waitForExistence(timeout: 5), id)
        picker.tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "\(id) option \(option)")
        item.tap()
    }

    func testExportSheetFlow() {
        let app = XCUIApplication()
        app.launch()
        let row = app.buttons["gas.family.gradient-noise"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let export = app.buttons["gas.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        XCTAssertEqual(export.label, "Export")
        export.tap()

        let dimensions = app.staticTexts["gas.export.dimensions"]
        XCTAssertTrue(dimensions.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForLabel(dimensions, "2048 × 2048 px"), "default 2048 px Square: \(dimensions.label)")
        XCTAssertTrue(app.staticTexts["gas.export.format"].label.hasSuffix("Opaque · sRGB"))
        let preview = element(app, "gas.export.preview")
        XCTAssertTrue(preview.exists)
        XCTAssertEqual(preview.label, "Crop preview, Square 1:1")

        // FR-A01-409: pickers expose labels and values.
        let size = element(app, "gas.export.size")
        XCTAssertTrue(size.label.contains("Size"), size.label)
        XCTAssertEqual(size.value as? String, "2048 px")

        choose(app, picker: "gas.export.aspect", option: "Portrait 4:5")
        XCTAssertTrue(waitForLabel(dimensions, "1638 × 2048 px"), dimensions.label)
        XCTAssertTrue(waitForLabel(preview, "Crop preview, Portrait 4:5"), preview.label)
        XCTAssertEqual(element(app, "gas.export.aspect").value as? String, "Portrait 4:5")
        choose(app, picker: "gas.export.size", option: "1080 px")
        XCTAssertTrue(waitForLabel(dimensions, "864 × 1080 px"), dimensions.label)
        choose(app, picker: "gas.export.aspect", option: "Landscape 16:9")
        XCTAssertTrue(waitForLabel(dimensions, "1080 × 608 px"), dimensions.label)

        let run = app.buttons["gas.export.run"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        let share = element(app, "gas.export.share")
        XCTAssertTrue(share.waitForExistence(timeout: 30), "share control after export")
        XCTAssertFalse(app.staticTexts["gas.export.error"].exists)

        app.buttons["gas.export.done"].tap()
        XCTAssertTrue(app.buttons["gas.controls.open"].waitForExistence(timeout: 5))
        XCTAssertFalse(dimensions.exists, "sheet closed")
        // The scene stays interactive: the controls still open.
        app.buttons["gas.controls.open"].tap()
        XCTAssertTrue(app.buttons["gas.time.playPause"].waitForExistence(timeout: 5))
    }
}
