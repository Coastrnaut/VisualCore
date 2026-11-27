// BinaryGardensScenarios — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-005, 008; SC-R02G2103-004; research
// R13). The scenarios the verification runner plays for Binary Gardens, a round-two game, all short (owner rule of
// 2026-11-13), on the pattern of Mushroom Weather's (feature 493):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G21-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md, section 6.21.19), each with the seed of its level; the
//     row's archived title (area and condition, verbatim) is ``acceptanceTitle(_:)``;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1 and the run, outcome `won`),
//     `fixture-run-fails` (the run with the level's starting arrangement, outcome `failed`: a certified level's start
//     never already wins) and `fixture-undo-redo` (the probe move, its undo and its redo).
// Every certified action comes from the generated level's minimal plan (`BinaryGardensGenerated.plan.actions`, the
// plan `BinaryGardensSolver.plan` finds for the prepared level, equal to the stored witness
// `docs/games/binary-gardens/levels/NNN.witness.json` without its run — level 1: star 2's luminosity to index 0), so a
// regenerated catalog cannot leave a stale script; the plan is won by its actions followed by `light.run`. An
// arrangement action never ends the play (only the run does). The probe move is the plan's first action, else the
// first legal move in the rules' move order (for each star its rings, phases on the grid and luminosities ascending,
// then the tilts); the second move is the first legal move after it. The two input actions are the probe and the
// second move; input-response, save-restore and reset play both and undo the second; completion plays the certified
// plan of level 1 and the run and expects `won`; full-playthrough wins levels 1, 2 and 3 with `level.next` between
// them; hero plays the certified plan of level 1 without the run (a run now would win) and shows (`clock.show`) the
// hero tick — the earliest tick at which the most worlds are comfortable — so the picture shows the flowering worlds
// while the play is still open; rejection refuses values outside the declared ranges, fractional values, actions the
// kernel refuses (a ring, luminosity or tilt the level lacks or a locked one, a phase off the grid or locked, an
// unchanged value, an undo or redo with nothing to revert), the shown ticks 0 and 49 (`r02-g21.tick`) and wrong value
// counts (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 70) mod 100 + 1 for rows 1 … 20 (071, 078, … 034, 041, 048, … 004);
// the same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to 100), each
// opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted on the real
// controls with the outcome the kernel gives; the row's command cycles through the matrix's five (commit light window,
// phase twin stars, adjust orbit, set luminosity, watch world) and its illegal condition through the matrix's five
// (overlap masks star positions, same game as orbital counterpart, divide by near-zero radius, numerical runaway flux,
// false realistic astrophysics claim):
//   1 … 10  truth and state transitions — the probe move, then an illegal command by (r − 1) mod 5: the same move again,
//           refused `r02-g21.action` (commit light window; overlap masks star positions: an unchanged value); star 1's
//           phase off the level's phase grid, refused `r02-g21.action` — or, on a level with phase step 1, a phase of
//           0.5, refused `r02-g21.not-whole` (phase twin stars; same game as orbital counterpart); star 1 on ring 8,
//           refused `action.out-of-range` (adjust orbit; divide by near-zero radius: a ring beyond any level's);
//           star 1's luminosity 0.5, refused `r02-g21.not-whole` (set luminosity; numerical runaway flux); tick 0
//           shown, refused `r02-g21.tick` (watch world; false realistic astrophysics claim);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last action perturbed (the first legal
//           move there other than it after which the run fails), the run (failed), an undo (an honest retry), an undo of
//           the perturbed move, the certified last action and the run (won); even rows: an exhausted path — the whole
//           budget spent toggling the first adjustable control between its start value and the first other value whose
//           lone change does not win (so the final arrangement never wins), a further move refused `r02-g21.budget`,
//           the run (failed) and the move refused `r02-g21.stage`;
//  21 … 30  numeric and geometry edges — tick 48 and tick 1 shown (the endpoints), then star 2 and luminosity index 4
//           (odd rows) or ring 8 and tilt 7 (even rows) refused out of range, a ring the level lacks (or star 1's own
//           ring) and a tilt above T_max (or the current tilt) refused `r02-g21.action`, a ring of 0.5 refused
//           `r02-g21.not-whole`, tick 49 refused `r02-g21.tick` and tick 61 out of range, then the extreme settings —
//           each adjustable control set to its smallest and largest other values the kernel accepts from the opening
//           (at most three), each undone — back to the opening digest;
//  31 … 40  touch and camera semantics — the probe move, undo, redo (the moved digest again), tick 24 shown
//           (presentation: the digest does not change), then a second redo refused `r02-g21.action`;
//  41 … 50  rendering — the certified plan and the run (won; the digest is the same at every quality tier), then an
//           undo refused `r02-g21.stage` (a won play is final);
//  51 … 60  accessibility and safety — a failing run named in words, then an undo: an honest retry back to the digest
//           before the run. The run follows a proper prefix of the certified plan, alone or after one legal move; the
//           first such run (prefixes shortest first, the bare run before the moves in the rules' order) whose failure
//           has the row's preferred code (`frozen`, `scorched`, `unstable`, `wilted`, `bleached` by (r − 1) mod 5),
//           else the first failing run found;
//  61 … 70  persistence and replay — the probe move, undo, redo, undo, then the certified plan and the run (won; the
//           saved trace replays to the same state);
//  71 … 80  integration — the certified plan and the run (won, the next level opened), `level.next` (the next
//           certified level, a fresh play), its probe move, an undo (the next level's fresh play) and a second undo
//           refused `r02-g21.action`; a row on level 100 (none of rows 71 … 80 today: they visit levels 61, 68, 75, 82,
//           89, 96, 3, 10, 17 and 24) would see `level.next` refused `r02-g21.locked` after the win (no wrap) and
//           choose level 1 with `level.select [1]` instead.
// Feature 505 (R02-G21-05) T-R02G2105-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`; the
// integration rows (71 … 80) therefore first win their level's certified plan and the run (a campaign win opens the
// next level) before `level.next`; rejection also refuses the progression controls' wrong value counts
// (`level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest is regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`).
// Feature 507 (R02-G21-07) T-R02G2107-003: digests are schema 3's ("…v3"), wins store their traces, and rejection also
// refuses the replay and sound controls' wrong value counts (`replay.start`, `replay.step`, `replay.stop`,
// `settings.sound`); the manifest was regenerated (`UPDATE_SCENARIO_MANIFEST=1`).
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension BinaryGardensExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` wins in order, with `level.next` between them (each campaign win opens the next
    /// level, so `level.next` reaches it; feature 505).
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G21-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10
    /// The tick a touch row shows (the middle of the cycle).
    public static let touchTick = 24
    /// The failure codes accessibility rows prefer, by (row − 1) mod 5: the kernel's five failures.
    public static let preferredFailures: [String] = ["frozen", "scorched", "unstable", "wilted", "bleached"]
    /// The archived matrix's eight areas, in row order (round2.md section 6.21.19, verbatim).
    public static let acceptanceAreas: [String] = [
        "Truth and state transitions", "Solver witness and rejection", "Numeric and geometry edge",
        "Touch and camera semantics", "Rendering and shaders", "Accessibility and safety", "Persistence and replay",
        "Integration, privacy and devices",
    ]
    /// The archived matrix's ten conditions, by (row − 1) mod 10 (round2.md section 6.21.19, verbatim).
    public static let acceptanceConditions: [String] = [
        "fresh install and zero-history start", "mid-level save/resume", "boundary minimum control",
        "boundary maximum control", "repeated rapid input", "input interrupted by app background",
        "language and larger text layout", "high-contrast/reduce-motion enabled", "all puzzle controls exercised",
        "resume after an app process kill",
    ]

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional star, ring, phase, luminosity, tilt or tick.
    static let notWholeCode = "action.rule." + BinaryGardensExperienceRule.notWhole
    /// The code of a shown tick outside 1 … 48 within the declared range (`clock.show`).
    static let tickCode = "action.rule." + BinaryGardensExperienceRule.tick
    /// The code of the kernel's action refusal (a ring, luminosity or tilt out of the level's range, a phase off the
    /// grid, a locked control, an unchanged value, a separation break, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + BinaryGardensError.action("").reasonCode
    /// The code of the kernel's stage refusal (an arrangement action or run outside stage `playing`, an undo of a won
    /// play).
    static let stageCode = "action.rule." + BinaryGardensError.stage.reasonCode
    /// The code of the kernel's budget refusal (an arrangement action with no action left).
    static let budgetCode = "action.rule." + BinaryGardensError.budget.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last action perturbed and recovered (odd) or an exhausted path (even).
        case witness
        /// Rows 21 … 30: the tick endpoints, the refusals just outside the ranges and the extreme settings undone.
        case numeric
        /// Rows 31 … 40: a move, undo, redo, a tick shown and a refused redo.
        case touch
        /// Rows 41 … 50: the plan won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failing run, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a move undone, redone and undone, then the plan won.
        case persistence
        /// Rows 71 … 80: the plan won, the next level, its probe move, an undo and a refused undo.
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
    static func scripted(_ action: BinaryGardensAction) -> ScriptedAction {
        switch action {
        case let .ring(star, index): ScriptedAction("star.ring", [Double(star), Double(index)])
        case let .phase(star, step): ScriptedAction("star.phase", [Double(star), Double(step)])
        case let .luminosity(star, index): ScriptedAction("star.luminosity", [Double(star), Double(index)])
        case let .tilt(step): ScriptedAction("orbit.tilt", [Double(step)])
        case .run: ScriptedAction("light.run", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: BinaryGardensAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: BinaryGardensAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The accepted entry of the run.
    static func runEntry() -> ScenarioStep { actionEntry(.run) }

    /// The accepted entry that shows `tick` (presentation only).
    static func showEntry(_ tick: Int) -> ScenarioStep {
        acceptedEntry("clock.show", [Double(tick)])
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> BinaryGardensGenerated? {
        try? generated(number: number)
    }

    /// The certified plan's actions of manifest number `number` (the run not included); empty when the level cannot be
    /// generated.
    public static func certifiedActions(_ number: Int) -> [BinaryGardensAction] {
        certified(number)?.plan.actions ?? []
    }

    /// The entries that win manifest number `number`: its certified actions, then the run; empty when the level cannot
    /// be generated.
    public static func winningEntries(_ number: Int) -> [ScenarioStep] {
        guard certified(number) != nil else { return [] }
        var entries: [ScenarioStep] = []
        for action in certifiedActions(number) { entries.append(actionEntry(action)) }
        entries.append(runEntry())
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
    static func openingPlay(_ number: Int) -> BinaryGardensPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The legal moves of `play` in the rules' order (for each star its rings, phases on the grid and luminosities
    /// ascending, then the tilts); empty outside stage `playing` or with the budget spent.
    static func legalMoves(_ play: BinaryGardensPlay) -> [BinaryGardensAction] {
        guard play.stage == .playing else { return [] }
        let position = BinaryGardensPuzzle.Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
        return BinaryGardensPuzzle(level: play.level).moves(in: position)
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: BinaryGardensPlay, _ action: BinaryGardensAction) -> BinaryGardensPlay? {
        var next: BinaryGardensPlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// `play` after `actions` in order; nil when the kernel refuses one.
    static func after(_ play: BinaryGardensPlay, _ actions: [BinaryGardensAction]) -> BinaryGardensPlay? {
        var current: BinaryGardensPlay = play
        for action in actions {
            guard let next = after(current, action) else { return nil }
            current = next
        }
        return current
    }

    /// The probe move of manifest number `number`: the certified plan's first action, else the first legal move at the
    /// opening; nil when there is none.
    public static func probeMove(_ number: Int) -> BinaryGardensAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [BinaryGardensAction] = []
        if let first = certifiedActions(number).first { candidates.append(first) }
        candidates += legalMoves(play)
        for move in candidates where after(play, move)?.stage == .playing {
            return move
        }
        return nil
    }

    /// The second move of manifest number `number`: after the probe move, the first legal move; nil when there is none.
    public static func secondMove(_ number: Int) -> BinaryGardensAction? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return legalMoves(moved).first
    }

    /// The two input actions on the opening level: the probe move, then the second move; empty when there is none.
    public static var inputActions: [BinaryGardensAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let probe = probeMove(number), let second = secondMove(number) else { return [] }
        return [probe, second]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [BinaryGardensAction] = inputActions
        guard !actions.isEmpty else { return [] }
        var entries: [ScenarioStep] = []
        for action in actions { entries.append(actionEntry(action, steps: 10)) }
        entries.append(acceptedEntry("play.undo", steps: 10))
        return entries
    }

    /// The entries of completion: the certified plan of the opening level and the run.
    public static var completionEntries: [ScenarioStep] {
        winningEntries(levelNumber(forSeed: manifestSeed))
    }

    /// The entries of full-playthrough: the certified plans of ``playthroughLevels``, each with its run, with
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

    /// The hero tick of manifest number `number`: after the certified plan, the earliest tick 1 … 48 at which the most
    /// worlds are comfortable; nil when the level cannot be generated or its plan is refused.
    public static func heroTick(_ number: Int) -> Int? {
        guard let play = openingPlay(number), let planned = after(play, certifiedActions(number)) else { return nil }
        var best: (tick: Int, count: Int) = (BinaryGardensSky.cycle, -1)
        for tick in 1...BinaryGardensSky.cycle {
            var count: Int = 0
            for light in planned.report.worlds where light.bands[tick - 1] == .comfortable { count += 1 }
            if count > best.count { best = (tick, count) }
        }
        return best.tick
    }

    /// The entries of hero: the certified plan of the opening level without the run, then the hero tick shown, so the
    /// picture shows the flowering worlds while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        let actions: [BinaryGardensAction] = certifiedActions(number)
        guard !actions.isEmpty, let tick = heroTick(number) else { return [] }
        var entries: [ScenarioStep] = []
        for action in actions { entries.append(actionEntry(action)) }
        entries.append(showEntry(tick))
        return entries
    }

    /// The failing run of manifest number `number`: a proper prefix of the certified plan (shortest first), then
    /// nothing or one legal move (in the rules' order), then the run, whose failure has the code `preferred`; the first
    /// failing run found when none has it; nil when there is none. A proper prefix of a minimal plan never wins, so
    /// the bare run after every prefix fails.
    static func failingRun(_ number: Int, preferring preferred: String)
        -> (prefix: [BinaryGardensAction], change: BinaryGardensAction?)? {
        let actions: [BinaryGardensAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [BinaryGardensAction], change: BinaryGardensAction?)?
        for count in 0..<max(actions.count, 1) {
            if count > 0 {
                guard let next = after(play, actions[count - 1]) else { break }
                play = next
            }
            var changes: [BinaryGardensAction?] = [nil]
            for move in legalMoves(play) { changes.append(move) }
            for change in changes {
                var tried: [BinaryGardensAction] = []
                if let change { tried.append(change) }
                tried.append(.run)
                guard let ran = after(play, tried), ran.stage == .failed, let failure = ran.failure else { continue }
                let found: (prefix: [BinaryGardensAction], change: BinaryGardensAction?) =
                    (Array(actions.prefix(count)), change)
                if failure.code == preferred { return found }
                if fallback == nil { fallback = found }
            }
        }
        return fallback
    }

    /// The entries of `fixture-run-fails`: the run with level 1's starting arrangement (the run fails).
    public static var runFailsEntries: [ScenarioStep] {
        guard certified(levelNumber(forSeed: manifestSeed)) != nil else { return [] }
        return [runEntry()]
    }

    /// The entries of `fixture-undo-redo`: the probe move, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The `star.ring` values the kernel refuses `r02-g21.action` at `level`'s opening: star 1 on the first ring index
    /// the level lacks, or, with all eight rings, on its own ring (unchanged or locked).
    static func refusedRing(_ level: BinaryGardensLevel) -> [Double] {
        let count: Int = level.ringRadii.count
        return count <= ringRange.upperBound ? [0, Double(count)] : [0, Double(level.start.rings[0])]
    }

    /// The `orbit.tilt` value the kernel refuses `r02-g21.action` at `level`'s opening: T_max + 1, or, at T_max = 6,
    /// the current tilt (unchanged).
    static func refusedTilt(_ level: BinaryGardensLevel) -> [Double] {
        level.maxTilt < tiltRange.upperBound ? [Double(level.maxTilt + 1)] : [Double(level.start.tilt)]
    }

    /// The `star.luminosity` values the kernel refuses `r02-g21.action` at `level`'s opening: star 1 at the first
    /// index the level lacks, or, with all four levels, at its own luminosity (unchanged or locked).
    static func refusedLuminosity(_ level: BinaryGardensLevel) -> [Double] {
        let count: Int = level.luminosityLevels.count
        return count <= luminosityRange.upperBound ? [0, Double(count)] : [0, Double(level.start.luminosities[0])]
    }

    /// The `star.phase` values the kernel refuses `r02-g21.action` at `level`'s opening: star 1 at phase 1 when the
    /// level's phase step is above 1 (off the grid), else at its own phase (unchanged or locked).
    static func refusedPhase(_ level: BinaryGardensLevel) -> [Double] {
        level.phaseStep > 1 ? [0, 1] : [0, Double(level.start.phases[0])]
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number) else { return [] }
        let level: BinaryGardensLevel = play.level
        let ring: Double = Double(level.start.rings[0])
        let highStar: Double = Double(starRange.upperBound + 1)
        let highRing: Double = Double(ringRange.upperBound + 1)
        let highPhase: Double = Double(phaseRange.upperBound + 1)
        let highLuminosity: Double = Double(luminosityRange.upperBound + 1)
        let highTilt: Double = Double(tiltRange.upperBound + 1)
        let highTick: Double = Double(tickRange.upperBound + 1)
        return [
            refusedEntry("star.ring", [highStar, ring], outOfRangeCode),
            refusedEntry("star.ring", [-1, ring], outOfRangeCode),
            refusedEntry("star.ring", [0, highRing], outOfRangeCode),
            refusedEntry("star.ring", [0, -1], outOfRangeCode),
            refusedEntry("star.phase", [highStar, 0], outOfRangeCode),
            refusedEntry("star.phase", [0, highPhase], outOfRangeCode),
            refusedEntry("star.phase", [0, -1], outOfRangeCode),
            refusedEntry("star.luminosity", [highStar, 0], outOfRangeCode),
            refusedEntry("star.luminosity", [0, highLuminosity], outOfRangeCode),
            refusedEntry("star.luminosity", [0, -1], outOfRangeCode),
            refusedEntry("orbit.tilt", [highTilt], outOfRangeCode),
            refusedEntry("orbit.tilt", [-1], outOfRangeCode),
            refusedEntry("clock.show", [highTick], outOfRangeCode),
            refusedEntry("clock.show", [-1], outOfRangeCode),
            refusedEntry("star.ring", [0.5, ring], notWholeCode),
            refusedEntry("star.ring", [0, ring + 0.5], notWholeCode),
            refusedEntry("star.phase", [0, 0.5], notWholeCode),
            refusedEntry("star.luminosity", [1, 0.5], notWholeCode),
            refusedEntry("orbit.tilt", [0.5], notWholeCode),
            refusedEntry("clock.show", [24.5], notWholeCode),
            refusedEntry("star.ring", refusedRing(level), kernelActionCode),
            refusedEntry("star.phase", refusedPhase(level), kernelActionCode),
            refusedEntry("star.luminosity", refusedLuminosity(level), kernelActionCode),
            refusedEntry("orbit.tilt", refusedTilt(level), kernelActionCode),
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("clock.show", [0], tickCode),
            refusedEntry("clock.show", [Double(shownTicks.upperBound + 1)], tickCode),
            refusedEntry("clock.show", [Double(tickRange.upperBound)], tickCode),
            refusedEntry("star.ring", [], wrongCountCode),
            refusedEntry("star.ring", [0], wrongCountCode),
            refusedEntry("star.ring", [0, 0, 0], wrongCountCode),
            refusedEntry("star.phase", [0], wrongCountCode),
            refusedEntry("star.luminosity", [0, 0, 0], wrongCountCode),
            refusedEntry("orbit.tilt", [], wrongCountCode),
            refusedEntry("orbit.tilt", [0, 0], wrongCountCode),
            refusedEntry("light.run", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
            refusedEntry("clock.show", [], wrongCountCode),
            refusedEntry("clock.show", [1, 1], wrongCountCode),
            refusedEntry("level.select", [], wrongCountCode),
            refusedEntry("level.select", [1, 1], wrongCountCode),
            refusedEntry("mode.daily", [2026, 1], wrongCountCode),
            refusedEntry("mode.practice", [1], wrongCountCode),
            refusedEntry("mode.campaign", [1], wrongCountCode),
            refusedEntry("tutorial.dismiss", [1], wrongCountCode),
            refusedEntry("replay.start", [], wrongCountCode),
            refusedEntry("replay.step", [1], wrongCountCode),
            refusedEntry("replay.stop", [1], wrongCountCode),
            refusedEntry("settings.sound", [], wrongCountCode),
        ]
    }

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 70) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (071, 078, … 034, 041, 048, … 004), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 70) % 100 + 1 }

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
    /// the `acceptance-` prefix; names are lower case, so the archived title is ``acceptanceTitle(_:)``).
    public static func acceptanceName(_ row: Int) -> String { "acceptance-" + threeDigits(row) }

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G21-QA-001` … `R2-G21-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G21-QA-" + threeDigits(row) }

    /// The archived title of acceptance row `row` (1 … 80), verbatim: its area and its condition, for example
    /// "Truth and state transitions: fresh install and zero-history start" for row 1.
    public static func acceptanceTitle(_ row: Int) -> String {
        let area: String = acceptanceAreas[min(max((row - 1) / acceptanceFamilySize, 0), acceptanceAreas.count - 1)]
        let condition: String = acceptanceConditions[((row - 1) % acceptanceConditions.count
                                                      + acceptanceConditions.count) % acceptanceConditions.count]
        return area + ": " + condition
    }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`
    /// (the level the win opened); for level 100, whose `level.next` is refused `r02-g21.locked` (no wrap, feature
    /// 505), level 1 chosen with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int {
        number < levelNumbers.upperBound ? number + 1 : levelNumbers.lowerBound
    }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + BinaryGardensExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 505).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The perturbed last action of manifest number `number`: after the certified plan without its last action, the
    /// first legal move there other than it after which the run fails; nil when there is none.
    public static func perturbedLast(_ number: Int) -> BinaryGardensAction? {
        let actions: [BinaryGardensAction] = certifiedActions(number)
        guard let opening = openingPlay(number), let last = actions.last,
              let play = after(opening, Array(actions.dropLast())) else { return nil }
        for move in legalMoves(play) where move != last {
            guard let ran = after(play, [move, .run]), ran.stage == .failed else { continue }
            return move
        }
        return nil
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level has no probe move.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number) else { return [] }
        var entries: [ScenarioStep] = [actionEntry(probe)]
        switch (row - 1) % 5 {
        case 0:   // commit light window — overlap masks star positions: the same move again is unchanged
            entries.append(refusedAction(probe, kernelActionCode))
        case 1:   // phase twin stars — same game as orbital counterpart: a phase off the grid (or a fraction)
            if play.level.phaseStep > 1 {
                entries.append(refusedEntry("star.phase", [0, 1], kernelActionCode, steps: 1))
            } else {
                entries.append(refusedEntry("star.phase", [0, 0.5], notWholeCode, steps: 1))
            }
        case 2:   // adjust orbit — divide by near-zero radius: a ring beyond any level's rings
            entries.append(refusedEntry("star.ring", [0, Double(ringRange.upperBound + 1)], outOfRangeCode, steps: 1))
        case 3:   // set luminosity — numerical runaway flux: a fractional luminosity
            entries.append(refusedEntry("star.luminosity", [0, 0.5], notWholeCode, steps: 1))
        default:  // watch world — false realistic astrophysics claim: tick 0, which the cycle does not show
            entries.append(refusedEntry("clock.show", [0], tickCode, steps: 1))
        }
        return entries
    }

    /// The control, its start value and the other value the exhausted path of manifest number `number` toggles: the
    /// first adjustable control (in `BinaryGardensControl` order) with a first other value (ascending) that the kernel
    /// accepts from the opening and whose lone change does not win; nil when there is none.
    public static func losingToggle(_ number: Int) -> (control: BinaryGardensControl, start: Int, other: Int)? {
        guard let play = openingPlay(number) else { return nil }
        let level: BinaryGardensLevel = play.level
        for control in BinaryGardensControl.allCases where control.isAdjustable(in: level) {
            let start: Int = control.value(of: level.start)
            for value in control.values(in: level) where value != start {
                guard let moved = after(play, control.action(value)) else { continue }
                if !moved.report.wins { return (control, start, value) }
            }
        }
        return nil
    }

    /// The exhausted path of manifest number `number`: the whole budget spent toggling ``losingToggle(_:)``'s control
    /// between its other value and its start value, so the final arrangement (the start, or that one change) never
    /// wins; empty when there is no such toggle.
    public static func exhaustedPath(_ number: Int) -> [BinaryGardensAction] {
        guard let level = certified(number)?.level, let toggle = losingToggle(number) else { return [] }
        var path: [BinaryGardensAction] = []
        for index in 0..<level.budget {
            path.append(toggle.control.action(index % 2 == 0 ? toggle.other : toggle.start))
        }
        return path
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or no exhausted path exists.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [BinaryGardensAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        var entries: [ScenarioStep] = []
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            for action in actions.dropLast() { entries.append(actionEntry(action)) }
            entries += [actionEntry(perturbed), runEntry(), acceptedEntry("play.undo"), acceptedEntry("play.undo"),
                        actionEntry(last), runEntry()]
            return entries
        }
        let path: [BinaryGardensAction] = exhaustedPath(number)
        guard path.count >= 2 else { return [] }
        // The move the budget refuses: the next toggle the path would make.
        let further: BinaryGardensAction = path.count % 2 == 0 ? path[0] : path[1]
        for action in path { entries.append(actionEntry(action)) }
        entries += [refusedAction(further, budgetCode), runEntry(), refusedAction(further, stageCode)]
        return entries
    }

    /// The extreme settings of `level`: for each adjustable control (in `BinaryGardensControl` order) its smallest and
    /// largest values other than the start that the kernel accepts from the opening, at most three in all.
    public static func extremeSettings(_ level: BinaryGardensLevel) -> [BinaryGardensAction] {
        guard let play = try? freshPlay(of: level) else { return [] }
        var settings: [BinaryGardensAction] = []
        for control in BinaryGardensControl.allCases where control.isAdjustable(in: level) {
            let start: Int = control.value(of: level.start)
            let others: [Int] = control.values(in: level).filter { $0 != start }
            var picks: [Int] = []
            if let low = others.first(where: { after(play, control.action($0)) != nil }) { picks.append(low) }
            if let high = others.last(where: { after(play, control.action($0)) != nil }), !picks.contains(high) {
                picks.append(high)
            }
            for value in picks where settings.count < 3 { settings.append(control.action(value)) }
        }
        return settings
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no extreme setting.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number) else { return [] }
        let level: BinaryGardensLevel = play.level
        let extremes: [BinaryGardensAction] = extremeSettings(level)
        guard !extremes.isEmpty else { return [] }
        var entries: [ScenarioStep] = [showEntry(shownTicks.upperBound), showEntry(shownTicks.lowerBound)]
        if row % 2 == 1 {
            entries.append(refusedEntry("star.ring", [Double(starRange.upperBound + 1), 0], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("star.luminosity", [0, Double(luminosityRange.upperBound + 1)],
                                        outOfRangeCode, steps: 1))
        } else {
            entries.append(refusedEntry("star.ring", [0, Double(ringRange.upperBound + 1)], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("orbit.tilt", [Double(tiltRange.upperBound + 1)], outOfRangeCode, steps: 1))
        }
        entries += [refusedEntry("star.ring", refusedRing(level), kernelActionCode, steps: 1),
                    refusedEntry("orbit.tilt", refusedTilt(level), kernelActionCode, steps: 1),
                    refusedEntry("star.ring", [0, 0.5], notWholeCode, steps: 1),
                    refusedEntry("clock.show", [Double(shownTicks.upperBound + 1)], tickCode, steps: 1),
                    refusedEntry("clock.show", [Double(tickRange.upperBound + 1)], outOfRangeCode, steps: 1)]
        for setting in extremes { entries += [actionEntry(setting), acceptedEntry("play.undo")] }
        return entries
    }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe move.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let probe = probeMove(number) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                showEntry(touchTick), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The failure code accessibility row `row` prefers: ``preferredFailures`` at (row − 1) mod 5.
    static func preferredFailure(row: Int) -> String {
        preferredFailures[(row - 1) % preferredFailures.count]
    }

    /// The entries of accessibility row `row` on level `number` (see the file header); empty when the level has no
    /// failing run.
    static func accessibilityEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let failing = failingRun(number, preferring: preferredFailure(row: row)) else { return [] }
        var entries: [ScenarioStep] = []
        for action in failing.prefix { entries.append(actionEntry(action)) }
        if let change = failing.change { entries.append(actionEntry(change)) }
        entries += [runEntry(), acceptedEntry("play.undo")]
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> BinaryGardensExperienceCore? {
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
            let end: BinaryGardensExperienceCore? = played(seed: acceptance.seed, entries: acceptance.entries)
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
