// LauncherUITests — feature 190 T-U04-007 (US2; FR-U04-020 to FR-U04-023, FR-U04-012; SC-U04-002): the launcher
// shows the six fixture experiences under three headings with the tier as text, narrows them by search, says so
// when nothing matches or nothing is available, and answers a premium tile with a plain notice.
import XCTest

final class LauncherUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private static let fixtureLaunch = [VC.reset, VC.fixture, VC.skipWelcome]

    /// FR-U04-021: the label of a tile is its title and its tier.
    @MainActor
    func testATileLabelIsTheTitleAndTheTier() throws {
        let app = launchApp(arguments: Self.fixtureLaunch)
        waitFor(element(app, "vc.route.catalog"))
        waitFor(tile(app).firstMatch, timeout: VC.wait)
        let pattern = try NSRegularExpression(pattern: "^(.+), (Free|Premium)$")
        var checked = 0
        for item in tile(app).allElementsBoundByIndex {
            let label = item.label
            let match = pattern.firstMatch(in: label, range: NSRange(label.startIndex..., in: label))
            let found = try XCTUnwrap(match, "'\(label)' is not '<title>, <tier>'")
            let title = (label as NSString).substring(with: found.range(at: 1))
            let id = String(item.identifier.dropFirst(VC.tilePrefix.count))
            XCTAssertFalse(title.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertNotEqual(title, id, "the title is a name, not the id")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0)
    }

    /// FR-U04-022: the search field shows and holds at most 100 characters.
    @MainActor
    func testTheSearchFieldHoldsAtMost100Characters() {
        let app = launchApp(arguments: Self.fixtureLaunch)
        waitFor(element(app, "vc.route.catalog"))
        let field = element(app, "vc.search")
        waitFor(field, timeout: VC.wait)
        field.tap()
        field.typeText(String(repeating: "q", count: 108))
        let shown = field.value as? String ?? ""
        XCTAssertEqual(shown.count, 100, "the field shows '\(shown)'")
        XCTAssertEqual(shown, String(repeating: "q", count: 100))
        waitFor(element(app, "vc.nomatch"), timeout: VC.wait)
        let second = relaunch(app, arguments: [VC.fixture, VC.skipWelcome])
        let again = element(second, "vc.search")
        waitFor(again)
        XCTAssertEqual((again.value as? String ?? "").count, 100, "the stored text has 100 characters")
    }

    /// FR-U04-024: a catalog that cannot be loaded gives a message with the error's code; the app stays usable.
    @MainActor
    func testADamagedCatalogShowsItsCodeAndTheAppStaysUsable() {
        let app = launchApp(arguments: [VC.reset, VC.skipWelcome, VC.damagedCatalog])
        waitFor(element(app, "vc.route.catalog"))
        let message = element(app, "vc.error")
        waitFor(message, timeout: VC.wait)
        XCTAssertTrue(text(app, of: "vc.error").contains("catalog.unreadable"), text(app, of: "vc.error"))
        XCTAssertEqual(tile(app).count, 0)
        XCTAssertFalse(element(app, "vc.empty").exists)
        openSettings(app)
        let second = relaunch(app, arguments: [VC.skipWelcome, VC.damagedCatalog])
        waitFor(element(second, "vc.route.settings"), timeout: VC.firstWait, "the route is restored without a catalog")
    }

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
            scrollCatalog(app)
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

        // The clear control empties the field and brings every tile back.
        let clear = element(app, "vc.search.clear")
        waitFor(clear, timeout: VC.wait)
        clear.tap()
        XCTAssertTrue(waitUntilGone(element(app, "vc.nomatch")))
        waitFor(element(app, firstIdentifier), timeout: VC.wait)
        XCTAssertTrue(waitUntilGone(clear), "an empty field has no clear control")
    }

    @MainActor
    func testTheRealCatalogShowsTheEmptyStatementAndNoTile() {
        let app = launchApp(arguments: [VC.reset, VC.skipWelcome, VC.nothingAvailable])
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
        for _ in 0..<5 where !premium.exists { scrollCatalog(app) }
        revealAndTap(app, premium)
        waitFor(element(app, "vc.premium.notice"), timeout: VC.wait)
        XCTAssertFalse(element(app, VC.canvas).exists, "a premium experience is not opened by this feature")
        XCTAssertFalse(element(app, "vc.route.experience").exists)
        let dismiss = element(app, "vc.premium.dismiss")
        waitFor(dismiss, timeout: VC.wait)
        dismiss.tap()
        XCTAssertTrue(waitUntilGone(element(app, "vc.premium.notice")))
        XCTAssertTrue(element(app, "vc.route.catalog").exists)
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
        let empty = relaunch(app, arguments: [VC.reset, VC.skipWelcome, VC.nothingAvailable], largeText: largeText)
        waitFor(element(empty, "vc.empty"))
        try audit(empty, "catalog, empty", largeText: largeText)
    }
}
