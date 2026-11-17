// LWClaimsUITests — feature 142 (A19-P05) T-A19-504 (FR-A19-502; SC-A19-502): the manual's regression fixture at the
// interface — no screen of Living Wallpapers (A19) claims that the app sets, installs or animates the wallpaper. The
// texts are collected from one snapshot of the app's element tree at a time (`LW.texts`: the labels, and values, of
// every static text, button, switch, slider, text field, link and menu item), so the screen is scanned as the person
// sees it, the shell's chrome (route title) included; nothing is excluded. The experience screen is collected while
// the controls are dragged from their top to their end (`LW.screenTexts`), and the help sheet while it is scrolled to
// its Done button (`LW.helpTexts`). The start caps the export limit at 1024 (`-lwExportLimit 1024`), so the screen
// also shows the notice and "Export at 470 × 1024"; after that export it shows the result line, the share link, the
// history and "How to use it", and is collected again, and the help is opened from both of its buttons (`help`,
// `result-help`). The joined texts, in lower case, hold none of the refused phrases of clarification Q5 ("live
// wallpaper", "set as wallpaper", "automatically", "sets your wallpaper", "installs", "animated wallpaper"), and the
// help holds "You set the wallpaper yourself" (`WallpaperHelp`). A hit names the element (type, identifier, text) so
// that a hit in the shell's chrome, outside the experience, can be told from one of the experience. Two journeys
// (the editor with its help; the screen after an export with the result's help), each with short bounded waits and
// under 60 s. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class LWClaimsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The editor's texts (with the notice at the capped limit) and its help: no refused phrase, and the help says the
    /// person sets the wallpaper.
    @MainActor
    func testTheEditorAndItsHelpClaimNothing() {
        let app = LW.open(arguments: LW.limited(1024))
        waitFor(LW.control(app, "export-notice"), timeout: LW.shortWait, "the notice is shown at the capped limit")

        var shown = LW.screenTexts(app)
        XCTAssertTrue(shown.contains { $0.identifier == LW.id("export-notice") }, "the notice was collected")

        let fromEditor = LW.helpTexts(app, from: "help")
        let editorHelp = fromEditor.map(\.text).joined(separator: " ")
        XCTAssertTrue(editorHelp.contains(LW.personSetsWallpaper),
                      "the help says \"\(LW.personSetsWallpaper)\": \(editorHelp)")
        shown.formUnion(fromEditor)

        XCTAssertGreaterThan(shown.count, 20, "the screens' texts were collected (\(shown.count))")
        assertNoRefusal(shown)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The screen after an export (result line, share link, history, "How to use it") and the help opened from the
    /// result: no refused phrase, and the help says the person sets the wallpaper.
    @MainActor
    func testTheExportResultAndItsHelpClaimNothing() {
        let app = LW.open(arguments: LW.limited(1024))
        XCTAssertTrue(LW.tap(app, "export-offered"), "Export at 470 × 1024 is tapped")
        let message = LW.waitForExport(app)
        XCTAssertTrue(message.hasPrefix("Exported"), "the offered export was written: \(message)")
        waitFor(LW.control(app, "history-0"), timeout: LW.shortWait, "the history lists the export")
        waitFor(LW.control(app, "share"), timeout: LW.shortWait, "the share link is there")

        // Back to the top of the controls, then collected through to their end.
        LW.reveal(app, LW.control(app, "help"))
        var shown = LW.screenTexts(app)
        XCTAssertTrue(shown.contains { $0.identifier == LW.id("export-message") }, "the result line was collected")
        XCTAssertTrue(shown.contains { $0.identifier == LW.id("history-0") }, "the history was collected")

        let fromResult = LW.helpTexts(app, from: "result-help")
        XCTAssertTrue(fromResult.map(\.text).joined(separator: " ").contains(LW.personSetsWallpaper),
                      "the help opened from the result says \"\(LW.personSetsWallpaper)\"")
        shown.formUnion(fromResult)

        XCTAssertGreaterThan(shown.count, 20, "the screens' texts were collected (\(shown.count))")
        assertNoRefusal(shown)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// No element's text, and not the joined texts in lower case, holds a refused phrase.
    @MainActor
    private func assertNoRefusal(_ shown: Set<LW.ShownText>, file: StaticString = #filePath, line: UInt = #line) {
        let hits = LW.refusals(in: shown)
        XCTAssertTrue(hits.isEmpty, "refused phrases shown:\n" + hits.joined(separator: "\n"), file: file, line: line)
        let joined = shown.map(\.text).joined(separator: "\n").lowercased()
        for phrase in LW.refusedPhrases {
            XCTAssertFalse(joined.contains(phrase), "the joined texts hold \"\(phrase)\"", file: file, line: line)
        }
    }
}
