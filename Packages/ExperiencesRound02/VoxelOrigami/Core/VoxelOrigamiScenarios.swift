// VoxelOrigamiScenarios — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-005; clarification Q5). The scenarios
// the verification runner plays for Voxel Origami, a round-two game, all short (owner rule of 2026-11-13), on the
// pattern of Moonlit Mechanism's (feature 433):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G15-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1, outcome `won`), `fixture-budget-out`
//     (a clear turn and its inverse alternated until the budget is spent, the last turn failing the play `budget`,
//     outcome `failed`) and `fixture-undo-redo` (the probe turn, its undo and its redo).
// Every certified turn comes from the generated level's minimal plan (`VoxelOrigamiGenerated.plan.turns`, equal to the
// stored witness `docs/games/voxel-origami/levels/NNN.witness.json`), so a regenerated catalog cannot leave a stale
// script. The inverse of a turn is the same hinge turned the other way. A certified plan may be a single turn (band 1
// plans have 1 … 2 turns), so a scenario that must stay open uses the level's probe turn: the first certified turn when
// neither it nor its inverse right after it wins or fails, else the first legal turn (the rules' move order) with that
// property. The two input actions are the probe turn and its inverse; input-response, save-restore and reset play both
// and undo the second; completion plays the certified plan of level 1 and expects `won`; full-playthrough solves
// levels 1, 2 and 3 with `level.next` between them; hero plays the certified plan of level 1 without its last turn and
// chooses that turn's hinge, so the picture shows the hinge that completes the shape while the play is still open;
// rejection refuses values outside the declared ranges, fractional values, actions the kernel refuses (the root, a
// hinge the level lacks, a step of 0, an idle hinge, an undo or redo with nothing to revert), a chosen hinge the level
// lacks and wrong value counts (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 52) mod 100 + 1 for rows 1 … 20 (053, 060, … 095, 002, … 086); the
// same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to 100), each
// opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted on the real
// controls with the outcome the kernel gives; the row's command cycles through the matrix's five (lock shape, fold
// hinge, select voxel, rotate assembly, inspect collision) and its illegal condition through the matrix's five:
//   1 … 10  truth and state transitions — a legal command then an illegal one, by (r − 1) mod 5: the probe turn, then
//           the root turned, refused `r02-g15.action` (hinge connectivity; voxel z-fighting); the probe turn, then a
//           hinge the level lacks, refused `r02-g15.action` (out of range at twelve cubes; inaccessible rear handles);
//           the probe turn's hinge chosen, then the root chosen, refused `r02-g15.hinge` (select voxel; canonical
//           polycube hash); the probe turn, then a step of 0.5 refused `r02-g15.not-whole` (target equivalence; mirror
//           false match); the probe turn, then a step of 0 refused `r02-g15.action` (integer grid occupancy);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last turn perturbed (its inverse, or
//           the first legal turn there that does not win), which does not win, an undo and the certified last turn
//           (won); even rows: a clear turn and its inverse alternated until the budget is spent (failed `budget`), then
//           a turn refused `r02-g15.stage`;
//  21 … 30  numeric and geometry edges — the highest and the lowest hinge of the level chosen (the hinge endpoints),
//           then a step of −2 (odd rows) or hinge 12 (even rows) refused out of range, hinge −1 refused out of range,
//           the root and a step of 0 refused `r02-g15.action`, a hinge the level lacks refused `r02-g15.action` (when
//           the level has fewer than 12 cubes), then the probe turn and its undo back to the opening digest;
//  31 … 40  touch and camera semantics — the probe turn, undo, redo (the moved digest again), its hinge chosen
//           (presentation: the digest does not change), then a second redo refused `r02-g15.action`;
//  41 … 50  rendering — the certified plan (won, the shape glows; the digest is the same at every quality tier), then
//           an undo refused `r02-g15.stage` (a won play is final);
//  51 … 60  accessibility and safety — odd rows: a clear turn and its inverse alternated until the budget is spent
//           (failed `budget`, named in words); even rows: the certified turns before the first turn that the lattice
//           refuses (`collision` on rows ≡ 2 mod 4, `sweep` on rows ≡ 0 mod 4 when the level has one, else the other,
//           else the budget path); then an undo, an honest retry back to the digest before the failing turn;
//  61 … 70  persistence and replay — the probe turn, undo, redo, undo, then the certified plan (won; the saved trace
//           replays to the same state);
//  71 … 80  integration — the certified plan (won, the next level opened), `level.next` (the next certified level, a
//           fresh play), its probe turn, an undo (the next level's fresh play) and a second undo refused
//           `r02-g15.action`; on level 100 (no row reaches it today) `level.next` is refused `r02-g15.locked` after the
//           win (no wrap) and the row chooses level 1 with `level.select [1]` instead.
// Feature 445 (R02-G15-05) T-R02G1505-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`; the
// integration rows (71 … 80) therefore first win their level's certified plan (a campaign win opens the next level)
// before `level.next`; rejection also refuses the progression controls' wrong value counts (`level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest was regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`).
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension VoxelOrigamiExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G15-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional hinge or step.
    static let notWholeCode = "action.rule." + VoxelOrigamiExperienceRule.notWhole
    /// The code of a chosen hinge the level lacks or the root (`hinge.choose`).
    static let hingeCode = "action.rule." + VoxelOrigamiExperienceRule.hinge
    /// The code of the kernel's action refusal (the root, a hinge the level lacks, a step of 0, an idle hinge, nothing
    /// to undo or redo).
    static let kernelActionCode = "action.rule." + VoxelOrigamiError.action("").reasonCode
    /// The code of the kernel's stage refusal (a turn outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + VoxelOrigamiError.stage.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last turn perturbed and recovered (odd) or an exhausted budget (even).
        case witness
        /// Rows 21 … 30: the hinge endpoints and the refusals just outside them.
        case numeric
        /// Rows 31 … 40: a turn, undo, redo, a hinge chosen and a refused redo.
        case touch
        /// Rows 41 … 50: the plan won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failing turn, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a turn undone, redone and undone, then the plan.
        case persistence
        /// Rows 71 … 80: the next level, its probe turn, an undo and a refused undo.
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
    static func scripted(_ action: VoxelOrigamiAction) -> ScriptedAction {
        switch action {
        case let .turn(hinge, step): ScriptedAction("hinge.turn", [Double(hinge), Double(step)])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: VoxelOrigamiAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: VoxelOrigamiAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The accepted entry that chooses `hinge` (presentation only).
    static func chooseEntry(_ hinge: Int) -> ScenarioStep {
        acceptedEntry("hinge.choose", [Double(hinge)])
    }

    /// The inverse of `action`: the same hinge turned the other way.
    public static func inverse(_ action: VoxelOrigamiAction) -> VoxelOrigamiAction {
        switch action {
        case let .turn(hinge, step): .turn(hinge, -step)
        }
    }

    /// The hinge `action` turns.
    public static func hinge(of action: VoxelOrigamiAction) -> Int {
        switch action {
        case let .turn(hinge, _): hinge
        }
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> VoxelOrigamiGenerated? {
        try? generated(number: number)
    }

    /// The certified plan's turns of manifest number `number`; empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [VoxelOrigamiAction] {
        certified(number)?.plan.turns ?? []
    }

    /// Certifies the levels of `numbers` concurrently into the process cache (certification is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The opening play of manifest number `number` (begun, past its tutorial); nil when it cannot be generated.
    static func openingPlay(_ number: Int) -> VoxelOrigamiPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The legal turns of `play` in the rules' order (each turnable hinge, step −1 then +1).
    static func legalTurns(_ play: VoxelOrigamiPlay) -> [VoxelOrigamiAction] {
        let position = VoxelOrigamiRules.Position(turns: play.turns, actionsSpent: play.actionsSpent,
                                                  outcome: .playing)
        return VoxelOrigamiRules(level: play.level).moves(in: position)
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: VoxelOrigamiPlay, _ action: VoxelOrigamiAction) -> VoxelOrigamiPlay? {
        var next: VoxelOrigamiPlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// The probe turn of manifest number `number`: the first certified turn when neither it nor its inverse right after
    /// it wins or fails, else the first legal turn at the opening with that property; nil when there is none.
    public static func probeMove(_ number: Int) -> VoxelOrigamiAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [VoxelOrigamiAction] = []
        if let first = certifiedActions(number).first { candidates.append(first) }
        candidates += legalTurns(play)
        for move in candidates {
            guard let moved = after(play, move), moved.stage == .playing else { continue }
            guard let back = after(moved, inverse(move)), back.stage == .playing else { continue }
            return move
        }
        return nil
    }

    /// The two input actions on the opening level: the probe turn, then its inverse; empty when there is none.
    public static var inputActions: [VoxelOrigamiAction] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [probe, inverse(probe)]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [VoxelOrigamiAction] = inputActions
        guard !actions.isEmpty else { return [] }
        return actions.map { actionEntry($0, steps: 10) } + [acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified plan of the opening level.
    public static var completionEntries: [ScenarioStep] {
        certifiedActions(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The entries of full-playthrough: the certified plans of ``playthroughLevels`` with `level.next` between them.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            let actions: [VoxelOrigamiAction] = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the certified plan of the opening level without its last turn, then that turn's hinge
    /// chosen, so the picture shows the hinge that completes the shape while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let actions: [VoxelOrigamiAction] = certifiedActions(levelNumber(forSeed: manifestSeed))
        guard let last = actions.last else { return [] }
        return actions.dropLast().map { actionEntry($0) } + [chooseEntry(hinge(of: last))]
    }

    /// The actions that spend the rest of `play`'s budget by alternating `first` and `second` (starting with `first`),
    /// the last one failing the play `budget`; empty when the play is not playing, a turn wins or fails otherwise, or
    /// the kernel refuses one.
    static func exhaustingActions(_ play: VoxelOrigamiPlay, alternating first: VoxelOrigamiAction,
                                  and second: VoxelOrigamiAction) -> [VoxelOrigamiAction] {
        var current: VoxelOrigamiPlay = play
        var actions: [VoxelOrigamiAction] = []
        while current.stage == .playing {
            let action: VoxelOrigamiAction = actions.count % 2 == 0 ? first : second
            guard let next = after(current, action) else { return [] }
            current = next
            actions.append(action)
        }
        if case .budget? = current.failure { return actions }
        return []
    }

    /// The actions that spend the whole budget of `play`: the first legal turn (the first certified turn tried first)
    /// that alternated with its inverse fails the play `budget`; empty when there is none.
    static func budgetSpending(_ play: VoxelOrigamiPlay,
                               preferring first: VoxelOrigamiAction?) -> [VoxelOrigamiAction] {
        var candidates: [VoxelOrigamiAction] = []
        if let first { candidates.append(first) }
        candidates += legalTurns(play)
        for move in candidates {
            let spending: [VoxelOrigamiAction] = exhaustingActions(play, alternating: move, and: inverse(move))
            if !spending.isEmpty { return spending }
        }
        return []
    }

    /// The budget-spending turns of manifest number `number` from its opening (see ``budgetSpending(_:preferring:)``).
    static func budgetPath(_ number: Int) -> [VoxelOrigamiAction] {
        guard let play = openingPlay(number) else { return [] }
        return budgetSpending(play, preferring: certifiedActions(number).first)
    }

    /// The entries of `fixture-budget-out`: a clear turn and its inverse alternated for the whole budget, the last
    /// turn failing the play.
    public static var budgetOutEntries: [ScenarioStep] {
        budgetPath(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The entries of `fixture-undo-redo`: the probe turn, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The first hinge of `play` that cannot turn at its turns (a leaf, or every descendant on its axis); nil when
    /// every hinge can.
    static func idleHinge(_ play: VoxelOrigamiPlay) -> Int? {
        for hinge in 1..<play.level.cubes.count where !play.level.canTurn(hinge, turns: play.turns) { return hinge }
        return nil
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        guard let play = openingPlay(levelNumber(forSeed: manifestSeed)) else { return [] }
        let cubes: Int = play.level.cubes.count
        let highHinge: Double = Double(hingeRange.upperBound + 1)
        var entries: [ScenarioStep] = [
            refusedEntry("hinge.turn", [highHinge, 1], outOfRangeCode),
            refusedEntry("hinge.turn", [-1, 1], outOfRangeCode),
            refusedEntry("hinge.turn", [1, 2], outOfRangeCode),
            refusedEntry("hinge.turn", [1, -2], outOfRangeCode),
            refusedEntry("hinge.choose", [highHinge], outOfRangeCode),
            refusedEntry("hinge.choose", [-1], outOfRangeCode),
            refusedEntry("hinge.turn", [0.5, 1], notWholeCode),
            refusedEntry("hinge.turn", [1, 0.5], notWholeCode),
            refusedEntry("hinge.choose", [0.5], notWholeCode),
            refusedEntry("hinge.turn", [0, 1], kernelActionCode),
            refusedEntry("hinge.turn", [1, 0], kernelActionCode),
            refusedEntry("hinge.choose", [0], hingeCode),
        ]
        if cubes <= hingeRange.upperBound {
            entries.append(refusedEntry("hinge.turn", [Double(cubes), 1], kernelActionCode))
            entries.append(refusedEntry("hinge.choose", [Double(cubes)], hingeCode))
        }
        if let idle = idleHinge(play) {
            entries.append(refusedEntry("hinge.turn", [Double(idle), 1], kernelActionCode))
        }
        entries += [
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("hinge.turn", [], wrongCountCode),
            refusedEntry("hinge.turn", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
            refusedEntry("hinge.choose", [], wrongCountCode),
            refusedEntry("hinge.choose", [1, 1], wrongCountCode),
            refusedEntry("level.select", [], wrongCountCode),
            refusedEntry("mode.daily", [2026, 1], wrongCountCode),
            refusedEntry("mode.practice", [1], wrongCountCode),
            refusedEntry("mode.campaign", [1], wrongCountCode),
            refusedEntry("tutorial.dismiss", [1], wrongCountCode),
        ]
        return entries
    }

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 52) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (053, 060, … 095, 002, … 086), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 52) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G15-QA-001` … `R2-G15-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G15-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`;
    /// for level 100, whose `level.next` is refused `r02-g15.locked` (no wrap), level 1 with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + VoxelOrigamiExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 445).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The perturbed last turn of manifest number `number`: after the certified plan without its last turn, the
    /// inverse of that turn, else the first legal turn there other than it, that does not win; nil when there is none.
    public static func perturbedLast(_ number: Int) -> VoxelOrigamiAction? {
        let actions: [VoxelOrigamiAction] = certifiedActions(number)
        guard var play = openingPlay(number), let last = actions.last else { return nil }
        for action in actions.dropLast() {
            guard let next = after(play, action) else { return nil }
            play = next
        }
        var candidates: [VoxelOrigamiAction] = [inverse(last)]
        candidates += legalTurns(play)
        for move in candidates where move != last {
            guard let moved = after(play, move), moved.stage != .won else { continue }
            return move
        }
        return nil
    }

    /// The certified turns before the first turn the lattice refuses, and that turn, on manifest number `number`: the
    /// plays after each proper prefix of the certified plan are searched in order (each in the rules' move order) for a
    /// turn that fails `collision` or `sweep`; the first of `preferred` wins, else the first of the other; nil when the
    /// level has none.
    static func failingTurn(_ number: Int, preferring preferred: String)
        -> (prefix: [VoxelOrigamiAction], turn: VoxelOrigamiAction)? {
        let actions: [VoxelOrigamiAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [VoxelOrigamiAction], turn: VoxelOrigamiAction)?
        for count in 0..<actions.count {
            if count > 0 {
                guard let next = after(play, actions[count - 1]), next.stage == .playing else { break }
                play = next
            }
            for move in legalTurns(play) {
                guard let moved = after(play, move), moved.stage == .failed, let failure = moved.failure else {
                    continue
                }
                if case .budget = failure { continue }
                let found: (prefix: [VoxelOrigamiAction], turn: VoxelOrigamiAction) = (Array(actions.prefix(count)),
                                                                                        move)
                if failure.code == preferred { return found }
                if fallback == nil { fallback = found }
            }
        }
        return fallback
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no probe turn.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number) else { return [] }
        let cubes: Int = play.level.cubes.count
        let probeHinge: Int = hinge(of: probe)
        switch (row - 1) % 5 {
        case 0:   // lock shape — hinge connectivity: the root has no hinge to turn
            return [actionEntry(probe), refusedAction(.turn(0, 1), kernelActionCode)]
        case 1:   // fold hinge — inaccessible rear handles: a hinge the level lacks (out of range at twelve cubes)
            let code: String = cubes <= hingeRange.upperBound ? kernelActionCode : outOfRangeCode
            return [actionEntry(probe), refusedAction(.turn(cubes, 1), code)]
        case 2:   // select voxel — canonical polycube hash: choosing never changes the state; the root is no hinge
            return [chooseEntry(probeHinge), refusedEntry("hinge.choose", [0], hingeCode, steps: 1)]
        case 3:   // rotate assembly — mirror-shape false match: a fractional step
            return [actionEntry(probe), refusedEntry("hinge.turn", [Double(probeHinge), 0.5], notWholeCode, steps: 1)]
        default:  // inspect collision — hinge detachment: a step of 0 turns nothing
            return [actionEntry(probe), refusedAction(.turn(probeHinge, 0), kernelActionCode)]
        }
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or the budget cannot be spent.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [VoxelOrigamiAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            return actions.dropLast().map { actionEntry($0) }
                + [actionEntry(perturbed), acceptedEntry("play.undo"), actionEntry(last)]
        }
        let spending: [VoxelOrigamiAction] = budgetPath(number)
        guard !spending.isEmpty else { return [] }
        return spending.map { actionEntry($0) } + [refusedAction(actions[0], stageCode)]
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no probe turn.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number) else { return [] }
        let cubes: Int = play.level.cubes.count
        var entries: [ScenarioStep] = [chooseEntry(cubes - 1), chooseEntry(1)]
        if row % 2 == 1 {
            entries.append(refusedAction(.turn(1, stepRange.lowerBound - 1), outOfRangeCode))
        } else {
            entries.append(refusedAction(.turn(hingeRange.upperBound + 1, 1), outOfRangeCode))
        }
        entries += [refusedAction(.turn(hingeRange.lowerBound - 1, 1), outOfRangeCode),
                    refusedAction(.turn(0, 1), kernelActionCode),
                    refusedAction(.turn(hinge(of: probe), 0), kernelActionCode)]
        if cubes <= hingeRange.upperBound {
            entries.append(refusedAction(.turn(cubes, 1), kernelActionCode))
        }
        entries += [actionEntry(probe), acceptedEntry("play.undo")]
        return entries
    }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe turn.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let probe = probeMove(number) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                chooseEntry(hinge(of: probe)), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The entries of accessibility row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or the budget cannot be spent.
    static func accessibilityEntries(row: Int, number: Int) -> [ScenarioStep] {
        if row % 2 == 0, let failing = failingTurn(number, preferring: row % 4 == 2 ? "collision" : "sweep") {
            return failing.prefix.map { actionEntry($0) } + [actionEntry(failing.turn), acceptedEntry("play.undo")]
        }
        let spending: [VoxelOrigamiAction] = budgetPath(number)
        guard !spending.isEmpty else { return [] }
        return spending.map { actionEntry($0) } + [acceptedEntry("play.undo")]
    }

    /// The entries of acceptance row `row` (1 … 80) on its level (see the file header); empty when the level cannot be
    /// generated.
    public static func acceptanceEntries(row: Int) -> [ScenarioStep] {
        let number: Int = acceptanceLevel(row)
        let actions: [VoxelOrigamiAction] = certifiedActions(number)
        guard !actions.isEmpty else { return [] }
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
            guard let probe = probeMove(number) else { return [] }
            return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                    acceptedEntry("play.undo")] + actions.map { actionEntry($0) }
        case .integration:
            guard let next = probeMove(nextLevel(after: number)) else { return [] }
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> VoxelOrigamiExperienceCore? {
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
