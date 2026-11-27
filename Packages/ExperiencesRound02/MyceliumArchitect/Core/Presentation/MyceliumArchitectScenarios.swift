// MyceliumArchitectScenarios — feature 513 (R02-G22-03) T-R02G2203-002 (FR-R02G2203-005, 008; SC-R02G2203-004;
// clarification Q5; research R11). The scenarios the verification runner plays for Mycelium Architect, a round-two
// game, all short (owner rule of 2026-11-13), on the pattern of Binary Gardens' (feature 503):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G22-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md, section 6.22.19), each with the seed of its level; the
//     row's archived title (area and condition, verbatim) is ``acceptanceTitle(_:)``;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1 and the run, outcome `won`),
//     `fixture-run-fails` (the run with the level's starting arrangement, outcome `failed`: a certified level's start
//     never already wins) and `fixture-undo-redo` (the probe move, its undo and its redo).
// Every certified action comes from the generated level's minimal plan (`MyceliumArchitectGeneratedLevel.solution`
// without its run, equal to the stored witness `docs/games/mycelium-architect/levels/NNN.witness.json` without its run
// — level 1: seed east), so a regenerated catalog cannot leave a stale script; the plan is won by its actions followed
// by `growth.run`. An arrangement action never ends the play (only the run does). The probe move is the plan's first
// action, else the first legal move in the rules' move order (`MyceliumArchitectPuzzle.moves`: nutrients on empty
// sites, blockers, clears, seeds, unseeds, each ascending); the second move is the first legal move after it. The two
// input actions are the probe and the second move; input-response, save-restore and reset play both and undo the
// second; completion plays the certified plan of level 1 and the run and expects `won`; full-playthrough wins levels 1,
// 2 and 3 with `level.next` between them; hero plays the certified plan of level 1 without the run (a run now would
// win) and shows (`growth.show`) the hero pulse — the pulse at which the last terminal is reached — so the picture
// shows every cap open while the play is still open; rejection refuses values outside the declared ranges, fractional
// values, actions the kernel refuses (a placement on the root or off the sites, a clear without a placed item, an
// unseed of a direction not seeded, an undo or redo with nothing to revert), shown pulses above the pulses run
// (`r02-g22.pulse`) and wrong value counts (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 73) mod 100 + 1 for rows 1 … 20 (074, 081, … 037, 044, 051, … 007);
// the same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to 100), each
// opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted on the real
// controls with the outcome the kernel gives; the row's command cycles through the matrix's five (commit graph, place
// nutrient, seed filament, block toxin, steer growth) and its illegal condition through the matrix's five (nutrient
// negative, thin lines flicker, exponential branch growth, cyclic graph mistaken for tree, toxic crossing):
//   1 … 10  truth and state transitions — the probe move, then an illegal command by (r − 1) mod 5: a nutrient at
//           column −1, refused `action.out-of-range` (nutrient negative); a shown pulse one above the pulses run,
//           refused `r02-g22.pulse` (thin lines flicker); the probe move again, refused `r02-g22.action` (exponential
//           branch growth: a cell or direction is taken once); an unseed of the first direction not seeded, refused
//           `r02-g22.action` (cyclic graph mistaken for tree); a nutrient on the first toxin (the root on a level
//           without toxins), refused `r02-g22.action` (toxic crossing);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last action perturbed (the first legal
//           move there other than it after which the run fails), the run (failed), an undo (an honest retry), an undo
//           of the perturbed move, the certified last action and the run (won); even rows: an exhausted path — the
//           whole budget spent toggling the first legal move whose lone change does not win and its inverse (a
//           placement and its clear, a seed and its unseed; so the final arrangement never wins), a further toggle
//           refused `r02-g22.budget`, the run (failed) and the toggle refused `r02-g22.stage`;
//  21 … 30  numeric and geometry edges — the pulses run and pulse 0 shown (the endpoints), then a nutrient at column 32
//           and a seed of direction 8 (odd rows) or a blocker at row 32 and an unseed of direction −1 (even rows)
//           refused out of range, a nutrient just off the board and an unseed of a direction not seeded refused
//           `r02-g22.action`, a clear at column 0.5 refused `r02-g22.not-whole`, the pulses run + 1 refused
//           `r02-g22.pulse` and pulse 129 out of range, then the extreme settings — the first and last nutrient sites,
//           the lowest and highest seed and the first and last blocker sites the kernel accepts from the opening (at
//           most three) — each undone, back to the opening digest;
//  31 … 40  touch and camera semantics — the probe move, undo, redo (the moved digest again), half the pulses run shown
//           (presentation: the digest does not change), then a second redo refused `r02-g22.action`;
//  41 … 50  rendering — the certified plan and the run (won; the digest is the same at every quality tier), then an
//           undo refused `r02-g22.stage` (a won play is final);
//  51 … 60  accessibility and safety — a failing run named in words, then an undo: an honest retry back to the digest
//           before the run. The run follows a proper prefix of the certified plan, alone or after one legal move; the
//           first such run (prefixes shortest first, the bare run before the moves in the rules' order) whose failure
//           has the row's preferred code (`toxic`, `starved`, `unreached`, `overweight` by (r − 1) mod 4), else the
//           first failing run found;
//  61 … 70  persistence and replay — the probe move, undo, redo, undo, then the certified plan and the run (won; the
//           saved trace replays to the same state);
//  71 … 80  integration — the certified plan and the run (won), `level.next` (the next certified level, 100 wrapping to
//           1, a fresh play), its probe move, an undo (the next level's fresh play) and a second undo refused
//           `r02-g22.action`.
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension MyceliumArchitectExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` wins in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G22-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10
    /// The failure codes accessibility rows prefer, by (row − 1) mod 4: the kernel's four failures.
    public static let preferredFailures: [String] = ["toxic", "starved", "unreached", "overweight"]
    /// The archived matrix's eight areas, in row order (round2.md section 6.22.19, verbatim).
    public static let acceptanceAreas: [String] = [
        "Truth and state transitions", "Solver witness and rejection", "Numeric and geometry edge",
        "Touch and camera semantics", "Rendering and shaders", "Accessibility and safety", "Persistence and replay",
        "Integration, privacy and devices",
    ]
    /// The archived matrix's ten conditions, by (row − 1) mod 10 (round2.md section 6.22.19, verbatim).
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
    /// The code of a fractional column, row, direction or pulse.
    static let notWholeCode = "action.rule." + MyceliumArchitectExperienceRule.notWhole
    /// The code of a shown pulse above the pulses run within the declared range (`growth.show`).
    static let pulseCode = "action.rule." + MyceliumArchitectExperienceRule.pulse
    /// The code of the kernel's action refusal (a cell off the board, not empty or not a site, a limit reached, a clear
    /// without a placed item, a direction seeded or not seeded, a starting seed, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + MyceliumArchitectError.action("").reasonCode
    /// The code of the kernel's stage refusal (an arrangement action or run outside stage `playing`, an undo of a won
    /// play).
    static let stageCode = "action.rule." + MyceliumArchitectError.stage.reasonCode
    /// The code of the kernel's budget refusal (an arrangement action with no action left).
    static let budgetCode = "action.rule." + MyceliumArchitectError.budget.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last action perturbed and recovered (odd) or an exhausted path (even).
        case witness
        /// Rows 21 … 30: the pulse endpoints, the refusals just outside the ranges and the extreme settings undone.
        case numeric
        /// Rows 31 … 40: a move, undo, redo, a pulse shown and a refused redo.
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

    /// The values of `cell`: its column and row.
    static func values(_ cell: MyceliumArchitectCell) -> [Double] {
        [Double(cell.column), Double(cell.row)]
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: MyceliumArchitectAction) -> ScriptedAction {
        switch action {
        case .nutrient(let cell): ScriptedAction("cell.nutrient", values(cell))
        case .blocker(let cell): ScriptedAction("cell.blocker", values(cell))
        case .clear(let cell): ScriptedAction("cell.clear", values(cell))
        case .seed(let direction): ScriptedAction("root.seed", [Double(direction.rawValue)])
        case .unseed(let direction): ScriptedAction("root.unseed", [Double(direction.rawValue)])
        case .run: ScriptedAction("growth.run", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: MyceliumArchitectAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: MyceliumArchitectAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The accepted entry of the run.
    static func runEntry() -> ScenarioStep { actionEntry(.run) }

    /// The accepted entry that shows `pulse` (presentation only).
    static func showEntry(_ pulse: Int) -> ScenarioStep {
        acceptedEntry("growth.show", [Double(pulse)])
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> MyceliumArchitectGeneratedLevel? {
        try? generated(number: number)
    }

    /// The certified plan's actions of manifest number `number` (the run not included); empty when the level cannot be
    /// generated.
    public static func certifiedActions(_ number: Int) -> [MyceliumArchitectAction] {
        guard let solution = certified(number)?.solution else { return [] }
        var actions: [MyceliumArchitectAction] = []
        for action in solution.actions where action != .run { actions.append(action) }
        return actions
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
    static func openingPlay(_ number: Int) -> MyceliumArchitectPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The legal moves of `play` in the rules' order (`MyceliumArchitectPuzzle.moves`); empty outside stage `playing`
    /// or with the budget spent.
    static func legalMoves(_ play: MyceliumArchitectPlay) -> [MyceliumArchitectAction] {
        guard play.stage == .playing else { return [] }
        let position = MyceliumArchitectPuzzle.Position(arrangement: play.arrangement,
                                                        actionsSpent: play.actionsSpent)
        return MyceliumArchitectPuzzle(level: play.level).moves(in: position)
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: MyceliumArchitectPlay, _ action: MyceliumArchitectAction) -> MyceliumArchitectPlay? {
        var next: MyceliumArchitectPlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// `play` after `actions` in order; nil when the kernel refuses one.
    static func after(_ play: MyceliumArchitectPlay, _ actions: [MyceliumArchitectAction]) -> MyceliumArchitectPlay? {
        var current: MyceliumArchitectPlay = play
        for action in actions {
            guard let next = after(current, action) else { return nil }
            current = next
        }
        return current
    }

    /// The probe move of manifest number `number`: the certified plan's first action, else the first legal move at the
    /// opening; nil when there is none.
    public static func probeMove(_ number: Int) -> MyceliumArchitectAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [MyceliumArchitectAction] = []
        if let first = certifiedActions(number).first { candidates.append(first) }
        candidates += legalMoves(play)
        for move in candidates where after(play, move)?.stage == .playing {
            return move
        }
        return nil
    }

    /// The second move of manifest number `number`: after the probe move, the first legal move; nil when there is none.
    public static func secondMove(_ number: Int) -> MyceliumArchitectAction? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return legalMoves(moved).first
    }

    /// The two input actions on the opening level: the probe move, then the second move; empty when there is none.
    public static var inputActions: [MyceliumArchitectAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let probe = probeMove(number), let second = secondMove(number) else { return [] }
        return [probe, second]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [MyceliumArchitectAction] = inputActions
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

    /// The hero pulse of manifest number `number`: after the certified plan, the pulse at which the last terminal is
    /// reached; nil when the level cannot be generated, its plan is refused or a terminal is not reached.
    public static func heroPulse(_ number: Int) -> Int? {
        guard let play = openingPlay(number), let planned = after(play, certifiedActions(number)) else { return nil }
        var latest: Int = 0
        for pulse in planned.report.terminalPulses {
            guard let reached = pulse else { return nil }
            latest = max(latest, reached)
        }
        return latest
    }

    /// The entries of hero: the certified plan of the opening level without the run, then the hero pulse shown, so the
    /// picture shows every cap open while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        let actions: [MyceliumArchitectAction] = certifiedActions(number)
        guard !actions.isEmpty, let pulse = heroPulse(number) else { return [] }
        var entries: [ScenarioStep] = []
        for action in actions { entries.append(actionEntry(action)) }
        entries.append(showEntry(pulse))
        return entries
    }

    /// The failing run of manifest number `number`: a proper prefix of the certified plan (shortest first), then
    /// nothing or one legal move (in the rules' order), then the run, whose failure has the code `preferred`; the first
    /// failing run found when none has it; nil when there is none. A proper prefix of a minimal plan never wins, so
    /// the bare run after every prefix fails.
    static func failingRun(_ number: Int, preferring preferred: String)
        -> (prefix: [MyceliumArchitectAction], change: MyceliumArchitectAction?)? {
        let actions: [MyceliumArchitectAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [MyceliumArchitectAction], change: MyceliumArchitectAction?)?
        for count in 0..<max(actions.count, 1) {
            if count > 0 {
                guard let next = after(play, actions[count - 1]) else { break }
                play = next
            }
            var changes: [MyceliumArchitectAction?] = [nil]
            for move in legalMoves(play) { changes.append(move) }
            for change in changes {
                var tried: [MyceliumArchitectAction] = []
                if let change { tried.append(change) }
                tried.append(.run)
                guard let ran = after(play, tried), ran.stage == .failed, let failure = ran.failure else { continue }
                let found: (prefix: [MyceliumArchitectAction], change: MyceliumArchitectAction?) =
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

    /// The first direction `arrangement` has not seeded (north when all are, which no level allows).
    static func unseeded(_ arrangement: MyceliumArchitectArrangement) -> MyceliumArchitectDirection {
        for direction in MyceliumArchitectDirection.allCases where !arrangement.seeds.contains(direction) {
            return direction
        }
        return .north
    }

    /// The first empty cell of `level` (ascending row, column) that is not a placement site; nil when every empty cell
    /// is a site or the level has no sites.
    static func emptyNonSite(_ level: MyceliumArchitectLevel) -> MyceliumArchitectCell? {
        guard level.sites != nil else { return nil }
        for row in 0..<level.height {
            for column in 0..<level.width {
                let cell: MyceliumArchitectCell = MyceliumArchitectCell(column: column, row: row)
                if level.isEmpty(cell, in: level.start) && !level.isSite(cell) { return cell }
            }
        }
        return nil
    }

    /// A cell just off `level`'s board within the declared range: column W at row 0 (a board 32 wide has none, so its
    /// root, which is not empty, stands in).
    static func offBoard(_ level: MyceliumArchitectLevel) -> MyceliumArchitectCell {
        level.width <= cellRange.upperBound ? MyceliumArchitectCell(column: level.width, row: 0) : level.root
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number) else { return [] }
        let level: MyceliumArchitectLevel = play.level
        let root: [Double] = values(level.root)
        let high: Double = Double(cellRange.upperBound + 1)
        let highDirection: Double = Double(directionRange.upperBound + 1)
        let highPulse: Double = Double(pulseRange.upperBound + 1)
        let pulses: Int = play.report.pulsesRun
        var entries: [ScenarioStep] = [
            refusedEntry("cell.nutrient", [high, 0], outOfRangeCode),
            refusedEntry("cell.nutrient", [-1, 0], outOfRangeCode),
            refusedEntry("cell.nutrient", [0, high], outOfRangeCode),
            refusedEntry("cell.nutrient", [0, -1], outOfRangeCode),
            refusedEntry("cell.blocker", [high, 0], outOfRangeCode),
            refusedEntry("cell.blocker", [0, -1], outOfRangeCode),
            refusedEntry("cell.clear", [0, high], outOfRangeCode),
            refusedEntry("cell.clear", [-1, 0], outOfRangeCode),
            refusedEntry("root.seed", [highDirection], outOfRangeCode),
            refusedEntry("root.seed", [-1], outOfRangeCode),
            refusedEntry("root.unseed", [highDirection], outOfRangeCode),
            refusedEntry("growth.show", [highPulse], outOfRangeCode),
            refusedEntry("growth.show", [-1], outOfRangeCode),
            refusedEntry("cell.nutrient", [0.5, 0], notWholeCode),
            refusedEntry("cell.nutrient", [0, 0.5], notWholeCode),
            refusedEntry("cell.blocker", [1.5, 1], notWholeCode),
            refusedEntry("cell.clear", [0, 2.5], notWholeCode),
            refusedEntry("root.seed", [0.5], notWholeCode),
            refusedEntry("root.unseed", [1.5], notWholeCode),
            refusedEntry("growth.show", [0.5], notWholeCode),
            refusedEntry("cell.nutrient", root, kernelActionCode),
            refusedEntry("cell.blocker", root, kernelActionCode),
            refusedEntry("cell.nutrient", values(offBoard(level)), kernelActionCode),
            refusedEntry("cell.clear", root, kernelActionCode),
            refusedEntry("root.unseed", [Double(unseeded(play.arrangement).rawValue)], kernelActionCode),
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("growth.show", [Double(pulses + 1)], pulseCode),
            refusedEntry("growth.show", [Double(pulseRange.upperBound)], pulseCode),
        ]
        if let cell = emptyNonSite(level) {
            entries.append(refusedEntry("cell.nutrient", values(cell), kernelActionCode))
            entries.append(refusedEntry("cell.blocker", values(cell), kernelActionCode))
        }
        entries += [
            refusedEntry("cell.nutrient", [], wrongCountCode),
            refusedEntry("cell.nutrient", [0], wrongCountCode),
            refusedEntry("cell.nutrient", [0, 0, 0], wrongCountCode),
            refusedEntry("cell.blocker", [0], wrongCountCode),
            refusedEntry("cell.clear", [0, 0, 0], wrongCountCode),
            refusedEntry("root.seed", [], wrongCountCode),
            refusedEntry("root.seed", [0, 0], wrongCountCode),
            refusedEntry("root.unseed", [], wrongCountCode),
            refusedEntry("growth.run", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
            refusedEntry("growth.show", [], wrongCountCode),
            refusedEntry("growth.show", [1, 1], wrongCountCode),
        ]
        return entries
    }

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 73) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (074, 081, … 037, 044, 051, … 007), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 73) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G22-QA-001` … `R2-G22-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G22-QA-" + threeDigits(row) }

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

    /// The level `level.next` reaches from level `number`: `number + 1`, and 1 after 100.
    public static func nextLevel(after number: Int) -> Int {
        number < levelNumbers.upperBound ? number + 1 : levelNumbers.lowerBound
    }

    /// The perturbed last action of manifest number `number`: after the certified plan without its last action, the
    /// first legal move there other than it after which the run fails; nil when there is none.
    public static func perturbedLast(_ number: Int) -> MyceliumArchitectAction? {
        let actions: [MyceliumArchitectAction] = certifiedActions(number)
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
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return []
        }
        var entries: [ScenarioStep] = [actionEntry(probe)]
        switch (row - 1) % 5 {
        case 0:   // commit graph — nutrient negative: a nutrient at column −1
            entries.append(refusedEntry("cell.nutrient", [-1, 0], outOfRangeCode, steps: 1))
        case 1:   // place nutrient — thin lines flicker: a pulse beyond the growth shown
            entries.append(refusedEntry("growth.show", [Double(moved.report.pulsesRun + 1)], pulseCode, steps: 1))
        case 2:   // seed filament — exponential branch growth: the same cell or direction again
            entries.append(refusedAction(probe, kernelActionCode))
        case 3:   // block toxin — cyclic graph mistaken for tree: an unseed of a direction never seeded
            let direction: MyceliumArchitectDirection = unseeded(moved.arrangement)
            entries.append(refusedEntry("root.unseed", [Double(direction.rawValue)], kernelActionCode, steps: 1))
        default:  // steer growth — toxic crossing: a nutrient on a toxin (the root without toxins)
            let cell: MyceliumArchitectCell = play.level.toxins.first ?? play.level.root
            entries.append(refusedEntry("cell.nutrient", values(cell), kernelActionCode, steps: 1))
        }
        return entries
    }

    /// The inverse of an arrangement action from the arrangement before it: a placement's clear, a seed's unseed; nil
    /// for any other action.
    static func inverse(of action: MyceliumArchitectAction) -> MyceliumArchitectAction? {
        switch action {
        case .nutrient(let cell), .blocker(let cell): .clear(cell)
        case .seed(let direction): .unseed(direction)
        case .clear, .unseed, .run: nil
        }
    }

    /// The move and its inverse the exhausted path of manifest number `number` toggles: the first legal move at the
    /// opening with an inverse whose lone change does not win; nil when there is none.
    public static func losingToggle(_ number: Int)
        -> (move: MyceliumArchitectAction, inverse: MyceliumArchitectAction)? {
        guard let play = openingPlay(number) else { return nil }
        for move in legalMoves(play) {
            guard let back = inverse(of: move), let moved = after(play, move), !moved.report.wins else { continue }
            return (move, back)
        }
        return nil
    }

    /// The exhausted path of manifest number `number`: the whole budget spent toggling ``losingToggle(_:)``'s move and
    /// its inverse, so the final arrangement (the start, or that one change) never wins; empty when there is no such
    /// toggle.
    public static func exhaustedPath(_ number: Int) -> [MyceliumArchitectAction] {
        guard let level = certified(number)?.level, let toggle = losingToggle(number) else { return [] }
        var path: [MyceliumArchitectAction] = []
        for index in 0..<level.budget {
            path.append(index % 2 == 0 ? toggle.move : toggle.inverse)
        }
        return path
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or no exhausted path exists.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [MyceliumArchitectAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        var entries: [ScenarioStep] = []
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            for action in actions.dropLast() { entries.append(actionEntry(action)) }
            entries += [actionEntry(perturbed), runEntry(), acceptedEntry("play.undo"), acceptedEntry("play.undo"),
                        actionEntry(last), runEntry()]
            return entries
        }
        let path: [MyceliumArchitectAction] = exhaustedPath(number)
        guard path.count >= 2 else { return [] }
        // The move the budget refuses: the next toggle the path would make.
        let further: MyceliumArchitectAction = path.count % 2 == 0 ? path[0] : path[1]
        for action in path { entries.append(actionEntry(action)) }
        entries += [refusedAction(further, budgetCode), runEntry(), refusedAction(further, stageCode)]
        return entries
    }

    /// The extreme settings of `level`: among the legal moves at the opening, the first and last nutrient sites, the
    /// lowest and highest seeds and the first and last blocker sites, in that order without repeats, at most three.
    public static func extremeSettings(_ level: MyceliumArchitectLevel) -> [MyceliumArchitectAction] {
        guard let play = try? freshPlay(of: level) else { return [] }
        var nutrients: [MyceliumArchitectAction] = []
        var seeds: [MyceliumArchitectAction] = []
        var blockers: [MyceliumArchitectAction] = []
        for move in legalMoves(play) {
            switch move {
            case .nutrient: nutrients.append(move)
            case .seed: seeds.append(move)
            case .blocker: blockers.append(move)
            case .clear, .unseed, .run: break
            }
        }
        var ordered: [MyceliumArchitectAction] = []
        for group in [nutrients, seeds, blockers] {
            if let first = group.first { ordered.append(first) }
            if let last = group.last { ordered.append(last) }
        }
        var settings: [MyceliumArchitectAction] = []
        for move in ordered where settings.count < 3 && !settings.contains(move) { settings.append(move) }
        return settings
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no extreme setting.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number) else { return [] }
        let level: MyceliumArchitectLevel = play.level
        let extremes: [MyceliumArchitectAction] = extremeSettings(level)
        guard !extremes.isEmpty else { return [] }
        let pulses: Int = play.report.pulsesRun
        let high: Double = Double(cellRange.upperBound + 1)
        var entries: [ScenarioStep] = [showEntry(pulses), showEntry(0)]
        if row % 2 == 1 {
            entries.append(refusedEntry("cell.nutrient", [high, 0], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("root.seed", [Double(directionRange.upperBound + 1)], outOfRangeCode, steps: 1))
        } else {
            entries.append(refusedEntry("cell.blocker", [0, high], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("root.unseed", [-1], outOfRangeCode, steps: 1))
        }
        entries += [refusedEntry("cell.nutrient", values(offBoard(level)), kernelActionCode, steps: 1),
                    refusedEntry("root.unseed", [Double(unseeded(play.arrangement).rawValue)], kernelActionCode,
                                 steps: 1),
                    refusedEntry("cell.clear", [0.5, 0], notWholeCode, steps: 1),
                    refusedEntry("growth.show", [Double(pulses + 1)], pulseCode, steps: 1),
                    refusedEntry("growth.show", [Double(pulseRange.upperBound + 1)], outOfRangeCode, steps: 1)]
        for setting in extremes { entries += [actionEntry(setting), acceptedEntry("play.undo")] }
        return entries
    }

    /// The pulse a touch row on level `number` shows: half the pulses run after the probe move (0 when there is none).
    public static func touchPulse(_ number: Int) -> Int {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return 0
        }
        return moved.report.pulsesRun / 2
    }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe move.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let probe = probeMove(number) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                showEntry(touchPulse(number)), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The failure code accessibility row `row` prefers: ``preferredFailures`` at (row − 1) mod 4.
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
            return winning + [acceptedEntry("level.next"), actionEntry(next), acceptedEntry("play.undo"),
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> MyceliumArchitectExperienceCore? {
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
            let end: MyceliumArchitectExperienceCore? = played(seed: acceptance.seed, entries: acceptance.entries)
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
