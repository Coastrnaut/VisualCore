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
            ExperienceRegistration(id: free) { launch in
                received.values.append(launch)
                return DebugExperience.make(id: free, launch: launch)
            }
        }
        let model = model(storage, registry: registry)
        let id = try XCTUnwrap(freeIDs(model).first)
        let first = await model.open(id)
        XCTAssertTrue(first)
        XCTAssertEqual(received.values, [ExperienceLaunch(reduceMotion: .system, reduceFlashing: .system)])
        model.closeExperience()

        model.setAccessibility(reduceMotion: .on, reduceFlashing: .off)
        let second = await model.open(id)
        XCTAssertTrue(second)
        XCTAssertEqual(received.values.last, ExperienceLaunch(reduceMotion: .on, reduceFlashing: .off))
        XCTAssertEqual(received.values.count, 2, "the factory is called once per open")
        model.closeExperience()

        // A new model on the same storage hands over the stored choices.
        let later = self.model(storage, registry: registry)
        let third = await later.open(id)
        XCTAssertTrue(third)
        XCTAssertEqual(received.values.last, ExperienceLaunch(reduceMotion: .on, reduceFlashing: .off))
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
        let registry = [ExperienceRegistration(id: id) { launch in
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
        XCTAssertEqual(DebugExperience.make(id: id).qualityProfile, profile, "the session sees the core's profile")
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
            let profile = registration.make(ExperienceLaunch()).qualityProfile
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
        let registry = [ExperienceRegistration(id: id) { _ in ExperienceShell(id: id, presenter: SlowPresenter()) }]
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
    #endif
}

#if DEBUG
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
