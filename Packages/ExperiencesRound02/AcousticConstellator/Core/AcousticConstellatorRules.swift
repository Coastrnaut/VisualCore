// AcousticConstellatorRules — feature 421 (R02-G13-01) T-R02G1301-005 (FR-R02G1301-010). Acoustic Constellator
// expressed as an R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a
// `Position` (the links, the starting phase of every star, the actions spent and the outcome), a move is an
// `AcousticConstellatorAction`, and a state is solved when its outcome is `won`. While playing the legal moves are
// every valid link — pairs (a, b) with a < b in lexicographic order, skipping pairs already linked and pairs that would
// take a star above the degree limit D or the links above the link limit E — then every valid unlink (the links the
// player made, in pair order; fixed links are never removed), then every nudge (star order, then −1, +1), then the
// listen. A won or failed position offers nothing. Applying a move mirrors the play's `apply(_:expecting:)`: a link, an
// unlink or a nudge changes the links or one starting phase, spends 1 action and fails the level when it spends the
// last of the budget; a listen spends 1 action and wins when the level's listen of the links (sorted) from the phases
// wins (even on the last action of the budget), else fails. Like the play, a link or unlink may name its stars in
// either order; the legal list names each pair once, lower star first. A move the play would refuse is refused (nil).
// The rules carry no stage, fingerprints, failure details, label, undo, redo or records: those belong to the play.
// Integers only; no clock, no random source.
import VisualCoreSimulation

/// The pure rules of one Acoustic Constellator level as an R02-F23 puzzle contract.
public struct AcousticConstellatorRules: PuzzleRules {
    /// A position of an Acoustic Constellator play as the rules see it: links, phases, actions spent and outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Actions are still possible.
            case playing
            /// A listen held: H consecutive coherent ticks within the window.
            case won
            /// A listen failed (missing, disconnected or incoherent), or another action spent the last of the budget.
            case failed
        }

        /// The links: the level's fixed links and the links the player made, sorted by (a, b).
        public let links: [AcousticConstellatorLink]
        /// The starting phase of every star, in star order.
        public let phases: [Int]
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(links: [AcousticConstellatorLink], phases: [Int], actionsSpent: Int, outcome: Outcome) {
            self.links = links
            self.phases = phases
            self.actionsSpent = actionsSpent
            self.outcome = outcome
        }
    }

    /// A position: links, phases, actions spent and outcome.
    public typealias State = Position
    /// A player action: a link, an unlink, a nudge or the listen.
    public typealias Move = AcousticConstellatorAction

    /// The level whose stars, fixed links, symbol, limits, listen parameters and budget decide the results.
    public let level: AcousticConstellatorLevel

    /// The rules of `level`.
    public init(level: AcousticConstellatorLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g13-acoustic-constellator" }

    /// The start position: the level's fixed links (sorted) and starting phases, no action spent, still playing.
    public var initialState: Position {
        Position(links: level.fixedLinks.sorted(), phases: level.startingPhases, actionsSpent: 0, outcome: .playing)
    }

    /// Whether `star` is a star of the level.
    private func isStar(_ star: Int) -> Bool { star >= 0 && star < level.stars.count }

    /// The links of `state` touching `star`, fixed links included.
    private func degree(_ star: Int, in state: Position) -> Int {
        var count: Int = 0
        for link in state.links where link.touches(star) { count += 1 }
        return count
    }

    /// Whether linking stars `u` and `v` (in either order) is valid in `state`: two distinct known stars, not linked
    /// yet, neither at the degree limit, and fewer links than the link limit.
    public func canLink(_ u: Int, _ v: Int, in state: Position) -> Bool {
        guard isStar(u), isStar(v), u != v else { return false }
        guard !state.links.contains(AcousticConstellatorLink.between(u, v)) else { return false }
        guard degree(u, in: state) < level.degreeLimit, degree(v, in: state) < level.degreeLimit else { return false }
        return state.links.count < level.linkLimit
    }

    /// Whether unlinking stars `u` and `v` (in either order) is valid in `state`: two distinct known stars whose link
    /// exists and is not one of the level's fixed links.
    public func canUnlink(_ u: Int, _ v: Int, in state: Position) -> Bool {
        guard isStar(u), isStar(v), u != v else { return false }
        let link = AcousticConstellatorLink.between(u, v)
        return state.links.contains(link) && !level.fixedLinks.contains(link)
    }

    /// Whether nudging `star` by `step` is valid: a known star and a step of −1 or +1.
    public func canNudge(_ star: Int, by step: Int) -> Bool {
        isStar(star) && (step == 1 || step == -1)
    }

    /// The legal moves: none once won or failed; otherwise every valid link (pair order, lower star first), every
    /// valid unlink (pair order), every nudge (star order, then −1, +1), then the listen.
    public func moves(in state: Position) -> [AcousticConstellatorAction] {
        guard state.outcome == .playing else { return [] }
        var result: [AcousticConstellatorAction] = []
        let count: Int = level.stars.count
        for a in 0..<count {
            for b in (a + 1)..<count where canLink(a, b, in: state) {
                result.append(.link(a, b))
            }
        }
        for link in state.links where canUnlink(link.a, link.b, in: state) {
            result.append(.unlink(link.a, link.b))
        }
        for star in 0..<count {
            result.append(.nudge(star, -1))
            result.append(.nudge(star, 1))
        }
        result.append(.listen)
        return result
    }

    /// The position after `move`, or nil when the play would refuse it (a link or unlink may name its stars in either
    /// order). A link, an unlink or a nudge changes the links or a starting phase, spends 1 action and fails the level
    /// when the budget is fully spent; a listen spends 1 action and wins when the level's listen wins, else fails —
    /// exactly as the play judges them.
    public func apply(_ move: AcousticConstellatorAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        var links: [AcousticConstellatorLink] = state.links
        var phases: [Int] = state.phases
        let spent: Int = state.actionsSpent + 1
        var outcome: Position.Outcome = .playing
        switch move {
        case .link(let u, let v):
            guard canLink(u, v, in: state) else { return nil }
            links.append(AcousticConstellatorLink.between(u, v))
            links.sort()
            if spent >= level.budget { outcome = .failed }
        case .unlink(let u, let v):
            guard canUnlink(u, v, in: state) else { return nil }
            let link = AcousticConstellatorLink.between(u, v)
            links.removeAll { $0 == link }
            if spent >= level.budget { outcome = .failed }
        case .nudge(let star, let step):
            guard canNudge(star, by: step), star < phases.count else { return nil }
            phases[star] = AcousticConstellatorClock.reduce(phases[star] + step)
            if spent >= level.budget { outcome = .failed }
        case .listen:
            outcome = level.listen(links: links, phases: phases).won ? .won : .failed
        }
        return Position(links: links, phases: phases, actionsSpent: spent, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
