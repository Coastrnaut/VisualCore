// ChronoConstellatorHints — feature 355 (R02-G06-05) T-R02G0605-002 (FR-R02G0605-002, 003; SC-R02G0605-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play and the plain-English explanation
// of a failure. The plan comes from the current state: a current timeline that wins (a replay from tick 0 reaches a win
// tick) is run to its win tick; otherwise after tick 0 the play is rewound; at tick 0 the first hold (star order, then
// start) is removed — a rewind or a release only when the state it leads to has a plan, so a plan exists exactly when
// following it wins; without holds the solver runs on the level with the current phases as its defaults, and its phase
// changes are the plan, accepted only when the edits in use afterwards fit the budget and the resulting timeline wins.
// Hints never change a play, are unlimited and do not affect stars; the hint level is presentation (held by the
// presenter, reset to 1 after any change of the play). A failure is explained from the failing tick: the colliding pair
// and their cell, or every star off its target when time ran out. Integers only; no clock, no random source.

/// One phase change of a plan: star `star` starts at phase `phase`.
public struct ChronoConstellatorPhaseChange: Sendable, Equatable {
    /// The star (0-based index).
    public let star: Int
    /// The new start phase, 0 … L − 1.
    public let phase: Int

    /// A phase change of the given values (not checked).
    public init(star: Int, phase: Int) {
        self.star = star
        self.phase = phase
    }
}

/// The plan of a play from its current state (clarification Q1).
public enum ChronoConstellatorPlan: Sendable, Equatable {
    /// The current timeline wins: replay `ticks` ticks from the current tick to the win tick.
    case run(ticks: Int)
    /// Return to tick 0 to change the timeline.
    case rewind
    /// Remove the hold of star `star` that starts at tick `start`.
    case release(star: Int, start: Int)
    /// Set these start phases, in star order; afterwards the timeline wins within the budget.
    case phases([ChronoConstellatorPhaseChange])
}

/// What a hint suggests (clarification Q1).
public enum ChronoConstellatorHintKind: String, Sendable, Codable {
    /// Change one star's start phase.
    case phase
    /// Remove one hold.
    case release
    /// Rewind to tick 0.
    case rewind
    /// Replay the winning timeline.
    case run
    /// No win is reachable from here (or the play failed): undo, rewind or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct ChronoConstellatorHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names what to do, 2 adds which star, 3 is exact.
    public let level: Int
    /// What the hint suggests.
    public let kind: ChronoConstellatorHintKind
    /// The star to change (`phase`) or whose hold to remove (`release`), 0-based; nil otherwise.
    public let star: Int?
    /// The cell the star starts on at the new phase (`phase`): its loop's cell at that phase; nil otherwise.
    public let cell: Int?
    /// The new start phase (`phase`); nil otherwise.
    public let phase: Int?
    /// The first tick of the hold to remove (`release`); nil otherwise.
    public let start: Int?
    /// The ticks to replay to the win tick from the current tick (`run`), else 0.
    public let ticks: Int
    /// The star's shape name (`phase`, `release`), else empty.
    let shapeName: String
    /// The place of ``cell`` in words, "row r, column c" (`phase`), else empty.
    let place: String
    /// Whether a `stuck` hint is for a failed play.
    let failed: Bool

    /// A hint of the given values (not checked).
    init(level: Int, kind: ChronoConstellatorHintKind, star: Int? = nil, cell: Int? = nil, phase: Int? = nil,
         start: Int? = nil, ticks: Int = 0, shapeName: String = "", place: String = "", failed: Bool = false) {
        self.level = level
        self.kind = kind
        self.star = star
        self.cell = cell
        self.phase = phase
        self.start = start
        self.ticks = ticks
        self.shapeName = shapeName
        self.place = place
        self.failed = failed
    }

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last change, rewind or retry the level."
    /// The text shown when no win is reachable, at every level.
    public static let stuckText: String =
        "No win is reachable from here: undo the last change, rewind or retry the level."
    /// The text of a rewind hint, at every level.
    public static let rewindText: String = "Rewind to tick 0 to change the timeline"

    /// The hint in plain English (clarification Q1), with k the 1-based star number, (shape) its shape name, r, c the
    /// 1-based row and column, p the phase, s the hold's first tick and N the ticks to the win tick:
    /// - run: "Replay the timeline", "Run to the end", "Run: N ticks"
    /// - rewind: ``rewindText`` at every level
    /// - release: "Remove a hold", "Remove star k's hold", "Remove star k's hold from tick s"
    /// - phase: "Change a star's start", "Change the start of star k (shape)",
    ///   "Start star k (shape) at row r, column c (phase p)"
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public var text: String {
        let number: Int = (star ?? 0) + 1
        switch (kind, level) {
        case (.run, 1): return "Replay the timeline"
        case (.run, 2): return "Run to the end"
        case (.run, _): return "Run: \(ticks) ticks"
        case (.rewind, _): return Self.rewindText
        case (.release, 1): return "Remove a hold"
        case (.release, 2): return "Remove star \(number)'s hold"
        case (.release, _): return "Remove star \(number)'s hold from tick \(start ?? 0)"
        case (.phase, 1): return "Change a star's start"
        case (.phase, 2): return "Change the start of star \(number) (\(shapeName))"
        case (.phase, _): return "Start star \(number) (\(shapeName)) at \(place) (phase \(phase ?? 0))"
        case (.stuck, _): return failed ? Self.failedText : Self.stuckText
        }
    }
}

/// The hint engine of Chrono Constellator (clarification Q1).
public enum ChronoConstellatorHints {
    /// The plan of `play` while `playing` or `paused` (nil in every other stage, and when no win is reachable):
    /// - the current timeline wins (``ChronoConstellatorGenerator/winTick(_:timeline:)`` from tick 0 is after the
    ///   current tick): `run` with the ticks to the win tick;
    /// - else after tick 0: `rewind`, when the timeline has a plan at tick 0;
    /// - else at tick 0 ``startPlan(_:timeline:)``.
    ///
    /// A plan exists exactly when following the plans step by step wins: a rewind or a release is offered only when the
    /// state it leads to has a plan of its own.
    public static func plan(_ play: ChronoConstellatorPlay) -> ChronoConstellatorPlan? {
        guard play.stage == .playing || play.stage == .paused else { return nil }
        let level: ChronoConstellatorLevel = play.level
        if let win = ChronoConstellatorGenerator.winTick(level, timeline: play.timeline), win > play.tick {
            return .run(ticks: win - play.tick)
        }
        guard play.tick == 0 else { return startPlan(level, timeline: play.timeline) == nil ? nil : .rewind }
        return startPlan(level, timeline: play.timeline)
    }

    /// The plan at tick 0 of `timeline` on `level`:
    /// - the timeline wins: `run` with the ticks to the win tick;
    /// - else with holds: `release` of the first hold (star order, then start), when the timeline without it has a
    ///   plan;
    /// - else ``ChronoConstellatorSolver/solve(_:)`` on the level with the timeline's phases as its defaults: `phases`
    ///   with the solution's changes in star order, accepted only when the edits in use afterwards (against the level's
    ///   own defaults) stay within the budget and the resulting timeline wins;
    /// - else nil.
    static func startPlan(_ level: ChronoConstellatorLevel,
                          timeline: ChronoConstellatorTimeline) -> ChronoConstellatorPlan? {
        if let win = ChronoConstellatorGenerator.winTick(level, timeline: timeline) { return .run(ticks: win) }
        if let hold = timeline.holds.first {
            guard let rest = try? timeline.releasing(star: hold.star, start: hold.start, level: level),
                  startPlan(level, timeline: rest) != nil else { return nil }
            return .release(star: hold.star, start: hold.start)
        }
        guard let shifted = withDefaults(level, phases: timeline.phases),
              let solution = ChronoConstellatorSolver.solve(shifted),
              solution.phases.count == level.stars.count,
              let solved = withDefaults(level, phases: solution.phases) else { return nil }
        var changes: [ChronoConstellatorPhaseChange] = []
        var edits: Int = 0
        for index in level.stars.indices {
            if solution.phases[index] != level.stars[index].phase { edits += 1 }
            if solution.phases[index] != timeline.phases[index] {
                changes.append(ChronoConstellatorPhaseChange(star: index, phase: solution.phases[index]))
            }
        }
        guard edits <= level.budget, !changes.isEmpty,
              ChronoConstellatorGenerator.winTick(level, timeline: ChronoConstellatorTimeline(level: solved)) != nil
        else { return nil }
        return .phases(changes)
    }

    /// `level` with its stars' default phases replaced by `phases`, or nil when that is not a valid level.
    private static func withDefaults(_ level: ChronoConstellatorLevel, phases: [Int]) -> ChronoConstellatorLevel? {
        guard phases.count == level.stars.count else { return nil }
        var stars: [ChronoConstellatorStar] = []
        for index in level.stars.indices {
            let star: ChronoConstellatorStar = level.stars[index]
            stars.append(ChronoConstellatorStar(loop: star.loop, phase: phases[index], target: star.target))
        }
        return try? ChronoConstellatorLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                                            columns: level.columns, rows: level.rows, stars: stars,
                                            budget: level.budget, tickLimit: level.tickLimit, tutorial: level.tutorial)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's hint (for `phases`,
    /// its first change in star order), `stuck` when there is no plan; when `failed`, `stuck` with the failed text; nil
    /// in every other stage (loading, tutorial, won, result). The same action is returned at every level.
    public static func hint(level: Int, play: ChronoConstellatorPlay) -> ChronoConstellatorHint? {
        let clamped: Int = min(3, max(1, level))
        switch play.stage {
        case .playing, .paused: break
        case .failed: return ChronoConstellatorHint(level: clamped, kind: .stuck, failed: true)
        case .loading, .tutorial, .won, .result: return nil
        }
        guard let plan = plan(play) else { return ChronoConstellatorHint(level: clamped, kind: .stuck) }
        let lvl: ChronoConstellatorLevel = play.level
        switch plan {
        case .run(let ticks):
            return ChronoConstellatorHint(level: clamped, kind: .run, ticks: ticks)
        case .rewind:
            return ChronoConstellatorHint(level: clamped, kind: .rewind)
        case .release(let star, let start):
            return ChronoConstellatorHint(level: clamped, kind: .release, star: star, start: start,
                                          shapeName: ChronoConstellatorLevel.shape(of: star).name)
        case .phases(let changes):
            guard let first = changes.first else { return ChronoConstellatorHint(level: clamped, kind: .stuck) }
            let cell: Int = lvl.stars[first.star].loop[first.phase]
            return ChronoConstellatorHint(level: clamped, kind: .phase, star: first.star, cell: cell,
                                          phase: first.phase,
                                          shapeName: ChronoConstellatorLevel.shape(of: first.star).name,
                                          place: lvl.place(cell))
        }
    }
}

/// The plain-English explanation of a failed play (FR-R02G0605-003; clarification Q5), from the failing tick.
public struct ChronoConstellatorFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: ChronoConstellatorFailure
    /// The failing tick.
    public let tick: Int
    /// The stars named (0-based): the colliding pair a < b (`collision`) or every star off its target (`time`).
    public let stars: [Int]
    /// The cell of the collision (`collision`); nil for `time`.
    public let cell: Int?
    /// The explanation's sentence before the shared advice.
    private let detail: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last change, rewind or retry the level."

    /// The explanation (clarification Q5), with star numbers 1-based and places "row r, column c" 1-based:
    /// - collision: "Star a (shape) and star b (shape) met at row r, column c on tick T."
    /// - time: "Time ran out at tick T: " followed by "star k (shape) is at row r, column c, its target is row r′,
    ///   column c′" for every star off its target at T, joined by "; ", and "."
    ///
    /// each followed by a space and ``advice``.
    public var text: String { detail + " " + Self.advice }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure).
    public init?(play: ChronoConstellatorPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: ChronoConstellatorLevel = play.level
        self.failure = failure
        tick = play.tick
        switch failure {
        case .collision(let a, let b, let cell):
            guard level.stars.indices.contains(a), level.stars.indices.contains(b) else { return nil }
            stars = [a, b]
            self.cell = cell
            detail = "Star \(a + 1) (\(ChronoConstellatorLevel.shape(of: a).name)) and star \(b + 1) "
                + "(\(ChronoConstellatorLevel.shape(of: b).name)) met at \(level.place(cell)) on tick \(play.tick)."
        case .time:
            let positions: [Int] = play.timeline.positions(at: play.tick, level: level)
            var off: [Int] = []
            var parts: [String] = []
            for index in level.stars.indices where positions[index] != level.stars[index].target {
                off.append(index)
                parts.append("star \(index + 1) (\(ChronoConstellatorLevel.shape(of: index).name)) is at "
                    + "\(level.place(positions[index])), its target is \(level.place(level.stars[index].target))")
            }
            stars = off
            cell = nil
            detail = "Time ran out at tick \(play.tick): " + parts.joined(separator: "; ") + "."
        }
    }
}
