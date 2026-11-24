// MoonlitMechanismScenarios — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-005; clarification Q5). The
// scenarios the verification runner plays for Moonlit Mechanism, a round-two game, all short (owner rule of
// 2026-11-13), on the pattern of Acoustic Constellator's (feature 423):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G14-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified witness of level 1, outcome `won`),
//     `fixture-budget-out` (the first certified move and its inverse alternated until the budget is spent, the last
//     action failing the play `budget`, outcome `failed`) and `fixture-undo-redo` (the first certified move, its undo
//     and its redo).
// Every certified action comes from the generated level's plan (`MoonlitMechanismGenerated.actions`, equal to the
// stored witness `docs/games/moonlit-mechanism/levels/NNN.witness.json`: the plan's turns, its re-seats in gear order,
// its lamp steps, then one run), so a regenerated catalog cannot leave a stale script. The inverse of a move is the
// same move with the opposite step (a turn back, the same gear re-seated back, the lamp stepped back), always legal
// right after the move. The two input actions are the first certified move and its inverse (neither runs, so neither
// decides; with a budget of at least 8, neither fails); input-response, save-restore and reset play both and undo the
// second; completion plays the certified witness of level 1 and expects `won`; full-playthrough solves levels 1, 2 and
// 3 with `level.next` between them; hero plays the certified moves of level 1 without the run, so the picture shows the
// solved set-up (its shadows on the targets) while the play is still open; rejection refuses values outside the
// declared ranges, fractional values, actions the kernel refuses (a step of 0, re-seating the driver or a gear the
// level lacks, a lamp step off the ladder, an undo or redo with nothing to revert), a key frame the level lacks and
// wrong value counts (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 49) mod 100 + 1 for rows 1 … 20 (050, 057, … 099, 006, … 083); the
// same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to 100), each
// opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted on the real
// controls with the outcome the kernel gives; the row's command cycles through the matrix's five (validate timed
// silhouette = run, rotate gear = turn, swap cog = re-seat, adjust ratio = re-seat, aim projector = lamp step):
//   1 … 10  truth and state transitions — a legal command then an illegal one, by (r − 1) mod 5: a run at the opening
//           (failed: a certified start never wins), then a turn refused `r02-g14.stage` (frame delta affects
//           judgement: the play is decided); a turn, then a re-seat of a gear the level lacks refused `r02-g14.action`
//           (out of range at five gears; occluded controls); the first certified move, then a re-seat of the driver
//           refused `r02-g14.action` (gear penetration); the first certified move, then a re-seat by 0.5 refused
//           `r02-g14.not-whole` (gear ratio drift); a lamp step onto the ladder, then a key frame the level lacks
//           refused `r02-g14.frame` (shadow mask animation desync);
//  11 … 20  solver witness and rejection — odd rows: the certified moves without one (the last whose omission fails
//           the run other than `missing`, else the last), a run (failed: the minimal plan has no smaller winning
//           vector), an undo, the omitted move and a run (won; moves commute); even rows: the certified moves, then the
//           inverse of the first certified move and the move alternated until the budget is spent (failed `budget`),
//           then a run refused `r02-g14.stage`;
//  21 … 30  numeric and geometry edges — gear 1 re-seated by −1 and the highest gear by +1 (the gear and step
//           endpoints; a phase of 0 wraps to T − 1), then a step of −2 (odd rows) or gear 5 (even rows) refused out of
//           range, gear −1 refused out of range, a re-seat step of 0 and a turn of 0 refused `r02-g14.action`, a
//           gear the level lacks refused `r02-g14.action` (when the level has fewer than 5 gears), then two undos back
//           to the opening digest;
//  31 … 40  touch and camera semantics — the first certified move, undo, redo (the moved digest again), the last key
//           frame shown (presentation: the digest does not change), then a second redo refused `r02-g14.action`;
//  41 … 50  rendering — the certified witness (won, the wall glows; the digest is the same at every quality tier),
//           then an undo refused `r02-g14.stage` (a won play is final);
//  51 … 60  accessibility and safety — odd rows: a run at the opening (failed, the failure named in words); even rows:
//           the certified moves without one (as rows 11 … 20) and a run (failed); then an undo, an honest retry back
//           to the digest before the run;
//  61 … 70  persistence and replay — the first certified move, undo, redo, then the rest of the witness (won; the
//           saved trace replays to the same state);
//  71 … 80  integration — the certified witness (won, the next level opened), `level.next` (the next certified level,
//           a fresh play), its first certified move, an undo (the next level's fresh play) and a second undo refused
//           `r02-g14.action`; on level 100 (no row reaches it today) `level.next` is refused `r02-g14.locked` after the
//           win (no wrap) and the row chooses level 1 with `level.select [1]` instead.
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
// Feature 435 (R02-G14-05) T-R02G1405-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`;
// the integration rows (71 … 80) therefore first win their level's certified witness (a campaign win opens the next
// level) before `level.next`; rejection also refuses the progression controls' wrong value counts (`level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest was regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`). Feature 437 (R02-G14-07) T-R02G1407-003: digests are schema 3's ("…v3"), wins store
// their traces, and rejection also refuses the replay and sound controls' wrong value counts (`replay.start`,
// `replay.step`, `replay.stop`, `settings.sound`); the manifest was regenerated.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension MoonlitMechanismExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G14-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional step, gear or key frame.
    static let notWholeCode = "action.rule." + MoonlitMechanismExperienceRule.notWhole
    /// The code of a key frame the level lacks (`frame.show`).
    static let frameCode = "action.rule." + MoonlitMechanismExperienceRule.frame
    /// The code of the kernel's action refusal (a step of 0, the driver or an unknown gear re-seated, a lamp step off
    /// the ladder, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + MoonlitMechanismError.action("").reasonCode
    /// The code of the kernel's stage refusal (an action outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + MoonlitMechanismError.stage.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the witness with a move omitted and recovered (odd) or an exhausted budget (even).
        case witness
        /// Rows 21 … 30: the gear and step endpoints and the refusals just outside them.
        case numeric
        /// Rows 31 … 40: a move, undo, redo, a key frame shown and a refused redo.
        case touch
        /// Rows 41 … 50: the witness won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failed run, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a move undone and redone, then the rest of the witness.
        case persistence
        /// Rows 71 … 80: the next level, its first move, an undo and a refused undo.
        case integration
    }

    /// One accepted entry of `control` with `values` after `steps` steps.
    static func acceptedEntry(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: acceptedCode)
    }

    /// One refused entry of `control` with `values`, expecting `result`, after `steps` steps.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String, steps: Int = 0) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: result)
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: MoonlitMechanismAction) -> ScriptedAction {
        switch action {
        case let .turn(step): ScriptedAction("handle.turn", [Double(step)])
        case let .reseat(gear, step): ScriptedAction("gear.reseat", [Double(gear), Double(step)])
        case let .lamp(step): ScriptedAction("lamp.step", [Double(step)])
        case .run: ScriptedAction("machine.run", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: MoonlitMechanismAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: MoonlitMechanismAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The inverse of `action`: the same move with the opposite step (a run is its own, never used).
    public static func inverse(_ action: MoonlitMechanismAction) -> MoonlitMechanismAction {
        switch action {
        case let .turn(step): .turn(-step)
        case let .reseat(gear, step): .reseat(gear, -step)
        case let .lamp(step): .lamp(-step)
        case .run: .run
        }
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> MoonlitMechanismGenerated? {
        try? generated(number: number)
    }

    /// The certified witness's actions of manifest number `number` (its turns, re-seats and lamp steps, then one run);
    /// empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [MoonlitMechanismAction] {
        certified(number)?.actions ?? []
    }

    /// The certified moves of manifest number `number` (the witness without its run); empty when the level cannot be
    /// generated.
    public static func certifiedMoves(_ number: Int) -> [MoonlitMechanismAction] {
        var moves: [MoonlitMechanismAction] = []
        for action in certifiedActions(number) where action != .run { moves.append(action) }
        return moves
    }

    /// The first certified move of manifest number `number` (every plan has at least one move, and a certified start
    /// never wins); nil when the level cannot be generated.
    static func firstMove(_ number: Int) -> MoonlitMechanismAction? {
        certifiedMoves(number).first
    }

    /// Certifies the levels of `numbers` concurrently into the process cache (certification is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The opening play of manifest number `number` (begun, past its tutorial); nil when it cannot be generated.
    static func openingPlay(_ number: Int) -> MoonlitMechanismPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The two input actions on the opening level: the first certified move, then its inverse; empty when the level
    /// cannot be generated or its budget is below 3 (so neither fails).
    public static var inputActions: [MoonlitMechanismAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), play.level.budget >= 3, let first = firstMove(number) else { return [] }
        return [first, inverse(first)]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [MoonlitMechanismAction] = inputActions
        guard !actions.isEmpty else { return [] }
        return actions.map { actionEntry($0, steps: 10) } + [acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified witness of the opening level.
    public static var completionEntries: [ScenarioStep] {
        certifiedActions(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The entries of full-playthrough: the certified witnesses of ``playthroughLevels`` with `level.next` between
    /// them.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            let actions: [MoonlitMechanismAction] = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the certified moves of the opening level without the run, so the picture shows the solved
    /// set-up while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        certifiedMoves(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The actions that spend the rest of `play`'s budget by alternating `first` and `second` (starting with `first`),
    /// the last one failing the play `budget`; empty when the play is not playing or the kernel refuses one.
    static func exhaustingActions(_ play: MoonlitMechanismPlay, alternating first: MoonlitMechanismAction,
                                  and second: MoonlitMechanismAction) -> [MoonlitMechanismAction] {
        var current: MoonlitMechanismPlay = play
        var actions: [MoonlitMechanismAction] = []
        while current.stage == .playing {
            let action: MoonlitMechanismAction = actions.count % 2 == 0 ? first : second
            guard (try? current.apply(action, expecting: current.fingerprint)) != nil else { return [] }
            actions.append(action)
        }
        if case .budget? = current.failure { return actions }
        return []
    }

    /// The entries of `fixture-budget-out`: the first certified move and its inverse alternated for the whole budget,
    /// the last action failing the play.
    public static var budgetOutEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), let first = firstMove(number) else { return [] }
        return exhaustingActions(play, alternating: first, and: inverse(first)).map { actionEntry($0) }
    }

    /// The entries of `fixture-undo-redo`: the first certified move, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let first = firstMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        guard let play = openingPlay(levelNumber(forSeed: manifestSeed)) else { return [] }
        let level: MoonlitMechanismLevel = play.level
        let highGear: Double = Double(gearRange.upperBound + 1)
        let highFrame: Double = Double(frameRange.upperBound + 1)
        var entries: [ScenarioStep] = [
            refusedEntry("handle.turn", [2], outOfRangeCode),
            refusedEntry("handle.turn", [-2], outOfRangeCode),
            refusedEntry("gear.reseat", [highGear, 1], outOfRangeCode),
            refusedEntry("gear.reseat", [-1, 1], outOfRangeCode),
            refusedEntry("gear.reseat", [1, 2], outOfRangeCode),
            refusedEntry("lamp.step", [-2], outOfRangeCode),
            refusedEntry("frame.show", [highFrame], outOfRangeCode),
            refusedEntry("frame.show", [-1], outOfRangeCode),
            refusedEntry("handle.turn", [0.5], notWholeCode),
            refusedEntry("gear.reseat", [0.5, 1], notWholeCode),
            refusedEntry("frame.show", [0.5], notWholeCode),
            refusedEntry("handle.turn", [0], kernelActionCode),
            refusedEntry("gear.reseat", [0, 1], kernelActionCode),
            refusedEntry("gear.reseat", [1, 0], kernelActionCode),
            refusedEntry("lamp.step", [0], kernelActionCode),
        ]
        if level.gears.count <= gearRange.upperBound {
            entries.append(refusedEntry("gear.reseat", [Double(level.gears.count), 1], kernelActionCode))
        }
        if play.height == 0 {
            entries.append(refusedEntry("lamp.step", [-1], kernelActionCode))
        } else if play.height == level.lampHeights - 1 {
            entries.append(refusedEntry("lamp.step", [1], kernelActionCode))
        }
        if level.keyFrames.count <= frameRange.upperBound {
            entries.append(refusedEntry("frame.show", [Double(level.keyFrames.count)], frameCode))
        }
        entries += [
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("handle.turn", [], wrongCountCode),
            refusedEntry("gear.reseat", [1], wrongCountCode),
            refusedEntry("lamp.step", [], wrongCountCode),
            refusedEntry("machine.run", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
            refusedEntry("frame.show", [], wrongCountCode),
            refusedEntry("level.select", [], wrongCountCode),
            refusedEntry("mode.daily", [2026, 1], wrongCountCode),
            refusedEntry("mode.practice", [1], wrongCountCode),
            refusedEntry("mode.campaign", [1], wrongCountCode),
            refusedEntry("tutorial.dismiss", [1], wrongCountCode),
            refusedEntry("replay.start", [], wrongCountCode),
            refusedEntry("replay.step", [1], wrongCountCode),
            refusedEntry("replay.stop", [1], wrongCountCode),
            refusedEntry("settings.sound", [], wrongCountCode),
        ]
        return entries
    }

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 49) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (050, 057, … 099, 006, … 083), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 49) % 100 + 1 }

    /// The level of each acceptance row, in row order: 80 distinct levels.
    public static var acceptanceLevels: [Int] {
        var levels: [Int] = []
        for row in 1...acceptanceRows { levels.append(acceptanceLevel(row)) }
        return levels
    }

    /// `number` written with at least three digits.
    static func threeDigits(_ number: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The scenario name of acceptance row `row` (1 … 80): `acceptance-001` … `acceptance-080` (the validator counts
    /// the `acceptance-` prefix; names are lower case).
    public static func acceptanceName(_ row: Int) -> String { "acceptance-" + threeDigits(row) }

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G14-QA-001` … `R2-G14-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G14-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`;
    /// for level 100, whose `level.next` is refused `r02-g14.locked` (no wrap), level 1 with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + MoonlitMechanismExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 435).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The failure of a run after the certified moves of manifest number `number` without move `omitted`; nil when the
    /// level cannot be generated, the kernel refuses a move or the run wins.
    static func omissionFailure(_ number: Int, omitting omitted: Int) -> MoonlitMechanismFailure? {
        guard var play = openingPlay(number) else { return nil }
        for (index, move) in certifiedMoves(number).enumerated() where index != omitted {
            guard (try? play.apply(move, expecting: play.fingerprint)) != nil else { return nil }
        }
        guard (try? play.apply(.run, expecting: play.fingerprint)) != nil else { return nil }
        return play.failure
    }

    /// The certified move of manifest number `number` that the witness and accessibility rows omit: the last one whose
    /// omission makes the run fail other than `missing` (a jam, a forbidden or a stray shadow), else the last one whose
    /// omission fails at all; nil when no omission fails (never for a minimal certified plan).
    public static func omittedMove(_ number: Int) -> Int? {
        let moves: [MoonlitMechanismAction] = certifiedMoves(number)
        var fallback: Int?
        for index in moves.indices.reversed() {
            guard let failure = omissionFailure(number, omitting: index) else { continue }
            if case .missing = failure {
                if fallback == nil { fallback = index }
                continue
            }
            return index
        }
        return fallback
    }

    /// The certified moves of manifest number `number` without ``omittedMove(_:)``, and that move; nil when the level
    /// cannot be generated or no omission fails.
    static func omission(_ number: Int) -> (kept: [MoonlitMechanismAction], omitted: MoonlitMechanismAction)? {
        let moves: [MoonlitMechanismAction] = certifiedMoves(number)
        guard let index = omittedMove(number) else { return nil }
        var kept: [MoonlitMechanismAction] = []
        for (position, move) in moves.enumerated() where position != index { kept.append(move) }
        return (kept, moves[index])
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let first = firstMove(number) else { return [] }
        let level: MoonlitMechanismLevel = play.level
        switch (row - 1) % 5 {
        case 0:   // validate timed silhouette — frame delta affects judgement: the run decides, then the play is closed
            return [actionEntry(.run), refusedAction(.turn(1), stageCode)]
        case 1:   // rotate gear — occluded controls: a gear the level lacks (out of the declared range at five gears)
            let gears: Int = level.gears.count
            let code: String = gears <= gearRange.upperBound ? kernelActionCode : outOfRangeCode
            return [actionEntry(.turn(1)), refusedAction(.reseat(gears, 1), code)]
        case 2:   // swap cog — gear penetration: the driver cannot be re-seated
            return [actionEntry(first), refusedAction(.reseat(0, 1), kernelActionCode)]
        case 3:   // adjust ratio — gear ratio drift: a fractional re-seat step
            return [actionEntry(first), ScenarioStep(steps: 1, action: ScriptedAction("gear.reseat", [1, 0.5]),
                                                     result: notWholeCode)]
        default:  // aim projector — shadow mask animation desync: a lamp step, then a key frame the level lacks
            let step: Int = play.height + 1 < level.lampHeights ? 1 : -1
            let frames: Int = level.keyFrames.count
            let code: String = frames <= frameRange.upperBound ? frameCode : outOfRangeCode
            return [actionEntry(.lamp(step)), ScenarioStep(steps: 1, action: ScriptedAction("frame.show",
                                                                                          [Double(frames)]),
                                                           result: code)]
        }
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no omission fails or the budget cannot be spent.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard var play = openingPlay(number), let first = firstMove(number) else { return [] }
        if row % 2 == 1 {
            guard let omission = omission(number) else { return [] }
            return omission.kept.map { actionEntry($0) }
                + [actionEntry(.run), acceptedEntry("play.undo"), actionEntry(omission.omitted), actionEntry(.run)]
        }
        var entries: [ScenarioStep] = []
        for move in certifiedMoves(number) {
            guard (try? play.apply(move, expecting: play.fingerprint)) != nil else { return [] }
            entries.append(actionEntry(move))
        }
        let spending: [MoonlitMechanismAction] = exhaustingActions(play, alternating: inverse(first), and: first)
        guard !spending.isEmpty else { return [] }
        for action in spending { entries.append(actionEntry(action)) }
        entries.append(refusedAction(.run, stageCode))
        return entries
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number) else { return [] }
        let gears: Int = play.level.gears.count
        var entries: [ScenarioStep] = [
            actionEntry(.reseat(1, stepRange.lowerBound)),
            actionEntry(.reseat(gears - 1, stepRange.upperBound)),
        ]
        if row % 2 == 1 {
            entries.append(refusedAction(.reseat(1, stepRange.lowerBound - 1), outOfRangeCode))
        } else {
            entries.append(refusedAction(.reseat(gearRange.upperBound + 1, 1), outOfRangeCode))
        }
        entries += [refusedAction(.reseat(gearRange.lowerBound - 1, 1), outOfRangeCode),
                    refusedAction(.reseat(1, 0), kernelActionCode),
                    refusedAction(.turn(0), kernelActionCode)]
        if gears <= gearRange.upperBound {
            entries.append(refusedAction(.reseat(gears, 1), kernelActionCode))
        }
        entries += [acceptedEntry("play.undo"), acceptedEntry("play.undo")]
        return entries
    }

    /// The entries of a touch row on level `number` (see the file header); empty when the level cannot be generated.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let first = firstMove(number) else { return [] }
        return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                acceptedEntry("frame.show", [Double(play.level.keyFrames.count - 1)]),
                refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The entries of accessibility row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or no omission fails.
    static func accessibilityEntries(row: Int, number: Int) -> [ScenarioStep] {
        if row % 2 == 1 { return [actionEntry(.run), acceptedEntry("play.undo")] }
        guard let omission = omission(number) else { return [] }
        return omission.kept.map { actionEntry($0) } + [actionEntry(.run), acceptedEntry("play.undo")]
    }

    /// The entries of acceptance row `row` (1 … 80) on its level (see the file header); empty when the level cannot be
    /// generated.
    public static func acceptanceEntries(row: Int) -> [ScenarioStep] {
        let number: Int = acceptanceLevel(row)
        let actions: [MoonlitMechanismAction] = certifiedActions(number)
        guard let first = actions.first, first != .run else { return [] }
        switch acceptanceFamily(row) {
        case .truth:
            return truthEntries(row: row, number: number)
        case .witness:
            return witnessEntries(row: row, number: number)
        case .numeric:
            return numericEntries(row: row, number: number)
        case .touch:
            return touchEntries(number: number)
        case .rendering:
            return actions.map { actionEntry($0) } + [refusedEntry("play.undo", [], stageCode, steps: 1)]
        case .accessibility:
            return accessibilityEntries(row: row, number: number)
        case .persistence:
            return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
                + actions.dropFirst().map { actionEntry($0) }
        case .integration:
            guard let next = firstMove(nextLevel(after: number)) else { return [] }
            return actions.map { actionEntry($0) } + integrationMoveEntries(number)
                + [actionEntry(next), acceptedEntry("play.undo"),
                   refusedEntry("play.undo", [], kernelActionCode, steps: 1)]
        }
    }

    /// The acceptance scenarios, one per row: its name, seed and entries (see the file header). Empty when a level
    /// cannot be generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        var needed: [Int] = acceptanceLevels + playthroughLevels
        for row in 1...acceptanceRows where acceptanceFamily(row) == .integration {
            needed.append(nextLevel(after: acceptanceLevel(row)))
        }
        prewarm(needed)
        for row in 1...acceptanceRows {
            let entries: [ScenarioStep] = acceptanceEntries(row: row)
            guard !entries.isEmpty else { return [] }
            list.append((acceptanceName(row), seed(forLevel: acceptanceLevel(row)), entries))
        }
        return list
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them (nil: none).
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String?)] {
        [("fixture-level-1-solved", completionEntries, wonCode),
         ("fixture-budget-out", budgetOutEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> MoonlitMechanismExperienceCore? {
        guard var core = try? opening(number: levelNumber(forSeed: seed)) else { return nil }
        var step = 0
        for entry in entries {
            for _ in 0..<max(0, entry.steps) {
                core.update(step: step)
                step += 1
            }
            guard let action = entry.action else { continue }
            if ExperienceInput.validate(control: action.control, values: action.values, controls: controls) != nil {
                continue
            }
            var next = core
            if next.apply(ExperienceAction(control: action.control, values: action.values, step: step)).isAccepted {
                core = next
            }
        }
        return core
    }

    /// The digest of the core prepared with `seed` after `entries`, computed as the engine computes it; nil when the
    /// level cannot be generated or the digest cannot be written.
    public static func expectedDigest(for id: ExperienceID, seed: UInt64, entries: [ScenarioStep]) -> String? {
        guard let core = played(seed: seed, entries: entries) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        do { try core.writeDigest(into: &builder) } catch { return nil }
        return builder.finish().hex
    }

    /// The scenario manifest of the experience `id`: a round-two game (see the file header).
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest {
        let input = inputEntries
        let initial = expectedDigest(for: id, seed: seed, entries: [])
        let final = expectedDigest(for: id, seed: seed, entries: input)
        let playthrough = playthroughEntries
        let hero = heroEntries
        var specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "completion", seed: seed, entries: completionEntries,
                         expect: ScenarioExpectations(outcome: wonCode)),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: initial)),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
            ScenarioSpec(name: "full-playthrough", seed: seed, entries: playthrough,
                         expect: ScenarioExpectations(initialDigest: initial,
                                                      finalDigest: expectedDigest(for: id, seed: seed,
                                                                                  entries: playthrough),
                                                      outcome: wonCode)),
            ScenarioSpec(name: "hero", seed: seed, entries: hero,
                         expect: ScenarioExpectations(initialDigest: initial,
                                                      finalDigest: expectedDigest(for: id, seed: seed,
                                                                                  entries: hero))),
        ]
        for acceptance in acceptanceScenarios {
            let end = played(seed: acceptance.seed, entries: acceptance.entries)
            specs.append(ScenarioSpec(name: acceptance.name, seed: acceptance.seed, entries: acceptance.entries,
                                      expect: ScenarioExpectations(
                                          initialDigest: expectedDigest(for: id, seed: acceptance.seed, entries: []),
                                          finalDigest: expectedDigest(for: id, seed: acceptance.seed,
                                                                      entries: acceptance.entries),
                                          outcome: end?.outcome?.code)))
        }
        for fixture in fixtures {
            specs.append(ScenarioSpec(name: fixture.name, seed: seed, entries: fixture.entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: expectedDigest(
                                                                       for: id, seed: seed, entries: fixture.entries),
                                                                   outcome: fixture.outcome)))
        }
        return ScenarioManifest(experience: id, kind: .game, round: manifestRound, scenarios: specs)
    }
}
#endif
