// SandboxQualityUITests — feature 034 A04-P02 T-A04-211 (FR-A04-205; US3 AC1, AC3; SC-A04-204, SC-A04-206): the
// effective particle limit follows the DEBUG heat and Low Power launch arguments.
import XCTest

final class SandboxQualityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func open(_ arguments: [String]) -> XCUIElement {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        let open = app.buttons["pu.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        let text = app.staticTexts["pu.sandbox.effective"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        return text
    }

    /// (effective, requested, tier, tierCount) from "Effective limit: 2,400 of 4,000 (quality tier 2 of 4)".
    private func parse(_ label: String) -> [Int] {
        label.replacingOccurrences(of: ",", with: "").components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }.compactMap(Int.init)
    }

    private func waitFor(_ text: XCUIElement, timeout: TimeInterval, _ ok: ([Int]) -> Bool) -> [Int] {
        let end = Date().addingTimeInterval(timeout)
        var v = parse(text.label)
        while !ok(v) && Date() < end { Thread.sleep(forTimeInterval: 0.25); v = parse(text.label) }
        return v
    }

    func testNominalKeepsTheFullLimit() {
        let text = open(["-uitestThermal", "nominal", "-uitestLowPower", "NO"])
        let v = waitFor(text, timeout: 3) { $0 == [4_000, 4_000, 1, 4] }
        XCTAssertEqual(v, [4_000, 4_000, 1, 4], text.label)
    }

    func testSeriousHeatLowersTheLimit() {
        let text = open(["-uitestThermal", "serious", "-uitestLowPower", "NO"])
        let v = waitFor(text, timeout: 10) { $0.count == 4 && $0[0] <= 800 }
        XCTAssertEqual(v.count, 4, text.label)
        XCTAssertLessThan(v[0], 4_000, "the first hot decision steps down at once")
        XCTAssertEqual(v[0], 800, "serious heat reaches the lowest tier: \(text.label)")
        XCTAssertEqual(v[2], 4)
    }

    func testLowPowerCapsAtTierTwo() {
        let text = open(["-uitestThermal", "nominal", "-uitestLowPower", "YES"])
        let v = waitFor(text, timeout: 3) { $0.first == 2_400 }
        XCTAssertEqual(v, [2_400, 4_000, 2, 4], text.label)
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(parse(text.label), [2_400, 4_000, 2, 4], "Low Power holds the tier")
    }
}
