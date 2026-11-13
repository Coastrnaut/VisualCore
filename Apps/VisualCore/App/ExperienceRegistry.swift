// ExperienceRegistry — feature 190 T-U04-011 (FR-U04-010, FR-U04-011; research R2). The one explicit list of the
// experiences the app can open: for each an id and a factory. It is empty in this feature, because no experience
// is integrated yet; an integration adds its line here and nowhere else.
import VisualCoreExperience
import VisualCoreExperienceHost

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
    /// Every registered experience, in catalog order. Empty until the first integration.
    static let all: [ExperienceRegistration] = []
}
