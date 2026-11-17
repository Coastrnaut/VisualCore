// LWHistoryUITests — feature 143 (A19-P06) T-A19-608 (FR-A19-607; SC-A19-604, clarification Q5): the export history of
// Living Wallpapers (A19) inside the one app, the experience's only stored-data action. A fresh start (erased data, so
// the history is empty) opens A19 with the iPhone 16 Pro template; the device menu (`template`) is set to the iPhone SE
// template exactly as `LWExportUITests` does, Export (`export`) is tapped and the job ends (`LW.waitForExport`), the
// first history line (`history-0`, `EditorModel.historyLine`) names the iPhone SE, and Clear history (`clear-history`,
// `WallpaperControls.historyList`) is scrolled into view and tapped. Within a short bounded wait the list is gone:
// neither `history-0` nor `clear-history` is there (the list and its button show only while the history holds an
// entry), and no failure is shown. The stored history's erasure itself stays proven by `HistoryStoreTests`. One
// journey, short bounded waits, well under 60 s. System accessibility audits wait for the device campaign (owner
// ruling of 2026-11-13).
import XCTest

final class LWHistoryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The iPhone SE template exported is listed in the history, and Clear history removes the list and its button.
    @MainActor
    func testAnExportListedInTheHistoryIsRemovedByClearHistory() {
        let app = LW.open()

        XCTAssertTrue(LW.choose(app, "template", LW.iPhoneSE), "the device is chosen iPhone SE")
        XCTAssertFalse(LW.control(app, "history-0").exists, "a fresh start lists no export")

        XCTAssertTrue(LW.tap(app, "export"), "Export is tapped")
        let message = LW.waitForExport(app)
        XCTAssertTrue(message.hasPrefix("Exported"), "the export was written: \(message)")

        let history = LW.control(app, "history-0")
        waitFor(history, timeout: LW.shortWait, "the history lists the export")
        XCTAssertTrue(history.label.contains("iPhone SE"), "the history line names the iPhone SE: \(history.label)")

        let clear = LW.control(app, "clear-history")
        waitFor(clear, timeout: LW.shortWait, "the Clear history button is there")
        XCTAssertTrue(LW.reveal(app, clear), "Clear history is scrolled into view")
        clear.tap()

        XCTAssertTrue(waitUntilGone(history, timeout: LW.shortWait), "the history line is gone after Clear history")
        XCTAssertTrue(waitUntilGone(clear, timeout: LW.shortWait), "the Clear history button is gone")
        XCTAssertFalse(LW.control(app, "history-0").exists, "no history line remains")
        XCTAssertFalse(LW.control(app, "clear-history").exists, "no Clear history button remains")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
