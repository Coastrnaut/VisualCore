// ApsidesWorkshopScenarios — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-005, 008). The scenarios the
// verification runner plays for Apsides Workshop, a round-two game, all short (owner rule of 2026-11-13), on the
// pattern of Celestial Eclipse Lab's (feature 463):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G18-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1 and the play, outcome `won`),
//     `fixture-run-fails` (the play at the opening orbit, outcome `failed`: a valid level's starting orbit never wins)
//     and `fixture-undo-redo` (the probe tuning, its undo and its redo).
// Every certified tuning comes from the generated level's minimal plan (`ApsidesWorkshopGenerated.plan.actions`, the
// plan `ApsidesWorkshopSolver.plan` finds for the prepared level, equal to the stored witness
// `docs/games/apsides-workshop/levels/NNN.witness.json` without its play), so a regenerated catalog cannot leave a
// stale script; the plan is won by its tunings followed by `orbit.play`. A tuning never ends the play (only the play
// does), so the probe tuning is the first certified tuning (the first legal one, in the rules' move order — periapsis k
// 0 … 15 and d 0 … 23, then sizes 8 … 48 — should the plan be empty) and the second tuning is the first legal tuning
// after it. The two input actions are the probe and the second tuning; input-response, save-restore and reset play both
// and undo the second; completion plays the certified plan of level 1 and the play and expects `won`; full-playthrough
// wins levels 1, 2 and 3 with `level.next` between them; hero plays the certified plan of level 1 without the play (a
// play now would win) and shows (`clock.show`) the hero tick T / 2 — the apoapsis, where the kernel's event tick of an
// apoapsis target lies — so the picture shows the winning loop with the orbiter at its far end while the play is still
// open; rejection refuses values outside the declared ranges, fractional values, actions the kernel refuses (a tuning
// equal to the current orbit, a tuning making the orbit invalid when the opening orbit has one, an undo or redo with
// nothing to revert), a shown tick the adapter refuses (the period) and wrong value counts (never an undeclared
// control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 61) mod 100 + 1 for rows 1 … 20 (062, 069, … 097, 004, 011, 018, 025,
// 032, … 095); the same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to
// 100), each opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted
// on the real controls with the outcome the kernel gives; the row's command cycles through the matrix's five (lock
// orbit, tune eccentricity, rotate apsides, set period, sample sector) and its illegal condition through the matrix's
// five (bad coordinate reference, angle wrap, eccentricity approaches one, solver convergence failure, time-of-flight
// alias):
//   1 … 10  truth and state transitions — a legal command then an illegal one, by (r − 1) mod 5: the probe tuning,
//           then the same tuning again, refused `r02-g18.action` (lock orbit; bad coordinate reference: an unchanged
//           orbit); the probe tuning, then direction step 24, refused `action.out-of-range` (tune eccentricity; angle
//           wrap: the direction never wraps); the probe tuning, then the first tuning making the orbit invalid
//           (eccentricity 15 … 0 at its direction, then sizes 48 … 8), refused `r02-g18.action` (`action.out-of-range`
//           for eccentricity 16 when the orbit has none; rotate apsides; eccentricity approaches one); the probe
//           tuning, then a size of a ± 0.5 refused `r02-g18.not-whole` (set period; solver convergence failure); the
//           probe tuning, then the period shown, refused `r02-g18.tick` (sample sector; time-of-flight alias);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last tuning perturbed (the first legal
//           tuning there other than it after which the play fails), the play (failed), an undo (an honest retry), an
//           undo of the perturbed tuning, the certified last tuning and the play (won); even rows: an exhausted path —
//           the whole budget spent toggling the size between its starting value and the first other valid size whose
//           one-tuning orbit does not win (so the final orbit never wins), a further tuning refused `r02-g18.budget`,
//           the play (failed) and the tuning refused `r02-g18.stage`;
//  21 … 30  numeric and geometry edges — the last and the first tick shown (the endpoints), then eccentricity 16 and
//           size 7 (odd rows) or size 49 and direction −1 (even rows) refused out of range, the current knob refused
//           `r02-g18.action` (unchanged), the first invalid tuning refused `r02-g18.action` (when the opening orbit has
//           one), a direction of 0.5 refused `r02-g18.not-whole`, the period shown refused `r02-g18.tick`, then the
//           extreme steps — the smallest and the largest valid size, each undone — back to the opening digest;
//  31 … 40  touch and camera semantics — the probe tuning, undo, redo (the tuned digest again), the apoapsis tick T / 2
//           shown (presentation: the digest does not change), then a second redo refused `r02-g18.action`;
//  41 … 50  rendering — the certified plan and the play (won, every gauge lit; the digest is the same at every quality
//           tier), then an undo refused `r02-g18.stage` (a won play is final);
//  51 … 60  accessibility and safety — a failing play named in words, then an undo: an honest retry back to the digest
//           before the play. The play follows a proper prefix of the certified plan, alone or after one legal tuning;
//           the first such play (prefixes shortest first, the bare play before the tunings in the rules' order) whose
//           failure has the row's preferred code (`contact`, `order`, `share`, `apsis-sector`, `apsis-distance` by
//           (r − 1) mod 5), else the first failing play found;
//  61 … 70  persistence and replay — the probe tuning, undo, redo, undo, then the certified plan and the play (won; the
//           saved trace replays to the same state);
//  71 … 80  integration — the certified plan and the play (won, the next level opened), `level.next` (the next
//           certified level, a fresh play), its probe tuning, an undo (the next level's fresh play) and a second undo
//           refused `r02-g18.action`; on level 100 (no row reaches it today) `level.next` is refused `r02-g18.locked`
//           after the win (no wrap) and the row chooses level 1 with `level.select [1]` instead.
// Feature 475 (R02-G18-05) T-R02G1805-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`; the
// integration rows (71 … 80) therefore first win their level's certified plan (a campaign win opens the next level)
// before `level.next`; rejection also refuses the progression controls' wrong value counts (`level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest is regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`).
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension ApsidesWorkshopExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` wins in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G18-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10
    /// The failure codes accessibility rows prefer, by (row − 1) mod 5.
    public static let preferredFailures: [String] = ["contact", "order", "share", "apsis-sector", "apsis-distance"]

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional step, size or tick.
    static let notWholeCode = "action.rule." + ApsidesWorkshopExperienceRule.notWhole
    /// The code of a shown tick outside 0 … period − 1 (`clock.show`).
    static let tickCode = "action.rule." + ApsidesWorkshopExperienceRule.tick
    /// The code of the kernel's action refusal (an unchanged or invalid orbit, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + ApsidesWorkshopError.action("").reasonCode
    /// The code of the kernel's stage refusal (a tuning or play outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + ApsidesWorkshopError.stage.reasonCode
    /// The code of the kernel's budget refusal (a tuning with no action left).
    static let budgetCode = "action.rule." + ApsidesWorkshopError.budget.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last tuning perturbed and recovered (odd) or an exhausted path (even).
        case witness
        /// Rows 21 … 30: the tick endpoints, the refusals just outside the ranges and the extreme sizes undone.
        case numeric
        /// Rows 31 … 40: a tuning, undo, redo, a tick shown and a refused redo.
        case touch
        /// Rows 41 … 50: the plan won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failing play, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a tuning undone, redone and undone, then the plan won.
        case persistence
        /// Rows 71 … 80: the plan won, the next level, its probe tuning, an undo and a refused undo.
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
    static func scripted(_ action: ApsidesWorkshopAction) -> ScriptedAction {
        switch action {
        case let .periapsis(k, d): ScriptedAction("orbit.periapsis", [Double(k), Double(d)])
        case let .size(a): ScriptedAction("orbit.size", [Double(a)])
        case .play: ScriptedAction("orbit.play", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: ApsidesWorkshopAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: ApsidesWorkshopAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The accepted entry of the play.
    static func playEntry() -> ScenarioStep { actionEntry(.play) }

    /// The accepted entry that shows `tick` (presentation only).
    static func showEntry(_ tick: Int) -> ScenarioStep {
        acceptedEntry("clock.show", [Double(tick)])
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> ApsidesWorkshopGenerated? {
        try? generated(number: number)
    }

    /// The certified plan's tunings of manifest number `number` (the play not included); empty when the level cannot
    /// be generated.
    public static func certifiedActions(_ number: Int) -> [ApsidesWorkshopAction] {
        certified(number)?.plan.actions ?? []
    }

    /// The entries that win manifest number `number`: its certified tunings, then the play; empty when the level cannot
    /// be generated.
    public static func winningEntries(_ number: Int) -> [ScenarioStep] {
        guard certified(number) != nil else { return [] }
        var entries: [ScenarioStep] = []
        for action in certifiedActions(number) { entries.append(actionEntry(action)) }
        entries.append(playEntry())
        return entries
    }

    /// Certifies the levels of `numbers` concurrently into the process cache (certification is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The opening play of manifest number `number` (begun, past its tutorial); nil when it cannot be generated.
    static func openingPlay(_ number: Int) -> ApsidesWorkshopPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The legal tunings of `play` in the rules' order (periapsis k 0 … 15 and d 0 … 23, then sizes 8 … 48, each
    /// other than the current and keeping the orbit valid); empty outside stage `playing` or with the budget spent.
    static func legalTunings(_ play: ApsidesWorkshopPlay) -> [ApsidesWorkshopAction] {
        guard play.stage == .playing else { return [] }
        let position = ApsidesWorkshopRules.Position(orbit: play.orbit, actionsSpent: play.actionsSpent)
        return ApsidesWorkshopRules(level: play.level).moves(in: position)
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: ApsidesWorkshopPlay, _ action: ApsidesWorkshopAction) -> ApsidesWorkshopPlay? {
        var next: ApsidesWorkshopPlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// `play` after `actions` in order; nil when the kernel refuses one.
    static func after(_ play: ApsidesWorkshopPlay, _ actions: [ApsidesWorkshopAction]) -> ApsidesWorkshopPlay? {
        var current: ApsidesWorkshopPlay = play
        for action in actions {
            guard let next = after(current, action) else { return nil }
            current = next
        }
        return current
    }

    /// The probe tuning of manifest number `number`: the first certified tuning, else the first legal tuning at the
    /// opening; nil when there is none.
    public static func probeMove(_ number: Int) -> ApsidesWorkshopAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [ApsidesWorkshopAction] = []
        if let first = certifiedActions(number).first { candidates.append(first) }
        candidates += legalTunings(play)
        for move in candidates where after(play, move)?.stage == .playing {
            return move
        }
        return nil
    }

    /// The second tuning of manifest number `number`: after the probe tuning, the first legal tuning; nil when there
    /// is none.
    public static func secondMove(_ number: Int) -> ApsidesWorkshopAction? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return legalTunings(moved).first
    }

    /// The two input actions on the opening level: the probe tuning, then the second tuning; empty when there is none.
    public static var inputActions: [ApsidesWorkshopAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let probe = probeMove(number), let second = secondMove(number) else { return [] }
        return [probe, second]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [ApsidesWorkshopAction] = inputActions
        guard !actions.isEmpty else { return [] }
        var entries: [ScenarioStep] = []
        for action in actions { entries.append(actionEntry(action, steps: 10)) }
        entries.append(acceptedEntry("play.undo", steps: 10))
        return entries
    }

    /// The entries of completion: the certified plan of the opening level and the play.
    public static var completionEntries: [ScenarioStep] {
        winningEntries(levelNumber(forSeed: manifestSeed))
    }

    /// The entries of full-playthrough: the certified plans of ``playthroughLevels``, each with its play, with
    /// `level.next` between them.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            let winning: [ScenarioStep] = winningEntries(number)
            guard !winning.isEmpty else { return [] }
            entries += winning
        }
        return entries
    }

    /// The hero tick of manifest number `number`: T / 2, where the orbiter is at the apoapsis (the kernel's event tick
    /// of an apoapsis target); nil when the level cannot be generated.
    public static func heroTick(_ number: Int) -> Int? {
        guard let level = certified(number)?.level else { return nil }
        return level.period / 2
    }

    /// The entries of hero: the certified plan of the opening level without the play, then the hero tick shown, so the
    /// picture shows the winning loop with the orbiter at its apoapsis while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        let actions: [ApsidesWorkshopAction] = certifiedActions(number)
        guard !actions.isEmpty, let tick = heroTick(number) else { return [] }
        var entries: [ScenarioStep] = []
        for action in actions { entries.append(actionEntry(action)) }
        entries.append(showEntry(tick))
        return entries
    }

    /// The failing play of manifest number `number`: a proper prefix of the certified plan (shortest first), then
    /// nothing or one legal tuning (in the rules' order), then the play, whose failure has the code `preferred`; the
    /// first failing play found when none has it; nil when there is none. A proper prefix of a minimal plan never wins,
    /// so the bare play after every prefix fails.
    static func failingRun(_ number: Int, preferring preferred: String)
        -> (prefix: [ApsidesWorkshopAction], change: ApsidesWorkshopAction?)? {
        let actions: [ApsidesWorkshopAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [ApsidesWorkshopAction], change: ApsidesWorkshopAction?)?
        for count in 0..<max(actions.count, 1) {
            if count > 0 {
                guard let next = after(play, actions[count - 1]) else { break }
                play = next
            }
            var changes: [ApsidesWorkshopAction?] = [nil]
            for tuning in legalTunings(play) { changes.append(tuning) }
            for change in changes {
                var tried: [ApsidesWorkshopAction] = []
                if let change { tried.append(change) }
                tried.append(.play)
                guard let ran = after(play, tried), ran.stage == .failed, let failure = ran.failure else { continue }
                let found: (prefix: [ApsidesWorkshopAction], change: ApsidesWorkshopAction?) =
                    (Array(actions.prefix(count)), change)
                if failure.code == preferred { return found }
                if fallback == nil { fallback = found }
            }
        }
        return fallback
    }

    /// The entries of `fixture-run-fails`: the play at the opening orbit of level 1 (the play fails).
    public static var runFailsEntries: [ScenarioStep] {
        guard certified(levelNumber(forSeed: manifestSeed)) != nil else { return [] }
        return [playEntry()]
    }

    /// The entries of `fixture-undo-redo`: the probe tuning, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The first tuning of `orbit` that the kernel refuses as making the orbit invalid: eccentricity 15 … 0 at its
    /// size and direction, then sizes 48 … 8 at its knob (each other than the current); nil when every such tuning
    /// keeps the orbit valid.
    public static func invalidTuning(_ orbit: ApsidesWorkshopOrbit) -> ApsidesWorkshopAction? {
        for k in ApsidesWorkshopOrbit.eccentricities.reversed() where k != orbit.eccentricity {
            let next = ApsidesWorkshopOrbit(size: orbit.size, eccentricity: k, direction: orbit.direction)
            if !next.isValid { return .periapsis(k, orbit.direction) }
        }
        for a in ApsidesWorkshopOrbit.sizes.reversed() where a != orbit.size {
            let next = ApsidesWorkshopOrbit(size: a, eccentricity: orbit.eccentricity, direction: orbit.direction)
            if !next.isValid { return .size(a) }
        }
        return nil
    }

    /// The smallest and the largest valid size of `orbit`'s knob other than its own size; nil when there are not two
    /// such sizes.
    public static func extremeSizes(_ orbit: ApsidesWorkshopOrbit) -> (smallest: Int, largest: Int)? {
        var valid: [Int] = []
        for a in ApsidesWorkshopOrbit.sizes where a != orbit.size {
            let next = ApsidesWorkshopOrbit(size: a, eccentricity: orbit.eccentricity, direction: orbit.direction)
            if next.isValid { valid.append(a) }
        }
        guard let smallest = valid.first, let largest = valid.last, smallest != largest else { return nil }
        return (smallest, largest)
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number) else { return [] }
        let orbit: ApsidesWorkshopOrbit = play.orbit
        let k: Double = Double(orbit.eccentricity)
        let d: Double = Double(orbit.direction)
        let a: Double = Double(orbit.size)
        let highK: Double = Double(ApsidesWorkshopOrbit.eccentricities.upperBound + 1)
        let highD: Double = Double(ApsidesWorkshopOrbit.directions.upperBound + 1)
        let highA: Double = Double(ApsidesWorkshopOrbit.sizes.upperBound + 1)
        let lowA: Double = Double(ApsidesWorkshopOrbit.sizes.lowerBound - 1)
        let highTick: Double = Double(tickRange.upperBound + 1)
        let halfSize: Double = Double(ApsidesWorkshopOrbit.sizes.lowerBound) + 0.5
        var entries: [ScenarioStep] = [
            refusedEntry("orbit.periapsis", [highK, d], outOfRangeCode),
            refusedEntry("orbit.periapsis", [-1, d], outOfRangeCode),
            refusedEntry("orbit.periapsis", [k, highD], outOfRangeCode),
            refusedEntry("orbit.periapsis", [k, -1], outOfRangeCode),
            refusedEntry("orbit.size", [highA], outOfRangeCode),
            refusedEntry("orbit.size", [lowA], outOfRangeCode),
            refusedEntry("clock.show", [highTick], outOfRangeCode),
            refusedEntry("clock.show", [-1], outOfRangeCode),
            refusedEntry("orbit.periapsis", [0.5, d], notWholeCode),
            refusedEntry("orbit.periapsis", [k, 0.5], notWholeCode),
            refusedEntry("orbit.size", [halfSize], notWholeCode),
            refusedEntry("clock.show", [0.5], notWholeCode),
            refusedEntry("orbit.periapsis", [k, d], kernelActionCode),
            refusedEntry("orbit.size", [a], kernelActionCode),
            refusedEntry("clock.show", [Double(play.level.period)], tickCode),
        ]
        if let invalid = invalidTuning(orbit) {
            entries.append(refusedAction(invalid, kernelActionCode))
        }
        entries += [
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("orbit.periapsis", [], wrongCountCode),
            refusedEntry("orbit.periapsis", [k], wrongCountCode),
            refusedEntry("orbit.periapsis", [k, d, 0], wrongCountCode),
            refusedEntry("orbit.size", [], wrongCountCode),
            refusedEntry("orbit.size", [a, 0], wrongCountCode),
            refusedEntry("orbit.play", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
            refusedEntry("clock.show", [], wrongCountCode),
            refusedEntry("clock.show", [0, 0], wrongCountCode),
            refusedEntry("level.select", [], wrongCountCode),
            refusedEntry("mode.daily", [2026, 1], wrongCountCode),
            refusedEntry("mode.practice", [1], wrongCountCode),
            refusedEntry("mode.campaign", [1], wrongCountCode),
            refusedEntry("tutorial.dismiss", [1], wrongCountCode),
        ]
        return entries
    }

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 61) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (062, 069, … 097, 004, 011, … 095), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 61) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G18-QA-001` … `R2-G18-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G18-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`;
    /// for level 100, whose `level.next` is refused `r02-g18.locked` (no wrap), level 1 with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + ApsidesWorkshopExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 475).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The perturbed last tuning of manifest number `number`: after the certified plan without its last tuning, the
    /// first legal tuning there other than it after which the play fails; nil when there is none.
    public static func perturbedLast(_ number: Int) -> ApsidesWorkshopAction? {
        let actions: [ApsidesWorkshopAction] = certifiedActions(number)
        guard let opening = openingPlay(number), let last = actions.last,
              let play = after(opening, Array(actions.dropLast())) else { return nil }
        for move in legalTunings(play) where move != last {
            guard let ran = after(play, [move, .play]), ran.stage == .failed else { continue }
            return move
        }
        return nil
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no probe tuning.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return []
        }
        let orbit: ApsidesWorkshopOrbit = moved.orbit
        let k: Double = Double(orbit.eccentricity)
        let highD: Double = Double(ApsidesWorkshopOrbit.directions.upperBound + 1)
        var entries: [ScenarioStep] = [actionEntry(probe)]
        switch (row - 1) % 5 {
        case 0:   // lock orbit — bad coordinate reference: the same tuning again leaves the orbit unchanged
            entries.append(refusedAction(probe, kernelActionCode))
        case 1:   // tune eccentricity — angle wrap: direction step 24 is out of range, the angle never wraps
            entries.append(refusedEntry("orbit.periapsis", [k, highD], outOfRangeCode, steps: 1))
        case 2:   // rotate apsides — eccentricity approaches one: a tuning making the orbit invalid
            if let invalid = invalidTuning(orbit) {
                entries.append(refusedAction(invalid, kernelActionCode))
            } else {
                let highK: Double = Double(ApsidesWorkshopOrbit.eccentricities.upperBound + 1)
                entries.append(refusedEntry("orbit.periapsis", [highK, Double(orbit.direction)], outOfRangeCode,
                                            steps: 1))
            }
        case 3:   // set period — solver convergence failure: a fractional size
            let half: Double = orbit.size < ApsidesWorkshopOrbit.sizes.upperBound
                ? Double(orbit.size) + 0.5 : Double(orbit.size) - 0.5
            entries.append(refusedEntry("orbit.size", [half], notWholeCode, steps: 1))
        default:  // sample sector — time-of-flight alias: the period is no tick
            entries.append(refusedEntry("clock.show", [Double(play.level.period)], tickCode, steps: 1))
        }
        return entries
    }

    /// The exhausted path of manifest number `number`: the whole budget spent toggling the size between its starting
    /// value and the first other valid size whose one-tuning orbit does not win, so the final orbit (the start, or that
    /// one tuning) never wins; empty when there is no such size.
    public static func exhaustedPath(_ number: Int) -> [ApsidesWorkshopAction] {
        guard let level = certified(number)?.level else { return [] }
        let rules: ApsidesWorkshopRules = ApsidesWorkshopRules(level: level)
        let start: ApsidesWorkshopOrbit = level.orbit
        var toggle: Int?
        for a in ApsidesWorkshopOrbit.sizes where a != start.size {
            let orbit = ApsidesWorkshopOrbit(size: a, eccentricity: start.eccentricity, direction: start.direction)
            if orbit.isValid && !rules.isSolved(ApsidesWorkshopRules.Position(orbit: orbit, actionsSpent: 0)) {
                toggle = a
                break
            }
        }
        guard let other = toggle else { return [] }
        var path: [ApsidesWorkshopAction] = []
        for index in 0..<level.budget { path.append(.size(index % 2 == 0 ? other : start.size)) }
        return path
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or no exhausted path exists.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [ApsidesWorkshopAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        var entries: [ScenarioStep] = []
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            for action in actions.dropLast() { entries.append(actionEntry(action)) }
            entries += [actionEntry(perturbed), playEntry(), acceptedEntry("play.undo"), acceptedEntry("play.undo"),
                        actionEntry(last), playEntry()]
            return entries
        }
        let path: [ApsidesWorkshopAction] = exhaustedPath(number)
        guard path.count >= 2, let level = certified(number)?.level else { return [] }
        // The tuning the budget refuses: the size the last toggle left behind.
        let further: ApsidesWorkshopAction = path.count % 2 == 0 ? path[0] : .size(level.orbit.size)
        for action in path { entries.append(actionEntry(action)) }
        entries += [refusedAction(further, budgetCode), playEntry(), refusedAction(further, stageCode)]
        return entries
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or its orbit has no two extreme sizes.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let extremes = extremeSizes(play.orbit) else { return [] }
        let orbit: ApsidesWorkshopOrbit = play.orbit
        let period: Int = play.level.period
        let k: Double = Double(orbit.eccentricity)
        let d: Double = Double(orbit.direction)
        var entries: [ScenarioStep] = [showEntry(period - 1), showEntry(0)]
        if row % 2 == 1 {
            let highK: Double = Double(ApsidesWorkshopOrbit.eccentricities.upperBound + 1)
            let lowA: Double = Double(ApsidesWorkshopOrbit.sizes.lowerBound - 1)
            entries.append(refusedEntry("orbit.periapsis", [highK, d], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("orbit.size", [lowA], outOfRangeCode, steps: 1))
        } else {
            let highA: Double = Double(ApsidesWorkshopOrbit.sizes.upperBound + 1)
            let lowD: Double = Double(ApsidesWorkshopOrbit.directions.lowerBound - 1)
            entries.append(refusedEntry("orbit.size", [highA], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("orbit.periapsis", [k, lowD], outOfRangeCode, steps: 1))
        }
        entries.append(refusedAction(.periapsis(orbit.eccentricity, orbit.direction), kernelActionCode))
        if let invalid = invalidTuning(orbit) {
            entries.append(refusedAction(invalid, kernelActionCode))
        }
        entries += [refusedEntry("orbit.periapsis", [k, 0.5], notWholeCode, steps: 1),
                    refusedEntry("clock.show", [Double(period)], tickCode, steps: 1),
                    actionEntry(.size(extremes.smallest)), acceptedEntry("play.undo"),
                    actionEntry(.size(extremes.largest)), acceptedEntry("play.undo")]
        return entries
    }

    /// The apoapsis tick of `level`: period / 2.
    static func apoapsisTick(_ level: ApsidesWorkshopLevel) -> Int { level.period / 2 }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe tuning.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                showEntry(apoapsisTick(play.level)), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The failure code accessibility row `row` prefers: ``preferredFailures`` at (row − 1) mod 5.
    static func preferredFailure(row: Int) -> String {
        preferredFailures[(row - 1) % preferredFailures.count]
    }

    /// The entries of accessibility row `row` on level `number` (see the file header); empty when the level has no
    /// failing play.
    static func accessibilityEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let failing = failingRun(number, preferring: preferredFailure(row: row)) else { return [] }
        var entries: [ScenarioStep] = []
        for action in failing.prefix { entries.append(actionEntry(action)) }
        if let change = failing.change { entries.append(actionEntry(change)) }
        entries += [playEntry(), acceptedEntry("play.undo")]
        return entries
    }

    /// The entries of acceptance row `row` (1 … 80) on its level (see the file header); empty when the level cannot be
    /// generated.
    public static func acceptanceEntries(row: Int) -> [ScenarioStep] {
        let number: Int = acceptanceLevel(row)
        let winning: [ScenarioStep] = winningEntries(number)
        guard !winning.isEmpty else { return [] }
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
            return winning + [refusedEntry("play.undo", [], stageCode, steps: 1)]
        case .accessibility:
            return accessibilityEntries(row: row, number: number)
        case .persistence:
            guard let probe = probeMove(number) else { return [] }
            return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                    acceptedEntry("play.undo")] + winning
        case .integration:
            guard let next = probeMove(nextLevel(after: number)) else { return [] }
            return winning + integrationMoveEntries(number)
                + [actionEntry(next), acceptedEntry("play.undo"),
                   refusedEntry("play.undo", [], kernelActionCode, steps: 1)]
        }
    }

    /// The acceptance scenarios, one per row: its name, seed and entries (see the file header). Empty when a level
    /// cannot be generated or a row cannot be scripted.
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
         ("fixture-run-fails", runFailsEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> ApsidesWorkshopExperienceCore? {
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
        let input: [ScenarioStep] = inputEntries
        let initial: String? = expectedDigest(for: id, seed: seed, entries: [])
        let final: String? = expectedDigest(for: id, seed: seed, entries: input)
        let playthrough: [ScenarioStep] = playthroughEntries
        let hero: [ScenarioStep] = heroEntries
        var specs: [ScenarioSpec] = [
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
            let end: ApsidesWorkshopExperienceCore? = played(seed: acceptance.seed, entries: acceptance.entries)
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
