// MushroomWeatherScenarios — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-005, 008; SC-R02G2003-004). The
// scenarios the verification runner plays for Mushroom Weather, a round-two game, all short (owner rule of 2026-11-13),
// on the pattern of Microscopic Aurora's (feature 483):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G20-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md, section 6.20.19), each with the seed of its level; the
//     row's archived title (area and condition, verbatim) is ``acceptanceTitle(_:)``;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1 and the run, outcome `won`),
//     `fixture-run-fails` (the run with the level's starting arrangement, outcome `failed`: a certified level's start
//     never already wins) and `fixture-undo-redo` (the probe placement, its undo and its redo).
// Every certified action comes from the generated level's minimal plan (`MushroomWeatherGenerated.plan.actions`, the
// plan `MushroomWeatherSolver.plan` finds for the prepared level: its placements in slot order, then its vent toggles,
// then its moonlight change, equal to the stored witness `docs/games/mushroom-weather/levels/NNN.witness.json` without
// its run — level 1: a pod in slot 0 at row 2, column 5, then vent 0 shut), so a regenerated catalog cannot leave a
// stale script; the plan is won by its actions followed by `weather.run`. An arrangement action never ends the play
// (only the run does). The probe placement is the plan's first placement, else the first legal placement in the rules'
// move order (slots 0 … P − 1, sites row-major; then removals, vent toggles, moonlight levels); the second move is the
// first legal move after it. Pods stand on the level's sites only. The two input actions are the probe and the second
// move; input-response, save-restore and reset play both and undo the second; completion plays the certified plan of
// level 1 and the run and expects `won`; full-playthrough wins levels 1, 2 and 3 with `level.next` between them; hero
// plays the certified plan of level 1 without the run (a run now would win) and shows (`clock.show`) the hero cycle —
// the last cycle of the predicted winning run, where every colony has held its band for the required cycles — so the
// picture shows the thriving forest while the play is still open; rejection refuses values outside the declared
// ranges, fractional values, actions the kernel refuses (the removal of an empty slot, a slot or vent the level lacks,
// a pod on a blocked cell, on a colony or off the level's sites, a vent or the moonlight set to its current value, an
// undo or redo with nothing to revert), a shown cycle past the cycles run and wrong value counts (never an undeclared
// control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 67) mod 100 + 1 for rows 1 … 20 (068, 075, … 096, 003, 010, … 094,
// 001); the same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to 100),
// each opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted on the
// real controls with the outcome the kernel gives; the row's command cycles through the matrix's five (commit season,
// place fungus, adjust mist vent, open canopy, route humidity) and its illegal condition through the matrix's five
// (small mushrooms invisible, growth update tied to FPS, negative humidity, unstable diffusion timestep, spore density
// excessive):
//   1 … 10  truth and state transitions — the probe placement, then an illegal command by (r − 1) mod 5: the same
//           placement again, refused `r02-g20.action` (commit season; small mushrooms invisible: an unchanged pod); a
//           pod on the first floor cell that is not a site, refused `r02-g20.action` (place fungus; growth update tied
//           to FPS); vent 0 set to a state of 0.5, refused `r02-g20.not-whole` (adjust mist vent; negative humidity); the
//           moonlight set to its current level, refused `r02-g20.action` (open canopy; unstable diffusion timestep: an
//           unchanged moonlight); a pod in slot 6, refused `action.out-of-range` (route humidity; spore density
//           excessive: more pods than any level holds);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last action perturbed (the first legal
//           move there other than it after which the run fails), the run (failed), an undo (an honest retry), an undo of
//           the perturbed move, the certified last action and the run (won); even rows: an exhausted path — the whole
//           budget spent toggling slot 0 between the first site whose lone pod does not win and empty (so the final
//           arrangement never wins), a further move refused `r02-g20.budget`, the run (failed) and the move refused
//           `r02-g20.stage`;
//  21 … 30  numeric and geometry edges — the last and the first cycle run shown (the endpoints), then slot 6 and
//           moonlight 4 (odd rows) or row 12 and vent state 2 (even rows) refused out of range, the removal of the empty
//           slot 0 and a pod off the sites refused `r02-g20.action`, a row of 0.5 refused `r02-g20.not-whole`, the cycle
//           past the cycles run refused `r02-g20.cycle` (out of range at 201), then the extreme settings — slot 0 at the
//           first site, the last slot at the last site and the moonlight extreme farthest from the start, each undone —
//           back to the opening digest;
//  31 … 40  touch and camera semantics — the probe placement, undo, redo (the placed digest again), the middle cycle of
//           its run shown (presentation: the digest does not change), then a second redo refused `r02-g20.action`;
//  41 … 50  rendering — the certified plan and the run (won; the digest is the same at every quality tier), then an
//           undo refused `r02-g20.stage` (a won play is final);
//  51 … 60  accessibility and safety — a failing run named in words, then an undo: an honest retry back to the digest
//           before the run. The run follows a proper prefix of the certified plan, alone or after one legal move; the
//           first such run (prefixes shortest first, the bare run before the moves in the rules' order) whose failure
//           has the row's preferred code (`dried`, `mold`, `unstable` by (r − 1) mod 3), else the first failing run
//           found;
//  61 … 70  persistence and replay — the probe placement, undo, redo, undo, then the certified plan and the run (won;
//           the saved trace replays to the same state);
//  71 … 80  integration — the certified plan and the run (won, the next level opened), `level.next` (the next
//           certified level, a fresh play), its probe placement, an undo (the next level's fresh play) and a second undo
//           refused `r02-g20.action`; on level 100 (row 77) `level.next` is refused `r02-g20.locked` after the win (no
//           wrap) and the row chooses level 1 with `level.select [1]` instead.
// Feature 495 (R02-G20-05) T-R02G2005-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`; the
// integration rows (71 … 80) therefore first win their level's certified plan (a campaign win opens the next level)
// before `level.next`; rejection also refuses the progression controls' wrong value counts (`level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest is regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`).
// Feature 497 (R02-G20-07) T-R02G2007-003: digests are schema 3's ("…v3"), wins store their traces, and rejection also
// refuses the replay and sound controls' wrong value counts (`replay.start`, `replay.step`, `replay.stop`,
// `settings.sound`); the manifest was regenerated (`UPDATE_SCENARIO_MANIFEST=1`).
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension MushroomWeatherExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` wins in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G20-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10
    /// The failure codes accessibility rows prefer, by (row − 1) mod 3: the kernel's three failures.
    public static let preferredFailures: [String] = ["dried", "mold", "unstable"]
    /// The archived matrix's eight areas, in row order (round2.md section 6.20.19, verbatim).
    public static let acceptanceAreas: [String] = [
        "Truth and state transitions", "Solver witness and rejection", "Numeric and geometry edge",
        "Touch and camera semantics", "Rendering and shaders", "Accessibility and safety", "Persistence and replay",
        "Integration, privacy and devices",
    ]
    /// The archived matrix's ten conditions, by (row − 1) mod 10 (round2.md section 6.20.19, verbatim).
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
    /// The code of a fractional slot, row, column, vent, state, moonlight or cycle.
    static let notWholeCode = "action.rule." + MushroomWeatherExperienceRule.notWhole
    /// The code of a shown cycle past the cycles run (`clock.show`).
    static let cycleCode = "action.rule." + MushroomWeatherExperienceRule.cycle
    /// The code of the kernel's action refusal (an unchanged pod, vent or moonlight; a slot or vent the level lacks; a
    /// cell off the floor, on a colony, off the sites or occupied; an empty slot removed; nothing to undo or redo).
    static let kernelActionCode = "action.rule." + MushroomWeatherError.action("").reasonCode
    /// The code of the kernel's stage refusal (an arrangement action or run outside stage `playing`, an undo of a won
    /// play).
    static let stageCode = "action.rule." + MushroomWeatherError.stage.reasonCode
    /// The code of the kernel's budget refusal (an arrangement action with no action left).
    static let budgetCode = "action.rule." + MushroomWeatherError.budget.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last action perturbed and recovered (odd) or an exhausted path (even).
        case witness
        /// Rows 21 … 30: the cycle endpoints, the refusals just outside the ranges and the extreme settings undone.
        case numeric
        /// Rows 31 … 40: a placement, undo, redo, a cycle shown and a refused redo.
        case touch
        /// Rows 41 … 50: the plan won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failing run, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a placement undone, redone and undone, then the plan won.
        case persistence
        /// Rows 71 … 80: the plan won, the next level, its probe placement, an undo and a refused undo.
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

    /// The `pod.place` values of a pod of `slot` on `cell`: slot, row and column.
    static func placeValues(slot: Int, _ cell: MushroomWeatherCell) -> [Double] {
        [Double(slot), Double(cell.row), Double(cell.column)]
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: MushroomWeatherAction) -> ScriptedAction {
        switch action {
        case let .place(slot, cell): ScriptedAction("pod.place", placeValues(slot: slot, cell))
        case let .remove(slot): ScriptedAction("pod.remove", [Double(slot)])
        case let .vent(index, open): ScriptedAction("vent.set", [Double(index), open ? 1 : 0])
        case let .moonlight(level): ScriptedAction("moon.set", [Double(level)])
        case .run: ScriptedAction("weather.run", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: MushroomWeatherAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: MushroomWeatherAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The accepted entry of the run.
    static func runEntry() -> ScenarioStep { actionEntry(.run) }

    /// The accepted entry that shows `cycle` (presentation only).
    static func showEntry(_ cycle: Int) -> ScenarioStep {
        acceptedEntry("clock.show", [Double(cycle)])
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> MushroomWeatherGenerated? {
        try? generated(number: number)
    }

    /// The certified plan's actions of manifest number `number` (the run not included); empty when the level cannot be
    /// generated.
    public static func certifiedActions(_ number: Int) -> [MushroomWeatherAction] {
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
    static func openingPlay(_ number: Int) -> MushroomWeatherPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The legal moves of `play` in the rules' order (placements by slot 0 … P − 1, sites row-major, skipping occupied
    /// cells and the slot's own cell; then removals of occupied slots; then vent toggles; then the other moonlight
    /// levels); empty outside stage `playing` or with the budget spent.
    static func legalMoves(_ play: MushroomWeatherPlay) -> [MushroomWeatherAction] {
        guard play.stage == .playing else { return [] }
        let position = MushroomWeatherPuzzle.Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
        return MushroomWeatherPuzzle(level: play.level).moves(in: position)
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: MushroomWeatherPlay, _ action: MushroomWeatherAction) -> MushroomWeatherPlay? {
        var next: MushroomWeatherPlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// `play` after `actions` in order; nil when the kernel refuses one.
    static func after(_ play: MushroomWeatherPlay, _ actions: [MushroomWeatherAction]) -> MushroomWeatherPlay? {
        var current: MushroomWeatherPlay = play
        for action in actions {
            guard let next = after(current, action) else { return nil }
            current = next
        }
        return current
    }

    /// Whether `action` is a placement.
    static func isPlacement(_ action: MushroomWeatherAction) -> Bool {
        if case .place = action { return true }
        return false
    }

    /// The probe placement of manifest number `number`: the certified plan's first placement, else the first legal
    /// placement at the opening; nil when there is none.
    public static func probeMove(_ number: Int) -> MushroomWeatherAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [MushroomWeatherAction] = []
        for action in certifiedActions(number) where isPlacement(action) {
            candidates.append(action)
            break
        }
        for move in legalMoves(play) where isPlacement(move) { candidates.append(move) }
        for move in candidates where after(play, move)?.stage == .playing {
            return move
        }
        return nil
    }

    /// The second move of manifest number `number`: after the probe placement, the first legal move; nil when there is
    /// none.
    public static func secondMove(_ number: Int) -> MushroomWeatherAction? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return legalMoves(moved).first
    }

    /// The two input actions on the opening level: the probe placement, then the second move; empty when there is
    /// none.
    public static var inputActions: [MushroomWeatherAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let probe = probeMove(number), let second = secondMove(number) else { return [] }
        return [probe, second]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [MushroomWeatherAction] = inputActions
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

    /// The hero cycle of manifest number `number`: the last cycle of the certified plan's predicted run (a winning run
    /// runs every cycle of the level), where every colony has held its band for the required cycles; nil when the level
    /// cannot be generated or its plan is refused.
    public static func heroCycle(_ number: Int) -> Int? {
        guard let play = openingPlay(number), let planned = after(play, certifiedActions(number)) else { return nil }
        return planned.report.cycles
    }

    /// The entries of hero: the certified plan of the opening level without the run, then the hero cycle shown, so the
    /// picture shows the thriving forest while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        let actions: [MushroomWeatherAction] = certifiedActions(number)
        guard !actions.isEmpty, let cycle = heroCycle(number) else { return [] }
        var entries: [ScenarioStep] = []
        for action in actions { entries.append(actionEntry(action)) }
        entries.append(showEntry(cycle))
        return entries
    }

    /// The failing run of manifest number `number`: a proper prefix of the certified plan (shortest first), then
    /// nothing or one legal move (in the rules' order), then the run, whose failure has the code `preferred`; the first
    /// failing run found when none has it; nil when there is none. A proper prefix of a minimal plan never wins, so
    /// the bare run after every prefix fails.
    static func failingRun(_ number: Int, preferring preferred: String)
        -> (prefix: [MushroomWeatherAction], change: MushroomWeatherAction?)? {
        let actions: [MushroomWeatherAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [MushroomWeatherAction], change: MushroomWeatherAction?)?
        for count in 0..<max(actions.count, 1) {
            if count > 0 {
                guard let next = after(play, actions[count - 1]) else { break }
                play = next
            }
            var changes: [MushroomWeatherAction?] = [nil]
            for move in legalMoves(play) { changes.append(move) }
            for change in changes {
                var tried: [MushroomWeatherAction] = []
                if let change { tried.append(change) }
                tried.append(.run)
                guard let ran = after(play, tried), ran.stage == .failed, let failure = ran.failure else { continue }
                let found: (prefix: [MushroomWeatherAction], change: MushroomWeatherAction?) =
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

    /// The entries of `fixture-undo-redo`: the probe placement, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The first cell of `level`, row-major, that is off its floor (a blocked cell; the kernel refuses a pod there);
    /// row 0, column 0 for a level without one.
    public static func blockedCell(_ level: MushroomWeatherLevel) -> MushroomWeatherCell {
        for row in 0..<level.rows {
            for column in 0..<level.columns {
                let cell: MushroomWeatherCell = MushroomWeatherCell(row: row, column: column)
                if !level.isFloor(cell) { return cell }
            }
        }
        return MushroomWeatherCell(row: 0, column: 0)
    }

    /// The first floor cell of `level`, row-major, without a colony that is not one of its sites (the kernel refuses a
    /// pod there); nil for a level without sites or without such a cell.
    public static func offSiteCell(_ level: MushroomWeatherLevel) -> MushroomWeatherCell? {
        guard level.sites != nil else { return nil }
        let colonies: Set<MushroomWeatherCell> = level.colonyCells
        for row in 0..<level.rows {
            for column in 0..<level.columns {
                let cell: MushroomWeatherCell = MushroomWeatherCell(row: row, column: column)
                if level.isFloor(cell) && !colonies.contains(cell) && !level.allowsPod(cell) { return cell }
            }
        }
        return nil
    }

    /// The placement in slot 0 on `level`'s first off-site cell (refused `r02-g20.action`), else on its first blocked
    /// cell (refused `r02-g20.action` too).
    static func offSitePlacement(_ level: MushroomWeatherLevel) -> MushroomWeatherAction {
        .place(slot: 0, cell: offSiteCell(level) ?? blockedCell(level))
    }

    /// The first site of `level` (row 0, column 0 for a level without sites).
    static func firstSite(_ level: MushroomWeatherLevel) -> MushroomWeatherCell {
        level.sites?.first ?? MushroomWeatherCell(row: 0, column: 0)
    }

    /// The cycle just past the cycles `play`'s report runs and the code that refuses it: `r02-g20.cycle` within the
    /// declared range, `action.out-of-range` past 200.
    static func beyondCycle(_ play: MushroomWeatherPlay) -> (cycle: Int, code: String) {
        let cycle: Int = play.report.cycles + 1
        return (cycle, cycleRange.contains(cycle) ? cycleCode : outOfRangeCode)
    }

    /// The moonlight extreme farthest from `level`'s starting moonlight: 3 from a start of 0 or 1, else 0.
    static func moonlightExtreme(_ level: MushroomWeatherLevel) -> Int {
        level.start.moonlight <= 1 ? moonRange.upperBound : moonRange.lowerBound
    }

    /// The extreme settings of `level`: slot 0 at the first site, the last slot at the last site and the moonlight
    /// extreme farthest from the start; nil when the level has fewer than two sites or two slots.
    public static func extremeSettings(_ level: MushroomWeatherLevel)
        -> (smallest: MushroomWeatherAction, largest: MushroomWeatherAction, moonlight: MushroomWeatherAction)? {
        guard let sites = level.sites, let first = sites.first, let last = sites.last, first != last,
              level.podRules.slots >= 2 else { return nil }
        return (.place(slot: 0, cell: first), .place(slot: level.podRules.slots - 1, cell: last),
                .moonlight(level: moonlightExtreme(level)))
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number) else { return [] }
        let level: MushroomWeatherLevel = play.level
        let site: MushroomWeatherCell = firstSite(level)
        let r: Double = Double(site.row)
        let c: Double = Double(site.column)
        let highSlot: Double = Double(slotRange.upperBound + 1)
        let highRow: Double = Double(rowRange.upperBound + 1)
        let highColumn: Double = Double(columnRange.upperBound + 1)
        let highVent: Double = Double(ventRange.upperBound + 1)
        let highOpen: Double = Double(openRange.upperBound + 1)
        let highMoon: Double = Double(moonRange.upperBound + 1)
        let highCycle: Double = Double(cycleRange.upperBound + 1)
        let beyond: (cycle: Int, code: String) = beyondCycle(play)
        let blocked: MushroomWeatherCell = blockedCell(level)
        let missingSlot: Double = Double(level.podRules.slots)
        let missingVent: Double = Double(level.vents.count)
        let ventState: Double = level.start.ventsOpen.first == true ? 1 : 0
        var entries: [ScenarioStep] = [
            refusedEntry("pod.place", [highSlot, r, c], outOfRangeCode),
            refusedEntry("pod.place", [-1, r, c], outOfRangeCode),
            refusedEntry("pod.place", [0, highRow, c], outOfRangeCode),
            refusedEntry("pod.place", [0, -1, c], outOfRangeCode),
            refusedEntry("pod.place", [0, r, highColumn], outOfRangeCode),
            refusedEntry("pod.place", [0, r, -1], outOfRangeCode),
            refusedEntry("pod.remove", [highSlot], outOfRangeCode),
            refusedEntry("pod.remove", [-1], outOfRangeCode),
            refusedEntry("vent.set", [highVent, 0], outOfRangeCode),
            refusedEntry("vent.set", [-1, 0], outOfRangeCode),
            refusedEntry("vent.set", [0, highOpen], outOfRangeCode),
            refusedEntry("vent.set", [0, -1], outOfRangeCode),
            refusedEntry("moon.set", [highMoon], outOfRangeCode),
            refusedEntry("moon.set", [-1], outOfRangeCode),
            refusedEntry("clock.show", [highCycle], outOfRangeCode),
            refusedEntry("clock.show", [-1], outOfRangeCode),
            refusedEntry("pod.place", [0.5, r, c], notWholeCode),
            refusedEntry("pod.place", [0, r + 0.5, c], notWholeCode),
            refusedEntry("pod.place", [0, r, c + 0.5], notWholeCode),
            refusedEntry("pod.remove", [0.5], notWholeCode),
            refusedEntry("vent.set", [0.5, 0], notWholeCode),
            refusedEntry("vent.set", [0, 0.5], notWholeCode),
            refusedEntry("moon.set", [0.5], notWholeCode),
            refusedEntry("clock.show", [0.5], notWholeCode),
            refusedEntry("pod.remove", [0], kernelActionCode),
            refusedEntry("pod.place", [0, Double(blocked.row), Double(blocked.column)], kernelActionCode),
            refusedAction(offSitePlacement(level), kernelActionCode),
        ]
        if let colony = level.colonies.first {
            entries.append(refusedAction(.place(slot: 0, cell: colony.cell), kernelActionCode))
        }
        if level.podRules.slots <= slotRange.upperBound {
            entries.append(refusedEntry("pod.place", [missingSlot, r, c], kernelActionCode))
        }
        if level.vents.count <= ventRange.upperBound {
            entries.append(refusedEntry("vent.set", [missingVent, 1], kernelActionCode))
        }
        if !level.vents.isEmpty {
            entries.append(refusedEntry("vent.set", [0, ventState], kernelActionCode))
        }
        entries += [
            refusedEntry("moon.set", [Double(level.start.moonlight)], kernelActionCode),
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("clock.show", [Double(beyond.cycle)], beyond.code),
            refusedEntry("pod.place", [], wrongCountCode),
            refusedEntry("pod.place", [0, r], wrongCountCode),
            refusedEntry("pod.place", [0, r, c, 0], wrongCountCode),
            refusedEntry("pod.remove", [], wrongCountCode),
            refusedEntry("pod.remove", [0, 0], wrongCountCode),
            refusedEntry("vent.set", [0], wrongCountCode),
            refusedEntry("vent.set", [0, 0, 0], wrongCountCode),
            refusedEntry("moon.set", [], wrongCountCode),
            refusedEntry("moon.set", [0, 0], wrongCountCode),
            refusedEntry("weather.run", [1], wrongCountCode),
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
            refusedEntry("replay.start", [], wrongCountCode),
            refusedEntry("replay.step", [1], wrongCountCode),
            refusedEntry("replay.stop", [1], wrongCountCode),
            refusedEntry("settings.sound", [], wrongCountCode),
        ]
        return entries
    }

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 67) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (068, 075, … 096, 003, 010, … 094, 001), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 67) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G20-QA-001` … `R2-G20-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G20-QA-" + threeDigits(row) }

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

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`;
    /// for level 100, whose `level.next` is refused `r02-g20.locked` (no wrap), level 1 with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + MushroomWeatherExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 495).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The perturbed last action of manifest number `number`: after the certified plan without its last action, the
    /// first legal move there other than it after which the run fails; nil when there is none.
    public static func perturbedLast(_ number: Int) -> MushroomWeatherAction? {
        let actions: [MushroomWeatherAction] = certifiedActions(number)
        guard let opening = openingPlay(number), let last = actions.last,
              let play = after(opening, Array(actions.dropLast())) else { return nil }
        for move in legalMoves(play) where move != last {
            guard let ran = after(play, [move, .run]), ran.stage == .failed else { continue }
            return move
        }
        return nil
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or its probe is not a placement.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number),
              case let .place(slot, cell) = probe else { return [] }
        var entries: [ScenarioStep] = [actionEntry(probe)]
        switch (row - 1) % 5 {
        case 0:   // commit season — small mushrooms invisible: the same pod again is unchanged
            entries.append(refusedAction(probe, kernelActionCode))
        case 1:   // place fungus — growth update tied to FPS: a pod off the level's sites
            entries.append(refusedAction(offSitePlacement(play.level), kernelActionCode))
        case 2:   // adjust mist vent — negative humidity: a fractional vent state
            entries.append(refusedEntry("vent.set", [0, 0.5], notWholeCode, steps: 1))
        case 3:   // open canopy — unstable diffusion timestep: the moonlight set to its current level is unchanged
            entries.append(refusedAction(.moonlight(level: play.arrangement.moonlight), kernelActionCode))
        default:  // route humidity — spore density excessive: a pod in a slot beyond any level's slots
            var values: [Double] = placeValues(slot: slot, cell)
            values[0] = Double(slotRange.upperBound + 1)
            entries.append(refusedEntry("pod.place", values, outOfRangeCode, steps: 1))
        }
        return entries
    }

    /// The site the exhausted path of manifest number `number` toggles in slot 0: the first site (row-major) whose lone
    /// pod in slot 0, with the start's vents and moonlight, does not win; nil when there is none.
    public static func losingSite(_ number: Int) -> MushroomWeatherCell? {
        guard let level = certified(number)?.level, let sites = level.sites, !level.start.pods.isEmpty else {
            return nil
        }
        for site in sites {
            var pods: [MushroomWeatherCell?] = level.start.pods
            pods[0] = site
            let arrangement = MushroomWeatherArrangement(pods: pods, ventsOpen: level.start.ventsOpen,
                                                         moonlight: level.start.moonlight)
            if !MushroomWeatherForest.report(level, arrangement: arrangement).wins { return site }
        }
        return nil
    }

    /// The exhausted path of manifest number `number`: the whole budget spent toggling slot 0 between
    /// ``losingSite(_:)`` and empty, so the final arrangement (the start, or that one pod) never wins; empty when there
    /// is no such site.
    public static func exhaustedPath(_ number: Int) -> [MushroomWeatherAction] {
        guard let level = certified(number)?.level, let site = losingSite(number) else { return [] }
        var path: [MushroomWeatherAction] = []
        for index in 0..<level.budget { path.append(index % 2 == 0 ? .place(slot: 0, cell: site) : .remove(slot: 0)) }
        return path
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or no exhausted path exists.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [MushroomWeatherAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        var entries: [ScenarioStep] = []
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            for action in actions.dropLast() { entries.append(actionEntry(action)) }
            entries += [actionEntry(perturbed), runEntry(), acceptedEntry("play.undo"), acceptedEntry("play.undo"),
                        actionEntry(last), runEntry()]
            return entries
        }
        let path: [MushroomWeatherAction] = exhaustedPath(number)
        guard path.count >= 2 else { return [] }
        // The move the budget refuses: the placement again after an even path (an empty slot 0), else the removal.
        let further: MushroomWeatherAction = path.count % 2 == 0 ? path[0] : .remove(slot: 0)
        for action in path { entries.append(actionEntry(action)) }
        entries += [refusedAction(further, budgetCode), runEntry(), refusedAction(further, stageCode)]
        return entries
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has fewer than two sites or slots.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let extremes = extremeSettings(play.level) else { return [] }
        let level: MushroomWeatherLevel = play.level
        let site: MushroomWeatherCell = firstSite(level)
        let r: Double = Double(site.row)
        let c: Double = Double(site.column)
        let beyond: (cycle: Int, code: String) = beyondCycle(play)
        var entries: [ScenarioStep] = [showEntry(play.report.cycles), showEntry(0)]
        if row % 2 == 1 {
            let highSlot: Double = Double(slotRange.upperBound + 1)
            let highMoon: Double = Double(moonRange.upperBound + 1)
            entries.append(refusedEntry("pod.place", [highSlot, r, c], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("moon.set", [highMoon], outOfRangeCode, steps: 1))
        } else {
            let highRow: Double = Double(rowRange.upperBound + 1)
            let highOpen: Double = Double(openRange.upperBound + 1)
            entries.append(refusedEntry("pod.place", [0, highRow, c], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("vent.set", [0, highOpen], outOfRangeCode, steps: 1))
        }
        entries += [refusedAction(.remove(slot: 0), kernelActionCode),
                    refusedAction(offSitePlacement(level), kernelActionCode),
                    refusedEntry("pod.place", [0, 0.5, c], notWholeCode, steps: 1),
                    refusedEntry("clock.show", [Double(beyond.cycle)], beyond.code, steps: 1),
                    actionEntry(extremes.smallest), acceptedEntry("play.undo"),
                    actionEntry(extremes.largest), acceptedEntry("play.undo"),
                    actionEntry(extremes.moonlight), acceptedEntry("play.undo")]
        return entries
    }

    /// The touch cycle of manifest number `number`: the middle cycle of the run after its probe placement; nil when
    /// there is none.
    public static func touchCycle(_ number: Int) -> Int? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return moved.report.cycles / 2
    }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe
    /// placement.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let probe = probeMove(number), let cycle = touchCycle(number) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                showEntry(cycle), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The failure code accessibility row `row` prefers: ``preferredFailures`` at (row − 1) mod 3.
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> MushroomWeatherExperienceCore? {
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
            let end: MushroomWeatherExperienceCore? = played(seed: acceptance.seed, entries: acceptance.entries)
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
