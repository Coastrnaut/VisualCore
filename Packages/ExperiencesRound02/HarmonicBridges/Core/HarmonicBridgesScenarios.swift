// HarmonicBridgesScenarios — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-005; clarification Q5). The
// scenarios the verification runner plays for Harmonic Bridges, a round-two game, all short (owner rule of 2026-11-13),
// on the pattern of Echo Cartographer's (feature 403):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G12-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified witness of level 1, outcome `won`),
//     `fixture-budget-out` (the first certified string tuned back and forth until the budget is spent, the last tuning
//     failing the play `budget`, outcome `failed`) and `fixture-undo-redo` (the first certified tuning, its undo and
//     its redo).
// Every certified action comes from the generated level's plan (`HarmonicBridgesGenerated.actions`, equal to the stored
// witness `docs/games/harmonic-bridges/levels/NNN.witness.json`), so a regenerated catalog cannot leave a stale script.
// The two input actions tune the first certified string to its certified peg and back to its starting peg (neither
// wins: only a test decides; with a budget above 2, neither fails); input-response, save-restore and reset play both
// and undo the second; completion plays the certified witness of level 1 and expects `won`; full-playthrough solves
// levels 1, 2 and 3 with `level.next` between them; hero plays the certified tunings of level 1 without the test, so the
// picture shows the bridges formed; rejection refuses values outside the declared ranges, fractional values, actions
// the kernel refuses (a string the level lacks, a locked string when the level has one, a tuning to the current peg,
// an undo or redo with nothing to revert) and wrong value counts (never an undeclared control: the content audit
// forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 43) mod 100 + 1 for rows 1 … 20 (044, 051, … 100, 007, … 077); the
// same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to 100), each
// opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted on the real
// controls with the outcome the kernel gives:
//   1 … 10  truth and state transitions — a legal command then an illegal one; the pair follows the row's command and
//           condition (r − 1) mod 5: the first certified tuning, then a locked string (or a string the level lacks)
//           refused `r02-g12.action`; the first certified tuning, then peg 13 refused out of range; the first
//           certified tuning twice, the second refused `r02-g12.noop`; the first certified tuning, then peg 2.5
//           refused `r02-g12.not-whole`; a test at the opening pegs (failed `broken`), then a tuning refused
//           `r02-g12.stage`;
//  11 … 20  solver witness and rejection — odd rows: the certified tunings with the last one perturbed to the lowest
//           other peg whose test breaks (failed `broken`), two undos, the certified last tuning and the test (won);
//           even rows: the certified tunings, then the first certified string tuned back and forth until the budget is
//           spent (failed `budget`), then a test refused `r02-g12.stage`;
//  21 … 30  numeric and geometry edges — the lowest unlocked string to both peg endpoints (1 and 12), then peg 0 and
//           (odd rows) string 12 or (even rows) peg 13 refused out of range, a string the level lacks refused
//           `r02-g12.action` (when the level has fewer than 12 strings), then two undos back to the opening digest;
//  31 … 40  touch and camera semantics — the first certified tuning, undo, redo (the tuned digest again), then a
//           second redo refused `r02-g12.action`;
//  41 … 50  rendering — the certified witness (won, the bridges brightened), then an undo refused `r02-g12.stage` (a
//           won play is final);
//  51 … 60  accessibility and safety — a test at the opening pegs (failed `broken`, the outline names the break), then
//           an undo, an honest retry back to the opening digest;
//  61 … 70  persistence and replay — the first certified tuning, undo, redo, then the rest of the witness (won; the
//           saved trace replays to the same state);
//  71 … 80  integration — the certified witness (won, the next level opened), `level.next` (the next certified level,
//           a fresh play), its first certified tuning, an undo (the next level's fresh play) and a second undo refused
//           `r02-g12.action`.
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
// Feature 415 (R02-G12-05) T-R02G1205-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`;
// the integration rows (71 … 80) therefore first win their level's certified witness (a campaign win opens the next
// level) before `level.next`; rejection also refuses the progression controls' wrong value counts (`level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest was regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`). Feature 417 (R02-G12-07) T-R02G1207-003: digests are schema 3's ("…v3"), wins store
// their traces, and rejection also refuses the replay and sound controls' wrong value counts (`replay.start`,
// `replay.step`, `replay.stop`, `settings.sound`); the manifest was regenerated.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension HarmonicBridgesExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G12-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional string index or peg.
    static let notWholeCode = "action.rule." + HarmonicBridgesExperienceRule.notWhole
    /// The code of the kernel's action refusal (a string the level lacks, a locked string, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + HarmonicBridgesError.action("").reasonCode
    /// The code of the kernel's no-op refusal (a tuning to the string's current peg).
    static let noopCode = "action.rule." + HarmonicBridgesError.noop.reasonCode
    /// The code of the kernel's stage refusal (an action outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + HarmonicBridgesError.stage.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the witness with a perturbed tuning recovered (odd) or an exhausted budget (even).
        case witness
        /// Rows 21 … 30: the peg endpoints and the refusals just outside them.
        case numeric
        /// Rows 31 … 40: a tuning, undo, redo and a refused redo.
        case touch
        /// Rows 41 … 50: the witness won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a broken test, then an undo back to the opening.
        case accessibility
        /// Rows 61 … 70: a tuning undone and redone, then the rest of the witness.
        case persistence
        /// Rows 71 … 80: the witness won, the next level, its first tuning, an undo and a refused undo.
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
    static func scripted(_ action: HarmonicBridgesAction) -> ScriptedAction {
        switch action {
        case let .tune(string, peg): ScriptedAction("string.tune", [Double(string), Double(peg)])
        case .test: ScriptedAction("crossing.test", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: HarmonicBridgesAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: HarmonicBridgesAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> HarmonicBridgesGenerated? {
        try? generated(number: number)
    }

    /// The certified witness's actions of manifest number `number` (its tunings, then one test); empty when the level
    /// cannot be generated.
    public static func certifiedActions(_ number: Int) -> [HarmonicBridgesAction] {
        certified(number)?.actions ?? []
    }

    /// The certified tunings of manifest number `number` (the witness without its test); empty when the level cannot be
    /// generated.
    public static func certifiedTunings(_ number: Int) -> [HarmonicBridgesAction] {
        var tunings: [HarmonicBridgesAction] = []
        for action in certifiedActions(number) where action != .test { tunings.append(action) }
        return tunings
    }

    /// Certifies the levels of `numbers` concurrently into the process cache (certification is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The opening play of manifest number `number` (begun, past its tutorial); nil when it cannot be generated.
    static func openingPlay(_ number: Int) -> HarmonicBridgesPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The two input actions on the opening level: the first certified string tuned to its certified peg, then back to
    /// its starting peg; empty when the level cannot be generated or its budget is below 3 (so neither fails).
    public static var inputActions: [HarmonicBridgesAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), play.level.budget >= 3,
              case let .tune(string, peg)? = certifiedTunings(number).first else { return [] }
        return [.tune(string, peg), .tune(string, play.pegs[string])]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [HarmonicBridgesAction] = inputActions
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
            let actions: [HarmonicBridgesAction] = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the certified tunings of the opening level without the test, so the picture shows the
    /// bridges formed while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        certifiedTunings(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The tunings that spend the rest of `play`'s budget by moving `string` between `first` and `second` (starting
    /// with whichever differs from its current peg), the last one failing the play `budget`; empty when the play is not
    /// playing or the kernel refuses one.
    static func exhaustingTunings(_ play: HarmonicBridgesPlay, string: Int, between first: Int,
                                  and second: Int) -> [HarmonicBridgesAction] {
        var current: HarmonicBridgesPlay = play
        var tunings: [HarmonicBridgesAction] = []
        while current.stage == .playing {
            let peg: Int = current.pegs[string] == first ? second : first
            let tuning: HarmonicBridgesAction = .tune(string, peg)
            guard (try? current.apply(tuning, expecting: current.fingerprint)) != nil else { return [] }
            tunings.append(tuning)
        }
        if case .budget? = current.failure { return tunings }
        return []
    }

    /// The entries of `fixture-budget-out`: the first certified string tuned between its certified and starting pegs
    /// for the whole budget, the last tuning failing the play.
    public static var budgetOutEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), case let .tune(string, peg)? = certifiedTunings(number).first else {
            return []
        }
        return exhaustingTunings(play, string: string, between: peg, and: play.pegs[string]).map { actionEntry($0) }
    }

    /// The entries of `fixture-undo-redo`: the first certified tuning, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let first = certifiedTunings(levelNumber(forSeed: manifestSeed)).first else { return [] }
        return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The lowest-index locked string of `level`, or nil.
    static func lockedString(_ level: HarmonicBridgesLevel) -> Int? {
        for (index, string) in level.strings.enumerated() where string.locked { return index }
        return nil
    }

    /// The lowest-index unlocked string of `level`, or nil.
    static func unlockedString(_ level: HarmonicBridgesLevel) -> Int? {
        for (index, string) in level.strings.enumerated() where !string.locked { return index }
        return nil
    }

    /// A peg other than `peg`: 1, or 2 when `peg` is 1.
    static func otherPeg(_ peg: Int) -> Int { peg == 1 ? 2 : 1 }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        guard let play = openingPlay(levelNumber(forSeed: manifestSeed)) else { return [] }
        let level: HarmonicBridgesLevel = play.level
        var entries: [ScenarioStep] = [
            refusedEntry("string.tune", [12, 1], outOfRangeCode),
            refusedEntry("string.tune", [-1, 1], outOfRangeCode),
            refusedEntry("string.tune", [0, 0], outOfRangeCode),
            refusedEntry("string.tune", [0, 13], outOfRangeCode),
            refusedEntry("string.tune", [0.5, 2], notWholeCode),
            refusedEntry("string.tune", [0, 1.5], notWholeCode),
        ]
        if level.strings.count <= stringRange.upperBound {
            entries.append(refusedEntry("string.tune", [Double(level.strings.count), 1], kernelActionCode))
        }
        if let locked = lockedString(level) {
            let peg: Int = otherPeg(play.pegs[locked])
            entries.append(refusedEntry("string.tune", [Double(locked), Double(peg)], kernelActionCode))
        }
        if let open = unlockedString(level) {
            entries.append(refusedEntry("string.tune", [Double(open), Double(play.pegs[open])], noopCode))
        }
        entries += [
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("string.tune", [1], wrongCountCode),
            refusedEntry("crossing.test", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
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

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 43) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (044, 051, … 100, 007, … 077), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 43) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G12-QA-001` … `R2-G12-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G12-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level after `number` as the integration rows reach it with `level.next` after a campaign win (no row's
    /// level is 100, whose `level.next` is refused).
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The lowest peg other than the certified one and `play`'s current one for which tuning `string` and testing
    /// breaks the crossing (failed `broken`), found by the kernel; nil when every other peg wins or is refused.
    static func breakingPeg(_ play: HarmonicBridgesPlay, string: Int, certified: Int) -> Int? {
        for peg in pegRange where peg != certified && peg != play.pegs[string] {
            var trial: HarmonicBridgesPlay = play
            guard (try? trial.apply(.tune(string, peg), expecting: trial.fingerprint)) != nil,
                  trial.stage == .playing,
                  (try? trial.apply(.test, expecting: trial.fingerprint)) != nil else { continue }
            if case .broken? = trial.failure { return peg }
        }
        return nil
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be generated.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), case let .tune(string, peg)? = certifiedTunings(number).first else {
            return []
        }
        let level: HarmonicBridgesLevel = play.level
        let legal: ScenarioStep = actionEntry(.tune(string, peg))
        switch (row - 1) % 5 {
        case 0:   // lock resonance — invalid player collision: a locked string or one the level lacks
            if let locked = lockedString(level) {
                return [legal, refusedAction(.tune(locked, otherPeg(play.pegs[locked])), kernelActionCode)]
            }
            if level.strings.count <= stringRange.upperBound {
                return [legal, refusedAction(.tune(level.strings.count, 1), kernelActionCode)]
            }
            return [legal, refusedAction(.tune(stringRange.upperBound + 1, 1), outOfRangeCode)]
        case 1:   // tune string — aliasing at high mode: a peg above the highest
            return [legal, refusedAction(.tune(string, pegRange.upperBound + 1), outOfRangeCode)]
        case 2:   // select mode — visual bridge but no logical edge: the same tuning again changes nothing
            return [legal, refusedAction(.tune(string, peg), noopCode)]
        case 3:   // set anchor — frequency beat glitches: a fractional peg
            return [legal, ScenarioStep(steps: 1, action: ScriptedAction("string.tune", [Double(string), 2.5]),
                                        result: notWholeCode)]
        default:  // test crossing — bridge flicker around threshold: the test breaks, then the play is closed
            return [actionEntry(.test), refusedAction(.tune(string, peg), stageCode)]
        }
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or no perturbation breaks.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard var play = openingPlay(number) else { return [] }
        let tunings: [HarmonicBridgesAction] = certifiedTunings(number)
        guard case let .tune(lastString, lastPeg)? = tunings.last,
              case let .tune(firstString, firstPeg)? = tunings.first else { return [] }
        var entries: [ScenarioStep] = []
        if row % 2 == 1 {
            for tuning in tunings.dropLast() {
                guard (try? play.apply(tuning, expecting: play.fingerprint)) != nil else { return [] }
                entries.append(actionEntry(tuning))
            }
            guard let wrong = breakingPeg(play, string: lastString, certified: lastPeg) else { return [] }
            entries += [actionEntry(.tune(lastString, wrong)), actionEntry(.test),
                        acceptedEntry("play.undo"), acceptedEntry("play.undo"),
                        actionEntry(.tune(lastString, lastPeg)), actionEntry(.test)]
            return entries
        }
        let start: Int = play.pegs[firstString]
        for tuning in tunings {
            guard (try? play.apply(tuning, expecting: play.fingerprint)) != nil else { return [] }
            entries.append(actionEntry(tuning))
        }
        let spending: [HarmonicBridgesAction] = exhaustingTunings(play, string: firstString, between: start,
                                                                  and: firstPeg)
        guard !spending.isEmpty else { return [] }
        for tuning in spending { entries.append(actionEntry(tuning)) }
        entries.append(refusedAction(.test, stageCode))
        return entries
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no unlocked string.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let string = unlockedString(play.level) else { return [] }
        let low: Int = pegRange.lowerBound
        let high: Int = pegRange.upperBound
        let first: Int = play.pegs[string] == low ? high : low
        let second: Int = first == low ? high : low
        var entries: [ScenarioStep] = [
            actionEntry(.tune(string, first)),
            actionEntry(.tune(string, second)),
            refusedAction(.tune(string, low - 1), outOfRangeCode),
        ]
        if row % 2 == 1 {
            entries.append(refusedAction(.tune(stringRange.upperBound + 1, low), outOfRangeCode))
        } else {
            entries.append(refusedAction(.tune(string, high + 1), outOfRangeCode))
        }
        if play.level.strings.count <= stringRange.upperBound {
            entries.append(refusedAction(.tune(play.level.strings.count, low), kernelActionCode))
        }
        entries += [acceptedEntry("play.undo"), acceptedEntry("play.undo")]
        return entries
    }

    /// The entries of acceptance row `row` (1 … 80) on its level (see the file header); empty when the level cannot be
    /// generated.
    public static func acceptanceEntries(row: Int) -> [ScenarioStep] {
        let number: Int = acceptanceLevel(row)
        let actions: [HarmonicBridgesAction] = certifiedActions(number)
        guard let first = actions.first, first != .test else { return [] }
        switch acceptanceFamily(row) {
        case .truth:
            return truthEntries(row: row, number: number)
        case .witness:
            return witnessEntries(row: row, number: number)
        case .numeric:
            return numericEntries(row: row, number: number)
        case .touch:
            return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                    refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
        case .rendering:
            return actions.map { actionEntry($0) } + [refusedEntry("play.undo", [], stageCode, steps: 1)]
        case .accessibility:
            return [actionEntry(.test), acceptedEntry("play.undo")]
        case .persistence:
            return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
                + actions.dropFirst().map { actionEntry($0) }
        case .integration:
            guard let next = certifiedTunings(nextLevel(after: number)).first else { return [] }
            return actions.map { actionEntry($0) }
                + [acceptedEntry("level.next"), actionEntry(next), acceptedEntry("play.undo"),
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> HarmonicBridgesExperienceCore? {
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

    /// The scenario manifest of the experience `id`: a round-two game.
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
