// AppModelTests — feature 190 T-U04-006 (US1; FR-U04-010 to FR-U04-012, FR-U04-024, FR-U04-051; SC-U04-006): the
// bundled catalog and the registry agree; the app model shows the empty launcher for the real catalog and six
// tiles in three sections for the fixture; a premium tile gives the notice and no session; the quality override
// is applied when an experience opens. The storage helper `TestStorage` is in StoreTests.swift.
import Foundation
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering
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
        XCTAssertEqual(code, "catalog.unreadable")
        XCTAssertEqual(model.diagnostics.catalog, "catalog.unreadable")
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

    // MARK: Convergence (T-U04-033, T-U04-034, T-U04-036 to T-U04-038, T-U04-041)

    private func model(_ storage: TestStorage, registry: [ExperienceRegistration],
                       arguments: [String] = []) -> AppModel {
        AppModel(environment: storage.environment(catalog: DebugLaunch.fixtureCatalogData,
                                                  categories: DebugLaunch.fixtureCategoriesData,
                                                  registry: registry, arguments: arguments))
    }

    /// US5, acceptance scenario 1: the stored accessibility choices are the value an experience receives.
    func testTheAccessibilityChoicesReachAnOpenedExperience() async throws {
        let storage = try TestStorage(self)
        let received = LaunchBox()
        let registry = DebugLaunch.fixtureFreeIDs.map { free in
            ExperienceRegistration(id: free, core: DebugExperienceCore.self) { launch in
                received.values.append(launch)
                return DebugExperience.make(id: free, launch: launch)
            }
        }
        let model = model(storage, registry: registry)
        let id = try XCTUnwrap(freeIDs(model).first)
        let first = await model.open(id)
        XCTAssertTrue(first)
        XCTAssertEqual(received.values.map(\.reduceMotion), [.system])
        XCTAssertEqual(received.values.map(\.reduceFlashing), [.system])
        XCTAssertEqual(received.values.map(\.storage.id), [id], "the factory receives the handle of its own id")
        model.closeExperience()

        model.setAccessibility(reduceMotion: .on, reduceFlashing: .off)
        let second = await model.open(id)
        XCTAssertTrue(second)
        XCTAssertEqual(received.values.last?.reduceMotion, .on)
        XCTAssertEqual(received.values.last?.reduceFlashing, .off)
        XCTAssertEqual(received.values.count, 2, "the factory is called once per open")
        model.closeExperience()

        // A new model on the same storage hands over the stored choices.
        let later = self.model(storage, registry: registry)
        let third = await later.open(id)
        XCTAssertTrue(third)
        XCTAssertEqual(received.values.last?.reduceMotion, .on)
        XCTAssertEqual(received.values.last?.reduceFlashing, .off)
        later.closeExperience()
    }

    /// FR-U04-011: a free experience without registration has no tile, and every mismatch is in the diagnostics.
    func testARegistryThatMismatchesTheCatalogHidesTheTileAndIsReported() async throws {
        let free = DebugLaunch.fixtureFreeIDs
        let dropped = try XCTUnwrap(free.first)
        let premium = try XCTUnwrap(DebugLaunch.fixturePremiumID)
        let categories = try CategoryList(data: DebugLaunch.fixtureCategoriesData)
        let manifest = try CatalogManifest(data: DebugLaunch.fixtureCatalogData, categories: categories)
        let unavailable = try XCTUnwrap(manifest.experiences.first { !$0.isAvailable && $0.tier == .free }).id
        let registry = free.dropFirst().map(DebugExperience.registration(for:))
            + [DebugExperience.registration(for: unavailable)]
        let model = model(try TestStorage(self), registry: Array(registry))

        XCTAssertEqual(model.diagnostics.registryMismatches,
                       [dropped.rawValue, unavailable.rawValue, premium.rawValue].sorted())
        let ids = try tiles(model).map(experienceID(of:))
        XCTAssertEqual(ids.count, 5, "four free tiles and the premium tile")
        XCTAssertFalse(ids.contains(dropped), "an unregistered free experience has no tile")
        XCTAssertFalse(ids.contains(unavailable), "a registered experience that is not available has no tile")
        let opened = await model.open(dropped)
        XCTAssertFalse(opened)
        XCTAssertNil(model.session.experience)
        XCTAssertTrue(model.diagnostics.text.contains("registryMismatches: "
            + model.diagnostics.registryMismatches.joined(separator: ",")))

        // The complete fixture registry leaves only the premium entry, which has no factory in this feature.
        XCTAssertEqual(fixtureModel(try TestStorage(self)).diagnostics.registryMismatches, [premium.rawValue])
    }

    /// Edge case: `-openExperience` with an unknown id, a malformed id or no value leaves a note and no session.
    func testOpenExperienceArgumentsThatCannotBeOpenedAreNoted() async throws {
        let cases: [([String], [String])] = [
            (["-openExperience", "a99.no-such-experience"], ["-openExperience a99.no-such-experience"]),
            (["-openExperience", "Not An Id"], ["-openExperience Not An Id"]),
            (["-vcFixtureCatalog", "-openExperience"], ["-openExperience"]),
            (["-vcBogus", "-vcSkipWelcome"], ["-vcBogus"]),
        ]
        for (arguments, expected) in cases {
            let model = model(try TestStorage(self), registry: DebugLaunch.fixtureRegistry, arguments: arguments)
            await DebugLaunch.start(model)
            XCTAssertEqual(model.diagnostics.unknownArguments, expected, "\(arguments)")
            XCTAssertTrue(model.diagnostics.text.contains("unknownArguments: " + expected.joined(separator: ",")))
            XCTAssertEqual(model.route, .catalog, "\(arguments)")
            XCTAssertNil(model.session.experience, "\(arguments)")
            XCTAssertTrue(model.showWelcome, "a first start keeps its welcome: \(arguments)")
        }
    }

    /// FR-U04-043: `-openExperience <id>` opens directly on a first start; the welcome stays unseen.
    func testOpenExperienceArgumentOpensDirectlyOnAFirstStart() async throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let model = model(storage, registry: DebugLaunch.fixtureRegistry,
                          arguments: ["-openExperience", id.rawValue])
        XCTAssertTrue(model.showWelcome)
        await DebugLaunch.start(model)
        XCTAssertFalse(model.showWelcome, "the experience is not covered by the welcome")
        XCTAssertEqual(model.route, .experience(id))
        XCTAssertNotNil(model.session.experience)
        XCTAssertEqual(model.diagnostics.unknownArguments, [])
        XCTAssertFalse(PreferencesStore(defaults: storage.defaults).load().preferences.welcomeSeen,
                       "the argument does not mark the welcome as seen")
        model.closeExperience()
    }

    /// FR-U04-022: the model holds at most 100 characters of search text.
    func testASearchTextOfMoreThan100CharactersIsHeldAs100() throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        model.searchText = String(repeating: "a", count: 130)
        XCTAssertEqual(model.searchText.count, 100)
        XCTAssertEqual(PreferencesStore(defaults: storage.defaults).load().preferences.searchText.count, 100)
    }

    /// Edge case: an experience that fails to open keeps its route, where the session shows the failure view.
    func testAFailedOpenKeepsTheExperienceRouteWithTheFailureState() async throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let registry = [DebugExperience.failingRegistration(for: id)]
            + DebugLaunch.fixtureFreeIDs.dropFirst().map(DebugExperience.registration(for:))
        let model = model(storage, registry: registry)
        let opened = await model.open(id)
        XCTAssertFalse(opened)
        XCTAssertEqual(model.session.state, .failed)
        XCTAssertEqual(model.route, .experience(id))
        XCTAssertNil(model.lastAppliedTier)
        // The app stays usable: another experience opens, and the catalog is reachable.
        let other = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.dropFirst().first)
        let second = await model.open(other)
        XCTAssertTrue(second)
        XCTAssertEqual(model.route, .experience(other))
        model.closeExperience()
        XCTAssertEqual(model.route, .catalog)
        XCTAssertEqual(model.session.state, .idle)
    }

    /// FR-U04-051: an experience that the failure view's Retry opens again runs with the stored quality override.
    func testTheQualityOverrideIsAppliedAfterARetry() async throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let calls = LaunchBox()
        let registry = [ExperienceRegistration(id: id, core: DebugExperienceCore.self) { launch in
            calls.values.append(launch)
            return ExperienceShell(id: id, presenter: DebugPresenter(experienceID: id, launch: launch,
                                                                     failsSetup: calls.values.count == 1))
        }]
        let model = model(storage, registry: registry)
        model.setQualityOverride(7)
        let opened = await model.open(id)
        XCTAssertFalse(opened)
        XCTAssertEqual(model.session.state, .failed)
        XCTAssertNil(model.lastAppliedTier)

        // What the Retry button of the failure view does. The session itself applies the pin (UA-F06).
        _ = await model.session.retry()
        XCTAssertEqual(model.session.state, .running)
        XCTAssertEqual(model.session.experience?.diagnostics.qualityTier, 1)
        XCTAssertEqual(model.lastAppliedTier, 1, "the debug experience declares two tiers; 7 becomes its last one")
        XCTAssertEqual(calls.values.count, 2)
        model.closeExperience()
    }

    // MARK: Quality and performance (UA-F06: T-U06-016, T-U06-020, T-U06-024, T-U06-028)

    /// FR-U06-004: the fixture experience declares as many named levels as its logic declares tiers.
    func testTheFixtureExperienceDeclaresTwoNamedLevels() throws {
        let profile = DebugExperienceCore.qualityProfile
        XCTAssertEqual(profile.names, ["full", "reduced"])
        XCTAssertEqual(profile.count, DebugExperienceCore.qualityTiers)
        XCTAssertEqual(QualityDeclaration.problems(profile: profile, tierCount: DebugExperienceCore.qualityTiers,
                                                   catalogNames: nil), [])
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        XCTAssertEqual(DebugExperience.make(id: id, launch: try TestStorage(self).launch(id)).qualityProfile, profile, "the session sees the core's profile")
    }

    /// SC-U06-001: the fixture experience keeps every obligation of the contract, the two of UA-F06 among them:
    /// its profile matches its tiers, and no level changes its state digest.
    func testTheFixtureExperiencePassesTheConformanceRun() async throws {
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let plan = ConformancePlan(seeds: [1, 2, 3], stepsPerSegment: 30,
                                   actions: [ScriptedAction("tap", []), ScriptedAction("tap", [])], rejected: [])
        let report = await ExperienceConformance.run(DebugExperienceCore.self, id: id, plan: plan)
        XCTAssertTrue(report.passed, "\(report.entries.filter { !$0.passed })")
        XCTAssertEqual(report.entries.count, ConformanceCheck.allCases.count)
        XCTAssertTrue(report.entries.contains { $0.check == .profileMatchesTiers && $0.passed })
        XCTAssertTrue(report.entries.contains { $0.check == .tierKeepsDigest && $0.passed })
    }

    /// FR-U06-004: every registered experience of the real registry names its levels as the catalog does.
    /// Today nothing is registered; the loop binds every later integration.
    func testRegisteredExperiencesDeclareTheCatalogLevelNames() throws {
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        for registration in ExperienceRegistry.all {
            let profile = registration.make(try TestStorage(self).launch(registration.id)).qualityProfile
            let names = try XCTUnwrap(manifest.experience(registration.id), "\(registration.id)").qualityTiers
            XCTAssertEqual(QualityDeclaration.problems(profile: profile, tierCount: profile.count,
                                                       catalogNames: names), [], "\(registration.id)")
        }
        XCTAssertEqual(ExperienceRegistry.all.count, 0, "no experience is integrated yet")
    }

    /// FR-U06-013: a pinned level is in force when the first frame is drawn, and the record says so.
    func testThePinnedLevelIsInForceFromTheFirstFrame() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let id = try XCTUnwrap(freeIDs(model).first)
        model.setQualityOverride(1)
        XCTAssertEqual(model.session.qualityPin, 1)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        // Nothing but the open happened: the level was set before the first frame.
        XCTAssertEqual(model.session.experience?.diagnostics.qualityTier, 1)
        XCTAssertEqual(model.session.qualityLevel, 1)
        XCTAssertEqual(model.lastAppliedTier, 1)
        let running = try XCTUnwrap(model.session.performanceRecord)
        XCTAssertEqual(running.qualityLevel, 1)
        XCTAssertTrue(running.qualityPinned)
        XCTAssertEqual(running.qualityLevels, 2)
        model.closeExperience()

        // A new model on the same storage pins the stored level; automatic clears the pin.
        let later = fixtureModel(storage)
        XCTAssertEqual(later.session.qualityPin, 1)
        later.setQualityOverride(nil)
        XCTAssertNil(later.session.qualityPin)
        let again = await later.open(id)
        XCTAssertTrue(again)
        XCTAssertEqual(later.session.qualityLevel, 0)
        XCTAssertNil(later.lastAppliedTier)
        later.closeExperience()
    }

    /// FR-U06-040, FR-U06-043: after an open and a close the session keeps the performance record.
    func testThePerformanceRecordOfAnOpenAndACloseIsKept() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let id = try XCTUnwrap(freeIDs(model).first)
        XCTAssertNil(model.session.lastPerformanceRecord)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        // SC-U06-005: 600 interactive frames compile no shader program. The host gets a surface first; without
        // one no frame is drawn (convergence T-U06-045).
        let host = try XCTUnwrap(model.session.renderHost)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        host.view.layoutIfNeeded()
        var drawn = 0
        for _ in 0..<600 where host.renderOneFrame(present: false) { drawn += 1 }
        XCTAssertEqual(drawn, 600, "every frame was drawn")
        XCTAssertEqual(model.session.experience?.diagnostics.stepIndex, 1_200, "600 frames of 1/60 s are 1,200 steps")
        XCTAssertEqual(model.session.performanceRecord?.lateCompilations, 0)
        XCTAssertEqual(host.resources.compileCount, model.session.diagnostics.timings.programsCompiled)
        model.closeExperience()
        XCTAssertNil(model.session.performanceRecord)
        let record = try XCTUnwrap(model.session.lastPerformanceRecord)
        XCTAssertEqual(record.experience, id.rawValue)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(record.prepareMs), 0)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(record.setupMs), 0)
        XCTAssertNotNil(record.programsCompiled)
        XCTAssertEqual(record.lateCompilations, 0)
        XCTAssertTrue(record.passes)
        XCTAssertEqual(record.qualityLevels, 2)
        XCTAssertFalse(record.qualityPinned)
        let text = try record.encoded()
        XCTAssertEqual(try PerformanceRecord(data: text), record)
        XCTAssertNotEqual(SettingsView.performanceText(record), "none")
        XCTAssertEqual(SettingsView.performanceText(nil), "none")
    }

    /// FR-U06-024: one launch time per process, marked as a first start when no preferences were stored, and
    /// taken before any rendering context exists.
    func testTheLaunchTimeIsRecordedOncePerProcess() async throws {
        let storage = try TestStorage(self)
        var environment = storage.environment(catalog: DebugLaunch.fixtureCatalogData,
                                              categories: DebugLaunch.fixtureCategoriesData,
                                              registry: DebugLaunch.fixtureRegistry)
        environment.launchStart = ContinuousClock.now
        let model = AppModel(environment: environment)
        XCTAssertNil(model.session.launch)
        model.noteLauncherUsable()
        let launch = try XCTUnwrap(model.session.launch)
        XCTAssertGreaterThanOrEqual(launch.milliseconds, 0)
        XCTAssertLessThan(launch.milliseconds, 60_000)
        XCTAssertTrue(launch.firstLaunch, "no preferences were stored")
        XCTAssertEqual(model.session.hostsAlive, 0, "no rendering context before the launcher is usable")
        model.noteLauncherUsable()
        XCTAssertEqual(model.session.launch, launch, "recorded once")

        // The launch time is part of the record of an experience.
        let id = try XCTUnwrap(freeIDs(model).first)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertEqual(model.session.performanceRecord?.launchMs, launch.milliseconds)
        XCTAssertEqual(model.session.performanceRecord?.firstLaunch, true)
        model.closeExperience()

        // A later start finds stored preferences: not a first start. Without a start instant nothing is recorded.
        var second = environment
        second.launchStart = ContinuousClock.now
        let later = AppModel(environment: second)
        later.noteLauncherUsable()
        XCTAssertEqual(later.session.launch?.firstLaunch, false)
        let none = fixtureModel(storage)
        none.noteLauncherUsable()
        XCTAssertNil(none.session.launch)
    }

    /// Edge case: leaving while an experience prepares cancels the open and returns to the catalog.
    func testLeavingWhileAnExperiencePreparesCancelsAndReturnsToTheCatalog() async throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let registry = [ExperienceRegistration(id: id, core: SlowPresenter.Core.self) { _ in
            ExperienceShell(id: id, presenter: SlowPresenter())
        }]
            + DebugLaunch.fixtureFreeIDs.dropFirst().map(DebugExperience.registration(for:))
        let model = model(storage, registry: registry)
        let task = Task { await model.open(id) }
        for _ in 0..<500 where model.session.state != .preparing {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(model.session.state, .preparing)
        XCTAssertEqual(model.route, .experience(id))
        model.closeExperience()
        let opened = await task.value
        XCTAssertFalse(opened)
        XCTAssertEqual(model.route, .catalog)
        XCTAssertEqual(model.session.state, .idle)
        XCTAssertNil(model.session.experience)
        XCTAssertEqual(PreferencesStore(defaults: storage.defaults).load().preferences.lastRoute, .catalog)
    }

    // MARK: Storage handles (feature 191, T-U05-012; FR-U05-002, FR-U05-006)

    func testTwoExperiencesEachSeeOnlyTheirOwnStoredValue() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let ids = Array(freeIDs(model).prefix(2))
        XCTAssertEqual(ids.count, 2)
        for id in ids {
            let opened = await model.open(id)
            XCTAssertTrue(opened)
        }
        let again = await model.open(ids[0])
        XCTAssertTrue(again)
        model.closeExperience()
        XCTAssertEqual(DebugExperience.opens(in: storage.handle(ids[0])), 2)
        XCTAssertEqual(DebugExperience.opens(in: storage.handle(ids[1])), 1)
        for id in ids {
            XCTAssertEqual(storage.handle(id).valueKeys(), [DebugExperience.opensKey])
            XCTAssertNotNil(storage.defaults.object(forKey: "exp.\(id.rawValue).opens"))
        }
        XCTAssertNil(storage.handle(ids[0]).value(for: "exp.\(ids[1].rawValue).opens"))
    }

    // MARK: Saved state (feature 191, T-U05-015; FR-U05-010 to FR-U05-015, FR-U05-020 to FR-U05-022)

    private func persistenceModel(_ storage: TestStorage, sleep: ScriptedSleep,
                                  registry: [ExperienceRegistration] = DebugLaunch.fixtureRegistry) -> AppModel {
        var environment = storage.environment(catalog: DebugLaunch.fixtureCatalogData,
                                              categories: DebugLaunch.fixtureCategoriesData, registry: registry)
        environment.checkpointSleep = { duration in try await sleep.sleep(duration) }
        addTeardownBlock { sleep.fire() }
        return AppModel(environment: environment)
    }

    /// Sends `count` taps to the open debug experience.
    private func tap(_ model: AppModel, _ count: Int = 1) {
        for _ in 0..<count {
            XCTAssertEqual(model.session.experience?.handle(control: "tap", values: []), .accepted)
        }
    }

    /// Lets the main actor run what was scheduled, until `condition` holds or about two seconds passed.
    private func settle(until condition: () -> Bool = { false }) async throws {
        for _ in 0..<40 where !condition() {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        for _ in 0..<10 { await Task.yield() }
    }

    /// The stored state of `id` on `storage`; fails the test when it is not a readable state.
    private func storedState(_ storage: TestStorage, _ id: ExperienceID,
                             file: StaticString = #filePath, line: UInt = #line) -> ExperienceSnapshot? {
        guard case .state(let snapshot) = SavedStateStore(root: storage.root).load(id) else {
            XCTFail("no readable stored state", file: file, line: line)
            return nil
        }
        return snapshot
    }

    /// The taps of the stored state of `id`, or nil without a readable state; never fails the test (for waits).
    private func quietTaps(_ storage: TestStorage, _ id: ExperienceID) -> Int? {
        guard case .state(let snapshot) = SavedStateStore(root: storage.root).load(id) else { return nil }
        return taps(of: snapshot)
    }

    private func stateURL(_ storage: TestStorage, _ id: ExperienceID) -> URL {
        SavedStateStore(root: storage.root).stateURL(for: id)
    }

    private func taps(of snapshot: ExperienceSnapshot?) -> Int? {
        guard let snapshot, let object = try? JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)),
              let fields = object as? [String: Any] else { return nil }
        return fields["count"] as? Int
    }

    func testAStateChangedByActionsIsRestoredAfterACloseAndByANewModel() async throws {
        let storage = try TestStorage(self)
        let sleep = ScriptedSleep()
        let model = persistenceModel(storage, sleep: sleep)
        let id = try XCTUnwrap(freeIDs(model).first)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL(storage, id).path), "nothing saved yet")
        tap(model, 3)
        model.closeExperience()
        let first = try XCTUnwrap(storedState(storage, id))
        XCTAssertEqual(taps(of: first), 3)
        XCTAssertEqual(first.seed, AppModel.seed(for: id))

        let reopened = await model.open(id)
        XCTAssertTrue(reopened)
        XCTAssertTrue(model.session.experience?.port.summary.contains("3 taps") ?? false,
                      model.session.experience?.port.summary ?? "no experience")
        model.closeExperience()
        let second = try XCTUnwrap(storedState(storage, id))
        XCTAssertEqual(second.digest, first.digest)
        XCTAssertEqual(second.seed, first.seed)
        XCTAssertEqual(second.stepIndex, first.stepIndex)

        let later = persistenceModel(storage, sleep: sleep)
        let third = await later.open(id)
        XCTAssertTrue(third)
        XCTAssertTrue(later.session.experience?.port.summary.contains("3 taps") ?? false)
        later.closeExperience()
        let last = try XCTUnwrap(storedState(storage, id))
        XCTAssertEqual(last.digest, first.digest)
        XCTAssertEqual(last.stepIndex, first.stepIndex)
    }

    func testAnAcceptedActionIsSavedOnceWhenTheDelayEndsAndNotBefore() async throws {
        let storage = try TestStorage(self)
        let sleep = ScriptedSleep()
        let model = persistenceModel(storage, sleep: sleep)
        let id = try XCTUnwrap(freeIDs(model).first)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        let url = stateURL(storage, id)

        // No action: no checkpoint is scheduled at all, however long the scripted time is.
        try await settle()
        XCTAssertEqual(sleep.calls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

        // Several actions inside the delay: one delay, no save before it ends, one save after.
        tap(model, 1)
        try await settle { sleep.pending == 1 }
        tap(model, 2)
        try await settle()
        XCTAssertEqual(sleep.calls, 1, "further actions inside the delay do not start another one")
        XCTAssertEqual(sleep.durations, [AppModel.checkpointDelay])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "no save before the delay ends")
        sleep.fire()
        try await settle { FileManager.default.fileExists(atPath: url.path) }
        XCTAssertEqual(taps(of: storedState(storage, id)), 3)
        XCTAssertEqual(model.session.state, .running)

        // A state equal to the stored one is not written again.
        let past = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: url.path)
        model.session.checkpoint()
        let date = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertEqual(date, past)

        // The next action starts the next delay; its save holds the new state.
        tap(model, 1)
        try await settle { sleep.pending == 1 }
        XCTAssertEqual(sleep.calls, 2)
        sleep.fire()
        try await settle { self.quietTaps(storage, id) == 4 }
        XCTAssertEqual(taps(of: storedState(storage, id)), 4)
        XCTAssertNil(model.diagnostics.lastSaveFailure)

        // A pending checkpoint is dropped by the close, which saves itself.
        tap(model, 1)
        try await settle { sleep.pending == 1 }
        model.closeExperience()
        XCTAssertEqual(taps(of: storedState(storage, id)), 5)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: url.path)
        sleep.fire()
        try await settle()
        let after = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertEqual(after, past, "the dropped checkpoint writes nothing")
    }

    func testASuspensionSavesOnceAndASecondModelReadsTheCompleteState() async throws {
        let storage = try TestStorage(self)
        let sleep = ScriptedSleep()
        let model = persistenceModel(storage, sleep: sleep)
        let id = try XCTUnwrap(freeIDs(model).first)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        tap(model, 2)
        // Two starts in quick succession: the second model exists before the first one saved.
        let second = persistenceModel(storage, sleep: sleep)
        model.session.setScenePhase(.background)
        XCTAssertEqual(taps(of: storedState(storage, id)), 2)
        let reopened = await second.open(id)
        XCTAssertTrue(reopened)
        XCTAssertTrue(second.session.experience?.port.summary.contains("2 taps") ?? false)
        second.closeExperience()
        model.closeExperience()
    }

    func testAFailedExperienceAndACancelledPreparationSaveNothing() async throws {
        let storage = try TestStorage(self)
        let sleep = ScriptedSleep()
        let failing = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let slow = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.dropFirst().first)
        let registry = [DebugExperience.failingRegistration(for: failing),
                        ExperienceRegistration(id: slow, core: SlowPresenter.Core.self) { _ in
                            ExperienceShell(id: slow, presenter: SlowPresenter())
                        }]
        let model = persistenceModel(storage, sleep: sleep, registry: registry)
        let opened = await model.open(failing)
        XCTAssertFalse(opened)
        XCTAssertEqual(model.session.state, .failed)
        XCTAssertNil(model.unreadable, "a failure of the set-up is not an unreadable state")
        model.closeExperience()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL(storage, failing).path))

        let task = Task { await model.open(slow) }
        for _ in 0..<500 where model.session.state != .preparing {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        model.closeExperience()
        let cancelled = await task.value
        XCTAssertFalse(cancelled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL(storage, slow).path))
        XCTAssertEqual(sleep.calls, 0)
    }

    func testASaveFailureIsRecordedAndTheExperienceKeepsRunning() async throws {
        let storage = try TestStorage(self)
        let sleep = ScriptedSleep()
        let model = persistenceModel(storage, sleep: sleep)
        let id = try XCTUnwrap(freeIDs(model).first)
        // A file in the place of the experience's folder: nothing can be written below it.
        try Data("in the way".utf8).write(to: storage.root.appendingPathComponent(id.storageNamespace))
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        tap(model, 1)
        model.session.checkpoint()
        XCTAssertEqual(model.diagnostics.lastSaveFailure, "storage.write-failed")
        XCTAssertEqual(model.session.state, .running)
        XCTAssertEqual(model.session.experience?.handle(control: "tap", values: []), .accepted)
        model.closeExperience()
        XCTAssertEqual(model.session.state, .idle)
    }

    func testLeftoverTemporaryFilesAreRemovedAtTheStart() throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let folder = storage.root.appendingPathComponent(id.storageNamespace)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("half".utf8).write(to: folder.appendingPathComponent(".state.json.tmp-interrupted"))
        try Data("kept".utf8).write(to: folder.appendingPathComponent("kept.txt"))
        let model = fixtureModel(storage)
        XCTAssertEqual(model.diagnostics.leftoversRemoved, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["kept.txt"])
        XCTAssertTrue(model.diagnostics.text.contains("leftoversRemoved: 1"))
    }

    // MARK: Retry after a failure (feature 191, T-U05-036; FR-U05-020, FR-U05-011)

    func testRetryAfterAFailureWhileRunningRestoresTheCheckpointedState() async throws {
        let storage = try TestStorage(self)
        let sleep = ScriptedSleep()
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let switches = FlakySwitch()
        let registry = [ExperienceRegistration(id: id, core: DebugExperienceCore.self) { launch in
            ExperienceShell(id: id, presenter: FlakyPresenter(inner: DebugPresenter(experienceID: id, launch: launch),
                                                              switches: switches))
        }]
        let model = persistenceModel(storage, sleep: sleep, registry: registry)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        tap(model, 3)
        try await settle { sleep.pending == 1 }
        sleep.fire()
        try await settle { FileManager.default.fileExists(atPath: self.stateURL(storage, id).path) }
        XCTAssertEqual(taps(of: storedState(storage, id)), 3, "the checkpoint stored three taps")

        // The experience fails while it runs: its next frame throws.
        let host = try XCTUnwrap(model.session.renderHost)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        host.view.layoutIfNeeded()
        switches.failsDraw = true
        _ = host.renderOneFrame(present: false)
        XCTAssertEqual(model.session.state, .failed)
        XCTAssertEqual(model.route, .experience(id))
        switches.failsDraw = false

        // Retry opens with the state stored now, not with what the first open began with (nothing).
        await model.retryExperience()
        XCTAssertEqual(model.session.state, .running)
        XCTAssertTrue(model.session.experience?.port.summary.contains(" 3 taps") ?? false,
                      model.session.experience?.port.summary ?? "no experience")
        XCTAssertEqual(switches.made, 2)

        // The retried experience is watched again: an action is saved when its delay ends.
        tap(model, 1)
        try await settle { sleep.pending == 1 }
        XCTAssertEqual(sleep.pending, 1, "the action of the retried experience started a delay")
        sleep.fire()
        try await settle { self.quietTaps(storage, id) == 4 }
        XCTAssertEqual(taps(of: storedState(storage, id)), 4)
        model.closeExperience()
    }

    func testRetryAfterAFailedSetUpWatchesTheActions() async throws {
        let storage = try TestStorage(self)
        let sleep = ScriptedSleep()
        let id = try XCTUnwrap(DebugLaunch.fixtureFreeIDs.first)
        let calls = LaunchBox()
        let registry = [ExperienceRegistration(id: id, core: DebugExperienceCore.self) { launch in
            calls.values.append(launch)
            return ExperienceShell(id: id, presenter: DebugPresenter(experienceID: id, launch: launch,
                                                                     failsSetup: calls.values.count == 1))
        }]
        let model = persistenceModel(storage, sleep: sleep, registry: registry)
        let opened = await model.open(id)
        XCTAssertFalse(opened)
        XCTAssertEqual(model.session.state, .failed)
        await model.retryExperience()
        XCTAssertEqual(model.session.state, .running)
        tap(model, 2)
        try await settle { sleep.pending == 1 }
        sleep.fire()
        try await settle { self.quietTaps(storage, id) == 2 }
        XCTAssertEqual(taps(of: storedState(storage, id)), 2)
        model.closeExperience()
    }

    // MARK: Diagnostics and reset rows (feature 191, T-U05-040, T-U05-042)

    func testAnUnreadableStateIsRecordedInTheDiagnostics() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let id = try XCTUnwrap(freeIDs(model).first)
        XCTAssertNil(model.diagnostics.lastUnreadable)
        let url = stateURL(storage, id)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: url)
        let opened = await model.open(id)
        XCTAssertFalse(opened)
        XCTAssertEqual(model.diagnostics.lastUnreadable, "\(id.rawValue): snapshot.corrupt")
        model.dismissUnreadable()
        XCTAssertEqual(model.diagnostics.lastUnreadable, "\(id.rawValue): snapshot.corrupt", "kept after Back")
        XCTAssertTrue(model.diagnostics.text.contains("lastUnreadable: \(id.rawValue): snapshot.corrupt"))
    }

    func testAnExperienceWithValuesAndNoFolderIsOfferedForReset() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let id = try XCTUnwrap(freeIDs(model).first)
        XCTAssertEqual(model.dataNamespaces, [])
        try storage.handle(id).setValue(Data("v".utf8), for: "only-a-value")
        storage.defaults.set("x", forKey: "exp.not an id.name")
        model.refreshDataNamespaces()
        XCTAssertEqual(model.dataNamespaces, [id.storageNamespace])
        model.reset(.experience(id))
        XCTAssertEqual(model.dataNamespaces, [])
        XCTAssertEqual(storage.handle(id).valueKeys(), [])
    }

    // MARK: Unreadable states (feature 191, T-U05-017; FR-U05-030 to FR-U05-034; SC-U05-004, SC-U05-009)

    /// A stored state of `id` with `count` taps, written by a real open and close.
    private func storeState(_ model: AppModel, _ id: ExperienceID, taps count: Int = 2) async throws -> Data {
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        tap(model, count)
        model.closeExperience()
        return try Data(contentsOf: SavedStateStore(root: model.dataRootForTests).stateURL(for: id))
    }

    /// `stored` with one field of its JSON object replaced.
    private func edited(_ stored: Data, _ key: String, _ value: Any) throws -> Data {
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: stored) as? [String: Any])
        XCTAssertNotNil(object[key], "the stored state has no field \(key)")
        object[key] = value
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `stored` rebuilt as a valid snapshot with another schema version or another experience id.
    private func rebuilt(_ stored: Data, schema: Int? = nil, experience: ExperienceID? = nil) throws -> Data {
        let snapshot = try ExperienceSnapshot(data: stored)
        return try ExperienceSnapshot(experience: experience ?? snapshot.experience,
                                      schemaVersion: schema ?? snapshot.schemaVersion, seed: snapshot.seed,
                                      stepIndex: snapshot.stepIndex, digest: snapshot.digest,
                                      payload: Data(snapshot.payload.utf8)).encoded()
    }

    /// The eight unreadable states of SC-U05-004 made from a good one: six the file shows, two only the
    /// experience finds.
    private func unreadableStates(from good: Data) throws -> [(name: String, data: Data, code: String, newer: Bool)] {
        let other = try XCTUnwrap(ExperienceID(rawValue: "a98.another-experience"))
        return [
            ("truncated", good.prefix(good.count / 2), "snapshot.corrupt", false),
            ("garbage", Data("not a saved state".utf8), "snapshot.corrupt", false),
            ("checksum", try edited(good, "checksum", String(repeating: "0f", count: 32)),
             "snapshot.checksum-mismatch", false),
            ("other experience", try rebuilt(good, experience: other), "snapshot.wrong-experience", false),
            ("unknown format", try edited(good, "format", 99), "snapshot.unknown-format", false),
            ("too large", Data(count: ExperienceSnapshot.maxBytes + 1), "snapshot.too-large", false),
            ("newer schema", try rebuilt(good, schema: 99), "snapshot.newer-schema", true),
            ("schema without migration", try rebuilt(good, schema: 0), "snapshot.missing-migration", false),
        ]
    }

    func testEachUnreadableStateGivesTheNoticeAndBackChangesNothing() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        await model.finishWelcome(openFirst: false)
        let id = try XCTUnwrap(freeIDs(model).first)
        let good = try await storeState(model, id)
        let states = try unreadableStates(from: good)
        XCTAssertEqual(states.count, 8)
        let url = stateURL(storage, id)
        let store = SavedStateStore(root: storage.root)
        for state in states {
            try state.data.write(to: url)
            let opened = await model.open(id)
            XCTAssertFalse(opened, state.name)
            XCTAssertEqual(model.unreadable?.id, id, state.name)
            XCTAssertEqual(model.unreadable?.problem.code, state.code, state.name)
            XCTAssertEqual(model.unreadable?.problem.newer, state.newer, state.name)
            XCTAssertNil(model.session.experience, "\(state.name): nothing runs")
            XCTAssertEqual(model.session.state, .idle, state.name)
            XCTAssertEqual(model.route, .experience(id), "\(state.name): the notice is on the experience route")
            XCTAssertEqual(try Data(contentsOf: url), state.data, "\(state.name): the file is unchanged")

            model.dismissUnreadable()
            XCTAssertNil(model.unreadable, state.name)
            XCTAssertEqual(model.route, .catalog, state.name)
            XCTAssertEqual(try Data(contentsOf: url), state.data, "\(state.name): Back keeps the file")
            XCTAssertEqual(store.quarantined(id), [], "\(state.name): Back makes no copy")

            // Opening again without Reset shows the notice again; so does a new model (a new start).
            let again = await model.open(id)
            XCTAssertFalse(again, state.name)
            XCTAssertEqual(model.unreadable?.problem.code, state.code, state.name)
            let later = fixtureModel(storage)
            XCTAssertEqual(later.route, .experience(id), state.name)
            await later.restoreRoute()
            XCTAssertEqual(later.unreadable?.problem.code, state.code, "\(state.name): after a new start")
            XCTAssertEqual(later.route, .experience(id), state.name)
            XCTAssertEqual(try Data(contentsOf: url), state.data, state.name)
            model.dismissUnreadable()
        }
    }

    func testResetOfTheNoticeKeepsACopyAndStartsAfresh() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        let id = try XCTUnwrap(freeIDs(model).first)
        let good = try await storeState(model, id, taps: 4)
        let url = stateURL(storage, id)
        let store = SavedStateStore(root: storage.root)
        var expected: [String] = []
        for (index, state) in try unreadableStates(from: good).prefix(5).enumerated() {
            try state.data.write(to: url)
            let opened = await model.open(id)
            XCTAssertFalse(opened, state.name)
            await model.resetUnreadable()
            XCTAssertNil(model.unreadable, state.name)
            XCTAssertEqual(model.session.state, .running, state.name)
            XCTAssertEqual(model.route, .experience(id), state.name)
            XCTAssertTrue(model.session.experience?.port.summary.contains(" 0 taps") ?? false,
                          "\(state.name): \(model.session.experience?.port.summary ?? "no experience")")
            let name = "quarantine-\(index + 1).json"
            expected = Array((expected + [name]).suffix(SavedStateStore.maxQuarantined))
            XCTAssertEqual(store.quarantined(id), expected, state.name)
            let copy = store.folder(for: id).appendingPathComponent(name)
            XCTAssertEqual(try Data(contentsOf: copy), state.data, "\(state.name): the copy holds the unreadable bytes")
            model.closeExperience()
            let fresh = try XCTUnwrap(storedState(storage, id))
            XCTAssertEqual(taps(of: fresh), 0, state.name)
            XCTAssertEqual(fresh.seed, AppModel.seed(for: id), "\(state.name): the same seed")
        }
        XCTAssertEqual(store.quarantined(id), ["quarantine-3.json", "quarantine-4.json", "quarantine-5.json"],
                       "five unreadable states in a row leave three copies")
    }

    // MARK: Migration examples and inventory rules (feature 191, T-U05-020, T-U05-022)

    func testEveryRegistrationHasAnExampleOfEveryEarlierSchemaVersion() async throws {
        for registration in ExperienceRegistry.all + DebugLaunch.fixtureRegistry {
            let problems = await registration.migrationProblems()
            XCTAssertEqual(problems, [], "\(registration.id)")
        }
        XCTAssertEqual(DebugExperienceCore.migrations.currentVersion, 1, "the debug core needs no example")
    }

    func testTheInventoryRulesAreValidAndNameNoPurchaseOrTrackingValue() throws {
        let inventory = try ContainerInventory(rules: DebugInventory.rules)
        XCTAssertEqual(inventory.rules.count, DebugInventory.rules.count)
        for rule in DebugInventory.rules {
            if rule.system {
                XCTAssertFalse((rule.origin ?? "").trimmingCharacters(in: .whitespaces).isEmpty, rule.pattern)
            }
            let text = (rule.pattern + " " + rule.writer).lowercased()
            for word in ["unlock", "purchas", "premium", "advert", "track", "account", "analytic"] {
                XCTAssertFalse(text.contains(word), "\(rule.pattern) names \(word)")
            }
        }
        let id = "a01.generative-art-studio"
        let listed = ["Library/Application Support/Experiences/\(id)/state.json",
                      "Library/Application Support/Experiences/\(id)/quarantine-2.json",
                      "Library/Application Support/Experiences/\(id)/seed.txt",
                      "Library/Preferences/dev.visualcore.VisualCore.plist"]
        let keys = ["vc.shell.preferences", "vc.shell.preferences.unreadable", "exp.\(id).opens"]
        XCTAssertEqual(DebugInventory.text(files: listed, keys: keys), "inventory: 4 files, 3 keys; unlisted: none")
        XCTAssertEqual(DebugInventory.text(files: listed + ["Library/Application Support/stray.txt"],
                                           keys: keys + ["stray.key"]),
                       "inventory: 5 files, 4 keys; unlisted: file:Library/Application Support/stray.txt, key:stray.key")
        // The property list of another defaults domain is not the app's (T-U05-041).
        XCTAssertEqual(DebugInventory.text(files: ["Library/Preferences/com.example.other.plist"], keys: []),
                       "inventory: 1 files, 0 keys; unlisted: file:Library/Preferences/com.example.other.plist")
        XCTAssertTrue(DebugInventory.text(files: ["Library/Caches/com.example.other/com.apple.metal/libraries.data"],
                                          keys: []).contains("unlisted: file:"))
        // A hidden temporary file of an interrupted write and a file outside an experience folder are not listed.
        XCTAssertTrue(DebugInventory.text(files: ["Library/Application Support/Experiences/\(id)/.state.json.tmp-x"],
                                          keys: []).hasSuffix(".state.json.tmp-x"))
        XCTAssertTrue(DebugInventory.text(files: [], keys: ["unlocked"]).hasSuffix("unlisted: key:unlocked"))
    }

    func testTheInventoryReaderListsEveryFileBelowTheThreeFolders() throws {
        let storage = try TestStorage(self)
        let home = storage.root
        for path in ["Documents/a.txt", "Library/Application Support/Experiences/a01.x/state.json", "tmp/b",
                     "Library/.hidden", "other/outside.txt"] {
            let url = home.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Data("x".utf8).write(to: url)
        }
        XCTAssertEqual(DebugInventory.files(home: home),
                       ["Documents/a.txt", "Library/.hidden",
                        "Library/Application Support/Experiences/a01.x/state.json", "tmp/b"])
        storage.defaults.set(1, forKey: "one")
        storage.defaults.set(2, forKey: "two")
        XCTAssertEqual(DebugInventory.keys(defaults: storage.defaults, domain: storage.suite), ["one", "two"])
    }
    #endif
}

#if DEBUG
/// The delay between an accepted action and its checkpoint, scripted: a call waits until the test fires it.
final class ScriptedSleep: @unchecked Sendable {
    private let lock = NSLock()
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var asked: [Duration] = []

    /// How many delays were started.
    var calls: Int { lock.withLock { asked.count } }
    /// The durations that were asked for.
    var durations: [Duration] { lock.withLock { asked } }
    /// How many delays wait to be fired.
    var pending: Int { lock.withLock { waiting.count } }

    /// Waits until `fire()`; throws when the task was cancelled meanwhile.
    func sleep(_ duration: Duration) async throws {
        await withCheckedContinuation { continuation in
            lock.withLock {
                asked.append(duration)
                waiting.append(continuation)
            }
        }
        try Task.checkCancellation()
    }

    /// Ends every waiting delay.
    func fire() {
        let ended = lock.withLock {
            let all = waiting
            waiting = []
            return all
        }
        for continuation in ended { continuation.resume() }
    }
}

/// What a test switches on a `FlakyPresenter`.
@MainActor
private final class FlakySwitch {
    /// The next frame throws.
    var failsDraw = false
    /// How many presenters were built.
    var made = 0
}

/// The debug presenter with a frame that can be made to throw, so that an experience fails while it runs.
@MainActor
private final class FlakyPresenter: ExperiencePresenter {
    typealias Core = DebugExperienceCore
    struct DrawFailure: Error {}

    private let inner: DebugPresenter
    private let switches: FlakySwitch

    init(inner: DebugPresenter, switches: FlakySwitch) {
        self.inner = inner
        self.switches = switches
        switches.made += 1
    }

    func setup(_ context: RenderContext) throws { try inner.setup(context) }
    func resize(_ context: RenderContext) { inner.resize(context) }
    func draw(_ core: DebugExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if switches.failsDraw { throw DrawFailure() }
        try inner.draw(core, tier: tier, context: context, frame: frame)
    }
    func teardown(_ context: RenderContext) { inner.teardown(context) }
    func describe(_ core: DebugExperienceCore) -> String { inner.describe(core) }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { inner.makeControls(port) }
}

/// Collects what the shell hands to a factory.
@MainActor
private final class LaunchBox {
    var values: [ExperienceLaunch] = []
}

/// A core whose preparation takes far longer than a test: it ends only by cancellation.
private struct SlowCore: ExperienceCore, Codable, Equatable {
    var value = 0

    static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    static var controls: [ExperienceControl] { [] }
    static var qualityTiers: Int { 1 }

    static func prepare(seed: UInt64) async throws -> SlowCore {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        return SlowCore()
    }

    mutating func update(step: Int) {}

    mutating func apply(_ action: ExperienceAction) -> ActionResult {
        .rejected(.unknownControl(action.control))
    }

    mutating func reset() {}

    func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(value)
    }
}

/// The presenter of `SlowCore`; it is never set up, because the preparation never ends.
@MainActor
private final class SlowPresenter: ExperiencePresenter {
    typealias Core = SlowCore

    func setup(_ context: RenderContext) throws {}
    func draw(_ core: SlowCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
    func describe(_ core: SlowCore) -> String { "" }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
}
#endif
