// LWExportUITests — feature 142 (A19-P05) T-A19-503 (FR-A19-501; SC-A19-501): the export journey of Living Wallpapers
// (A19) inside the one app. A fresh start (erased data, so the history is empty) opens A19 with the iPhone 16 Pro
// template; the device menu (`template`) is set to the iPhone SE template, Export (`export`) is tapped, the job's
// progress (`export-progress`) ends, the result line (`export-message`, "Exported PNG, 750 × 1334 pixels, sRGB.",
// `ExportResultLine`) names the format, the size and sRGB, the share link (`share`) appears and the first history line
// (`history-0`) names the iPhone SE. A second start caps the export limit at 1024 (`-lwExportLimit 1024`,
// `LaunchOptions`): the iPhone 16 Pro template in portrait does not fit, so the notice (`export-notice`,
// `ExportNotice`) names its size 1206 × 2622, the limit 1024 and the offered size 470 × 1024 (`ExportGeometry` at the
// template's aspect: 2 × round(1024 × 1206 ÷ 2622 ÷ 2) = 470), and "Export at 470 × 1024" (`export-offered`) writes
// that size. Cancellation and recovery stay proven by A19-P04's `ExportJobTests` (an export this small finishes too
// fast to cancel reliably here). One journey per test, short bounded waits, well under 60 s. System accessibility
// audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class LWExportUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The iPhone SE template exported: the progress ends, the line names PNG, 750 × 1334 and sRGB, the share link is
    /// there and the history lists the export.
    @MainActor
    func testTheIPhoneSETemplateExportsWithItsResultLineShareAndHistory() {
        let app = LW.open()

        XCTAssertTrue(LW.choose(app, "template", LW.iPhoneSE), "the device is chosen iPhone SE")
        XCTAssertTrue(LW.shows(LW.control(app, "orientation"), "Portrait"), "a fresh start is in portrait")
        XCTAssertFalse(LW.control(app, "export-notice").exists, "the iPhone SE size fits: no notice")

        XCTAssertTrue(LW.tap(app, "export"), "Export is tapped")
        let message = LW.waitForExport(app)
        XCTAssertTrue(message.hasPrefix("Exported"), "the export was written: \(message)")
        XCTAssertTrue(message.contains("PNG"), "the result line names PNG: \(message)")
        XCTAssertTrue(message.contains(LW.size(750, 1334)), "the result line names 750 × 1334: \(message)")
        XCTAssertTrue(message.contains("sRGB"), "the result line names sRGB: \(message)")

        waitFor(LW.control(app, "share"), timeout: LW.shortWait, "the share link appears after the export")
        waitFor(LW.control(app, "result-help"), timeout: LW.shortWait, "the How to use it button appears")

        let history = LW.control(app, "history-0")
        waitFor(history, timeout: LW.shortWait, "the history lists the export")
        XCTAssertTrue(history.label.contains("iPhone SE"), "the history line names the iPhone SE: \(history.label)")
        XCTAssertTrue(history.label.contains(LW.size(750, 1334)), "the history line names the size: \(history.label)")
        XCTAssertFalse(LW.control(app, "history-1").exists, "a fresh start lists one export")
        XCTAssertFalse(LW.control(app, "export-retry").exists, "a written export offers no retry")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// With the export limit capped at 1024 the iPhone 16 Pro (portrait) shows the notice with 1206 × 2622, 1024 and
    /// 470 × 1024, and the offered export writes 470 × 1024.
    @MainActor
    func testALimitTooSmallShowsTheNoticeAndExportsAtTheOfferedSize() {
        let app = LW.open(arguments: LW.limited(1024))

        XCTAssertTrue(LW.choose(app, "template", LW.iPhone16Pro), "the device is chosen iPhone 16 Pro")
        XCTAssertTrue(LW.choose(app, "orientation", "Portrait"), "the orientation is chosen Portrait")

        let notice = LW.control(app, "export-notice")
        waitFor(notice, timeout: LW.shortWait, "the notice appears beside the device menu")
        XCTAssertTrue(notice.label.contains(LW.size(1206, 2622)), "the notice names 1206 × 2622: \(notice.label)")
        XCTAssertTrue(notice.label.contains("(1024)"), "the notice names the limit 1024: \(notice.label)")
        XCTAssertTrue(notice.label.contains(LW.size(470, 1024)), "the notice names 470 × 1024: \(notice.label)")

        let offered = LW.control(app, "export-offered")
        waitFor(offered, timeout: LW.shortWait, "the offered export button is there")
        XCTAssertTrue(offered.label.hasPrefix("Export at " + LW.size(470, 1024)),
                      "the button offers 470 × 1024: \(offered.label)")
        XCTAssertTrue(LW.tap(app, "export-offered"), "Export at 470 × 1024 is tapped")

        let message = LW.waitForExport(app)
        XCTAssertTrue(message.hasPrefix("Exported"), "the offered export was written: \(message)")
        XCTAssertTrue(message.contains(LW.size(470, 1024)), "the result line names 470 × 1024: \(message)")
        XCTAssertTrue(message.contains("PNG") && message.contains("sRGB"), "PNG in sRGB: \(message)")
        waitFor(LW.control(app, "share"), timeout: LW.shortWait, "the share link appears after the offered export")
        let history = LW.control(app, "history-0")
        waitFor(history, timeout: LW.shortWait, "the history lists the offered export")
        XCTAssertTrue(history.label.contains(LW.size(470, 1024)), "the history line names 470 × 1024: \(history.label)")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
