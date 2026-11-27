// BinaryGardensHints — feature 505 (R02-G21-05) T-R02G2105-002 (FR-R02G2105-002, 003, 009; SC-R02G2105-002, 003;
// clarifications Q1, Q5; research R1 … R3). Progressive hints computed from the current state of a play, and the
// plain-English explanation of a failed run of the cycle.
//
// While a play is `playing`, the plan is empty when the current arrangement already wins (the play's report wins).
// Otherwise, while the current arrangement lies on the way to the certified arrangement — each of the seven controls
// (`BinaryGardensControl`: star 1 ring, phase, luminosity, star 2 ring, phase, luminosity, tilt) holds either its
// starting or its certified value — the remaining actions are the certified witness's arrangement actions whose control
// is not yet at its certified value, in the witness's order; when the actions left cover them and each, applied in that
// order from the current arrangement, is a legal move (the kernel's check, so locks and the minimum separation are
// kept), the plan is them. Exact hints from a level's start therefore replay its certified witness of 1 … 4 actions
// with no search at all.
//
// Otherwise a bounded breadth-first search from the current arrangement looks for a winning arrangement within
// min(actions left, 2) actions, an action being any legal move of `BinaryGardensPuzzle.moves(in:)` in its fixed order
// (star 1 ring, phase, luminosity, star 2 ring, phase, luminosity, tilt; values ascending). One action is tried before
// two. Each reached arrangement is judged with `BinaryGardensSky.report(level, arrangement:)` (a report depends only on
// the arrangement); an arrangement already judged (or the current one) is not judged again, and the work is the number
// of arrangements judged, bounded at 2,000 (above any catalog level's two-action space, at most 25 + 25 × 25 = 650).
// The plan is the first winning sequence found; nil when none is found within those actions or the bound would be
// exceeded.
//
// The first action of the plan is the hint: level 1 names the kind of change ("Move a star to another ring", "Shift a
// star's phase", "Change a star's brightness" or "Tilt the orbit plane"), level 2 adds which star and which way ("Move
// star n outward" or "inward" — a higher ring index is outward —, "Shift star n's phase forward" when
// (target − current) mod 48 is 1 … 24, else "back", "Make star n brighter" or "dimmer", "Tilt the orbit plane more" or
// "less"), level 3 the exact action ("Move star n to ring r (ρ units)", "Shift star n to phase p", "Set star n's
// luminosity to L", "Set the tilt to t of T steps"), stars and rings numbered from 1, ρ the ring's radius and L the
// luminosity in units. With an empty plan the hint is the run ("Every world keeps its light: run the cycle"); with no
// plan it is `stuck`. A failed play (or one in `result` after a failure) gets `retry`, the advice to undo or retry;
// loading, tutorial, paused, won and `result` after a win have no hint. Hints never change a play, are unlimited and do
// not affect stars; the hint level is presentation.
//
// The failure explanation numbers worlds from 1, names walk ticks in the level's words (`walkTickWords`, so a tick
// beyond 48 reads "tick 50 (tick 2 of the next cycle)"), groups numbers as the level does (`grouped`) and ends with one
// space and "Undo the last action or retry the level.". Integers and strings only; no clock, no random source; work is
// counted, never timed. Modelled on `MushroomWeatherHints` (feature 495).
import Foundation

/// The plan of a play from its current arrangement (clarification Q1): the certified witness's actions still to do, or
/// a shortest winning completion's ring, phase, luminosity and tilt actions. The first action is the hint; an empty
/// plan means the current arrangement already wins.
public struct BinaryGardensHintPlan: Sendable, Equatable {
    /// The arrangement actions in order; the run is not part of it.
    public let actions: [BinaryGardensAction]

    /// A plan of the given actions (not checked).
    public init(actions: [BinaryGardensAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum BinaryGardensHintKind: String, Sendable, Codable {
    /// Move a star to another ring.
    case ring
    /// Shift a star's phase.
    case phase
    /// Change a star's brightness.
    case luminosity
    /// Tilt the orbit plane.
    case tilt
    /// Every world keeps its light: run the cycle.
    case run
    /// No way to win was found in the actions left: undo or retry.
    case stuck
    /// The run failed: undo or retry.
    case retry
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct BinaryGardensHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the kind of change, 2 adds which star and which way, 3 the exact action.
    public let level: Int
    /// What the hint suggests.
    public let kind: BinaryGardensHintKind
    /// The suggested action: a ring, phase, luminosity or tilt action, `.run` for `run`, nil for `stuck` and `retry`.
    public let action: BinaryGardensAction?
    /// The hint in plain English.
    public var text: String

    /// The text of the hint when the current arrangement already wins, at every level.
    public static let runText: String = "Every world keeps its light: run the cycle"
    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: BinaryGardensHintKind, action: BinaryGardensAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// The kind of `action`: `ring`, `phase`, `luminosity`, `tilt` or `run`.
    public static func kind(of action: BinaryGardensAction) -> BinaryGardensHintKind {
        switch action {
        case .ring: .ring
        case .phase: .phase
        case .luminosity: .luminosity
        case .tilt: .tilt
        case .run: .run
        }
    }

    /// The text of a ring, phase, luminosity or tilt hint at `level` (clamped to 1 … 3) on `gardens` from
    /// `arrangement` (the arrangement the action would change); nil for the run and for an action naming a star, ring,
    /// luminosity or tilt the level lacks. With n = star + 1:
    /// - `.ring(star, index)`: "Move a star to another ring"; "Move star n outward" (index above the current ring) or
    ///   "Move star n inward"; "Move star n to ring r (ρ units)" with r = index + 1 and ρ the ring's radius.
    /// - `.phase(star, step)`: "Shift a star's phase"; "Shift star n's phase forward" when (step − current) mod 48 is
    ///   1 … 24, else "Shift star n's phase back"; "Shift star n to phase p".
    /// - `.luminosity(star, index)`: "Change a star's brightness"; "Make star n brighter" (index above the current one)
    ///   or "Make star n dimmer"; "Set star n's luminosity to L" with L the luminosity in units.
    /// - `.tilt(step)`: "Tilt the orbit plane"; "Tilt the orbit plane more" (step above the current tilt) or "Tilt the
    ///   orbit plane less"; "Set the tilt to t of T steps" with T the level's largest tilt.
    public static func actionText(level: Int, action: BinaryGardensAction, gardens: BinaryGardensLevel,
                                  arrangement: BinaryGardensArrangement) -> String? {
        let clamped: Int = min(3, max(1, level))
        switch action {
        case .ring(let star, let index):
            guard arrangement.rings.indices.contains(star), gardens.ringRadii.indices.contains(index) else {
                return nil
            }
            if clamped == 1 { return "Move a star to another ring" }
            let number: String = String(star + 1)
            if clamped == 2 {
                return "Move star " + number + (index > arrangement.rings[star] ? " outward" : " inward")
            }
            return "Move star " + number + " to ring " + String(index + 1) + " ("
                + BinaryGardensLevel.grouped(gardens.ringRadii[index]) + " units)"
        case .phase(let star, let step):
            guard arrangement.phases.indices.contains(star) else { return nil }
            if clamped == 1 { return "Shift a star's phase" }
            let number: String = String(star + 1)
            if clamped == 2 {
                let cycle: Int = BinaryGardensSky.cycle
                let ahead: Int = ((step - arrangement.phases[star]) % cycle + cycle) % cycle
                let way: String = (1...(cycle / 2)).contains(ahead) ? " forward" : " back"
                return "Shift star " + number + "'s phase" + way
            }
            return "Shift star " + number + " to phase " + String(step)
        case .luminosity(let star, let index):
            guard arrangement.luminosities.indices.contains(star),
                  gardens.luminosityLevels.indices.contains(index) else { return nil }
            if clamped == 1 { return "Change a star's brightness" }
            let number: String = String(star + 1)
            if clamped == 2 {
                return "Make star " + number + (index > arrangement.luminosities[star] ? " brighter" : " dimmer")
            }
            return "Set star " + number + "'s luminosity to "
                + BinaryGardensLevel.grouped(gardens.luminosityLevels[index])
        case .tilt(let step):
            if clamped == 1 { return "Tilt the orbit plane" }
            if clamped == 2 { return "Tilt the orbit plane" + (step > arrangement.tilt ? " more" : " less") }
            return "Set the tilt to " + String(step) + " of " + String(gardens.maxTilt) + " steps"
        case .run:
            return nil
        }
    }
}

/// The hint engine of Binary Gardens (clarification Q1).
public enum BinaryGardensHints {
    /// The bound on arrangements judged per plan.
    public static let workBound: Int = 2_000

    /// The most actions a searched plan holds.
    static let maxActions: Int = 2

    /// The value of `control` in `arrangement`.
    static func value(_ control: BinaryGardensControl, in arrangement: BinaryGardensArrangement) -> Int {
        switch control {
        case .star1Ring: arrangement.rings[0]
        case .star1Phase: arrangement.phases[0]
        case .star1Luminosity: arrangement.luminosities[0]
        case .star2Ring: arrangement.rings[1]
        case .star2Phase: arrangement.phases[1]
        case .star2Luminosity: arrangement.luminosities[1]
        case .tilt: arrangement.tilt
        }
    }

    /// The control `action` sets, or nil for the run and a star outside 0 … 1.
    static func control(of action: BinaryGardensAction) -> BinaryGardensControl? {
        switch action {
        case .ring(let star, _):
            star == 0 ? .star1Ring : (star == 1 ? .star2Ring : nil)
        case .phase(let star, _):
            star == 0 ? .star1Phase : (star == 1 ? .star2Phase : nil)
        case .luminosity(let star, _):
            star == 0 ? .star1Luminosity : (star == 1 ? .star2Luminosity : nil)
        case .tilt:
            .tilt
        case .run:
            nil
        }
    }

    /// Whether `arrangement` has two entries per star list.
    static func hasTwoStars(_ arrangement: BinaryGardensArrangement) -> Bool {
        arrangement.rings.count == 2 && arrangement.phases.count == 2 && arrangement.luminosities.count == 2
    }

    /// The certified witness's actions still to do from `arrangement` when it lies on the way to `certified`'s
    /// arrangement (each of the seven controls at its starting or its certified value): the witness's arrangement
    /// actions whose control is not yet at its certified value, in the witness's order, each a legal move from the
    /// arrangement before it (the kernel's check). Nil when the arrangement does not lie on the way, a remaining action
    /// is refused or the plan does not fit the level. The budget is not checked here.
    static func remainingCertified(_ arrangement: BinaryGardensArrangement, level: BinaryGardensLevel,
                                   certified: BinaryGardensPlan) -> [BinaryGardensAction]? {
        let start: BinaryGardensArrangement = level.start
        let target: BinaryGardensArrangement = certified.arrangement
        guard hasTwoStars(arrangement), hasTwoStars(start), hasTwoStars(target) else { return nil }
        for control in BinaryGardensControl.allCases {
            let now: Int = value(control, in: arrangement)
            if now != value(control, in: start) && now != value(control, in: target) { return nil }
        }
        var current: BinaryGardensArrangement = arrangement
        var result: [BinaryGardensAction] = []
        for action in certified.actions {
            if case .run = action { continue }
            guard let control = control(of: action) else { return nil }
            if value(control, in: current) == value(control, in: target) { continue }
            guard let next = try? BinaryGardensSky.changed(level, current, by: action) else { return nil }
            result.append(action)
            current = next
        }
        return result
    }

    /// The bounded breadth-first search of ``plan(_:certified:workBound:)`` from `play`'s arrangement: the first
    /// winning sequence of one, else two, legal moves within `min(actions left, 2)`, each new arrangement judged once,
    /// and the arrangements judged. The legal moves of an arrangement are exactly `BinaryGardensPuzzle.moves(in:)`'s
    /// in its order: the puzzle's candidate actions the kernel's check (`BinaryGardensSky.changed`) accepts, each
    /// checked once and its arrangement kept, while an action is left (the cap). The plan is nil when no winning
    /// sequence is found or more than `workBound` arrangements would be judged (the work then stops at the bound).
    static func search(_ play: BinaryGardensPlay,
                       workBound: Int) -> (plan: BinaryGardensHintPlan?, work: Int) {
        let level: BinaryGardensLevel = play.level
        let cap: Int = min(maxActions, play.actionsLeft)
        guard cap >= 1, BinaryGardensSky.isWellFormed(level, play.arrangement) else { return (nil, 0) }
        let candidates: [BinaryGardensAction] = BinaryGardensPuzzle(level: level).candidates()
        var seen: Set<BinaryGardensArrangement> = [play.arrangement]
        var work: Int = 0
        var middles: [(action: BinaryGardensAction, arrangement: BinaryGardensArrangement)] = []
        for first in candidates {
            guard let next = try? BinaryGardensSky.changed(level, play.arrangement, by: first) else { continue }
            middles.append((first, next))
            if seen.contains(next) { continue }
            guard work < workBound else { return (nil, work) }
            work += 1
            seen.insert(next)
            if BinaryGardensSky.report(level, arrangement: next).wins {
                return (BinaryGardensHintPlan(actions: [first]), work)
            }
        }
        guard cap >= 2 else { return (nil, work) }
        for middle in middles {
            for second in candidates {
                guard let next = try? BinaryGardensSky.changed(level, middle.arrangement, by: second) else { continue }
                if seen.contains(next) { continue }
                guard work < workBound else { return (nil, work) }
                work += 1
                seen.insert(next)
                if BinaryGardensSky.report(level, arrangement: next).wins {
                    return (BinaryGardensHintPlan(actions: [middle.action, second]), work)
                }
            }
        }
        return (nil, work)
    }

    /// The plan of `play` while `playing`: empty when the current arrangement already wins (the play's report wins);
    /// else the certified witness's actions still to do while the arrangement lies on the way to `certified`'s
    /// arrangement, each a legal move in order, and the actions left cover them; else the first winning sequence of a
    /// breadth-first search within `min(actions left, 2)` legal moves of `BinaryGardensPuzzle.moves(in:)`, one action
    /// before two, each new arrangement judged once with `BinaryGardensSky.report(_:arrangement:)`. Nil in every other
    /// stage, when no winning arrangement is reachable within those actions, and when more than `workBound`
    /// arrangements would be judged. The play is not changed.
    public static func plan(_ play: BinaryGardensPlay, certified: BinaryGardensPlan?,
                            workBound: Int = workBound) -> BinaryGardensHintPlan? {
        guard play.stage == .playing else { return nil }
        if play.report.wins { return BinaryGardensHintPlan(actions: []) }
        if let certified,
           let remaining = remainingCertified(play.arrangement, level: play.level, certified: certified),
           !remaining.isEmpty, remaining.count <= play.actionsLeft {
            return BinaryGardensHintPlan(actions: remaining)
        }
        return search(play, workBound: workBound).plan
    }

    /// The hint of `level` (clamped to 1 … 3) for `play` with the certified plan `certified`: while `playing`, `run`
    /// with ``BinaryGardensHint/runText`` when the plan is empty, the plan's first action (`ring`, `phase`,
    /// `luminosity` or `tilt`, text per ``BinaryGardensHint/actionText(level:action:gardens:arrangement:)``), or
    /// `stuck` with ``BinaryGardensHint/stuckText`` when there is no plan; when `failed` (or `result` after a failure),
    /// `retry` with ``BinaryGardensHint/failedText``; nil in every other stage (loading, tutorial, paused, won, result
    /// after a win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: BinaryGardensPlay,
                            certified: BinaryGardensPlan?) -> BinaryGardensHint? {
        switch play.stage {
        case .playing:
            break
        case .failed:
            return BinaryGardensHint(level: level, kind: .retry, action: nil, text: BinaryGardensHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return BinaryGardensHint(level: level, kind: .retry, action: nil, text: BinaryGardensHint.failedText)
        case .loading, .tutorial, .paused, .won:
            return nil
        }
        guard let found = plan(play, certified: certified) else {
            return BinaryGardensHint(level: level, kind: .stuck, action: nil, text: BinaryGardensHint.stuckText)
        }
        guard let first = found.actions.first else {
            return BinaryGardensHint(level: level, kind: .run, action: .run, text: BinaryGardensHint.runText)
        }
        guard let text = BinaryGardensHint.actionText(level: level, action: first, gardens: play.level,
                                                      arrangement: play.arrangement) else {
            return BinaryGardensHint(level: level, kind: .stuck, action: nil, text: BinaryGardensHint.stuckText)
        }
        return BinaryGardensHint(level: level, kind: BinaryGardensHint.kind(of: first), action: first, text: text)
    }
}

/// The plain-English explanation of a failed run of the cycle (FR-R02G2105-003; clarification Q5), from the play's
/// failure.
public struct BinaryGardensFailureExplanation: Sendable, Equatable {
    /// Why the run failed.
    public let failure: BinaryGardensFailure
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With n
    /// the world's number (its index + 1), t the walk tick in the level's words, E the level's lethal tolerance and
    /// numbers grouped as the level groups them (``sentence(_:tolerance:)``), followed by one space and ``advice``.
    /// Nil when the failure names a world the level lacks.
    public init?(play: BinaryGardensPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        guard play.level.worlds.indices.contains(failure.world) else { return nil }
        self.failure = failure
        text = Self.sentence(failure, tolerance: play.level.lethalTolerance) + " " + Self.advice
    }

    /// "1 tick" or "n ticks" (n grouped).
    static func ticks(_ count: Int) -> String {
        count == 1 ? "1 tick" : BinaryGardensLevel.grouped(count) + " ticks"
    }

    /// The sentence of `failure` with the lethal tolerance `tolerance` (E), worlds numbered from 1:
    /// - frozen: "World n froze at tick t: its light stayed below its lethal floor for more than E ticks in a row."
    ///   ("1 tick" when E is 1; with E = 0 "World n froze at tick t: its light fell below its lethal floor.").
    /// - scorched: "World n scorched at tick t: its light stayed above its lethal ceiling for more than E ticks in a
    ///   row." ("1 tick" when E is 1; with E = 0 "World n scorched at tick t: its light rose above its lethal
    ///   ceiling.").
    /// - unstable: "World n kept comfortable light for only w ticks in a row; W were needed." ("1 tick" when w is 1,
    ///   "1 was needed" when W is 1; with w = 0 "World n never had comfortable light; W were needed.").
    /// - wilted: "World n wilted: its light over the cycle totalled I, below its bloom band B_lo … B_hi."
    /// - bleached: "World n bleached: its light over the cycle totalled I, above its bloom band B_lo … B_hi."
    public static func sentence(_ failure: BinaryGardensFailure, tolerance: Int) -> String {
        switch failure {
        case .frozen(let world, let tick):
            let head: String = "World " + String(world + 1) + " froze at " + BinaryGardensLevel.walkTickWords(tick)
            if tolerance == 0 { return head + ": its light fell below its lethal floor." }
            return head + ": its light stayed below its lethal floor for more than " + ticks(tolerance) + " in a row."
        case .scorched(let world, let tick):
            let head: String = "World " + String(world + 1) + " scorched at "
                + BinaryGardensLevel.walkTickWords(tick)
            if tolerance == 0 { return head + ": its light rose above its lethal ceiling." }
            return head + ": its light stayed above its lethal ceiling for more than " + ticks(tolerance)
                + " in a row."
        case .unstable(let world, let window, let required):
            let needed: String = BinaryGardensLevel.grouped(required)
                + (required == 1 ? " was needed." : " were needed.")
            if window == 0 { return "World " + String(world + 1) + " never had comfortable light; " + needed }
            return "World " + String(world + 1) + " kept comfortable light for only " + ticks(window) + " in a row; "
                + needed
        case .wilted(let world, let integral, let low, let high):
            return "World " + String(world + 1) + " wilted: its light over the cycle totalled "
                + BinaryGardensLevel.grouped(integral) + ", below its bloom band " + BinaryGardensLevel.grouped(low)
                + " … " + BinaryGardensLevel.grouped(high) + "."
        case .bleached(let world, let integral, let low, let high):
            return "World " + String(world + 1) + " bleached: its light over the cycle totalled "
                + BinaryGardensLevel.grouped(integral) + ", above its bloom band " + BinaryGardensLevel.grouped(low)
                + " … " + BinaryGardensLevel.grouped(high) + "."
        }
    }
}
