// SSReleaseUITests — feature 164 (A22-P06) T-A22-608 (FR-A22-607; US4; clarification "Which interface journey
// runs?"): the first-session defaults of Shader Studio (A22) inside the one app, at the release gate. A fresh start
// (erased data, `SS.fresh`) opens A22 on Gradient; `SS.open` waits until the status reads "Compiled". No diagnostic is
// listed (no `diagnostic-0`), the inspector shows the template's one uniform (`uniform-0`, no `uniform-1`), and the
// library (`library`) is empty (no `project-0`). One journey in chunk `d3`, well under 60 s, every wait bounded.
// System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
// T-A22-614 (convergence; FR-A22-605): the store text's "Command-R runs it" is proved by pressing ⌘R on the
// hardware keyboard, never the Run button, after a broken line is typed: the status turns to "Failed".
import XCTest

final class SSReleaseUITests: XCTestCase {
    /// How long the empty library is watched for a row that should never appear.
    static let emptyLibraryWait: TimeInterval = 2

    override func setUp() { continueAfterFailure = false }

    /// A fresh start is compiled, without diagnostics, with one uniform and an empty library.
    @MainActor
    func testAFreshStartIsCompiledWithOneUniformAndAnEmptyLibrary() {
        let app = SS.open(arguments: SS.fresh)
        XCTAssertTrue(SS.status(app).hasPrefix("Compiled"), "a fresh start compiles: \(SS.status(app))")
        XCTAssertFalse(SS.diagnostic(app, 0).exists, "a fresh start lists no diagnostic")

        let uniform = SS.control(app, "uniform-0")
        waitFor(uniform, timeout: SS.shortWait, "the template's uniform is in the inspector")
        SS.reveal(app, uniform)
        XCTAssertTrue(uniform.exists, "uniform-0 is there")
        XCTAssertFalse(SS.control(app, "uniform-1").exists, "the Gradient template has a single uniform")

        XCTAssertTrue(SS.tapAnywhere(app, "library"), "the library is opened")
        XCTAssertFalse(SS.project(app, 0).waitForExistence(timeout: Self.emptyLibraryWait),
                       "a fresh library lists no project: \(SS.project(app, 0).label)")
        XCTAssertTrue(SS.backToEditor(app), "the editor is reached again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Command-R on the hardware keyboard runs the shader: a broken line typed into the editor fails at the run that
    /// ⌘R starts (the Run button is never tapped).
    @MainActor
    func testCommandRRunsTheShader() {
        let app = SS.open(arguments: SS.fresh)
        XCTAssertTrue(SS.append(app, "vec4 broken = vec4(undefinedThing);"), "the broken line is typed")
        app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(SS.waitForValue(SS.control(app, "status"), timeout: SS.runWait) { $0.hasPrefix("Failed") },
                      "Command-R ran the broken shader: \(SS.status(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
