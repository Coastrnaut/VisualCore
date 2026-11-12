// AppModelTests — feature 190 T-U04-006 (US1; FR-U04-010 to FR-U04-012, FR-U04-024, FR-U04-051; SC-U04-006): the
// bundled catalog and the registry agree; the app model shows the empty launcher for the real catalog and six
// tiles in three sections for the fixture; a premium tile gives the notice and no session; the quality override
// is applied when an experience opens. The storage helper `TestStorage` is in StoreTests.swift.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost
import XCTest
@testable import VisualCoreApp

@MainActor
final class AppModelTests: XCTestCase {
    private func bundled(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json"), "\(name).json missing")
        return try Data(contentsOf: url)
    }

    // MARK: The bundled catalog and the registry

    func testTheBundledCatalogLoadsWith100Experiences() throws {
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertEqual(manifest.experiences.count, 100)
        XCTAssertEqual(manifest.experiences.filter { $0.tier == .free }.count, 50)
        XCTAssertEqual(manifest.experiences.filter { $0.tier == .premium }.count, 50)
        XCTAssertEqual(Set(manifest.experiences.map(\.id)).count, 100)
    }

    func testTheRegistryAndTheBundledCatalogAgree() throws {
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        let registered = ExperienceRegistry.all.map(\.id)
        let report = manifest.registryReport(registered: registered)
        XCTAssertTrue(report.isMatch, "missing \(report.missingRegistrations), unexpected "
            + "\(report.unexpectedRegistrations), duplicates \(report.duplicates)")
        // Today no experience is integrated: none registered, none available.
        XCTAssertEqual(registered.count, manifest.available.count)
        XCTAssertEqual(registered, [])
        XCTAssertEqual(manifest.available.map(\.id), [])
    }

    func testTheRealCatalogGivesTheEmptyLauncher() throws {
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertEqual(model.launcher, .empty)
        XCTAssertEqual(model.shown.map(\.id), [])
        XCTAssertEqual(model.diagnostics.registryMismatches, [])
        XCTAssertNil(model.diagnostics.preferencesNote)
        XCTAssertTrue(model.showWelcome, "a first start shows the welcome")
        XCTAssertEqual(model.route, .catalog)
        XCTAssertNil(model.session.experience)
    }

    func testADamagedCatalogGivesTheErrorStateAndNoCrash() throws {
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: Data("not a catalog".utf8),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        guard case .error(let code) = model.launcher else { return XCTFail("\(model.launcher)") }
        XCTAssertFalse(code.isEmpty)
        XCTAssertEqual(model.shown.map(\.id), [])
    }

    func testDamagedPreferencesAreNotedInTheDiagnostics() throws {
        let storage = try TestStorage(self)
        storage.defaults.set(Data("{".utf8), forKey: ShellPreferences.storageKey)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertEqual(model.diagnostics.preferencesNote, "preferences.unreadable")
        XCTAssertEqual(model.preferences, ShellPreferences())
    }

    // MARK: The fixture catalog

    #if DEBUG
    private func fixtureModel(_ storage: TestStorage) -> AppModel {
        AppModel(environment: storage.environment(catalog: DebugLaunch.fixtureCatalogData,
                                                  categories: DebugLaunch.fixtureCategoriesData,
                                                  registry: DebugLaunch.fixtureRegistry))
    }

    private func tiles(_ model: AppModel) -> [LauncherTile] {
        guard case .sections(let sections) = model.launcher else { return [] }
        return sections.flatMap(\.tiles)
    }

    private func experienceID(of tile: LauncherTile) throws -> ExperienceID {
        let prefix = "vc.tile."
        XCTAssertTrue(tile.accessibilityIdentifier.hasPrefix(prefix), tile.accessibilityIdentifier)
        return try XCTUnwrap(ExperienceID(rawValue: String(tile.accessibilityIdentifier.dropFirst(prefix.count))))
    }

    private func freeIDs(_ model: AppModel) -> [ExperienceID] {
        model.shown.filter { $0.tier == .free }.map(\.id)
    }

    func testTheFixtureCatalogGivesSixTilesInThreeSections() throws {
        let model = fixtureModel(try TestStorage(self))
        guard case .sections(let sections) = model.launcher else { return XCTFail("\(model.launcher)") }
        XCTAssertEqual(sections.count, 3)
        XCTAssertTrue(sections.allSatisfy { !$0.tiles.isEmpty })
        let all = sections.flatMap(\.tiles)
        XCTAssertEqual(all.count, 6)
        XCTAssertEqual(Set(all.map(\.accessibilityIdentifier)).count, 6)
        XCTAssertEqual(all.filter(\.isPremium).count, 1)
        XCTAssertEqual(all.filter { !$0.isPremium }.count, 5)
        XCTAssertTrue(all.allSatisfy { $0.tierText == ($0.isPremium ? "Premium" : "Free") })
        XCTAssertEqual(freeIDs(model).count, 5)
        XCTAssertEqual(Set(freeIDs(model)), Set(DebugLaunch.fixtureRegistry.map(\.id)))
    }

    func testASearchWithoutResultGivesNoMatchAndIsStored() throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        model.searchText = "zzqqxxzz"
        XCTAssertEqual(model.launcher, .noMatch)
        XCTAssertEqual(PreferencesStore(defaults: storage.defaults).load().preferences.searchText, "zzqqxxzz")
        model.searchText = ""
        XCTAssertEqual(tiles(model).count, 6)
    }

    func testAPremiumTileGivesTheNoticeAndNoSession() async throws {
        let model = fixtureModel(try TestStorage(self))
        let premium = try experienceID(of: try XCTUnwrap(tiles(model).first(where: \.isPremium)))
        XCTAssertFalse(model.premiumNotice)
        let opened = await model.open(premium)
        XCTAssertFalse(opened)
        XCTAssertTrue(model.premiumNotice)
        XCTAssertNil(model.session.experience, "no session for a premium experience")
        XCTAssertEqual(model.route, .catalog)
        XCTAssertNil(model.lastAppliedTier)
        model.dismissPremiumNotice()
        XCTAssertFalse(model.premiumNotice)
    }

    func testAFreeExperienceOpensAndCloses() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let id = try XCTUnwrap(freeIDs(model).first)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertEqual(model.route, .experience(id))
        XCTAssertNotNil(model.session.experience)
        XCTAssertFalse(model.premiumNotice)
        XCTAssertEqual(PreferencesStore(defaults: storage.defaults).load().preferences.lastRoute, .experience(id))
        model.closeExperience()
        XCTAssertEqual(model.route, .catalog)
        XCTAssertNil(model.session.experience)
    }

    /// FR-U04-051: the debug experience declares two tiers (0 and 1).
    func testTheQualityOverrideIsAppliedWhenAnExperienceOpens() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let id = try XCTUnwrap(freeIDs(model).first)
        for (override, applied) in [(7, 1), (1, 1), (nil, nil)] as [(Int?, Int?)] {
            model.setQualityOverride(override)
            XCTAssertEqual(model.preferences.qualityOverride, override)
            XCTAssertEqual(PreferencesStore(defaults: storage.defaults).load().preferences.qualityOverride, override)
            let opened = await model.open(id)
            XCTAssertTrue(opened, "override \(String(describing: override))")
            XCTAssertEqual(model.lastAppliedTier, applied, "override \(String(describing: override))")
            model.closeExperience()
        }
    }

    func testTheWelcomeIsFinishedOnceAndOpensTheFirstFreeExperience() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        XCTAssertTrue(model.showWelcome)
        await model.finishWelcome(openFirst: true)
        XCTAssertFalse(model.showWelcome)
        XCTAssertEqual(model.route, .experience(try XCTUnwrap(freeIDs(model).first)))
        model.closeExperience()

        let second = fixtureModel(storage)
        XCTAssertFalse(second.showWelcome, "the welcome is shown once")
    }

    func testTheRouteAndTheAccessibilityChoicesAreStored() throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        model.go(.settings)
        model.setAccessibility(reduceMotion: .on, reduceFlashing: .off)
        XCTAssertEqual(model.route, .settings)
        let stored = PreferencesStore(defaults: storage.defaults).load().preferences
        XCTAssertEqual(stored.lastRoute, .settings)
        XCTAssertEqual(stored.reduceMotion, .on)
        XCTAssertEqual(stored.reduceFlashing, .off)
    }

    func testAnUnknownExperienceIsNotOpened() async throws {
        let model = fixtureModel(try TestStorage(self))
        let unknown = try ExperienceID("a99.no-such-experience")
        let opened = await model.open(unknown)
        XCTAssertFalse(opened)
        XCTAssertNil(model.session.experience)
        XCTAssertFalse(model.premiumNotice)
    }
    #endif
}
