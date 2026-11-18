// SSLibraryUITests — feature 162 (A22-P04) T-A22-412 (FR-A22-407; contracts/limits.md "Interface (`d3`)"): the
// guidance and the project library of Shader Studio (A22) inside the one app. A fresh start (erased data, so the
// library is empty) opens A22 on Gradient. The first journey appends a `#version 300 es` line (the validator refuses a
// #version line wherever it stands), runs it: the status reads "Refused" and the guidance under it (`guidance`) names
// the #version line; deleting the typed line and a second run read "Compiled". The second journey saves the Gradient
// source as "Waves" (`library` → `save` → `project-name` → `save-confirm`), appends a comment line, then opens "Waves"
// (`library` → `project-0` → `open`): the editor shows the saved source again. Short bounded waits; each journey well
// under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class SSLibraryUITests: XCTestCase {
    /// The refused line: GLSL's version directive, which Shader Studio supplies itself.
    static let versionLine = "#version 300 es"
    /// The change made after saving: a comment, so the source still validates.
    static let changeLine = "// changed"
    /// The name the project is saved under.
    static let projectName = "Waves"

    override func setUp() { continueAfterFailure = false }

    /// A #version line is refused with guidance that names it; deleting it compiles again.
    @MainActor
    func testVersionLineIsRefusedWithGuidance() {
        let app = SS.open()
        let valid = SS.source(app)
        XCTAssertTrue(valid.contains("uniform float u_speed;"), "the editor shows the Gradient source: \(valid)")

        // The source ends with a line break, so the typed directive lands on a line of its own: the last one.
        XCTAssertTrue(SS.append(app, Self.versionLine), "the #version line is typed")
        XCTAssertTrue(SS.run(app) { $0.hasPrefix("Refused") }, "the run is refused: \(SS.status(app))")
        let guidance = SS.control(app, "guidance")
        XCTAssertTrue(guidance.waitForExistence(timeout: SS.shortWait), "the guidance is shown under the status")
        XCTAssertTrue(SS.waitForLabel(guidance) { $0.contains("#version") },
                      "the guidance names the #version line: \(SS.guidance(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")

        XCTAssertTrue(SS.deleteLast(app, Self.versionLine.count, expecting: valid), "the #version line is deleted")
        XCTAssertTrue(SS.run(app) { $0.hasPrefix("Compiled") }, "the fixed source compiles: \(SS.status(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// A project saved as "Waves" and opened after a change brings back the saved source.
    @MainActor
    func testSavedProjectOpensWithItsSource() {
        let app = SS.open()
        let saved = SS.source(app)
        XCTAssertTrue(saved.contains("uniform float u_speed;"), "the editor shows the Gradient source: \(saved)")

        XCTAssertTrue(SS.tapAnywhere(app, "library"), "the library is opened")
        XCTAssertTrue(SS.tapAnywhere(app, "save"), "Save is tapped")
        let name = SS.control(app, "project-name")
        XCTAssertTrue(name.waitForExistence(timeout: SS.shortWait), "the name field is there")
        name.tap()
        name.typeText(Self.projectName)
        XCTAssertTrue(SS.tapAnywhere(app, "save-confirm"), "the save is confirmed")
        XCTAssertTrue(SS.waitForLabel(SS.project(app, 0)) { $0.contains(Self.projectName) },
                      "the library lists \(Self.projectName) first: \(SS.project(app, 0).label)")

        XCTAssertTrue(SS.backToEditor(app), "the editor is reached after saving")
        XCTAssertTrue(SS.append(app, Self.changeLine), "the source is changed")
        XCTAssertNotEqual(SS.source(app), saved, "the source differs from the saved one")

        XCTAssertTrue(SS.tapAnywhere(app, "library"), "the library is opened again")
        XCTAssertTrue(SS.waitForLabel(SS.project(app, 0)) { $0.contains(Self.projectName) },
                      "the library still lists \(Self.projectName): \(SS.project(app, 0).label)")
        XCTAssertTrue(SS.tapAnywhere(app, "project-0"), "\(Self.projectName) is selected")
        XCTAssertTrue(SS.tapAnywhere(app, "open"), "\(Self.projectName) is opened")

        SS.backToEditor(app)
        XCTAssertTrue(SS.waitForValue(SS.editor(app)) { $0 == saved },
                      "the editor shows the saved source again: \(SS.source(app))")
        XCTAssertFalse(SS.source(app).contains(Self.changeLine), "the change is gone")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
