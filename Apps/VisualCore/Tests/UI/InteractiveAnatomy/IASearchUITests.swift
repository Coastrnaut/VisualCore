// IASearchUITests — feature 129 (A17-P06) T-A17-608 (clarification Q4; FR-A17-607): the search field and the isolate
// controls of Interactive Anatomy (A17) inside the one app. Typing "ACL" in the search field (`search-field`) lists the
// anterior cruciate ligament (`search-result-8`, found by its synonym); choosing it selects the part (`structure-8`
// valued "Selected") and the panel names it. With a part selected, Isolate selected (`isolate-part`) isolates it
// ("Isolated: <name>, …") and Show all (`show-all`) ends the isolate ("Showing everything") without a failure. One
// journey per test, well under 60 s. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class IASearchUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// "ACL" typed in the search field: the first result is the anterior cruciate ligament, and choosing it selects it.
    @MainActor
    func testSearchingACLSelectsTheAnteriorCruciateLigament() {
        let app = IA.open()

        let field = IA.control(app, "search-field")
        waitFor(field, timeout: IA.shortWait, "the search field is there")
        XCTAssertEqual(field.label, "Search structures", "the search field is labelled Search structures")
        XCTAssertTrue(IA.tap(app, element: field, "the search field"), "the search field takes the focus")
        // The return key ends the editing and dismisses the keyboard, so it covers no result.
        field.typeText("ACL\n")

        // An empty query lists every part, so wait until the list has narrowed: Femur (result 0) no longer matches.
        let results = elements(app, prefix: IA.id("search-result-"))
        let aclID = IA.id("search-result-\(IA.aclIndex)")
        XCTAssertTrue(waitUntilGone(IA.control(app, "search-result-\(IA.femurIndex)"), timeout: IA.shortWait),
                      "the results narrowed to the matches of ACL")
        XCTAssertEqual(results.firstMatch.identifier, aclID, "the first result is the anterior cruciate ligament")
        let acl = IA.control(app, "search-result-\(IA.aclIndex)")
        XCTAssertTrue(acl.label.hasPrefix("Anterior cruciate ligament"),
                      "the result is labelled with the English name (now \(acl.label))")

        XCTAssertTrue(IA.tap(app, element: acl, "the ACL result"), "the result is chosen")
        let row = IA.row(app, IA.aclIndex)
        XCTAssertTrue(IA.waitForValue(row) { $0 == "Selected" },
                      "structure-\(IA.aclIndex) is selected (now \(IA.value(app, "structure-\(IA.aclIndex)")))")
        XCTAssertTrue(IA.waitForPanel(app) { $0.contains("Anterior cruciate ligament") },
                      "the panel names the anterior cruciate ligament (now \(IA.panelText(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// A part selected, Isolate selected, then Show all: the isolate starts and ends, with no failure.
    @MainActor
    func testIsolateSelectedThenShowAll() {
        let app = IA.open()

        XCTAssertTrue(IA.select(app, IA.femurIndex), "Femur is selected")
        let isolate = IA.control(app, "isolate-part")
        waitFor(isolate, timeout: IA.shortWait, "Isolate selected is there")
        XCTAssertTrue(IA.waitForLabel(isolate, timeout: IA.shortWait) { _ in isolate.isEnabled },
                      "Isolate selected is enabled with a selection")

        XCTAssertTrue(IA.tap(app, "isolate-part"), "Isolate selected is tapped")
        XCTAssertTrue(IA.waitForValue(isolate) { $0.hasPrefix("Isolated: Femur") },
                      "Femur is isolated (now \(IA.value(app, "isolate-part")))")

        XCTAssertTrue(IA.tap(app, "show-all"), "Show all is tapped")
        let showAll = IA.control(app, "show-all")
        XCTAssertTrue(IA.waitForValue(showAll) { $0 == "Showing everything" },
                      "the isolate has ended (now \(IA.value(app, "show-all")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
