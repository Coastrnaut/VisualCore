// AmethystEscapeHints — feature 365 (R02-G07-05) T-R02G0705-002 (FR-R02G0705-002, 003; SC-R02G0705-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play and the plain-English explanation
// of a failure. The plan comes from the current state: the solver's breadth-first search started at the play's crystal
// (`AmethystEscapeSolver.solve(_:from:maxDepth:)`, the same rules and packed states as the certification) and limited to
// the moves left finds the shortest escape; its first action is the hint. A plan exists exactly when an escape fits in the
// moves left, so following exact hints from any state with a plan wins. Hints never change a play, are unlimited and do
// not affect stars; the hint level is presentation (held by the presenter, reset to 1 after any change of the play). A
// failure is explained from the failing move: the blocked wedge the pearl fell into, or the spent budget and where the
// pearl is. Integers only; no clock, no random source.

/// The plan of a play from its current state (clarification Q1): the actions of the shortest escape from the current
/// crystal that fits in the moves left; the first one is the hint.
public struct AmethystEscapePlan: Sendable, Equatable {
    /// The actions, in order; the last is the advance through the exit gap.
    public let actions: [AmethystEscapeAction]

    /// A plan of the given actions (not checked).
    public init(actions: [AmethystEscapeAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum AmethystEscapeHintKind: String, Sendable, Codable {
    /// Turn one shell by one sector.
    case turn
    /// Roll the pearl one pocket.
    case advance
    /// No escape fits in the moves left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct AmethystEscapeHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names what to do, 2 adds which shell, 3 is exact.
    public let level: Int
    /// What the hint suggests.
    public let kind: AmethystEscapeHintKind
    /// The shell to turn (`turn`), 0-based; nil otherwise.
    public let shell: Int?
    /// The step to turn it by (`turn`): +1 clockwise, −1 anticlockwise; nil otherwise.
    public let step: Int?
    /// The shell in words, "shell 1 (inner)" … "shell K (outer)" (`turn`), else empty.
    let shellName: String
    /// Whether a `stuck` hint is for a failed play.
    let failed: Bool

    /// A hint of the given values (not checked).
    init(level: Int, kind: AmethystEscapeHintKind, shell: Int? = nil, step: Int? = nil, shellName: String = "",
         failed: Bool = false) {
        self.level = level
        self.kind = kind
        self.shell = shell
        self.step = step
        self.shellName = shellName
        self.failed = failed
    }

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last move or retry the level."
    /// The text shown when no escape fits in the moves left, at every level.
    public static let stuckText: String =
        "No escape is reachable in the moves left: undo the last move or retry the level."

    /// The hint in plain English (clarification Q1), with (shell) the shell in words from
    /// ``AmethystEscapeLevel/shellName(_:)`` ("shell 1 (inner)", "shell 2", … "shell K (outer)"):
    /// - turn: "Turn a shell", "Turn (shell)", "Turn (shell) one sector clockwise" (+1) or "… anticlockwise" (−1)
    /// - advance: "Roll the pearl", "Roll the pearl", "Roll the pearl one pocket"
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public var text: String {
        switch (kind, level) {
        case (.turn, 1): return "Turn a shell"
        case (.turn, 2): return "Turn \(shellName)"
        case (.turn, _): return "Turn \(shellName) one sector " + ((step ?? 1) > 0 ? "clockwise" : "anticlockwise")
        case (.advance, 1), (.advance, 2): return "Roll the pearl"
        case (.advance, _): return "Roll the pearl one pocket"
        case (.stuck, _): return failed ? Self.failedText : Self.stuckText
        }
    }

    /// The kernel action this hint names; nil for `stuck`.
    public var action: AmethystEscapeAction? {
        switch kind {
        case .turn:
            guard let shell, let step else { return nil }
            return .rotate(shell, step)
        case .advance: return .advance
        case .stuck: return nil
        }
    }
}

/// The hint engine of Amethyst Escape (clarification Q1).
public enum AmethystEscapeHints {
    /// The plan of `play` while `playing` or `paused`: the shortest escape from the current crystal within the moves left
    /// (``AmethystEscapeSolver/solve(_:from:maxDepth:)`` with `maxDepth` ``AmethystEscapePlay/remaining``). Nil in every
    /// other stage and when no escape fits in the moves left. An escape on the last move left wins (the exit is judged
    /// before the budget), so a plan of exactly the moves left is kept.
    public static func plan(_ play: AmethystEscapePlay) -> AmethystEscapePlan? {
        guard play.stage == .playing || play.stage == .paused else { return nil }
        guard let solution = AmethystEscapeSolver.solve(play.level, from: play.crystal, maxDepth: play.remaining),
              !solution.actions.isEmpty else { return nil }
        return AmethystEscapePlan(actions: solution.actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first action (`turn`
    /// with its shell and step, or `advance`), `stuck` with ``AmethystEscapeHint/stuckText`` when there is no plan; when
    /// `failed` (or `result` after a failure), `stuck` with ``AmethystEscapeHint/failedText``; nil in every other stage
    /// (loading, tutorial, won, result after a win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: AmethystEscapePlay) -> AmethystEscapeHint? {
        let clamped: Int = min(3, max(1, level))
        switch play.stage {
        case .playing, .paused: break
        case .failed: return AmethystEscapeHint(level: clamped, kind: .stuck, failed: true)
        case .result:
            return play.failure == nil ? nil : AmethystEscapeHint(level: clamped, kind: .stuck, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else { return AmethystEscapeHint(level: clamped, kind: .stuck) }
        switch first {
        case .rotate(let shell, let step):
            return AmethystEscapeHint(level: clamped, kind: .turn, shell: shell, step: step,
                                      shellName: play.level.shellName(shell))
        case .advance:
            return AmethystEscapeHint(level: clamped, kind: .advance)
        }
    }
}

/// The plain-English explanation of a failed play (FR-R02G0705-003; clarification Q5), from the failing move.
public struct AmethystEscapeFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: AmethystEscapeFailure
    /// The moves spent: the number of the failing move (1-based), which for `budget` equals the budget.
    public let move: Int
    /// The shell named (0-based): the wedge's shell (`wedge`) or the pearl's shell (`budget`).
    public let shell: Int
    /// The absolute sector named (0-based): the wedge's sector (`wedge`) or the pearl's sector (`budget`).
    public let sector: Int
    /// The pearl's pocket at the failure (the wedge itself for `wedge`).
    public let pearl: AmethystEscapePocket
    /// The explanation's sentence before the shared advice.
    private let detail: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last move or retry the level."

    /// The explanation (clarification Q5), with (shell) the shell in words (``AmethystEscapeLevel/shellName(_:)``) and
    /// "sector s of N" 1-based (``AmethystEscapeLevel/sectorName(_:)``):
    /// - wedge: "The pearl fell into the blocked wedge of (shell), sector s of N, on move m."
    /// - budget: "The moves ran out: m of B spent and the pearl is in (shell), sector s of N."
    ///
    /// each followed by a space and ``advice``.
    public var text: String { detail + " " + Self.advice }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure).
    public init?(play: AmethystEscapePlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: AmethystEscapeLevel = play.level
        self.failure = failure
        move = play.moves
        pearl = play.crystal.pearl
        switch failure {
        case .wedge(let wedgeShell, let wedgeSector):
            guard level.shells.indices.contains(wedgeShell), (0..<level.sectors).contains(wedgeSector) else { return nil }
            shell = wedgeShell
            sector = wedgeSector
            detail = "The pearl fell into the blocked wedge of \(level.shellName(wedgeShell)), "
                + "\(level.sectorName(wedgeSector)), on move \(play.moves)."
        case .budget:
            shell = play.crystal.pearl.shell
            sector = play.crystal.pearl.sector
            detail = "The moves ran out: \(play.moves) of \(level.budget) spent and the pearl is in "
                + "\(level.shellName(shell)), \(level.sectorName(sector))."
        }
    }
}
