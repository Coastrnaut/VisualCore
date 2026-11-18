// SSEditorUITests — feature 161 (A22-P03) T-A22-311 (FR-A22-307; contracts/editor.md "Interface (`d3`)"): the editor
// and the inspector of Shader Studio (A22) inside the one app. A fresh start (erased data) opens A22 on Gradient. The
// first journey appends a broken line after the template's source (an undeclared name; the template's
// `uniform float u_speed;` stays declared, so the project still validates), runs it: the status reads "Failed", the
// gutter marks the new line and the diagnostics list names it; deleting the typed line restores the valid source, and
// a second run clears the marker and the list and reads "Compiled". The second journey moves the inspector's first
// slider (`uniform-0`, Speed): its value text changes; Reset (`reset`) brings back the default. Short bounded waits;
// each journey well under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class SSEditorUITests: XCTestCase {
    /// The broken line: `undefinedThing` is declared nowhere. It has no quotes, dashes or words a keyboard would
    /// correct, and stays broken (and as long) if its first letter is capitalised.
    static let brokenLine = "vec4 broken = vec4(undefinedThing);"

    override func setUp() { continueAfterFailure = false }

    /// A broken line is marked in the gutter and listed; the fix clears both.
    @MainActor
    func testBrokenLineIsMarkedAndTheFixClearsIt() {
        let app = SS.open()
        let valid = SS.source(app)
        XCTAssertTrue(valid.contains("uniform float u_speed;"), "the editor shows the Gradient source: \(valid)")
        // The source ends with a line break, so the typed text lands on a line of its own: the last one.
        let brokenNumber = valid.components(separatedBy: "\n").count

        XCTAssertTrue(SS.append(app, Self.brokenLine), "the broken line is typed")
        XCTAssertTrue(SS.run(app) { $0.hasPrefix("Failed") }, "the run fails: \(SS.status(app))")
        XCTAssertTrue(SS.diagnostic(app, 0).waitForExistence(timeout: SS.shortWait), "the list has an entry")
        XCTAssertTrue(SS.diagnostic(app, 0).label.contains("Line \(brokenNumber)"),
                      "the first entry names line \(brokenNumber): \(SS.diagnostic(app, 0).label)")
        let marker = SS.gutterLine(app, brokenNumber)
        XCTAssertTrue(SS.waitForLabel(marker) { $0.localizedCaseInsensitiveContains("error") },
                      "the gutter marks line \(brokenNumber): \(marker.exists ? marker.label : "missing")")
        XCTAssertGreaterThan(SS.markedLines(app).count, 0, "a gutter line is marked")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")

        XCTAssertTrue(SS.deleteLast(app, Self.brokenLine.count, expecting: valid), "the broken line is deleted")
        XCTAssertTrue(SS.run(app) { $0.hasPrefix("Compiled") }, "the fixed source compiles: \(SS.status(app))")
        XCTAssertTrue(SS.waitUntilEmpty(SS.markedLines(app)), "no gutter line is marked after the fix")
        XCTAssertTrue(SS.waitUntilEmpty(SS.diagnostics(app)), "the list is empty after the fix")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Moving the first inspector slider changes its value; Reset brings back the default.
    @MainActor
    func testInspectorSliderChangesAndResetRestoresIt() {
        let app = SS.open()
        guard let slider = SS.shown(app, "uniform-0") else { return }
        let before = SS.value(app, "uniform-0")
        XCTAssertFalse(before.isEmpty, "the slider has a value text")

        slider.adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertTrue(SS.waitForValue(slider) { $0 != before },
                      "the slider's value changed from \(before) (now \(SS.value(app, "uniform-0")))")

        XCTAssertTrue(SS.tap(app, "reset"), "Reset is tapped")
        XCTAssertTrue(SS.waitForValue(SS.control(app, "uniform-0")) { $0 == before },
                      "Reset brings back \(before) (now \(SS.value(app, "uniform-0")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
