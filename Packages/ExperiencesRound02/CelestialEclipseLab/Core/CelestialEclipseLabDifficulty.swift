// CelestialEclipseLabDifficulty — feature 462 (R02-G17-02) T-R02G1702-002 (FR-R02G1702-003; SC-R02G1702-004;
// clarification Q3). The difficulty metrics of a certified Celestial Eclipse Lab level, from the level and the solver's
// actual result: the witness length (phase changes), the bodies, the movable bodies, the target eclipses, the eclipse
// events of the winning timeline, the settings judged at smaller depths and the solver work. Modelled on
// `StarlitCartoucheDifficulty` (feature 452).
import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct CelestialEclipseLabDifficulty: Sendable, Hashable, Codable {
    /// The witness length: the plan's phase changes.
    public let changes: Int
    /// The bodies.
    public let bodies: Int
    /// The movable bodies.
    public let movable: Int
    /// The target eclipses.
    public let targets: Int
    /// The eclipse events of the winning setting's timeline.
    public let events: Int
    /// The settings judged at every depth below the plan's.
    public let settingsSearched: Int
    /// The settings the solver judged.
    public let work: Int

    /// The metrics of the given values.
    public init(changes: Int, bodies: Int, movable: Int, targets: Int, events: Int, settingsSearched: Int,
                work: Int) {
        self.changes = changes
        self.bodies = bodies
        self.movable = movable
        self.targets = targets
        self.events = events
        self.settingsSearched = settingsSearched
        self.work = work
    }

    /// The metrics of `level` certified by `plan`.
    public init(level: CelestialEclipseLabLevel, plan: CelestialEclipseLabPlan) {
        self.init(changes: plan.size, bodies: level.bodies.count,
                  movable: level.bodies.filter { !$0.fixed }.count, targets: level.target.count,
                  events: CelestialEclipseLabSky.intervals(level, phases: plan.phases(from: level)).count,
                  settingsSearched: plan.settingsSearched, work: plan.work)
    }

    /// The shared difficulty of R02-F24: the shortest plan and the work explored.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: changes, explored: work) }
}
