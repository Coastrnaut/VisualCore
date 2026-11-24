// AppModelTests — feature 190 T-U04-006 (US1; FR-U04-010 to FR-U04-012, FR-U04-024, FR-U04-051; SC-U04-006): the
// bundled catalog and the registry agree; the app model shows the empty launcher for the real catalog and six
// tiles in three sections for the fixture; a premium tile gives the notice and no session; the quality override
// is applied when an experience opens. The storage helper `TestStorage` is in StoreTests.swift.
import AcousticConstellatorCore
import AmethystEscapeCore
import AuroraLoomCore
import BackwardsAuroraCore
import ChronoConstellatorCore
import ColorfallCanyonsCore
import EchoCartographerCore
import FacetedForgeCore
import Foundation
import HarmonicBridgesCore
import HueCompassCore
import LissajousLabyrinthCore
import MoonlitMechanismCore
import NocturneGardenCore
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering
import WaveKnotKeeperCore
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
        // A01–A25 and R02-G01 … G13 are integrated (X-A01 to X-A25 and X-R02-G01 … G13 pass): registered and
        // available, nothing else.
        XCTAssertEqual(registered.count, manifest.available.count)
        XCTAssertEqual(registered.map(\.rawValue), ["a01.generative-art-studio", "a02.fluid-art-playground",
                                                     "a03.fractal-explorer", "a04.particle-universe",
                                                     "a05.infinite-geometry", "a06.visualcore-music-lab",
                                                     "a07.audio-odyssey", "a08.oscilloscope-studio",
                                                     "a09.digital-aquarium", "a10.neon-arcade",
                                                     "a11.physics-playground", "a12.tiny-worlds",
                                                     "a13.light-maze", "a14.solar-system-explorer",
                                                     "a15.molecular-explorer", "a16.simulation-lab",
                                                     "a17.interactive-anatomy", "a18.ambient-clock",
                                                     "a19.living-wallpapers", "a20.digital-zen-garden",
                                                     "a21.aurora", "a22.shader-studio",
                                                     "a23.visual-programming-lab", "a24.graphics-benchmark-lab",
                                                     "a25.effects-composer", "r02-g01.aurora-loom",
                                                     "r02-g02.lissajous-labyrinth", "r02-g03.wave-knot-keeper",
                                                     "r02-g04.hue-compass",
                                                     "r02-g05.colorfall-canyons",
                                                     "r02-g06.chrono-constellator",
                                                     "r02-g07.amethyst-escape",
                                                     "r02-g08.faceted-forge",
                                                     "r02-g09.nocturne-garden",
                                                     "r02-g10.backwards-aurora",
                                                     "r02-g11.echo-cartographer",
                                                     "r02-g12.harmonic-bridges",
                                                     "r02-g13.acoustic-constellator"])
        XCTAssertEqual(manifest.available.map(\.id), registered)
    }

    // MARK: Candidates (feature 193, FR-U07-021; clarification 4)

    /// Candidates are adopted experiences before their X gate: they are not in `all`, so the agreement test above
    /// never sees them, and none is available in the bundled catalog.
    func testCandidatesAreApartFromTheRegistryAndUnavailableInTheBundledCatalog() throws {
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        let candidates = ExperienceRegistry.candidates.map(\.id)
        XCTAssertEqual(Set(candidates).count, candidates.count, "no candidate twice")
        XCTAssertTrue(Set(candidates).isDisjoint(with: ExperienceRegistry.all.map(\.id)))
        let ids = Set(manifest.experiences.map(\.id))
        for id in candidates {
            XCTAssertTrue(ids.contains(id), "\(id.rawValue) is a catalog id")
            XCTAssertFalse(manifest.available.contains { $0.id == id }, "\(id.rawValue) stays unavailable")
        }
    }

    /// `-vcCandidates` makes the candidates' entries available and registers them; nothing else changes.
    func testTheCandidatesArgumentMakesTheCandidatesAvailableAndRegistersThem() throws {
        let storage = try TestStorage(self)
        let integrated = ExperienceRegistry.all.map(\.id)
        // Any catalog experience before its X gate works as a candidate; R02-G15 is one (unavailable, not in `all`, not yet
        // registered; R02-G01 … R02-G13 were real candidates until their X gates, and R02-G14 is a registered one).
        // The synthetic debug registration stands in for one.
        let id = try XCTUnwrap(ExperienceID(rawValue: "r02-g15.voxel-origami"))
        XCTAssertFalse(integrated.contains(id), "the synthetic candidate is not integrated")
        let candidate = DebugExperience.registration(for: id)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                       registry: ExperienceRegistry.all, arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [candidate])
        XCTAssertEqual(environment.registry.map(\.id), integrated + [id])
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertEqual(manifest.available.map(\.id), integrated + [id], "the integrated ones and the candidate")
        XCTAssertTrue(manifest.registryReport(registered: environment.registry.map(\.id)).isMatch)

        let model = AppModel(environment: environment)
        XCTAssertEqual(model.shown.map(\.id), integrated + [id], "the launcher shows the candidate too")

        // Without the argument nothing changes.
        let plain = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                        registry: ExperienceRegistry.all)
        let unchanged = DebugLaunch.environment(base: plain, candidates: [candidate])
        XCTAssertEqual(unchanged.catalogData, plain.catalogData)
        XCTAssertEqual(unchanged.registry.map(\.id), integrated)
        XCTAssertFalse(DebugLaunch.unknownArguments(in: [DebugLaunch.candidatesArgument]).contains("-vcCandidates"))
    }

    /// The verification runner's targets read the registered experiences and the candidates.
    func testScenarioTargetsReadTheRegistryAndTheCandidates() {
        let all = Set(ScenarioLaunch.targets(registry: ExperienceRegistry.all + ExperienceRegistry.candidates).keys)
        XCTAssertEqual(Set(ScenarioLaunch.targets().keys), all)
    }

    /// The real catalog with the real registry shows the integrated experiences (A01–A25, R02-G01 and R02-G02 since
    /// their X gates).
    func testTheRealCatalogShowsTheIntegratedExperiences() throws {
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertNotEqual(model.launcher, .empty)
        XCTAssertEqual(model.shown.map(\.id), ExperienceRegistry.all.map(\.id))
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
        model.setAccessibility(reduceMotion: .on, reduceFlashing: .off, colorVision: .standard)
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

        model.setAccessibility(reduceMotion: .on, reduceFlashing: .off, colorVision: .standard)
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
        XCTAssertEqual(ExperienceRegistry.all.count, 38, "A01–A25 and R02-G01 … G13 are integrated")
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

    // MARK: Aurora Loom in the app (feature 309, R02-G01-09; T-R02G0109-005, FR-R02G0109-003, FR-R02G0109-006)

    /// Aurora Loom's registration (a candidate until X-R02-G01, integrated since 2026-11-21).
    private func auroraLoomRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(AuroraLoomExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Aurora Loom is integrated")
    }

    /// Clarification Q3: the stored schema-1 and schema-2 examples restore to their digests through the migrations.
    func testTheAuroraLoomRegistrationRestoresItsStoredExamples() async throws {
        let registration = try auroraLoomRegistration()
        XCTAssertEqual(AuroraLoomExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(AuroraLoomExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(AuroraLoomExperienceCore.schemaTwoExample(), "schema-2 example")
        XCTAssertEqual(one.version, 1)
        XCTAssertEqual(two.version, 2)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G01 (2026-11-21): Aurora Loom is integrated: in `all`, not a candidate, available in the bundled catalog,
    /// shown and opened without `-vcCandidates`.
    func testAuroraLoomIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(AuroraLoomExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g01.aurora-loom")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// With the candidates registered Aurora Loom is shown, opens through the registry and engine, and level 1 is
    /// won by its certified solution as `ribbon.move [ribbon, control, step]` actions (control 0 wave, 1 phase).
    func testAuroraLoomOpensAsACandidateAndLevelOneIsWonByItsCertifiedSolution() async throws {
        let registration = try auroraLoomRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                       registry: ExperienceRegistry.all, arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows it")
        XCTAssertTrue(registration.controls.map(\.id).contains("ribbon.move"))

        var engine = ExperienceEngine<AuroraLoomExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        let certified = try AuroraLoomExperienceCore.generated(number: 1)
        XCTAssertFalse(certified.solution.moves.isEmpty)
        for move in certified.solution.moves {
            let control: Double = move.control == .wave ? 0 : 1
            let values: [Double] = [Double(move.ribbon), control, Double(move.step)]
            XCTAssertEqual(engine.handle(control: "ribbon.move", values: values), .accepted, "\(values)")
        }
        XCTAssertEqual(engine.outcome?.code, "won")
    }

    /// Clarification Q5: the interface tests pin level 1's target steps; they equal the Core's certified solution.
    /// Spec amendment (feature 309): the round-two puzzles open with seed 0, so a player starts at level 1 (the stable
    /// seed of their ids opened Aurora Loom at level 79 and Lissajous Labyrinth at level 35).
    func testTheRoundTwoPuzzlesOpenAtLevelOne() throws {
        XCTAssertEqual(try auroraLoomRegistration().openingSeed, 0)
        XCTAssertEqual(AuroraLoomExperienceCore.levelNumber(forSeed: 0), 1)
        XCTAssertEqual(try lissajousLabyrinthRegistration().openingSeed, 0)
        XCTAssertEqual(try waveKnotKeeperRegistration().openingSeed, 0)
        XCTAssertEqual(try hueCompassRegistration().openingSeed, 0)
        XCTAssertEqual(try colorfallCanyonsRegistration().openingSeed, 0)
        XCTAssertEqual(try chronoConstellatorRegistration().openingSeed, 0)
        XCTAssertEqual(try amethystEscapeRegistration().openingSeed, 0)
        XCTAssertEqual(try facetedForgeRegistration().openingSeed, 0)
        XCTAssertEqual(try nocturneGardenRegistration().openingSeed, 0)
        XCTAssertEqual(try backwardsAuroraRegistration().openingSeed, 0)
        XCTAssertEqual(try echoCartographerRegistration().openingSeed, 0)
        XCTAssertEqual(try harmonicBridgesRegistration().openingSeed, 0)
        let puzzles: Set<String> = [AuroraLoomExperienceCore.experienceID,
                                    LissajousLabyrinthExperienceCore.experienceID,
                                    WaveKnotKeeperExperienceCore.experienceID,
                                    HueCompassExperienceCore.experienceID,
                                    ColorfallCanyonsExperienceCore.experienceID,
                                    ChronoConstellatorExperienceCore.experienceID,
                                    AmethystEscapeExperienceCore.experienceID,
                                    FacetedForgeExperienceCore.experienceID,
                                    NocturneGardenExperienceCore.experienceID,
                                    BackwardsAuroraExperienceCore.experienceID,
                                    EchoCartographerExperienceCore.experienceID,
                                    HarmonicBridgesExperienceCore.experienceID,
                                    AcousticConstellatorExperienceCore.experienceID]
        for other in ExperienceRegistry.all where !puzzles.contains(other.id.rawValue) {
            XCTAssertNil(other.openingSeed, "\(other.id.rawValue) keeps its stable seed")
        }
    }

    func testAuroraLoomLevelOneTargetStepsEqualTheCore() throws {
        let certified = try AuroraLoomExperienceCore.generated(number: 1)
        XCTAssertEqual(certified.level.startSteps.wave, [15, 15, 3])
        XCTAssertEqual(certified.level.startSteps.phase, [12, 12, 3])
        XCTAssertEqual(certified.solution.setting.wave, [15, 15, 15])
        XCTAssertEqual(certified.solution.setting.phase, [12, 12, 12])
        XCTAssertEqual(AuroraLoomExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Lissajous Labyrinth in the app (feature 319, R02-G02-09; T-R02G0209-005, FR-R02G0209-003,
    // FR-R02G0209-006; clarifications Q2, Q3, Q5)

    /// Lissajous Labyrinth's registration (a candidate until X-R02-G02, integrated since 2026-11-21).
    private func lissajousLabyrinthRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(LissajousLabyrinthExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Lissajous Labyrinth is integrated")
    }

    /// Clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples restore to their
    /// digests through the migrations (the app's migration check).
    func testTheLissajousLabyrinthRegistrationRestoresItsStoredExamples() async throws {
        let registration = try lissajousLabyrinthRegistration()
        XCTAssertEqual(LissajousLabyrinthExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(LissajousLabyrinthExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(LissajousLabyrinthExperienceCore.schemaTwoExample(), "schema-2 example")
        XCTAssertEqual(one.version, 1)
        XCTAssertEqual(two.version, 2)
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G02 (2026-11-21): Lissajous Labyrinth is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0209-006 held until then).
    func testLissajousLabyrinthIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(LissajousLabyrinthExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g02.lissajous-labyrinth")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0209-003, clarification Q2: with `-vcCandidates` (which the interface tests still pass; the integrated
    /// registration is not added twice) Lissajous Labyrinth is shown, opens through the registry and engine, and
    /// level 1 is won by its certified solution as `dial.set [dial, value]` actions
    /// (dial 0 frequencyA, 1 frequencyB, 2 phaseA, 3 phaseC).
    func testLissajousLabyrinthOpensAsACandidateAndLevelOneIsWonByItsCertifiedSolution() async throws {
        let registration = try lissajousLabyrinthRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        let model = AppModel(environment: environment)
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows it")
        XCTAssertTrue(registration.controls.map(\.id).contains("dial.set"))
        XCTAssertEqual(registration.openingSeed, 0)

        var engine = ExperienceEngine<LissajousLabyrinthExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        let certified = try LissajousLabyrinthExperienceCore.generated(number: 1)
        XCTAssertFalse(certified.solution.actions.isEmpty)
        for move in certified.solution.actions {
            let dial = try XCTUnwrap(LissajousLabyrinthExperienceCore.dialOrder.firstIndex(of: move.dial))
            let values: [Double] = [Double(dial), Double(move.value)]
            XCTAssertEqual(engine.handle(control: "dial.set", values: values), .accepted, "\(values)")
        }
        XCTAssertEqual(engine.outcome?.code, LissajousLabyrinthExperienceCore.wonCode)
        XCTAssertEqual(LissajousLabyrinthExperienceCore.wonCode, "won")
    }

    /// Clarification Q2: the interface tests pin level 1 in their `LL` namespace (Tests/UI/LissajousLabyrinth/
    /// LLSupport.swift, which this target cannot import); the same literals equal the Core's certified level 1: start
    /// dials a 7, b 1, φ 5, ψ 12; one action, ψ to 3; final dials a 7, b 1, φ 5, ψ 3; allowance 9. Seed 0 opens
    /// level 1 (T-R02G0209-013 added the allowance).
    func testLissajousLabyrinthLevelOneDialsEqualTheCore() throws {
        let certified = try LissajousLabyrinthExperienceCore.generated(number: 1)
        XCTAssertEqual(certified.level.start,
                       LissajousLabyrinthDials(frequencyA: 7, frequencyB: 1, phaseA: 5, phaseC: 12))
        XCTAssertEqual(certified.level.allowance, 9, "LL.levelOneAllowance")
        XCTAssertEqual(certified.solution.shortest, 1)
        XCTAssertEqual(certified.solution.actions, [LissajousLabyrinthAction(dial: .phaseC, value: 3)])
        XCTAssertEqual(certified.solution.setting,
                       LissajousLabyrinthDials(frequencyA: 7, frequencyB: 1, phaseA: 5, phaseC: 3))
        XCTAssertEqual(LissajousLabyrinthExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Wave Knot Keeper in the app (feature 329, R02-G03-09; T-R02G0309-005, FR-R02G0309-003,
    // FR-R02G0309-006; clarifications Q2, Q3, Q5)

    /// Wave Knot Keeper's registration (a candidate until X-R02-G03, integrated since 2026-11-21).
    private func waveKnotKeeperRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(WaveKnotKeeperExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Wave Knot Keeper is integrated")
    }

    /// Clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples restore to their
    /// digests through the migrations (the app's migration check).
    func testTheWaveKnotKeeperRegistrationRestoresItsStoredExamples() async throws {
        let registration = try waveKnotKeeperRegistration()
        XCTAssertEqual(WaveKnotKeeperExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(WaveKnotKeeperExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(WaveKnotKeeperExperienceCore.schemaTwoExample(), "schema-2 example")
        XCTAssertEqual(one.version, 1)
        XCTAssertEqual(two.version, 2)
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G03 (2026-11-21): Wave Knot Keeper is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0309-006 held until then).
    func testWaveKnotKeeperIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(WaveKnotKeeperExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g03.wave-knot-keeper")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0309-003, clarification Q2: with `-vcCandidates` (which the interface tests still pass; the integrated
    /// registration is not added twice) Wave Knot Keeper is shown, opens through the
    /// registry and engine, and level 1 is won by its certified solution as `point.move [point, direction]` actions
    /// (direction index into `directionOrder`: 0 plusX, 1 minusX, 2 plusY, 3 minusY, 4 plusZ, 5 minusZ).
    func testWaveKnotKeeperOpensAsACandidateAndLevelOneIsWonByItsCertifiedSolution() async throws {
        let registration = try waveKnotKeeperRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        let model = AppModel(environment: environment)
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows it")
        XCTAssertTrue(registration.controls.map(\.id).contains("point.move"))
        XCTAssertEqual(registration.openingSeed, 0)

        var engine = ExperienceEngine<WaveKnotKeeperExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        let certified = try WaveKnotKeeperExperienceCore.generated(number: 1)
        XCTAssertFalse(certified.solution.moves.isEmpty)
        for move in certified.solution.moves {
            let direction = try XCTUnwrap(WaveKnotKeeperExperienceCore.directionOrder.firstIndex(of: move.direction))
            let values: [Double] = [Double(move.point), Double(direction)]
            XCTAssertEqual(engine.handle(control: "point.move", values: values), .accepted, "\(values)")
        }
        XCTAssertEqual(engine.outcome?.code, WaveKnotKeeperExperienceCore.wonCode)
        XCTAssertEqual(WaveKnotKeeperExperienceCore.wonCode, "won")
    }

    /// Clarification Q2 (the convergence lesson of feature 319): the interface tests pin level 1 in their `WK`
    /// namespace (Tests/UI/WaveKnotKeeper/WKSupport.swift, which this target cannot import); the same literals equal
    /// the Core's certified level 1: a rope of 6 points, allowance 9, one move: point 1 (0-based) plusX, direction
    /// index 0 (WK.levelOneMoves). Seed 0 opens level 1.
    func testWaveKnotKeeperLevelOneEqualsTheCore() throws {
        let certified = try WaveKnotKeeperExperienceCore.generated(number: 1)
        XCTAssertEqual(certified.level.points.count, 6, "WK.levelOnePointCount")
        XCTAssertEqual(certified.level.allowance, 9, "WK.levelOneAllowance")
        XCTAssertEqual(certified.solution.shortest, 1, "WK.levelOneShortest")
        XCTAssertEqual(certified.solution.moves, [WaveKnotKeeperMove(point: 1, direction: .plusX)], "WK.levelOneMoves")
        XCTAssertEqual(WaveKnotKeeperExperienceCore.directionOrder.firstIndex(of: .plusX), 0,
                       "WK.directions[0] is move-plus-x")
        XCTAssertEqual(WaveKnotKeeperExperienceCore.directionOrder,
                       [.plusX, .minusX, .plusY, .minusY, .plusZ, .minusZ], "WK.directions")
        XCTAssertEqual(WaveKnotKeeperExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Hue Compass in the app (feature 339, R02-G04-09; T-R02G0409-005, FR-R02G0409-003,
    // FR-R02G0409-006; clarifications Q2, Q3, Q5)

    /// Hue Compass's registration (a candidate until X-R02-G04, integrated since 2026-11-21).
    private func hueCompassRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(HueCompassExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Hue Compass is integrated")
    }

    /// Clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples restore to their
    /// digests through the migrations (the app's migration check).
    func testTheHueCompassRegistrationRestoresItsStoredExamples() async throws {
        let registration = try hueCompassRegistration()
        XCTAssertEqual(HueCompassExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(HueCompassExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(HueCompassExperienceCore.schemaTwoExample(), "schema-2 example")
        XCTAssertEqual(one.version, 1)
        XCTAssertEqual(two.version, 2)
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G04 (2026-11-21): Hue Compass is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0409-006 held until then).
    func testHueCompassIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(HueCompassExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g04.hue-compass")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0409-003, clarification Q2: with `-vcCandidates` (which the interface tests still pass; the integrated
    /// registration is not added twice) Hue Compass is shown, opens through the
    /// registry and engine with seed 0 (level 1), and level 1 is won by its certified witness actions
    /// (`HueCompassWitness.actions(for:level:)`) sent as `compass.turn [steps]`, `compass.probe` and
    /// `compass.select [bearing, band]`.
    func testHueCompassOpensAsACandidateAndLevelOneIsWonByItsCertifiedWitness() async throws {
        let registration = try hueCompassRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows it")
        let controls = registration.controls.map(\.id)
        for control in ["compass.turn", "compass.probe", "compass.select"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(HueCompassExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<HueCompassExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        let certified = try HueCompassExperienceCore.generated(number: 1)
        let actions = HueCompassWitness.actions(for: certified.solution, level: certified.level)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            let control: String
            let values: [Double]
            switch action {
            case .turn(let steps):
                control = "compass.turn"
                values = [Double(steps)]
            case .probe:
                control = "compass.probe"
                values = []
            case .select(let bearing, let band):
                control = "compass.select"
                values = [Double(bearing), Double(band)]
            }
            XCTAssertEqual(engine.handle(control: control, values: values), .accepted, "\(control) \(values)")
        }
        XCTAssertEqual(engine.outcome?.code, HueCompassExperienceCore.wonCode)
        XCTAssertEqual(HueCompassExperienceCore.wonCode, "won")
    }

    /// Clarification Q2 (the convergence lesson of feature 319): the interface tests pin level 1 in their `HC`
    /// namespace (Tests/UI/HueCompass/HCSupport.swift, which this target cannot import); the same literals equal the
    /// Core's certified level 1 (docs/games/hue-compass/levels/001.witness.json): start bearing 35, target bearing 88
    /// in band 12, bearing tolerance 4, band tolerance 2, allowance 9, certified smallest 1 probe (at bearing 8),
    /// witness actions turn −27, probe, select bearing 84 band 10. Seed 0 opens level 1.
    func testHueCompassLevelOneEqualsTheCore() throws {
        let certified = try HueCompassExperienceCore.generated(number: 1)
        let level = certified.level
        XCTAssertEqual(level.start, 35, "HC.levelOneStart")
        XCTAssertEqual(level.target, 88, "HC.levelOneTarget")
        XCTAssertEqual(level.targetBand, 12, "HC.levelOneTargetBand")
        XCTAssertEqual(level.bearingTolerance, 4, "HC.levelOneBearingTolerance")
        XCTAssertEqual(level.bandTolerance, 2, "HC.levelOneBandTolerance")
        XCTAssertEqual(level.allowance, 9, "HC.levelOneAllowance")
        XCTAssertTrue(level.tutorial, "level 1 shows the tutorial")
        XCTAssertEqual(certified.solution.smallest, 1, "HC.levelOneSmallest")
        XCTAssertEqual(certified.solution.probes, [8], "HC.levelOneProbes")
        let witness: [HueCompassAction] = [.turn(-27), .probe, .select(bearing: 84, band: 10)]
        XCTAssertEqual(HueCompassWitness.actions(for: certified.solution, level: level), witness,
                       "HC.levelOneWitnessActions")
        XCTAssertTrue(level.accepts(bearing: 84, band: 10), "the witness selection is accepted")
        XCTAssertEqual(HueCompassProgress.stars(units: 2, smallest: certified.solution.smallest), 3,
                       "a probe and the selection earn 3 of 3 stars")
        XCTAssertEqual(HueCompassExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Colorfall Canyons in the app (feature 349, R02-G05-09; T-R02G0509-005, FR-R02G0509-003,
    // FR-R02G0509-006; SC-R02G0509-002)

    /// Colorfall Canyons's registration (a candidate until X-R02-G05, integrated since 2026-11-21).
    private func colorfallCanyonsRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(ColorfallCanyonsExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Colorfall Canyons is integrated")
    }

    /// FR-R02G0509-003: the snapshot is schema 3 and the stored schema-1 and schema-2 examples restore to their digests
    /// through the migrations (the app's migration check).
    func testTheColorfallCanyonsRegistrationRestoresItsStoredExamples() async throws {
        let registration = try colorfallCanyonsRegistration()
        XCTAssertEqual(ColorfallCanyonsExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(ColorfallCanyonsExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(ColorfallCanyonsExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G05 (2026-11-21): Colorfall Canyons is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0509-006 held until then).
    func testColorfallCanyonsIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(ColorfallCanyonsExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g05.colorfall-canyons")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0509-003, SC-R02G0509-002: with `-vcCandidates` Colorfall Canyons is shown, opens through the registry
    /// and engine with seed 0 (level 1), and level 1 is won by its certified witness actions
    /// (`ColorfallCanyonsWitness.make(_:).actions`) sent as `canyon.carve [cell]`, `canyon.valve [spring]` and
    /// `time.step [ticks]`; the win opens level 2 and `level.next` plays it.
    func testColorfallCanyonsOpensAsACandidateAndLevelOneIsWonByItsCertifiedWitness() async throws {
        let registration = try colorfallCanyonsRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows it")
        let controls = registration.controls.map(\.id)
        for control in ["canyon.carve", "canyon.valve", "time.step", "level.next"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(ColorfallCanyonsExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<ColorfallCanyonsExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        let witness = try ColorfallCanyonsWitness.make(ColorfallCanyonsExperienceCore.generated(number: 1))
        XCTAssertFalse(witness.actions.isEmpty)
        for action in witness.actions {
            let control: String
            let values: [Double]
            switch action {
            case .carve(let cell):
                control = "canyon.carve"
                values = [Double(cell)]
            case .valve(let spring):
                control = "canyon.valve"
                values = [Double(spring)]
            case .step(let ticks):
                control = "time.step"
                values = [Double(ticks)]
            }
            XCTAssertEqual(engine.handle(control: control, values: values), .accepted, "\(control) \(values)")
        }
        XCTAssertEqual(engine.outcome?.code, ColorfallCanyonsExperienceCore.wonCode)
        XCTAssertEqual(ColorfallCanyonsExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, ColorfallCanyonsStage.won)
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 (their own literals, which this target
    /// cannot import); the same literals equal the Core's certified level 1: witness actions carve 10, carve 10,
    /// step 120; certified smallest 2 edits; the carvable cells at the start; 6 columns. Seed 0 opens level 1.
    func testColorfallCanyonsLevelOneEqualsTheCore() throws {
        let pinnedActions: [ColorfallCanyonsAction] = [.carve(10), .carve(10), .step(120)]
        let pinnedSmallest: Int = 2
        let pinnedCarvable: [Int] = [0, 2, 3, 5, 6, 7, 8, 9, 10, 11, 13, 15, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 29]
        let pinnedColumns: Int = 6
        let certified = try ColorfallCanyonsExperienceCore.generated(number: 1)
        let level = certified.level
        XCTAssertEqual(try ColorfallCanyonsWitness.make(certified).actions, pinnedActions, "level 1 witness actions")
        XCTAssertEqual(certified.solution.smallest, pinnedSmallest, "level 1 smallest")
        var carvable: [Int] = []
        for cell in 0..<level.cellCount where level.isCarvable(cell, heights: level.heights) {
            carvable.append(cell)
        }
        XCTAssertEqual(carvable, pinnedCarvable, "level 1 carvable cells at the start")
        XCTAssertEqual(level.columns, pinnedColumns, "level 1 columns")
        XCTAssertEqual(ColorfallCanyonsExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Chrono Constellator in the app (feature 359, R02-G06-09; T-R02G0609-005, FR-R02G0609-003,
    // FR-R02G0609-006; SC-R02G0609-002)

    /// Chrono Constellator's registration (a candidate until X-R02-G06, integrated since 2026-11-22).
    private func chronoConstellatorRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(ChronoConstellatorExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Chrono Constellator is integrated")
    }

    /// FR-R02G0609-003, clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples restore
    /// to their digests through the migrations (the app's migration check).
    func testTheChronoConstellatorRegistrationRestoresItsStoredExamples() async throws {
        let registration = try chronoConstellatorRegistration()
        XCTAssertEqual(ChronoConstellatorExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(ChronoConstellatorExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(ChronoConstellatorExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G06 (2026-11-22): Chrono Constellator is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0609-006 held until then).
    func testChronoConstellatorIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(ChronoConstellatorExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g06.chrono-constellator")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0609-003, SC-R02G0609-002: with `-vcCandidates` Chrono Constellator is shown, opens through the registry
    /// and engine with seed 0 (level 1), and level 1 is won by its certified witness actions
    /// (`ChronoConstellatorExperienceCore.certifiedActions(1)`) sent as `star.phase [star, phase]` and
    /// `time.step [ticks]`; the win opens level 2 and `level.next` plays it.
    func testChronoConstellatorOpensAsACandidateAndLevelOneIsWonByItsCertifiedWitness() async throws {
        let registration = try chronoConstellatorRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows it")
        let controls = registration.controls.map(\.id)
        for control in ["star.phase", "time.step", "level.next"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(ChronoConstellatorExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<ChronoConstellatorExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        let actions: [ChronoConstellatorAction] = ChronoConstellatorExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            let control: String
            let values: [Double]
            switch action {
            case .phase(let star, let phase):
                control = "star.phase"
                values = [Double(star), Double(phase)]
            case .step(let ticks):
                control = "time.step"
                values = [Double(ticks)]
            default:
                XCTFail("level 1's certified actions are phase changes and one step, not \(action)")
                return
            }
            XCTAssertEqual(engine.handle(control: control, values: values), .accepted, "\(control) \(values)")
        }
        XCTAssertEqual(engine.outcome?.code, ChronoConstellatorExperienceCore.wonCode)
        XCTAssertEqual(ChronoConstellatorExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, ChronoConstellatorStage.won)
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `CR` (their own literals, which this
    /// target cannot import); the same literals equal the Core's certified level 1: witness actions phase(0, 8),
    /// step 145; certified smallest 1; two stars with default phases 7 and 3, loop lengths 10 and 6, certified phases
    /// 8 and 3; 6 columns; tick limit 145. Seed 0 opens level 1.
    func testChronoConstellatorLevelOneEqualsTheCore() throws {
        let pinnedActions: [ChronoConstellatorAction] = [.phase(0, 8), .step(145)]
        let pinnedSmallest: Int = 1
        let pinnedDefaultPhases: [Int] = [7, 3]
        let pinnedLoopLengths: [Int] = [10, 6]
        let pinnedCertifiedPhases: [Int] = [8, 3]
        let pinnedColumns: Int = 6
        let pinnedTickLimit: Int = 145
        let certified = try ChronoConstellatorExperienceCore.generated(number: 1)
        let level = certified.level
        XCTAssertEqual(ChronoConstellatorExperienceCore.certifiedActions(1), pinnedActions, "level 1 witness actions")
        XCTAssertEqual(certified.solution.lowerBound, pinnedSmallest, "level 1 smallest")
        var defaultPhases: [Int] = []
        var loopLengths: [Int] = []
        for star in level.stars {
            defaultPhases.append(star.phase)
            loopLengths.append(star.length)
        }
        XCTAssertEqual(defaultPhases, pinnedDefaultPhases, "level 1 default phases")
        XCTAssertEqual(loopLengths, pinnedLoopLengths, "level 1 loop lengths")
        XCTAssertEqual(certified.solution.phases, pinnedCertifiedPhases, "level 1 certified phases")
        XCTAssertEqual(level.columns, pinnedColumns, "level 1 columns")
        XCTAssertEqual(level.tickLimit, pinnedTickLimit, "level 1 tick limit")
        XCTAssertEqual(ChronoConstellatorExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Amethyst Escape in the app (feature 369, R02-G07-09; T-R02G0709-005, FR-R02G0709-003,
    // FR-R02G0709-006; SC-R02G0709-002)

    /// Amethyst Escape's registration (a candidate until X-R02-G07, integrated since 2026-11-22).
    private func amethystEscapeRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(AmethystEscapeExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Amethyst Escape is integrated")
    }

    /// FR-R02G0709-003, clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples
    /// restore to their digests through the migrations (the app's migration check).
    func testTheAmethystEscapeRegistrationRestoresItsStoredExamples() async throws {
        let registration = try amethystEscapeRegistration()
        XCTAssertEqual(AmethystEscapeExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(AmethystEscapeExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(AmethystEscapeExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G07 (2026-11-22): Amethyst Escape is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0709-006 held until then).
    func testAmethystEscapeIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(AmethystEscapeExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g07.amethyst-escape")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0709-003, SC-R02G0709-002: with `-vcCandidates` Amethyst Escape is shown, opens through the registry and
    /// engine with seed 0 (level 1), and level 1 is won by its certified witness actions
    /// (`AmethystEscapeExperienceCore.certifiedActions(1)`) sent as `shell.rotate [shell, step]` and `pearl.advance`;
    /// the win opens level 2 and `level.next` plays it.
    func testAmethystEscapeOpensAsACandidateAndLevelOneIsWonByItsCertifiedWitness() async throws {
        let registration = try amethystEscapeRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows it")
        let controls = registration.controls.map(\.id)
        for control in ["shell.rotate", "pearl.advance", "level.next"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(AmethystEscapeExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<AmethystEscapeExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        let actions: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            let control: String
            let values: [Double]
            switch action {
            case .rotate(let shell, let step):
                control = "shell.rotate"
                values = [Double(shell), Double(step)]
            case .advance:
                control = "pearl.advance"
                values = []
            }
            XCTAssertEqual(engine.handle(control: control, values: values), .accepted, "\(control) \(values)")
        }
        XCTAssertEqual(engine.outcome?.code, AmethystEscapeExperienceCore.wonCode)
        XCTAssertEqual(AmethystEscapeExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, AmethystEscapeStage.won)
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `AE` (their own literals, which this
    /// target cannot import); the same literals equal the Core's certified level 1: witness actions rotate(0, −1),
    /// advance, advance; certified smallest 3; the shell picker starts on shell 0 (the innermost shell, a shell of
    /// level 1, and the shell of the first certified turn, so the interface test needs no picker step for it). Seed 0
    /// opens level 1.
    func testAmethystEscapeLevelOneEqualsTheCore() throws {
        let pinnedActions: [AmethystEscapeAction] = [.rotate(0, -1), .advance, .advance]
        let pinnedSmallest: Int = 3
        let pinnedStartingShell: Int = 0
        let certified = try AmethystEscapeExperienceCore.generated(number: 1)
        let level = certified.level
        XCTAssertEqual(AmethystEscapeExperienceCore.certifiedActions(1), pinnedActions, "level 1 witness actions")
        XCTAssertEqual(certified.solution.actions, pinnedActions, "level 1 solution actions")
        XCTAssertEqual(certified.solution.smallest, pinnedSmallest, "level 1 smallest")
        XCTAssertEqual(pinnedActions.count, pinnedSmallest, "the witness is a shortest solution")
        XCTAssertEqual(level.shells.indices.lowerBound, pinnedStartingShell, "the picker starts on the innermost shell")
        XCTAssertEqual(AmethystEscapeExperienceCore.shellRange.lowerBound, pinnedStartingShell, "a declared shell")
        XCTAssertTrue(level.shells.indices.contains(pinnedStartingShell), "level 1 has the starting shell")
        var firstTurnedShell: Int?
        for action in pinnedActions {
            if case .rotate(let shell, _) = action {
                firstTurnedShell = shell
                break
            }
        }
        XCTAssertEqual(firstTurnedShell, pinnedStartingShell, "the first certified turn is of the starting shell")
        XCTAssertEqual(AmethystEscapeExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Faceted Forge in the app (feature 379, R02-G08-09; T-R02G0809-005, FR-R02G0809-003,
    // FR-R02G0809-006; SC-R02G0809-002)

    /// Faceted Forge's registration (a candidate until X-R02-G08, integrated since 2026-11-22).
    private func facetedForgeRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(FacetedForgeExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Faceted Forge is integrated")
    }

    /// FR-R02G0809-003, clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples
    /// restore to their digests through the migrations (the app's migration check).
    func testTheFacetedForgeRegistrationRestoresItsStoredExamples() async throws {
        let registration = try facetedForgeRegistration()
        XCTAssertEqual(FacetedForgeExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(FacetedForgeExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(FacetedForgeExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G08 (2026-11-22): Faceted Forge is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0809-006 held until then).
    func testFacetedForgeIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(FacetedForgeExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g08.faceted-forge")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0809-003, SC-R02G0809-002: with `-vcCandidates` Faceted Forge is shown, opens through the registry and
    /// engine with seed 0 (level 1), and level 1 is won by its certified cuts
    /// (`FacetedForgeExperienceCore.certifiedActions(1)`) sent as `piece.cut [piece, direction, depth]` with three
    /// stars; the win opens level 2 and `level.next` plays it.
    func testFacetedForgeOpensAsACandidateAndLevelOneIsWonByItsCertifiedCuts() async throws {
        let registration = try facetedForgeRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows the candidate")
        let controls = registration.controls.map(\.id)
        for control in ["piece.cut", "play.undo", "level.next", "tutorial.dismiss", "replay.start"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(FacetedForgeExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<FacetedForgeExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        let actions: [FacetedForgeAction] = FacetedForgeExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            let values: [Double]
            switch action {
            case .cut(let piece, let direction, let depth):
                values = [Double(piece), Double(direction), Double(depth)]
            }
            XCTAssertEqual(engine.handle(control: "piece.cut", values: values), .accepted, "piece.cut \(values)")
        }
        XCTAssertEqual(engine.outcome?.code, FacetedForgeExperienceCore.wonCode)
        XCTAssertEqual(FacetedForgeExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, FacetedForgeStage.won)
        XCTAssertEqual(engine.core?.progress.solved[1]?.stars, 3, "the certified cuts earn three stars")
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `FF` (`FF.levelOneCuts` and
    /// `FF.startChoice`, their own literals in Tests/UI/FacetedForge/FFSupport.swift, which this target cannot
    /// import); the same literals equal the Core's certified level 1: cuts (piece, direction, depth) (0, 3, −3),
    /// (0, 3, 1), (1, 5, −5); certified smallest 3; the pickers start on piece 0, direction 2 (z, the facing
    /// direction) and depth 0 (the middle crossing depth of level 1's cube). Seed 0 opens level 1.
    func testFacetedForgeLevelOneEqualsTheCore() throws {
        let pinnedCuts: [[Int]] = [[0, 3, -3], [0, 3, 1], [1, 5, -5]]
        let pinnedSmallest: Int = 3
        let pinnedStartChoice: [Int] = [0, 2, 0]
        func triples(_ actions: [FacetedForgeAction]) -> [[Int]] {
            actions.map { action -> [Int] in
                switch action {
                case .cut(let piece, let direction, let depth): return [piece, direction, depth]
                }
            }
        }
        let certified = try FacetedForgeExperienceCore.generated(number: 1)
        XCTAssertEqual(triples(FacetedForgeExperienceCore.certifiedActions(1)), pinnedCuts, "level 1 certified cuts")
        XCTAssertEqual(triples(certified.solution.actions), pinnedCuts, "level 1 solution cuts")
        XCTAssertEqual(certified.solution.smallest, pinnedSmallest, "level 1 smallest")
        XCTAssertEqual(pinnedCuts.count, pinnedSmallest, "the certified cuts are a shortest solution")
        for cut in pinnedCuts {
            XCTAssertTrue(FacetedForgeExperienceCore.pieceRange.contains(cut[0]), "declared piece \(cut)")
            XCTAssertTrue(FacetedForgeExperienceCore.directionRange.contains(cut[1]), "declared direction \(cut)")
            XCTAssertTrue(FacetedForgeExperienceCore.depthRange.contains(cut[2]), "declared depth \(cut)")
        }
        let opening = try FacetedForgeExperienceCore.opening(number: 1)
        let initial = FacetedForgePreviewChoice.initial(opening.play)
        XCTAssertEqual([initial.piece, initial.direction, initial.depth], pinnedStartChoice, "the opening choice")
        let fresh = FacetedForgePreviewChoice.initial(try FacetedForgeExperienceCore.freshPlay(of: certified.level))
        XCTAssertEqual([fresh.piece, fresh.direction, fresh.depth], pinnedStartChoice, "a fresh play's choice")
        XCTAssertEqual(pinnedStartChoice[1], FacetedForgePreviewChoice.facingDirection, "the facing direction")
        XCTAssertEqual(FacetedForgeExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Nocturne Garden in the app (feature 389, R02-G09-09; T-R02G0909-005, FR-R02G0909-003,
    // FR-R02G0909-006; SC-R02G0909-002)

    /// Nocturne Garden's registration (a candidate until X-R02-G09, integrated since 2026-11-22).
    private func nocturneGardenRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(NocturneGardenExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Nocturne Garden is integrated")
    }

    /// FR-R02G0909-003, clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples
    /// restore to their digests through the migrations (the app's migration check).
    func testTheNocturneGardenRegistrationRestoresItsStoredExamples() async throws {
        let registration = try nocturneGardenRegistration()
        XCTAssertEqual(NocturneGardenExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(NocturneGardenExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(NocturneGardenExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G09 (2026-11-22): Nocturne Garden is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G0909-006 held until then).
    func testNocturneGardenIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(NocturneGardenExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g09.nocturne-garden")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G0909-003, SC-R02G0909-002: with `-vcCandidates` Nocturne Garden is shown, opens through the registry and
    /// engine with seed 0 (level 1), and level 1 is won by its certified moves
    /// (`NocturneGardenExperienceCore.certifiedActions(1)`) sent as `bloom.plant [kind, column, row, size]` (kind as
    /// `NocturneGardenKind.order`) and `sun.set [elevation]` with three stars; the win opens level 2 and `level.next`
    /// plays it.
    func testNocturneGardenOpensAsACandidateAndLevelOneIsWonByItsCertifiedMoves() async throws {
        let registration = try nocturneGardenRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows the candidate")
        let controls = registration.controls.map(\.id)
        for control in ["bloom.plant", "sun.set", "play.undo", "level.next", "tutorial.dismiss", "replay.start"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(NocturneGardenExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<NocturneGardenExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        let actions: [NocturneGardenAction] = NocturneGardenExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            let control: String
            let values: [Double]
            switch action {
            case .plant(let kind, let column, let row, let size):
                control = "bloom.plant"
                values = [Double(kind.order), Double(column), Double(row), Double(size)]
            case .move(let bloom, let column, let row):
                control = "bloom.move"
                values = [Double(bloom), Double(column), Double(row)]
            case .resize(let bloom, let size):
                control = "bloom.resize"
                values = [Double(bloom), Double(size)]
            case .remove(let bloom):
                control = "bloom.remove"
                values = [Double(bloom)]
            case .sun(let elevation):
                control = "sun.set"
                values = [Double(elevation)]
            }
            XCTAssertEqual(engine.handle(control: control, values: values), .accepted, "\(control) \(values)")
        }
        XCTAssertEqual(engine.outcome?.code, NocturneGardenExperienceCore.wonCode)
        XCTAssertEqual(NocturneGardenExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, NocturneGardenStage.won)
        XCTAssertEqual(engine.core?.progress.solved[1]?.stars, 3, "the certified moves earn three stars")
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `NG` (`NG.levelOneMoves` and
    /// `NG.levelOneStartingPicks`, their own literals in Tests/UI/NocturneGarden/NGSupport.swift, which this target
    /// cannot import); the same literals equal the Core's certified level 1: plants (kind, column, row, size)
    /// (0 tulip, 4, 0, 2), (2 star, 11, 0, 2) and no sun move; certified smallest 2; the pickers start on the level's
    /// first supplied kind (tulip, 0), column 0, row 0, its smallest size (2) and its opening sun (2). Seed 0 opens
    /// level 1.
    func testNocturneGardenLevelOneEqualsTheCore() throws {
        // A plant is [kind, column, row, size]; a sun move is [elevation].
        let pinnedMoves: [[Int]] = [[0, 4, 0, 2], [2, 11, 0, 2]]
        let pinnedSmallest: Int = 2
        // [kind, column, row, size, sun]
        let pinnedStartingPicks: [Int] = [0, 0, 0, 2, 2]
        func moves(_ actions: [NocturneGardenAction]) -> [[Int]] {
            actions.map { action -> [Int] in
                switch action {
                case .plant(let kind, let column, let row, let size): return [kind.order, column, row, size]
                case .sun(let elevation): return [elevation]
                // The certified solution only plants and moves the sun; anything else fails the comparison.
                case .move, .resize, .remove: return []
                }
            }
        }
        let certified = try NocturneGardenExperienceCore.generated(number: 1)
        XCTAssertEqual(moves(NocturneGardenExperienceCore.certifiedActions(1)), pinnedMoves, "level 1 certified moves")
        XCTAssertEqual(moves(certified.solution.actions), pinnedMoves, "level 1 solution moves")
        XCTAssertEqual(certified.solution.smallest, pinnedSmallest, "level 1 smallest")
        XCTAssertEqual(pinnedMoves.count, pinnedSmallest, "the certified moves are a shortest solution")
        let level = certified.level
        for move in pinnedMoves where move.count == 4 {
            let kind = try XCTUnwrap(NocturneGardenExperienceCore.kind(move[0]), "declared kind \(move)")
            XCTAssertGreaterThan(level.supplyCount(kind), 0, "supplied kind \(move)")
            XCTAssertTrue((0..<level.width).contains(move[1]), "column on the bed \(move)")
            XCTAssertTrue((0..<level.height).contains(move[2]), "row on the bed \(move)")
            XCTAssertTrue(level.sizes.contains(move[3]), "allowed size \(move)")
        }
        for move in pinnedMoves where move.count == 1 {
            XCTAssertTrue(level.elevations.contains(move[0]), "allowed elevation \(move)")
        }
        // The pickers' starting picks as NocturneGardenPresenter.follow(_:) sets them on a new level.
        func startingPicks(_ play: NocturneGardenPlay) -> [Int] {
            let kind: Int = NocturneGardenKind.allCases.first { play.level.supplyCount($0) > 0 }?.order ?? 0
            return [kind, 0, 0, play.level.sizes.min() ?? 1, play.elevation]
        }
        let opening = try NocturneGardenExperienceCore.opening(number: 1)
        XCTAssertEqual(startingPicks(opening.play), pinnedStartingPicks, "the opening picks")
        let fresh = try NocturneGardenExperienceCore.freshPlay(of: level)
        XCTAssertEqual(startingPicks(fresh), pinnedStartingPicks, "a fresh play's picks")
        XCTAssertEqual(pinnedStartingPicks[4], level.sun, "the opening sun")
        XCTAssertEqual(NocturneGardenExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Backwards Aurora in the app (feature 399, R02-G10-09; T-R02G1009-005, FR-R02G1009-003,
    // FR-R02G1009-006; SC-R02G1009-002)

    /// Backwards Aurora's registration (a candidate until X-R02-G10, integrated since 2026-11-23).
    private func backwardsAuroraRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(BackwardsAuroraExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Backwards Aurora is integrated")
    }

    /// FR-R02G1009-003, clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples
    /// restore to their digests through the migrations (the app's migration check).
    func testTheBackwardsAuroraRegistrationRestoresItsStoredExamples() async throws {
        let registration = try backwardsAuroraRegistration()
        XCTAssertEqual(BackwardsAuroraExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(BackwardsAuroraExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(BackwardsAuroraExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G10 (2026-11-23): Backwards Aurora is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G1009-006 held until then).
    func testBackwardsAuroraIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(BackwardsAuroraExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g10.backwards-aurora")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G1009-003, SC-R02G1009-002: with `-vcCandidates` Backwards Aurora is shown, opens through the registry
    /// and engine with seed 0 (level 1), and level 1 is won by its certified reversals
    /// (`BackwardsAuroraExperienceCore.certifiedActions(1)`) sent as `wave.reverse [start, end]` with three stars; the
    /// win opens level 2 and `level.next` plays it.
    func testBackwardsAuroraOpensAsACandidateAndLevelOneIsWonByItsCertifiedReversals() async throws {
        let registration = try backwardsAuroraRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows the candidate")
        let controls = registration.controls.map(\.id)
        for control in ["wave.reverse", "play.undo", "play.redo", "level.next", "tutorial.dismiss", "replay.start"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(BackwardsAuroraExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<BackwardsAuroraExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        let actions: [BackwardsAuroraAction] = BackwardsAuroraExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            switch action {
            case .reverse(let start, let end):
                let values: [Double] = [Double(start), Double(end)]
                XCTAssertEqual(engine.handle(control: "wave.reverse", values: values), .accepted, "reverse \(values)")
            }
        }
        XCTAssertEqual(engine.outcome?.code, BackwardsAuroraExperienceCore.wonCode)
        XCTAssertEqual(BackwardsAuroraExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, BackwardsAuroraStage.won)
        XCTAssertEqual(engine.core?.progress.solved[1]?.stars, 3, "the certified reversals earn three stars")
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `BA` (`BA.certifiedReversals` and
    /// `BA.openingSection`, their own literals in Tests/UI/BackwardsAurora/BASupport.swift, which this target cannot
    /// import); the same literals equal the Core's certified level 1: reversals (start, end) (3, 4) and (8, 11)
    /// (the stored witness `docs/games/backwards-aurora/levels/001.witness.json`); certified smallest 2; the start and
    /// end steppers begin on the section 0 … 1, as `BackwardsAuroraPresenter`'s mirror sets it on a new level, and each
    /// pinned reversal is reachable by the steppers (start 0 … count − 2, end start + 1 … count − 1) and has a length
    /// within the level's shortest … longest. Seed 0 opens level 1.
    func testBackwardsAuroraLevelOneEqualsTheCore() throws {
        // A reversal is [start, end] (inclusive).
        let pinnedReversals: [[Int]] = [[3, 4], [8, 11]]
        let pinnedSmallest: Int = 2
        // [start, end]
        let pinnedOpeningSection: [Int] = [0, 1]
        func reversals(_ actions: [BackwardsAuroraAction]) -> [[Int]] {
            actions.map { action -> [Int] in
                switch action {
                case .reverse(let start, let end): return [start, end]
                }
            }
        }
        let certified = try BackwardsAuroraExperienceCore.generated(number: 1)
        XCTAssertEqual(reversals(BackwardsAuroraExperienceCore.certifiedActions(1)), pinnedReversals,
                       "level 1 certified reversals")
        XCTAssertEqual(reversals(certified.solution.actions), pinnedReversals, "level 1 solution reversals")
        XCTAssertEqual(certified.solution.smallest, pinnedSmallest, "level 1 smallest")
        XCTAssertEqual(pinnedReversals.count, pinnedSmallest, "the certified reversals are a shortest solution")
        let level = certified.level
        for reversal in pinnedReversals {
            XCTAssertEqual(reversal.count, 2, "a reversal is a start and an end \(reversal)")
            let start: Int = reversal[0]
            let end: Int = reversal[1]
            XCTAssertTrue((0...(level.count - 2)).contains(start), "start on the start stepper \(reversal)")
            XCTAssertTrue(((start + 1)...(level.count - 1)).contains(end), "end on the end stepper \(reversal)")
            XCTAssertTrue((level.shortest...level.longest).contains(end - start + 1), "allowed length \(reversal)")
        }
        // The steppers' starting section as BackwardsAuroraPresenter's mirror sets it on a new level (follow(_:)).
        func startingSection(_ play: BackwardsAuroraPlay) -> [Int] {
            let count: Int = play.level.count
            return count >= 2 ? [0, 1] : []
        }
        let opening = try BackwardsAuroraExperienceCore.opening(number: 1)
        XCTAssertEqual(startingSection(opening.play), pinnedOpeningSection, "the opening section")
        let fresh = try BackwardsAuroraExperienceCore.freshPlay(of: level)
        XCTAssertEqual(startingSection(fresh), pinnedOpeningSection, "a fresh play's section")
        XCTAssertEqual(opening.play.level.id, level.id, "the opening plays certified level 1")
        XCTAssertEqual(BackwardsAuroraExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }


    // MARK: Echo Cartographer in the app (feature 409, R02-G11-09; T-R02G1109-005, FR-R02G1109-003,
    // FR-R02G1109-006; SC-R02G1109-002)

    /// Echo Cartographer's registration (a candidate until X-R02-G11, integrated since 2026-11-23).
    private func echoCartographerRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(EchoCartographerExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Echo Cartographer is integrated")
    }

    /// FR-R02G1109-003, clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples
    /// restore to their digests through the migrations (the app's migration check).
    func testTheEchoCartographerRegistrationRestoresItsStoredExamples() async throws {
        let registration = try echoCartographerRegistration()
        XCTAssertEqual(EchoCartographerExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(EchoCartographerExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(EchoCartographerExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G11 (2026-11-23): Echo Cartographer is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G1109-006 held until then).
    func testEchoCartographerIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(EchoCartographerExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g11.echo-cartographer")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G1109-003, SC-R02G1109-002: with `-vcCandidates` Echo Cartographer is shown, opens through the registry
    /// and engine with seed 0 (level 1), and level 1 is won by its certified actions
    /// (`EchoCartographerExperienceCore.certifiedActions(1)`) sent as `cell.pulse [x, y]` and `cell.claim [x, y]` with
    /// three stars (the opening play is already past the kernel's tutorial stage, so no `tutorial.dismiss` is needed);
    /// the win opens level 2 and `level.next` plays it.
    func testEchoCartographerOpensAsACandidateAndLevelOneIsWonByItsCertifiedActions() async throws {
        let registration = try echoCartographerRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows the candidate")
        let controls = registration.controls.map(\.id)
        for control in ["cell.pulse", "cell.claim", "cell.mark", "play.undo", "play.redo", "level.next",
                        "tutorial.dismiss", "replay.start"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(EchoCartographerExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<EchoCartographerExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        XCTAssertEqual(engine.core?.play.stage, EchoCartographerStage.playing, "the opening play accepts actions")
        let actions: [EchoCartographerAction] = EchoCartographerExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            switch action {
            case .pulse(let x, let y):
                let values: [Double] = [Double(x), Double(y)]
                XCTAssertEqual(engine.handle(control: "cell.pulse", values: values), .accepted, "pulse \(values)")
            case .claim(let x, let y):
                let values: [Double] = [Double(x), Double(y)]
                XCTAssertEqual(engine.handle(control: "cell.claim", values: values), .accepted, "claim \(values)")
            case .mark(let x, let y):
                let values: [Double] = [Double(x), Double(y)]
                XCTAssertEqual(engine.handle(control: "cell.mark", values: values), .accepted, "mark \(values)")
            }
        }
        XCTAssertEqual(engine.outcome?.code, EchoCartographerExperienceCore.wonCode)
        XCTAssertEqual(EchoCartographerExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, EchoCartographerStage.won)
        XCTAssertEqual(engine.core?.progress.solved[1]?.stars, 3, "the certified actions earn three stars")
        XCTAssertEqual(engine.core?.progress.solved[1]?.verified, true, "the win is recorded with its trace")
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `ECG` (their own literals in
    /// Tests/UI/EchoCartographer/ECGSupport.swift, which this target cannot import); the same literals equal the
    /// Core's certified level 1: pulses from (0, 3) and (0, 2), then a claim at (1, 2) (the stored witness
    /// `docs/games/echo-cartographer/levels/001.witness.json`); the cursor starts on level 1's entry, column 0, row 3,
    /// as `EchoCartographerPresenter`'s mirror sets it on a new level (`follow(_:)` puts it on `play.level.entry`);
    /// the chamber is 6 × 6 and every pinned cell is reachable by the column and row steppers. Seed 0 opens level 1.
    func testEchoCartographerLevelOnePinsInECGEqualTheCore() throws {
        // An action is [kind, column, row]; the kind is "pulse", "claim" or "mark".
        let pinnedKinds: [String] = ["pulse", "pulse", "claim"]
        let pinnedCells: [[Int]] = [[0, 3], [0, 2], [1, 2]]
        // [column, row]
        let pinnedStartingCell: [Int] = [0, 3]
        // [columns, rows]
        let pinnedChamberSize: [Int] = [6, 6]

        let certifiedActions: [EchoCartographerAction] = EchoCartographerExperienceCore.certifiedActions(1)
        var coreKinds: [String] = []
        var coreCells: [[Int]] = []
        for action in certifiedActions {
            switch action {
            case .pulse(let x, let y):
                coreKinds.append("pulse")
                coreCells.append([x, y])
            case .claim(let x, let y):
                coreKinds.append("claim")
                coreCells.append([x, y])
            case .mark(let x, let y):
                coreKinds.append("mark")
                coreCells.append([x, y])
            }
        }
        XCTAssertEqual(coreKinds, pinnedKinds, "level 1 certified action kinds")
        XCTAssertEqual(coreCells, pinnedCells, "level 1 certified action cells")

        let certified = try EchoCartographerExperienceCore.generated(number: 1)
        let level: EchoCartographerLevel = certified.level
        XCTAssertEqual(certified.actions, certifiedActions, "the certified witness is the generated level's")
        var pinnedPulses: [[Int]] = []
        var index: Int = 0
        while index < pinnedKinds.count {
            if pinnedKinds[index] == "pulse" { pinnedPulses.append(pinnedCells[index]) }
            index += 1
        }
        var planPulses: [[Int]] = []
        for cell in certified.plan.pulses {
            planPulses.append([cell.x, cell.y])
        }
        XCTAssertEqual(planPulses, pinnedPulses, "the certified plan's pulses")

        let chamberSize: [Int] = [level.chamber.width, level.chamber.height]
        XCTAssertEqual(chamberSize, pinnedChamberSize, "level 1's chamber size")
        for cell in pinnedCells {
            XCTAssertEqual(cell.count, 2, "a cell is a column and a row \(cell)")
            XCTAssertTrue((0...(level.chamber.width - 1)).contains(cell[0]), "column on the column stepper \(cell)")
            XCTAssertTrue((0...(level.chamber.height - 1)).contains(cell[1]), "row on the row stepper \(cell)")
        }

        // The cursor's starting cell as EchoCartographerPresenter's mirror sets it on a new level (follow(_:)).
        let entry: [Int] = [level.entry.x, level.entry.y]
        XCTAssertEqual(entry, pinnedStartingCell, "level 1's entry")
        let opening = try EchoCartographerExperienceCore.opening(number: 1)
        let openingEntry: [Int] = [opening.play.level.entry.x, opening.play.level.entry.y]
        XCTAssertEqual(openingEntry, pinnedStartingCell, "the opening cursor cell")
        let fresh = try EchoCartographerExperienceCore.freshPlay(of: level)
        let freshEntry: [Int] = [fresh.level.entry.x, fresh.level.entry.y]
        XCTAssertEqual(freshEntry, pinnedStartingCell, "a fresh play's cursor cell")
        XCTAssertEqual(opening.play.level.id, level.id, "the opening plays certified level 1")
        XCTAssertEqual(EchoCartographerExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Harmonic Bridges in the app (feature 419, R02-G12-09; T-R02G1209-005, FR-R02G1209-003,
    // FR-R02G1209-006; SC-R02G1209-002)

    /// Harmonic Bridges' registration (a candidate until X-R02-G12, integrated since 2026-11-23).
    private func harmonicBridgesRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(HarmonicBridgesExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id }, "Harmonic Bridges is integrated")
    }

    /// FR-R02G1209-003, clarification Q3: the snapshot is schema 3 and the stored schema-1 and schema-2 examples
    /// restore to their digests through the migrations (the app's migration check).
    func testTheHarmonicBridgesRegistrationRestoresItsStoredExamples() async throws {
        let registration = try harmonicBridgesRegistration()
        XCTAssertEqual(HarmonicBridgesExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(HarmonicBridgesExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(HarmonicBridgesExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G12 (2026-11-23): Harmonic Bridges is integrated: in `all`, not a candidate, available in the bundled
    /// catalog, shown and opened without `-vcCandidates` (FR-R02G1209-006 held until then).
    func testHarmonicBridgesIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(HarmonicBridgesExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g12.harmonic-bridges")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G1209-003, SC-R02G1209-002: with `-vcCandidates` Harmonic Bridges is shown, opens through the registry
    /// and engine with seed 0 (level 1), and level 1 is won by its certified actions
    /// (`HarmonicBridgesExperienceCore.certifiedActions(1)`) sent as `string.tune [string, peg]` and `crossing.test`
    /// with three stars (the opening play is already past the kernel's tutorial stage, so no `tutorial.dismiss` is
    /// needed); the win opens level 2 and `level.next` plays it.
    func testHarmonicBridgesOpensAsACandidateAndLevelOneIsWonByItsCertifiedActions() async throws {
        let registration = try harmonicBridgesRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows the candidate")
        let controls = registration.controls.map(\.id)
        for control in ["string.tune", "crossing.test", "play.undo", "play.redo", "level.next", "tutorial.dismiss",
                        "replay.start"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(HarmonicBridgesExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<HarmonicBridgesExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        XCTAssertEqual(engine.core?.play.stage, HarmonicBridgesStage.playing, "the opening play accepts actions")
        let actions: [HarmonicBridgesAction] = HarmonicBridgesExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            switch action {
            case .tune(let string, let peg):
                let values: [Double] = [Double(string), Double(peg)]
                XCTAssertEqual(engine.handle(control: "string.tune", values: values), .accepted, "tune \(values)")
            case .test:
                XCTAssertEqual(engine.handle(control: "crossing.test"), .accepted, "test")
            }
        }
        XCTAssertEqual(engine.outcome?.code, HarmonicBridgesExperienceCore.wonCode)
        XCTAssertEqual(HarmonicBridgesExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, HarmonicBridgesStage.won)
        XCTAssertEqual(engine.core?.progress.solved[1]?.stars, 3, "the certified actions earn three stars")
        XCTAssertEqual(engine.core?.progress.solved[1]?.verified, true, "the win is recorded with its trace")
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `HB` (their own literals in
    /// Tests/UI/HarmonicBridges/HBSupport.swift, which this target cannot import); the same literals equal the Core's
    /// certified level 1: one tuning, string 0 to peg 12, then the test; the panel opens a new level with string 0
    /// chosen at its current peg (`HarmonicBridgesMirror.follow(_:)`), peg 11 on level 1; the budget is 9; every pinned
    /// string and peg is reachable by the string and peg steppers. Seed 0 opens level 1.
    func testHarmonicBridgesLevelOnePinsInHBEqualTheCore() throws {
        // An action is a kind ("tune" or "test") with, for a tune, [string, peg] (empty for the test).
        let pinnedKinds: [String] = ["tune", "test"]
        let pinnedTunings: [[Int]] = [[0, 12]]
        // [string, peg]
        let pinnedOpeningChoice: [Int] = [0, 11]
        let pinnedBudget: Int = 9

        let certifiedActions: [HarmonicBridgesAction] = HarmonicBridgesExperienceCore.certifiedActions(1)
        var coreKinds: [String] = []
        var coreTunings: [[Int]] = []
        for action in certifiedActions {
            switch action {
            case .tune(let string, let peg):
                coreKinds.append("tune")
                coreTunings.append([string, peg])
            case .test:
                coreKinds.append("test")
            }
        }
        XCTAssertEqual(coreKinds, pinnedKinds, "level 1 certified action kinds")
        XCTAssertEqual(coreTunings, pinnedTunings, "level 1 certified tunings")
        XCTAssertEqual(HarmonicBridgesExperienceCore.certifiedTunings(1).count, pinnedTunings.count, "one tuning")

        let certified = try HarmonicBridgesExperienceCore.generated(number: 1)
        let level: HarmonicBridgesLevel = certified.level
        XCTAssertEqual(certified.actions, certifiedActions, "the certified witness is the generated level's")
        XCTAssertEqual(level.budget, pinnedBudget, "level 1's budget")
        XCTAssertGreaterThanOrEqual(level.budget, certifiedActions.count, "the witness fits the budget")
        for tuning in pinnedTunings {
            XCTAssertEqual(tuning.count, 2, "a tuning is a string and a peg \(tuning)")
            XCTAssertTrue((0...(level.strings.count - 1)).contains(tuning[0]), "string on the string stepper \(tuning)")
            XCTAssertTrue(HarmonicBridgesExperienceCore.pegRange.contains(tuning[1]), "peg on the peg stepper \(tuning)")
        }

        // The panel's opening choice as HarmonicBridgesMirror sets it on a new level (follow(_:)): string 0 at its
        // current peg.
        let startingChoice: [Int] = [0, level.startingPegs[0]]
        XCTAssertEqual(startingChoice, pinnedOpeningChoice, "level 1's starting peg of string 0")
        let opening = try HarmonicBridgesExperienceCore.opening(number: 1)
        let openingChoice: [Int] = [0, opening.play.pegs[0]]
        XCTAssertEqual(openingChoice, pinnedOpeningChoice, "the opening choice")
        XCTAssertEqual(opening.play.actionsLeft, pinnedBudget, "the opening's actions left")
        let fresh = try HarmonicBridgesExperienceCore.freshPlay(of: level)
        let freshChoice: [Int] = [0, fresh.pegs[0]]
        XCTAssertEqual(freshChoice, pinnedOpeningChoice, "a fresh play's choice")
        XCTAssertEqual(opening.play.level.id, level.id, "the opening plays certified level 1")
        XCTAssertEqual(HarmonicBridgesExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Acoustic Constellator in the app (feature 429, R02-G13-09; T-R02G1309-005, FR-R02G1309-003, 006; SC-R02G1309-002)

    /// Acoustic Constellator's registration (a candidate until X-R02-G13, integrated since 2026-11-24).
    private func acousticConstellatorRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(AcousticConstellatorExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.all.first { $0.id == id },
                             "Acoustic Constellator is integrated")
    }

    /// FR-R02G1309-003: the snapshot is schema 3 and the stored schema-1 and schema-2 examples restore to their digests
    /// through the migrations (the app's migration check, which also reports a version without a stored example).
    func testTheAcousticConstellatorRegistrationRestoresItsStoredExamples() async throws {
        let registration = try acousticConstellatorRegistration()
        XCTAssertEqual(AcousticConstellatorExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(AcousticConstellatorExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(AcousticConstellatorExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// X-R02-G13 (2026-11-24): Acoustic Constellator is integrated: in `all`, not a candidate, available in the
    /// bundled catalog, shown and opened without `-vcCandidates` (FR-R02G1309-006 held until then).
    func testAcousticConstellatorIsIntegratedAndAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(AcousticConstellatorExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g13.acoustic-constellator")
        XCTAssertFalse(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertTrue(ExperienceRegistry.all.map(\.id).contains(id))
        XCTAssertEqual(try acousticConstellatorRegistration().openingSeed, 0)
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertTrue(model.shown.map(\.id).contains(id), "a tile")
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertNotNil(model.session.experience)
    }

    /// FR-R02G1309-003, SC-R02G1309-002: with `-vcCandidates` Acoustic Constellator is shown, opens through the
    /// registry and engine with seed 0 (level 1), and level 1 is won by its certified actions
    /// (`AcousticConstellatorExperienceCore.certifiedActions(1)`) sent as `link.add [a, b]`, `star.nudge [star, step]`
    /// and `constellation.listen` with three stars (the opening play is already past the kernel's tutorial stage; the
    /// tutorial step is presentation and blocks no action, so no `tutorial.dismiss` is needed); the win opens level 2
    /// and `level.next` plays it.
    func testAcousticConstellatorOpensAsACandidateAndLevelOneIsWonByItsCertifiedActions() async throws {
        let registration = try acousticConstellatorRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows the candidate")
        let controls = registration.controls.map(\.id)
        for control in ["link.add", "link.remove", "star.nudge", "constellation.listen", "play.undo", "play.redo",
                        "level.next", "tutorial.dismiss", "replay.start"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(AcousticConstellatorExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<AcousticConstellatorExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        XCTAssertEqual(engine.core?.play.stage, AcousticConstellatorStage.playing, "the opening play accepts actions")
        let actions: [AcousticConstellatorAction] = AcousticConstellatorExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            switch action {
            case .link(let a, let b):
                let values: [Double] = [Double(a), Double(b)]
                XCTAssertEqual(engine.handle(control: "link.add", values: values), .accepted, "link \(values)")
            case .unlink(let a, let b):
                let values: [Double] = [Double(a), Double(b)]
                XCTAssertEqual(engine.handle(control: "link.remove", values: values), .accepted, "unlink \(values)")
            case .nudge(let star, let step):
                let values: [Double] = [Double(star), Double(step)]
                XCTAssertEqual(engine.handle(control: "star.nudge", values: values), .accepted, "nudge \(values)")
            case .listen:
                XCTAssertEqual(engine.handle(control: "constellation.listen"), .accepted, "listen")
            }
        }
        XCTAssertEqual(engine.outcome?.code, AcousticConstellatorExperienceCore.wonCode)
        XCTAssertEqual(AcousticConstellatorExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, AcousticConstellatorStage.won)
        XCTAssertEqual(engine.core?.progress.solved[1]?.stars, 3, "the certified actions earn three stars")
        XCTAssertEqual(engine.core?.progress.solved[1]?.verified, true, "the win is recorded with its trace")
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `ACN` (their own literals in
    /// Tests/UI/AcousticConstellator/ACNSupport.swift, which this target cannot import); the same literals equal the
    /// Core's certified level 1: one link, star 0 to star 1, then the listen; the panel opens a level with star 0 and
    /// partner 1 chosen (`openingStar`, `openingPartner`); the budget is 9; every pinned star is on the level. Seed 0
    /// opens level 1.
    func testAcousticConstellatorLevelOnePinsInACNEqualTheCore() throws {
        // An action is a kind ("link" or "listen") with, for a link, [a, b] (none for the listen).
        let pinnedKinds: [String] = ["link", "listen"]
        let pinnedLinks: [[Int]] = [[0, 1]]
        // [star, partner]
        let pinnedOpeningChoice: [Int] = [0, 1]
        let pinnedBudget: Int = 9

        let certifiedActions: [AcousticConstellatorAction] = AcousticConstellatorExperienceCore.certifiedActions(1)
        XCTAssertEqual(certifiedActions, [.link(0, 1), .listen], "level 1's certified actions")
        var coreKinds: [String] = []
        var coreLinks: [[Int]] = []
        for action in certifiedActions {
            switch action {
            case .link(let a, let b):
                coreKinds.append("link")
                coreLinks.append([a, b])
            case .unlink:
                coreKinds.append("unlink")
            case .nudge:
                coreKinds.append("nudge")
            case .listen:
                coreKinds.append("listen")
            }
        }
        XCTAssertEqual(coreKinds, pinnedKinds, "level 1 certified action kinds")
        XCTAssertEqual(coreLinks, pinnedLinks, "level 1 certified links")

        let certified = try AcousticConstellatorExperienceCore.generated(number: 1)
        let level: AcousticConstellatorLevel = certified.level
        XCTAssertEqual(certified.actions, certifiedActions, "the certified witness is the generated level's")
        XCTAssertEqual(level.budget, pinnedBudget, "level 1's budget")
        XCTAssertGreaterThanOrEqual(level.budget, certifiedActions.count, "the witness fits the budget")
        XCTAssertGreaterThanOrEqual(level.stars.count, 2, "the opening choice names two stars of the level")
        for link in pinnedLinks {
            XCTAssertEqual(link.count, 2, "a link is two stars \(link)")
            for star in link {
                XCTAssertTrue((0..<level.stars.count).contains(star), "star on the level \(link)")
                XCTAssertTrue(AcousticConstellatorExperienceCore.starRange.contains(star), "star in range \(link)")
            }
        }

        // The panel's opening choice as the presenter's mirror sets it on a new level: star 0 and partner 1.
        let coreChoice: [Int] = [AcousticConstellatorExperienceCore.openingStar,
                                 AcousticConstellatorExperienceCore.openingPartner]
        XCTAssertEqual(coreChoice, pinnedOpeningChoice, "the opening choice")
        for star in pinnedOpeningChoice {
            XCTAssertTrue((0..<level.stars.count).contains(star), "opening choice on the level \(star)")
        }
        let opening = try AcousticConstellatorExperienceCore.opening(number: 1)
        XCTAssertEqual(opening.play.actionsLeft, pinnedBudget, "the opening's actions left")
        XCTAssertEqual(opening.play.level.id, level.id, "the opening plays certified level 1")
        XCTAssertEqual(opening.play.stage, AcousticConstellatorStage.playing, "the opening accepts actions")
        XCTAssertEqual(AcousticConstellatorExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
    }

    // MARK: Moonlit Mechanism in the app (feature 439, R02-G14-09; T-R02G1409-005, FR-R02G1409-003, 006; SC-R02G1409-002)

    /// Moonlit Mechanism's registration: a candidate until X-R02-G14.
    private func moonlitMechanismRegistration() throws -> ExperienceRegistration {
        let id = try ExperienceID(MoonlitMechanismExperienceCore.experienceID)
        return try XCTUnwrap(ExperienceRegistry.candidates.first { $0.id == id },
                             "Moonlit Mechanism is a candidate")
    }

    /// FR-R02G1409-003: the snapshot is schema 3 and the stored schema-1 and schema-2 examples restore to their digests
    /// through the migrations (the app's migration check, which also reports a version without a stored example).
    func testTheMoonlitMechanismRegistrationRestoresItsStoredExamples() async throws {
        let registration = try moonlitMechanismRegistration()
        XCTAssertEqual(MoonlitMechanismExperienceCore.schemaVersion, 3)
        let one = try XCTUnwrap(MoonlitMechanismExperienceCore.schemaOneExample(), "schema-1 example")
        let two = try XCTUnwrap(MoonlitMechanismExperienceCore.schemaTwoExample(), "schema-2 example")
        let versions: [Int] = [one.version, two.version]
        XCTAssertEqual(versions, [1, 2])
        XCTAssertNotEqual(one.expectedDigest, two.expectedDigest)
        let problems: [String] = await registration.migrationProblems()
        XCTAssertEqual(problems, [], "\(registration.id)")
    }

    /// FR-R02G1409-006: without `-vcCandidates` Moonlit Mechanism is a candidate only: in `candidates`, outside `all`,
    /// listed in the bundled catalog as not available, without a tile and not opened.
    func testMoonlitMechanismIsACandidateAndNotAvailableWithoutTheCandidatesArgument() async throws {
        let id = try ExperienceID(MoonlitMechanismExperienceCore.experienceID)
        XCTAssertEqual(id.rawValue, "r02-g14.moonlit-mechanism")
        XCTAssertTrue(ExperienceRegistry.candidates.map(\.id).contains(id))
        XCTAssertFalse(ExperienceRegistry.all.map(\.id).contains(id))
        let categories = try CategoryList(data: bundled("categories"))
        let manifest = try CatalogManifest(data: bundled("experiences"), categories: categories)
        XCTAssertTrue(manifest.experiences.contains { $0.id == id }, "a catalog id")
        XCTAssertFalse(manifest.available.contains { $0.id == id }, "not available")
        let storage = try TestStorage(self)
        let model = AppModel(environment: storage.environment(catalog: try bundled("experiences"),
                                                              categories: try bundled("categories"),
                                                              registry: ExperienceRegistry.all))
        XCTAssertFalse(model.shown.map(\.id).contains(id), "no tile")
        let opened = await model.open(id)
        XCTAssertFalse(opened)
        XCTAssertNil(model.session.experience)
    }

    /// FR-R02G1409-003, SC-R02G1409-002: with `-vcCandidates` Moonlit Mechanism is shown, opens through the registry and
    /// engine with seed 0 (level 1), and level 1 is won by its certified actions
    /// (`MoonlitMechanismExperienceCore.certifiedActions(1)`) sent as `handle.turn [step]`, `gear.reseat [gear, step]`,
    /// `lamp.step [step]` and `machine.run` with three stars (the opening play is already past the kernel's tutorial
    /// stage; the tutorial step is presentation and blocks no action, so no `tutorial.dismiss` is needed); the win opens
    /// level 2 and `level.next` plays it.
    func testMoonlitMechanismOpensAsACandidateAndLevelOneIsWonByItsCertifiedActions() async throws {
        let registration = try moonlitMechanismRegistration()
        let id = registration.id
        let storage = try TestStorage(self)
        let base = try storage.environment(catalog: bundled("experiences"), categories: bundled("categories"),
                                           registry: ExperienceRegistry.all,
                                           arguments: [DebugLaunch.candidatesArgument])
        let environment = DebugLaunch.environment(base: base, candidates: [registration])
        XCTAssertTrue(environment.registry.map(\.id).contains(id))
        XCTAssertEqual(environment.registry.filter { $0.id == id }.count, 1, "registered once")
        let categories = try CategoryList(data: try XCTUnwrap(environment.categoriesData))
        let manifest = try CatalogManifest(data: try XCTUnwrap(environment.catalogData), categories: categories)
        XCTAssertTrue(manifest.available.contains { $0.id == id }, "available with the candidates argument")
        let model = AppModel(environment: environment)
        XCTAssertTrue(model.shown.map(\.id).contains(id), "the launcher shows the candidate")
        let controls = registration.controls.map(\.id)
        for control in ["handle.turn", "gear.reseat", "lamp.step", "machine.run", "play.undo", "play.redo",
                        "level.next", "frame.show", "tutorial.dismiss", "replay.start"] {
            XCTAssertTrue(controls.contains(control), control)
        }
        XCTAssertEqual(registration.openingSeed, 0)
        XCTAssertEqual(MoonlitMechanismExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")

        var engine = ExperienceEngine<MoonlitMechanismExperienceCore>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        XCTAssertNil(engine.outcome)
        XCTAssertEqual(engine.core?.levelNumber, 1)
        XCTAssertEqual(engine.core?.play.stage, MoonlitMechanismStage.playing, "the opening play accepts actions")
        let actions: [MoonlitMechanismAction] = MoonlitMechanismExperienceCore.certifiedActions(1)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            switch action {
            case .turn(let step):
                let values: [Double] = [Double(step)]
                XCTAssertEqual(engine.handle(control: "handle.turn", values: values), .accepted, "turn \(values)")
            case .reseat(let gear, let step):
                let values: [Double] = [Double(gear), Double(step)]
                XCTAssertEqual(engine.handle(control: "gear.reseat", values: values), .accepted, "reseat \(values)")
            case .lamp(let step):
                let values: [Double] = [Double(step)]
                XCTAssertEqual(engine.handle(control: "lamp.step", values: values), .accepted, "lamp \(values)")
            case .run:
                XCTAssertEqual(engine.handle(control: "machine.run"), .accepted, "run")
            }
        }
        XCTAssertEqual(engine.outcome?.code, MoonlitMechanismExperienceCore.wonCode)
        XCTAssertEqual(MoonlitMechanismExperienceCore.wonCode, "won")
        XCTAssertEqual(engine.core?.play.stage, MoonlitMechanismStage.won)
        XCTAssertEqual(engine.core?.progress.solved[1]?.stars, 3, "the certified actions earn three stars")
        XCTAssertEqual(engine.core?.progress.solved[1]?.verified, true, "the win is recorded with its trace")
        XCTAssertEqual(engine.core?.progress.isOpen(2), true, "the win opens level 2")
        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        XCTAssertEqual(engine.core?.levelNumber, 2)
        XCTAssertNil(engine.outcome, "level 2 is being played")
    }

    /// The convergence lesson of feature 319: the interface tests pin level 1 in `MM` (their own literals in
    /// Tests/UI/MoonlitMechanism/MMSupport.swift, which this target cannot import); the same literals equal the Core's
    /// certified level 1: one handle turn (+1), one lamp step (−1), then the run (a kind with its step; 0 for the run);
    /// the budget is 9; no gear chooser has to move; the lamp step stays on the level's heights. Seed 0 opens level 1.
    func testMoonlitMechanismLevelOnePinsInMMEqualTheCore() throws {
        // The same literals as `MM.levelOneActions` and `MM.levelOneBudget` in MMSupport.swift.
        let levelOneActions: [(kind: String, value: Int)] = [("turn", 1), ("lamp", -1), ("run", 0)]
        let levelOneBudget = 9

        let certifiedActions: [MoonlitMechanismAction] = MoonlitMechanismExperienceCore.certifiedActions(1)
        XCTAssertEqual(certifiedActions, [.turn(1), .lamp(-1), .run], "level 1's certified actions")
        var coreKinds: [String] = []
        var coreValues: [Int] = []
        for action in certifiedActions {
            switch action {
            case .turn(let step):
                coreKinds.append("turn")
                coreValues.append(step)
            case .reseat(_, let step):
                coreKinds.append("reseat")
                coreValues.append(step)
            case .lamp(let step):
                coreKinds.append("lamp")
                coreValues.append(step)
            case .run:
                coreKinds.append("run")
                coreValues.append(0)
            }
        }
        let pinnedKinds: [String] = levelOneActions.map { $0.kind }
        let pinnedValues: [Int] = levelOneActions.map { $0.value }
        XCTAssertEqual(coreKinds, pinnedKinds, "level 1 certified action kinds")
        XCTAssertEqual(coreValues, pinnedValues, "level 1 certified action steps")
        XCTAssertFalse(coreKinds.contains("reseat"), "no gear chooser has to move on level 1")

        let certified = try MoonlitMechanismExperienceCore.generated(number: 1)
        let level: MoonlitMechanismLevel = certified.level
        XCTAssertEqual(certified.actions, certifiedActions, "the certified witness is the generated level's")
        XCTAssertEqual(level.budget, levelOneBudget, "level 1's budget")
        XCTAssertGreaterThanOrEqual(level.budget, certifiedActions.count, "the witness fits the budget")
        var height: Int = level.startingHeight
        for action in levelOneActions where action.kind == "lamp" {
            XCTAssertTrue(MoonlitMechanismExperienceCore.stepRange.contains(action.value), "a lamp step \(action)")
            height += action.value
            XCTAssertTrue((0..<level.lampHeights).contains(height), "the lamp stays on the level's heights \(height)")
        }
        for action in levelOneActions where action.kind == "turn" {
            XCTAssertTrue(MoonlitMechanismExperienceCore.stepRange.contains(action.value), "a turn step \(action)")
            XCTAssertNotEqual(action.value, 0, "a turn of 0 is refused")
        }

        let opening = try MoonlitMechanismExperienceCore.opening(number: 1)
        XCTAssertEqual(opening.play.actionsLeft, levelOneBudget, "the opening's actions left")
        XCTAssertEqual(opening.play.level.id, level.id, "the opening plays certified level 1")
        XCTAssertEqual(opening.play.stage, MoonlitMechanismStage.playing, "the opening accepts actions")
        XCTAssertEqual(opening.certifiedActions, certifiedActions.count, "stars are counted against the witness")
        XCTAssertEqual(MoonlitMechanismExperienceCore.levelNumber(forSeed: 0), 1, "seed 0 opens level 1")
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
