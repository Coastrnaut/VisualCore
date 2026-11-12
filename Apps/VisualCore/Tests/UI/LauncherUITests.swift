// LauncherUITests — feature 190 T-U04-007 (US2; FR-U04-020 to FR-U04-023, FR-U04-012; SC-U04-002): the launcher
// shows the six fixture experiences under three headings with the tier as text, narrows them by search, says so
// when nothing matches or nothing is available, and answers a premium tile with a plain notice.
import XCTest

final class LauncherUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private static let fixtureLaunch = [VC.reset, VC.fixture, VC.skipWelcome]

    @MainActor
    func testSixTilesUnderThreeHeadingsWithTierText() {
        let app = launchApp(arguments: Self.fixtureLaunch)
        waitFor(element(app, "vc.route.catalog"))
        waitFor(tile(app).firstMatch, timeout: VC.wait)
        // Labels are read while the tiles are on screen; the headings are collected in the same pass.
        var tiers: [String: String] = [:]
        var sections: [String] = []
        for attempt in 0...5 {
            for item in tile(app).allElementsBoundByIndex where tiers[item.identifier] == nil {
                tiers[item.identifier] = item.label
            }
            for id in elements(app, prefix: VC.sectionPrefix).allElementsBoundByIndex.map(\.identifier)
            where !sections.contains(id) {
                sections.append(id)
            }
            if (tiers.count >= 6 && sections.count >= 3) || attempt == 5 { break }
            app.swipeUp()
        }
        XCTAssertEqual(tiers.count, 6, "tiles: \(tiers.keys.sorted())")
        XCTAssertEqual(sections.count, 3, "headings: \(sections)")
        for (id, label) in tiers {
            XCTAssertGreaterThan(id.count, VC.tilePrefix.count, "a tile identifier ends with the experience id")
            XCTAssertTrue(label.contains("Free") || label.contains("Premium"), "\(id) has no tier text: '\(label)'")
        }
        XCTAssertEqual(tiers.values.filter { $0.contains("Premium") }.count, 1, "one premium tile: \(tiers)")
        XCTAssertEqual(tiers.values.filter { $0.contains("Free") }.count, 5, "five free tiles: \(tiers)")
        XCTAssertFalse(element(app, "vc.empty").exists)
    }

    @MainActor
    func testSearchNarrowsAndAnUnmatchedSearchSaysSo() {
        let app = launchApp(arguments: Self.fixtureLaunch)
        waitFor(element(app, "vc.route.catalog"))
        let first = tile(app).firstMatch
        waitFor(first, timeout: VC.wait)
        let firstIdentifier = first.identifier
        // The id is `<code>.<slug>`; the slug's words are the title's words.
        let id = String(firstIdentifier.dropFirst(VC.tilePrefix.count))
        let words = id.split(separator: ".").dropFirst().joined(separator: " ").replacingOccurrences(of: "-", with: " ")
        XCTAssertFalse(words.isEmpty, firstIdentifier)

        let search = element(app, "vc.search")
        waitFor(search, timeout: VC.wait)
        search.tap()
        search.typeText(words)
        waitFor(element(app, firstIdentifier), timeout: VC.wait, "the searched tile stays")
        let deadline = Date().addingTimeInterval(VC.wait)
        while tile(app).count >= 6, Date() < deadline { usleep(200_000) }
        let narrowed = Set(tile(app).allElementsBoundByIndex.map(\.identifier))
        XCTAssertTrue(narrowed.contains(firstIdentifier), "\(narrowed)")
        XCTAssertLessThan(narrowed.count, 6, "'\(words)' narrows the tiles: \(narrowed)")
        XCTAssertFalse(element(app, "vc.nomatch").exists)

        search.typeText(" zzqqxxzz")
        waitFor(element(app, "vc.nomatch"), timeout: VC.wait)
        XCTAssertEqual(tile(app).count, 0)
    }

    @MainActor
    func testTheRealCatalogShowsTheEmptyStatementAndNoTile() {
        let app = launchApp(arguments: [VC.reset, VC.skipWelcome])
        waitFor(element(app, "vc.route.catalog"))
        waitFor(element(app, "vc.empty"), timeout: VC.wait)
        XCTAssertEqual(tile(app).count, 0)
        XCTAssertFalse(element(app, "vc.error").exists)
    }

    @MainActor
    func testThePremiumTileOpensTheNoticeAndNoExperience() {
        let app = launchApp(arguments: Self.fixtureLaunch)
        waitFor(element(app, "vc.route.catalog"))
        waitFor(tile(app).firstMatch, timeout: VC.wait)
        let premium = firstTile(app, tier: "Premium")
        for _ in 0..<5 where !premium.exists { app.swipeUp() }
        revealAndTap(app, premium)
        waitFor(element(app, "vc.premium.notice"), timeout: VC.wait)
        XCTAssertFalse(element(app, VC.canvas).exists, "a premium experience is not opened by this feature")
        XCTAssertFalse(element(app, "vc.route.experience").exists)
    }

    @MainActor
    func testAuditOfTheCatalogAtTheDefaultTextSize() throws { try auditCatalog(largeText: false) }

    @MainActor
    func testAuditOfTheCatalogAtTheLargestTextSize() throws { try auditCatalog(largeText: true) }

    @MainActor
    private func auditCatalog(largeText: Bool) throws {
        continueAfterFailure = true
        let app = launchApp(arguments: Self.fixtureLaunch, largeText: largeText)
        waitFor(element(app, "vc.route.catalog"))
        waitFor(tile(app).firstMatch, timeout: VC.wait)
        try audit(app, "catalog", largeText: largeText)
        let empty = relaunch(app, arguments: [VC.reset, VC.skipWelcome], largeText: largeText)
        waitFor(element(empty, "vc.empty"))
        try audit(empty, "catalog, empty", largeText: largeText)
    }
}
