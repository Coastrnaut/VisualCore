// ACThemeUITests — feature 136 (A18-P06) T-A18-608 (FR-A18-607; clarification Q5): a theme and a favourite of Ambient
// Clock (A18) inside the one app. A fresh start (erased data, so no favourite yet) opens A18 like `ACPowerUITests`;
// the theme menu (`theme`) is set to "Wave Field", the favourite name field (`favourite-name`) gets "Evening" and the
// Save button (`favourite-save`) saves it, so the first Apply button (`favourite-0`, labelled "Apply Evening") appears;
// the theme menu is set back to "Noise Gradient" (the default), the favourite is applied, and the theme menu shows
// "Wave Field" again. The identifiers are those of `AmbientControls` (`experience.a18.ambient-clock.<name>`). One
// journey, short waits and no sleeps, well under 60 s. System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class ACThemeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Wave Field saved as "Evening", the theme switched away, the favourite applied: the theme is Wave Field again.
    @MainActor
    func testAFavouriteSavedAndAppliedBringsItsThemeBack() {
        let app = AC.open()

        XCTAssertTrue(AC.choose(app, "theme", "Wave Field"), "the theme is chosen Wave Field")

        let field = AC.control(app, "favourite-name")
        waitFor(field, timeout: AC.shortWait, "the favourite name field is there")
        AC.reveal(app, field)
        field.tap()
        // The return key ends the editing and dismisses the keyboard, so it covers no control.
        field.typeText("Evening\n")

        let save = AC.control(app, "favourite-save")
        waitFor(save, timeout: AC.shortWait, "the Save favourite button is there")
        AC.reveal(app, save)
        save.tap()

        let favourite = AC.control(app, "favourite-0")
        waitFor(favourite, timeout: AC.shortWait, "the saved favourite has an Apply button")
        XCTAssertEqual(favourite.label, "Apply Evening", "the first favourite is Evening")
        XCTAssertTrue((favourite.value as? String ?? "").hasPrefix("Wave Field"),
                      "the favourite holds Wave Field (now \(favourite.value as? String ?? ""))")

        XCTAssertTrue(AC.choose(app, "theme", "Noise Gradient"), "the theme is switched back to Noise Gradient")

        let apply = AC.control(app, "favourite-0")
        waitFor(apply, timeout: AC.shortWait, "the Apply Evening button is still there")
        AC.reveal(app, apply)
        apply.tap()

        XCTAssertTrue(AC.waitForValue(AC.control(app, "theme")) { $0 == "Wave Field" },
                      "the theme menu shows Wave Field again (now \(AC.value(app, "theme")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
