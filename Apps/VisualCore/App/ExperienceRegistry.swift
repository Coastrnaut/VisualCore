// ExperienceRegistry — feature 190 T-U04-011 (FR-U04-010, FR-U04-011; research R2). The one explicit list of the
// experiences the app can open: for each an id and a factory. It is empty in this feature, because no experience
// is integrated yet; an integration adds its line here and nowhere else.
import AudioOdysseyExperience
import FluidArtPlaygroundExperience
import FractalExplorerExperience
import GenerativeArtStudioExperience
import InfiniteGeometryExperience
import ParticleUniverseExperience
import VisualCoreMusicLabExperience
import OscilloscopeStudioExperience
import DigitalAquariumExperience
import NeonArcadeExperience
import PhysicsPlaygroundExperience
import TinyWorldsExperience
import LightMazeExperience
import SolarSystemExplorerExperience
import MolecularExplorerExperience
import SimulationLabExperience
import InteractiveAnatomyExperience
import AmbientClockExperience
import LivingWallpapersExperience
import DigitalZenGardenExperience
import AuroraExperience
import ShaderStudioExperience
import VisualProgrammingLabExperience
import GraphicsBenchmarkLabExperience
import EffectsComposerExperience
import AuroraLoomCore
import AuroraLoomExperience
import LissajousLabyrinthCore
import LissajousLabyrinthExperience
import WaveKnotKeeperCore
import WaveKnotKeeperExperience
import ColorfallCanyonsCore
import ColorfallCanyonsExperience
import ChronoConstellatorCore
import ChronoConstellatorExperience
import AmethystEscapeCore
import AmethystEscapeExperience
import FacetedForgeCore
import FacetedForgeExperience
import HueCompassCore
import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI
import enum VisualCoreSimulation.ColorVisionChoice

/// What the shell hands to an experience when it opens it (US5, acceptance scenario 1): the person's stored
/// accessibility choices and the experience's own storage. `.system` means "follow the device setting"; the
/// experience combines the choice with the system value. A change in the settings reaches an experience the next
/// time it opens: the settings route closes an open experience, so no open experience holds an old value.
struct ExperienceLaunch: Sendable {
    /// The storage of this experience and of no other (feature 191, FR-U05-001): named files in its own folder
    /// and named values under its own defaults prefix. An experience stores nothing by any other way.
    var storage: ExperienceStorage
    /// The stored reduce-motion choice.
    var reduceMotion: AccessibilityChoice = .system
    /// The stored reduce-flashing choice.
    var reduceFlashing: AccessibilityChoice = .system
    /// The stored colour-vision choice (feature 210 T-R02F10-008); `.standard` keeps the experience's own colours,
    /// another choice asks it to draw colour-coded content with that preset (`ColorVisionChoice.palette`).
    var colorVision: ColorVisionChoice = .standard
}

/// One registered experience: its id, the factory the session calls on the main actor, and the check of its
/// stored examples of earlier schema versions.
struct ExperienceRegistration: Sendable {
    /// The id of the experience, as the catalog writes it.
    let id: ExperienceID
    /// Builds the experience with what the shell hands over. Called once per open.
    let make: @MainActor (ExperienceLaunch) -> any Experience
    /// Runs the migration check of the experience's core (feature 191, FR-U05-051): a text for every earlier
    /// schema version without a stored example and for every example that does not restore to its digest.
    let migrationProblems: @Sendable () async -> [String]
    /// The controls of the experience's core, for checking its scenario manifest.
    let controls: [ExperienceControl]
    /// The seed a fresh open passes instead of the id's stable seed (feature 309, R02-G01-09): the round-two puzzles
    /// map a seed to their opening level (`seed % 100 + 1`), so a player starts at level 1 with seed 0. Nil keeps the
    /// stable seed of ``AppModel/seed(for:)``.
    var openingSeed: UInt64?
    #if DEBUG || VISUALCORE_AUTOMATION
    /// The scenarios the verification runner plays for this experience (feature 195); nil when it has none yet,
    /// so that it cannot be verified.
    var scenarioManifest: ScenarioManifest?
    #endif

    /// Registers the experience `id` whose state is the core `core`. `examples` holds one stored snapshot of
    /// every schema version below the core's current one; a core with schema 1 needs none.
    init<Core: ExperienceCore>(id: ExperienceID, core: Core.Type, examples: [MigrationExample] = [],
                               make: @escaping @MainActor (ExperienceLaunch) -> any Experience) {
        self.id = id
        self.make = make
        controls = Core.controls
        migrationProblems = { await SnapshotMigrationCheck.problems(for: core, id: id, examples: examples) }
    }
}

/// The explicit list of registered experiences.
enum ExperienceRegistry {
    /// Every registered experience, in catalog order: those whose X gate is pass (X-A01, X-A02 and X-A03, recorded
    /// 2026-11-13 after UA-F07; X-A04 recorded 2026-11-13 after A04-P06; X-A05 recorded 2026-11-14 after A05-P06; X-A06 recorded 2026-11-14 after A06-P06; X-A07 recorded 2026-11-14 after A07-P06; X-A08 recorded 2026-11-14 after A08-P06; X-A09 recorded 2026-11-14 after A09-P06; X-A10 recorded 2026-11-15 after A10-P06; X-A11 recorded 2026-11-15 after A11-P06; X-A12 recorded 2026-11-15 after A12-P06; X-A13 recorded 2026-11-15 after A13-P06; X-A14 recorded 2026-11-15 after A14-P06; X-A15 recorded 2026-11-16 after A15-P06; X-A16 recorded 2026-11-16 after A16-P06; X-A17 recorded 2026-11-16 after A17-P06; X-A18 recorded 2026-11-16 after A18-P06; X-A19 recorded 2026-11-17 after A19-P06; X-A20 recorded 2026-11-17 after A20-P06; X-A21 recorded 2026-11-17 after A21-P06; X-A22 recorded 2026-11-18 after A22-P06; X-A23 recorded 2026-11-19 after A23-P06; X-A24 recorded 2026-11-19 after A24-P06; X-A25 recorded 2026-11-19 after A25-P06; X-R02-G01 recorded 2026-11-21 after R02-G01-10; X-R02-G02 recorded 2026-11-21 after R02-G02-10; X-R02-G03 recorded 2026-11-21 after R02-G03-10; X-R02-G04 recorded 2026-11-21 after R02-G04-10; X-R02-G05 recorded 2026-11-21 after R02-G05-10; X-R02-G06 recorded 2026-11-22 after R02-G06-10; X-R02-G07 recorded 2026-11-22 after R02-G07-10; X-R02-G08 recorded 2026-11-22 after R02-G08-10).
    static let all: [ExperienceRegistration] = [generativeArtStudio, fluidArtPlayground, fractalExplorer,
                                                particleUniverse, infiniteGeometry,
                                                visualCoreMusicLab, audioOdyssey,
                                                oscilloscopeStudio, digitalAquarium, neonArcade,
                                                physicsPlayground, tinyWorlds, lightMaze,
                                                solarSystemExplorer, molecularExplorer, simulationLab,
                                                interactiveAnatomy, ambientClock, livingWallpapers,
                                                digitalZenGarden, aurora, shaderStudio,
                                                visualProgrammingLab, graphicsBenchmarkLab, effectsComposer,
                                                auroraLoom, lissajousLabyrinth, waveKnotKeeper,
                                                hueCompass, colorfallCanyons, chronoConstellator,
                                                amethystEscape, facetedForge].compactMap { $0 }

    /// The adopted experiences before their X gate (feature 193, FR-U07-021; clarification 4), in catalog order:
    /// each carries its scenario manifest, so that the verification runner can open it, but it stays unavailable
    /// in the catalog and outside `all`. Debug builds show them with `-vcCandidates`. Recording an experience's X
    /// gate moves its registration from here to `all`.
    static let candidates: [ExperienceRegistration] = []

    /// R02-G08 Faceted Forge (features 371–380, R02-G08-01…10): integrated at X-R02-G08 (2026-11-22). Snapshot schema 3 (feature 377),
    /// so the schema-1 and schema-2 examples are stored (feature 379, R02-G08-09).
    fileprivate static var facetedForge: ExperienceRegistration? {
        guard let id = FacetedForgeExperience.id else { return nil }
        let examples = [FacetedForgeExperienceCore.schemaOneExample(),
                        FacetedForgeExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: FacetedForgeExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return FacetedForgeExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1, as for the other round-two puzzles.
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = FacetedForgeExperienceCore.manifest(for: id)
        #endif
        return registration
    }

    /// R02-G07 Amethyst Escape (features 361–370, R02-G07-01…10): integrated at X-R02-G07 (2026-11-22). Snapshot schema 3 (feature 367),
    /// so the schema-1 and schema-2 examples are stored (feature 369, R02-G07-09).
    fileprivate static var amethystEscape: ExperienceRegistration? {
        guard let id = AmethystEscapeExperience.id else { return nil }
        let examples = [AmethystEscapeExperienceCore.schemaOneExample(),
                        AmethystEscapeExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: AmethystEscapeExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return AmethystEscapeExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1, as for the other round-two puzzles.
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = AmethystEscapeExperienceCore.manifest(for: id)
        #endif
        return registration
    }

    /// R02-G06 Chrono Constellator (features 351–360, R02-G06-01…10): integrated at X-R02-G06 (2026-11-22). Snapshot schema 3
    /// (feature 357), so the schema-1 and schema-2 examples are stored (feature 359, R02-G06-09).
    fileprivate static var chronoConstellator: ExperienceRegistration? {
        guard let id = ChronoConstellatorExperience.id else { return nil }
        let examples = [ChronoConstellatorExperienceCore.schemaOneExample(),
                        ChronoConstellatorExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: ChronoConstellatorExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return ChronoConstellatorExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1, as for the other round-two puzzles.
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = ChronoConstellatorExperienceCore.manifest(for: id)
        #endif
        return registration
    }

    /// R02-G05 Colorfall Canyons (features 341–350, R02-G05-01…10): integrated at X-R02-G05 (2026-11-21). Snapshot schema 3
    /// (feature 347), so the schema-1 and schema-2 examples are stored (feature 349, R02-G05-09).
    fileprivate static var colorfallCanyons: ExperienceRegistration? {
        guard let id = ColorfallCanyonsExperience.id else { return nil }
        let examples = [ColorfallCanyonsExperienceCore.schemaOneExample(),
                        ColorfallCanyonsExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: ColorfallCanyonsExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return ColorfallCanyonsExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1, as for the other round-two puzzles.
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = ColorfallCanyonsExperienceCore.manifest(for: id)
        #endif
        return registration
    }

    /// R02-G04 Hue Compass (features 331–340, R02-G04-01…10): integrated at X-R02-G04 (2026-11-21). Snapshot schema 3 (feature 337), so
    /// the schema-1 and schema-2 examples are stored (feature 339, R02-G04-09).
    fileprivate static var hueCompass: ExperienceRegistration? {
        guard let id = HueCompassExperience.id else { return nil }
        let examples = [HueCompassExperienceCore.schemaOneExample(),
                        HueCompassExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: HueCompassExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return HueCompassExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1, as for the other round-two puzzles.
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = HueCompassExperienceCore.manifest(for: id)
        #endif
        return registration
    }

    /// A01 Generative Art Studio (feature 193, US1).
    private static var generativeArtStudio: ExperienceRegistration? {
        guard let id = GenerativeArtExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: GenerativeArtCore.self) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return GenerativeArtExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = GenerativeArtCore.manifest(for: id)
        #endif
        return registration
    }
}

extension ExperienceRegistry {
    /// A02 Fluid Art Playground (feature 193, US5).
    fileprivate static var fluidArtPlayground: ExperienceRegistration? {
        guard let id = FluidArtExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: FluidArtCore.self) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return FluidArtExperience.make(id: id,
                                           reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = FluidArtCore.manifest(for: id)
        #endif
        return registration
    }
}

extension ExperienceRegistry {
    /// A03 Fractal Explorer (feature 193, US3).
    fileprivate static var fractalExplorer: ExperienceRegistration? {
        guard let id = FractalExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: FractalCore.self) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return FractalExperience.make(id: id, storage: launch.storage,
                                          reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = FractalCore.manifest(for: id)
        #endif
        return registration
    }
}

extension ExperienceRegistry {
    /// A04 Particle Universe (feature 193, US4). Its X gate waits for the legacy phases A04-P04 to P06.
    fileprivate static var particleUniverse: ExperienceRegistration? {
        guard let id = ParticleExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: ParticleCore.self) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return ParticleExperience.make(id: id, storage: launch.storage,
                                           reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                           reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = ParticleCore.manifest(for: id)
        #endif
        return registration
    }
    /// A05 Infinite Geometry (features 040–042, A05-P01…P03): integrated at X-A05 (2026-11-14).
    fileprivate static var infiniteGeometry: ExperienceRegistration? {
        guard let id = InfiniteGeometryExperience.id else { return nil }
        // Schema 2 (feature 041, A05-P02) adds the camera and schema 3 (feature 042, A05-P03) its target and field of
        // view; the stored schema-1 and schema-2 examples prove the migrations.
        let examples = [GeometryCore.schemaOneExample(), GeometryCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: GeometryCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return InfiniteGeometryExperience.make(id: id, storage: launch.storage,
                                                   reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                                   reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = GeometryCore.manifest(for: id)
        #endif
        return registration
    }
    /// A06 VisualCore Music Lab (features 047–052, A06-P01…P06): integrated at X-A06 (2026-11-14).
    fileprivate static var visualCoreMusicLab: ExperienceRegistration? {
        guard let id = VisualCoreMusicLabExperience.id else { return nil }
        // Schema 2 (feature 049) adds the scene and mappings and schema 3 (feature 051) the palette; the stored
        // schema-1 and schema-2 examples prove the migrations.
        let examples = [MusicLabCore.schemaOneExample(), MusicLabCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: MusicLabCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return VisualCoreMusicLabExperience.make(id: id, storage: launch.storage,
                                                     reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                                     reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = MusicLabCore.manifest(for: id)
        #endif
        return registration
    }
    /// A07 Audio Odyssey (features 053–059, A07-P00…P06): integrated at X-A07 (2026-11-14).
    fileprivate static var audioOdyssey: ExperienceRegistration? {
        guard let id = AudioOdysseyExperience.id else { return nil }
        // Schema 2 (feature 055) adds the sound source and schema 3 (feature 056) speed, easing, calm motion and mappings;
        // the stored schema-1 and schema-2 examples prove the migrations.
        let examples = [OdysseyCore.schemaOneExample(), OdysseyCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: OdysseyCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return AudioOdysseyExperience.make(id: id, storage: launch.storage,
                                               reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                               reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = OdysseyCore.manifest(for: id)
        #endif
        return registration
    }
    /// A08 Oscilloscope Studio (features 060–066, A08-P00…P06): integrated at X-A08 (2026-11-14).
    fileprivate static var oscilloscopeStudio: ExperienceRegistration? {
        guard let id = OscilloscopeStudioExperience.id else { return nil }
        // Schema 2 (feature 062) adds the display mode, schema 3 (feature 064) the freeze and the cursors; the stored
        // schema-1 and schema-2 examples prove the migrations.
        let examples = [ScopeCore.schemaOneExample(), ScopeCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: ScopeCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return OscilloscopeStudioExperience.make(id: id, storage: launch.storage,
                                                     reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                                     reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = ScopeCore.manifest(for: id)
        #endif
        return registration
    }
    /// A09 Digital Aquarium (features 067–073, A09-P00…P06): integrated at X-A09 (2026-11-14).
    fileprivate static var digitalAquarium: ExperienceRegistration? {
        guard let id = DigitalAquariumExperience.id else { return nil }
        // Schema 2 (feature 069) adds the fish turn and the decor transforms, schema 3 (feature 070) the pellets and the
        // chosen decoration kind, schema 4 (feature 072) the ambient choice; the stored schema-1…3 examples prove the
        // migrations.
        let examples = [AquariumCore.schemaOneExample(), AquariumCore.schemaTwoExample(),
                        AquariumCore.schemaThreeExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: AquariumCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return DigitalAquariumExperience.make(id: id, storage: launch.storage,
                                                  reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                                  reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = AquariumCore.manifest(for: id)
        #endif
        return registration
    }

    /// A10 Neon Arcade (features 074–080, A10-P00…P06): integrated at X-A10 (2026-11-15).
    fileprivate static var neonArcade: ExperienceRegistration? {
        guard let id = NeonArcadeExperience.id else { return nil }
        // Schema 2 (feature 076, A10-P02) adds the waves, schema 3 (feature 077, A10-P03) the screen and the sound and
        // haptics settings, schema 4 (feature 078, A10-P04) the sensitivity and the run number; the stored schema-1…3
        // examples prove the migrations.
        let examples = [ArcadeCore.schemaOneExample(), ArcadeCore.schemaTwoExample(),
                        ArcadeCore.schemaThreeExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: ArcadeCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return NeonArcadeExperience.make(id: id, storage: launch.storage,
                                             reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                             reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = ArcadeCore.manifest(for: id)
        #endif
        return registration
    }

    /// A11 Physics Playground (features 081–087, A11-P00…P06): integrated at X-A11 (2026-11-15).
    fileprivate static var physicsPlayground: ExperienceRegistration? {
        guard let id = PhysicsPlaygroundExperience.id else { return nil }
        // Schema 2 (feature 083, A11-P02) adds springs, force levels and the contact cache, schema 3 (feature 084,
        // A11-P03) pins, selection, the grab and the overlay choices, schema 4 (feature 085, A11-P04) the opened
        // experiment and tutorial progress; the stored schema-1 to schema-3 examples prove the migrations.
        // Schema 5 (feature 086, A11-P05) adds sleep to the world; the schema-4 example proves that step.
        let examples = [PlaygroundCore.schemaOneExample(), PlaygroundCore.schemaTwoExample(),
                        PlaygroundCore.schemaThreeExample(), PlaygroundCore.schemaFourExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: PlaygroundCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return PhysicsPlaygroundExperience.make(id: id, storage: launch.storage,
                                                    reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                                    reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = PlaygroundCore.manifest(for: id)
        #endif
        return registration
    }

    /// A12 Tiny Worlds (features 088–094, A12-P00…P06): integrated at X-A12 (2026-11-15).
    fileprivate static var tinyWorlds: ExperienceRegistration? {
        guard let id = TinyWorldsExperience.id else { return nil }
        // Schema 2 (feature 091, A12-P03) adds props, the selection and the light; the stored schema-1 example proves
        // the migration.
        let examples = [WorldsCore.schemaOneExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: WorldsCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return TinyWorldsExperience.make(id: id, storage: launch.storage,
                                             reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                             reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = WorldsCore.manifest(for: id)
        #endif
        return registration
    }

    /// A13 Light Maze (features 095–101, A13-P00…P06): integrated at X-A13 (2026-11-15).
    fileprivate static var lightMaze: ExperienceRegistration? {
        guard let id = LightMazeExperience.id else { return nil }
        let examples = [MazeCore.schemaOneExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: MazeCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return LightMazeExperience.make(id: id, storage: launch.storage,
                                            reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                                            reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = MazeCore.manifest(for: id)
        #endif
        return registration
    }

    /// A14 Solar System Explorer (features 102–108, A14-P00…P06): integrated at X-A14 (2026-11-15).
    fileprivate static var solarSystemExplorer: ExperienceRegistration? {
        guard let id = SolarSystemExplorerExperience.id else { return nil }
        // Schemas 2–4 (A14-P02 to A14-P04) add the date and camera, the scale mode, and the clock and tour; the stored
        // schema 1–3 examples prove the migrations (A14-P06, T-A14-606).
        let examples = [SolarCore.schemaOneExample(), SolarCore.schemaTwoExample(),
                        SolarCore.schemaThreeExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: SolarCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return SolarSystemExplorerExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = SolarCore.manifest(for: id)
        #endif
        return registration
    }

    /// A15 Molecular Explorer (features 109–115, A15-P00…P06): integrated at X-A15 (2026-11-16).
    fileprivate static var molecularExplorer: ExperienceRegistration? {
        guard let id = MolecularExplorerExperience.id else { return nil }
        // Schema 4 (feature 114) holds the imported molecule; the stored schema-1 to schema-3 examples (feature 115,
        // A15-P06) prove the migrations.
        let examples = [MoleculeCore.schemaOneExample(), MoleculeCore.schemaTwoExample(),
                        MoleculeCore.schemaThreeExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: MoleculeCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return MolecularExplorerExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = MoleculeCore.manifest(for: id)
        #endif
        return registration
    }

    /// A16 Simulation Lab (features 116–122, A16-P00…P06): integrated at X-A16 (2026-11-16).
    fileprivate static var simulationLab: ExperienceRegistration? {
        guard let id = SimulationLabExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: SimulationCore.self) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return SimulationLabExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = SimulationCore.manifest(for: id)
        #endif
        return registration
    }

    /// A17 Interactive Anatomy (features 123–129, A17-P00…P06): integrated at X-A17 (2026-11-16).
    fileprivate static var interactiveAnatomy: ExperienceRegistration? {
        guard let id = InteractiveAnatomyExperience.id else { return nil }
        // The stored schema-1 example proves the view migration of A17-P03.
        let examples = [AnatomyCore.schemaOneExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: AnatomyCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return InteractiveAnatomyExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = AnatomyCore.manifest(for: id)
        #endif
        return registration
    }

    /// A18 Ambient Clock (features 130–136, A18-P00…P06): integrated at X-A18 (2026-11-16).
    fileprivate static var ambientClock: ExperienceRegistration? {
        guard let id = AmbientClockExperience.id else { return nil }
        // Schema 3 (feature 134, A18-P04) adds night mode, reduce motion and keep-awake; both earlier examples are stored.
        let examples = [AmbientCore.schemaOneExample(), AmbientCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: AmbientCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return AmbientClockExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = AmbientCore.manifest(for: id)
        #endif
        return registration
    }

    /// A19 Living Wallpapers (features 137–143, A19-P00…P06): integrated at X-A19 (2026-11-17). Snapshot schema 2 (feature 140
    /// adds editable colours); the stored schema-1 example proves the migration.
    fileprivate static var livingWallpapers: ExperienceRegistration? {
        guard let id = LivingWallpapersExperience.id else { return nil }
        let examples = [WallpaperCore.schemaOneExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: WallpaperCore.self, examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return LivingWallpapersExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = WallpaperCore.manifest(for: id)
        #endif
        return registration
    }

    /// A20 Digital Zen Garden (features 144–150, A20-P00…P06): integrated at X-A20 (2026-11-17). Snapshot schema 1, so no earlier
    /// example is stored yet.
    fileprivate static var digitalZenGarden: ExperienceRegistration? {
        guard let id = DigitalZenGardenExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: GardenCore.self) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return DigitalZenGardenExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = GardenCore.manifest(for: id)
        #endif
        return registration
    }

    /// A21 Aurora (features 151–157, A21-P00…P06): integrated at X-A21 (2026-11-17). Snapshot schema 1, so no earlier
    /// example is stored yet.
    fileprivate static var aurora: ExperienceRegistration? {
        guard let id = AuroraExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: SkyCore.self) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return AuroraExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = SkyCore.manifest(for: id)
        #endif
        return registration
    }

    /// A22 Shader Studio (features 158–164, A22-P00…P06): integrated at X-A22 (2026-11-18). Snapshot schema 1, so no
    /// earlier example is stored yet.
    fileprivate static var shaderStudio: ExperienceRegistration? {
        guard let id = ShaderStudioExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: StudioCore.self) { launch in
            ShaderStudioExperience.make(id: id, storage: launch.storage)
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = StudioCore.manifest(for: id)
        #endif
        return registration
    }

    /// A23 Visual Programming Lab (features 165–171, A23-P00…P06): integrated at X-A23 (2026-11-19). Snapshot schema 1,
    /// so no earlier example is stored yet.
    fileprivate static var visualProgrammingLab: ExperienceRegistration? {
        guard let id = VisualProgrammingLabExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: LabCore.self) { launch in
            VisualProgrammingLabExperience.make(id: id, storage: launch.storage)
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = LabCore.manifest(for: id)
        #endif
        return registration
    }

    /// A24 Graphics Benchmark Lab (features 172–178, A24-P00…P06): integrated at X-A24 (2026-11-19). Snapshot schema
    /// 1, so no earlier example is stored yet.
    fileprivate static var graphicsBenchmarkLab: ExperienceRegistration? {
        guard let id = GraphicsBenchmarkLabExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: BenchCore.self) { launch in
            GraphicsBenchmarkLabExperience.make(id: id, storage: launch.storage)
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = BenchCore.manifest(for: id)
        #endif
        return registration
    }

    /// A25 Effects Composer (features 179–185, A25-P00…P06): integrated at X-A25 (2026-11-19). Snapshot schema 1, so
    /// no earlier example is stored yet.
    fileprivate static var effectsComposer: ExperienceRegistration? {
        guard let id = EffectsComposerExperience.id else { return nil }
        var registration = ExperienceRegistration(id: id, core: ComposerCore.self) { launch in
            EffectsComposerExperience.make(id: id, storage: launch.storage)
        }
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = ComposerCore.manifest(for: id)
        #endif
        return registration
    }

    /// R02-G01 Aurora Loom (features 301–310, R02-G01-01…10): integrated at X-R02-G01 (2026-11-21). Snapshot schema 3 (feature 307,
    /// R02-G01-07): the stored schema-1 and schema-2 examples prove the migrations (feature 309, R02-G01-09).
    fileprivate static var auroraLoom: ExperienceRegistration? {
        guard let id = AuroraLoomExperience.id else { return nil }
        let examples = [AuroraLoomExperienceCore.schemaOneExample(),
                        AuroraLoomExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: AuroraLoomExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return AuroraLoomExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1 with only level 1 open (feature 309; the stable seed opened level 79).
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = AuroraLoomExperienceCore.manifest(for: id)
        #endif
        return registration
    }

    /// R02-G02 Lissajous Labyrinth (features 311–320, R02-G02-01…10): integrated at X-R02-G02 (2026-11-21). Snapshot schema 3
    /// (feature 317), so the schema-1 and schema-2 examples are stored (feature 319, R02-G02-09).
    fileprivate static var lissajousLabyrinth: ExperienceRegistration? {
        guard let id = LissajousLabyrinthExperience.id else { return nil }
        let examples = [LissajousLabyrinthExperienceCore.schemaOneExample(),
                        LissajousLabyrinthExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: LissajousLabyrinthExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return LissajousLabyrinthExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1 (feature 309; the stable seed opened level 35).
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = LissajousLabyrinthExperienceCore.manifest(for: id)
        #endif
        return registration
    }

    /// R02-G03 Wave Knot Keeper (features 321–330, R02-G03-01…10): integrated at X-R02-G03 (2026-11-21). Snapshot schema 3
    /// (feature 327), so the schema-1 and schema-2 examples are stored (feature 329, R02-G03-09).
    fileprivate static var waveKnotKeeper: ExperienceRegistration? {
        guard let id = WaveKnotKeeperExperience.id else { return nil }
        let examples = [WaveKnotKeeperExperienceCore.schemaOneExample(),
                        WaveKnotKeeperExperienceCore.schemaTwoExample()].compactMap { $0 }
        var registration = ExperienceRegistration(id: id, core: WaveKnotKeeperExperienceCore.self,
                                                  examples: examples) { launch in
            let system = SystemAccessibilityObserver.systemValues()
            return WaveKnotKeeperExperience.make(
                id: id, storage: launch.storage,
                reduceMotion: launch.reduceMotion.resolved(system: system.reduceMotion),
                reduceFlashing: launch.reduceFlashing.resolved(system: system.dimFlashingLights))
        }
        // Seed 0 opens certified level 1, as for the other round-two puzzles.
        registration.openingSeed = 0
        #if DEBUG || VISUALCORE_AUTOMATION
        registration.scenarioManifest = WaveKnotKeeperExperienceCore.manifest(for: id)
        #endif
        return registration
    }
}


extension AccessibilityChoice {
    /// The setting in effect: the system's value for `.system`, else the choice (as VisualCoreSimulation's
    /// `AccessibilityPreferences.resolve` does for the standalone apps).
    func resolved(system: Bool) -> Bool {
        switch self {
        case .system: system
        case .on: true
        case .off: false
        }
    }
}
