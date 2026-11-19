// VPLCanvasUITests — feature 170 (A23-P05) T-A23-505 (FR-A23-504, SC-A23-504; clarification Q4; User Story 4;
// contracts/tests.md "Interface", chunk `e3`): the accessible list form of Visual Programming Lab (A23) inside the one
// app, without a single drag on the canvas. A fresh start (erased data) opens A23 on the starter graph Noise 1 →
// Output 2. The first journey adds a Mix (identity 3) from the inline list of `add-node` (`add-node-mix`), feeds
// both its inputs from Noise 1's image (`input-3-0`, `input-3-1`, each through its option `…-option-1-0`), frees
// Output 2's input (`input-2-0` → "None", option `none`: an input already fed refuses a second source) and feeds it
// from Mix 3's image (`3-0`); the connection line reads "Mix 3 image → Output 2 image" and the status "Ready". The
// second journey adds a Constant (identity 3) and chooses its colour (`3-1`) for Noise 1's scale (`input-1-1`): the
// choice is refused and `feedback` reads "A colour output cannot feed a scalar input."; the input stays "None".
// Short bounded waits; each journey well under 60 s. System accessibility audits wait for the device campaign (owner
// ruling of 2026-11-13).
import XCTest

final class VPLCanvasUITests: XCTestCase {
    /// The refusal's sentence for a colour output chosen for a scalar input.
    static let mismatch = "A colour output cannot feed a scalar input."

    override func setUp() { continueAfterFailure = false }

    /// The list form alone builds Noise 1 → Mix 3 (both inputs) → Output 2, and the status reads "Ready".
    @MainActor
    func testListFormBuildsAMixToReady() {
        let app = VPL.open()
        XCTAssertTrue(VPL.addNode(app, "Mix", expectedID: 3), "a Mix is added")

        XCTAssertTrue(VPL.choose(app, node: 3, input: 0, "Noise 1 image", tag: "1-0"),
                      "Mix 3 input a takes Noise 1's image")
        XCTAssertTrue(VPL.choose(app, node: 3, input: 1, "Noise 1 image", tag: "1-0"),
                      "Mix 3 input b takes Noise 1's image")
        XCTAssertTrue(VPL.choose(app, node: 2, input: 0, "None", tag: "none"), "Output 2's input is freed")
        XCTAssertTrue(VPL.choose(app, node: 2, input: 0, "Mix 3 image", tag: "3-0"), "Output 2 takes Mix 3's image")

        XCTAssertTrue(VPL.waitForLabel(VPL.connection(app, node: 2, input: 0)) { $0 == "Mix 3 image → Output 2 image" },
                      "the connection line names Mix 3: \(VPL.connection(app, node: 2, input: 0).label)")
        XCTAssertTrue(VPL.waitForStatus(app) { $0 == "Ready" }, "the status reads Ready: \(VPL.status(app))")
        XCTAssertFalse(VPL.control(app, "feedback").exists, "no refusal: \(VPL.feedback(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// A colour chosen for a scalar input is refused with its sentence, and the input stays unfed.
    @MainActor
    func testAMismatchedChoiceShowsItsSentence() {
        let app = VPL.open()
        XCTAssertTrue(VPL.addNode(app, "Constant", expectedID: 3), "a Constant is added")

        XCTAssertTrue(VPL.choose(app, node: 1, input: 1, "Constant 3 colour", tag: "3-1", expectValue: false),
                      "Constant 3's colour is chosen for Noise 1's scale")
        let feedback = VPL.control(app, "feedback")
        XCTAssertTrue(feedback.waitForExistence(timeout: VPL.shortWait), "the refusal is shown")
        XCTAssertTrue(VPL.waitForLabel(feedback) { $0 == Self.mismatch },
                      "the feedback names both types: \(VPL.feedback(app))")
        XCTAssertTrue(VPL.waitForValue(VPL.control(app, "input-1-1")) { $0 == "None" },
                      "Noise 1's scale stays unfed: \(VPL.control(app, "input-1-1").value as? String ?? "-")")
        XCTAssertFalse(VPL.connection(app, node: 1, input: 1).exists, "no connection into Noise 1's scale")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
