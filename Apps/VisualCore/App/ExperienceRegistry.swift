// ExperienceRegistry — feature 190 T-U04-011 (FR-U04-010, FR-U04-011; research R2). The one explicit list of the
// experiences the app can open: for each an id and a factory. It is empty in this feature, because no experience
// is integrated yet; an integration adds its line here and nowhere else.
import FluidArtPlaygroundExperience
import FractalExplorerExperience
import GenerativeArtStudioExperience
import ParticleUniverseExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

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
    /// 2026-11-13 after UA-F07).
    static let all: [ExperienceRegistration] = [generativeArtStudio, fluidArtPlayground, fractalExplorer].compactMap { $0 }

    /// The adopted experiences before their X gate (feature 193, FR-U07-021; clarification 4), in catalog order:
    /// each carries its scenario manifest, so that the verification runner can open it, but it stays unavailable
    /// in the catalog and outside `all`. Debug builds show them with `-vcCandidates`. Recording an experience's X
    /// gate moves its registration from here to `all`.
    static let candidates: [ExperienceRegistration] = [particleUniverse].compactMap { $0 }

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
