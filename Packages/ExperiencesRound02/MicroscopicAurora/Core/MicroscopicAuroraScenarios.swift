// MicroscopicAuroraScenarios — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-005, 008). The scenarios the
// verification runner plays for Microscopic Aurora, a round-two game, all short (owner rule of 2026-11-13), on the
// pattern of Apsides Workshop's (feature 473):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G19-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1 and the play, outcome `won`),
//     `fixture-run-fails` (the play with no well placed, outcome `failed`: a certified level's minimal plan has at
//     least one placement, so the empty dish never wins) and `fixture-undo-redo` (the probe placement, its undo and
//     its redo).
// Every certified placement comes from the generated level's minimal plan (`MicroscopicAuroraGenerated.plan.actions`,
// the plan `MicroscopicAuroraSolver.plan` finds for the prepared level, equal to the stored witness
// `docs/games/microscopic-aurora/levels/NNN.witness.json` without its play — level 1: one well in slot 0 at row 11,
// column 18, strength 2, clockwise), so a regenerated catalog cannot leave a stale script; the plan is won by its
// placements followed by `swim.play`. A placement never ends the play (only the play does), so the probe placement is
// the first certified placement (the first legal move, in the rules' move order — slots 0 … 2, sites row-major,
// strengths 1 … 4, clockwise first, then removals — should the plan be empty) and the second move is the first legal
// move after it. Wells stand on the level's sites only. The two input actions are the probe and the second move;
// input-response, save-restore and reset play both and undo the second; completion plays the certified plan of level 1
// and the play and expects `won`; full-playthrough wins levels 1, 2 and 3 with `level.next` between them; hero plays
// the certified plan of level 1 without the play (a play now would win) and shows (`clock.show`) the hero tick — the
// last tick of the predicted winning swim, where every ribbon is complete over the lit stencil — so the picture shows
// the winning aurora while the play is still open; rejection refuses values outside the declared ranges, fractional
// values, actions the kernel refuses (the removal of an empty slot, a well outside the enclosure, a well off the
// level's sites, an undo or redo with nothing to revert), a shown tick past the ticks swum and wrong value counts
// (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 64) mod 100 + 1 for rows 1 … 20 (065, 072, … 100, 007, 014, 021, 028,
// 035, … 098); the same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to
// 100), each opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted
// on the real controls with the outcome the kernel gives; the row's command cycles through the matrix's five (commit
// organism shape, place magnetic pole, tune field, release swimmers, record trail) and its illegal condition through
// the matrix's five (crowd overdraw on D3, false pattern due to blur, chaotic nondeterminism, neighbor-order
// dependence, unstable high forces):
//   1 … 10  truth and state transitions — a legal command then an illegal one, by (r − 1) mod 5: the probe placement,
//           then the same placement again, refused `r02-g19.action` (commit organism shape; crowd overdraw: an
//           unchanged well); the probe placement, then a well on the first usable cell that is not a site, refused
//           `r02-g19.action` (place magnetic pole; false pattern due to blur); the probe placement, then a strength of
//           s ± 0.5, refused `r02-g19.not-whole` (tune field; chaotic nondeterminism); the probe placement, then the
//           probe's cell in the next slot, refused `r02-g19.action` (release swimmers; neighbor-order dependence: an
//           occupied cell); the probe placement, then strength 5, refused `action.out-of-range` (record trail; unstable
//           high forces);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last placement perturbed (the first
//           legal move there other than it after which the play fails), the play (failed), an undo (an honest retry),
//           an undo of the perturbed move, the certified last placement and the play (won); even rows: an exhausted
//           path — the whole budget spent toggling slot 0 between the first one-well setting (sites row-major,
//           strengths 1 … 4, clockwise first) whose swim does not win and empty (so the final dish never wins), a further move
//           refused `r02-g19.budget`, the play (failed) and the move refused `r02-g19.stage`;
//  21 … 30  numeric and geometry edges — the last and the first tick swum shown (the endpoints), then strength 5 and
//           slot 3 (odd rows) or row 24 and sense 2 (even rows) refused out of range, the removal of the empty slot 0
//           and a well off the sites refused `r02-g19.action`, a row of 0.5 refused `r02-g19.not-whole`, the tick past
//           the ticks swum refused `r02-g19.tick` (out of range at 481), then the extreme placements — slot 0 at the
//           first site with strength 1 clockwise and at the last site with strength 4 counterclockwise, each undone —
//           back to the opening digest;
//  31 … 40  touch and camera semantics — the probe placement, undo, redo (the placed digest again), the middle tick of
//           its swim shown (presentation: the digest does not change), then a second redo refused `r02-g19.action`;
//  41 … 50  rendering — the certified plan and the play (won, the stencil lit; the digest is the same at every quality
//           tier), then an undo refused `r02-g19.stage` (a won play is final);
//  51 … 60  accessibility and safety — a failing play named in words, then an undo: an honest retry back to the digest
//           before the play. The play follows a proper prefix of the certified plan, alone or after one legal move;
//           the first such play (prefixes shortest first, the bare play before the moves in the rules' order) whose
//           failure has the row's preferred code (`coverage`, `connectedness`, `exit`, `coherence` by (r − 1) mod 4),
//           else the first failing play found;
//  61 … 70  persistence and replay — the probe placement, undo, redo, undo, then the certified plan and the play (won;
//           the saved trace replays to the same state);
//  71 … 80  integration — the certified plan and the play (won, the next level opened), `level.next` (the next
//           certified level, a fresh play), its probe placement, an undo (the next level's fresh play) and a second undo
//           refused `r02-g19.action`; on level 100 (no row reaches it today) `level.next` is refused `r02-g19.locked`
//           after the win (no wrap) and the row chooses level 1 with `level.select [1]` instead.
// Feature 485 (R02-G19-05) T-R02G1905-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
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

extension MicroscopicAuroraExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` wins in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G19-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10
    /// The failure codes accessibility rows prefer, by (row − 1) mod 4.
    public static let preferredFailures: [String] = ["coverage", "connectedness", "exit", "coherence"]

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional slot, cell, strength, sense or tick.
    static let notWholeCode = "action.rule." + MicroscopicAuroraExperienceRule.notWhole
    /// The code of a shown tick past the ticks swum (`clock.show`).
    static let tickCode = "action.rule." + MicroscopicAuroraExperienceRule.tick
    /// The code of the kernel's action refusal (an unchanged well, a cell outside, off the sites or occupied, an empty
    /// slot removed, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + MicroscopicAuroraError.action("").reasonCode
    /// The code of the kernel's stage refusal (a move or play outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + MicroscopicAuroraError.stage.reasonCode
    /// The code of the kernel's budget refusal (a placement or removal with no action left).
    static let budgetCode = "action.rule." + MicroscopicAuroraError.budget.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last placement perturbed and recovered (odd) or an exhausted path (even).
        case witness
        /// Rows 21 … 30: the tick endpoints, the refusals just outside the ranges and the extreme placements undone.
        case numeric
        /// Rows 31 … 40: a placement, undo, redo, a tick shown and a refused redo.
        case touch
        /// Rows 41 … 50: the plan won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failing play, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a placement undone, redone and undone, then the plan won.
        case persistence
        /// Rows 71 … 80: the next level, its probe placement, an undo and a refused undo.
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

    /// The `well.place` values of `well` in `slot`: slot, row, column, strength and sense (0 clockwise, 1
    /// counterclockwise).
    static func placeValues(slot: Int, _ well: MicroscopicAuroraWell) -> [Double] {
        [Double(slot), Double(well.cell.row), Double(well.cell.column), Double(well.strength),
         well.sense == .clockwise ? 0 : 1]
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: MicroscopicAuroraAction) -> ScriptedAction {
        switch action {
        case let .place(slot, well): ScriptedAction("well.place", placeValues(slot: slot, well))
        case let .remove(slot): ScriptedAction("well.remove", [Double(slot)])
        case .play: ScriptedAction("swim.play", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: MicroscopicAuroraAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: MicroscopicAuroraAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The accepted entry of the play.
    static func playEntry() -> ScenarioStep { actionEntry(.play) }

    /// The accepted entry that shows `tick` (presentation only).
    static func showEntry(_ tick: Int) -> ScenarioStep {
        acceptedEntry("clock.show", [Double(tick)])
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> MicroscopicAuroraGenerated? {
        try? generated(number: number)
    }

    /// The certified plan's placements of manifest number `number` (the play not included); empty when the level
    /// cannot be generated.
    public static func certifiedActions(_ number: Int) -> [MicroscopicAuroraAction] {
        certified(number)?.plan.actions ?? []
    }

    /// The entries that win manifest number `number`: its certified placements, then the play; empty when the level
    /// cannot be generated.
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
    static func openingPlay(_ number: Int) -> MicroscopicAuroraPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The legal moves of `play` in the rules' order (placements by slot 0 … 2, sites row-major, strengths 1 … 4,
    /// clockwise first, skipping occupied cells and the slot's own well; then removals of occupied slots); empty
    /// outside stage `playing` or with the budget spent.
    static func legalMoves(_ play: MicroscopicAuroraPlay) -> [MicroscopicAuroraAction] {
        guard play.stage == .playing else { return [] }
        let position = MicroscopicAuroraPuzzle.Position(wells: play.wells, actionsSpent: play.actionsSpent)
        return MicroscopicAuroraPuzzle(level: play.level).moves(in: position)
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: MicroscopicAuroraPlay, _ action: MicroscopicAuroraAction) -> MicroscopicAuroraPlay? {
        var next: MicroscopicAuroraPlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// `play` after `actions` in order; nil when the kernel refuses one.
    static func after(_ play: MicroscopicAuroraPlay, _ actions: [MicroscopicAuroraAction]) -> MicroscopicAuroraPlay? {
        var current: MicroscopicAuroraPlay = play
        for action in actions {
            guard let next = after(current, action) else { return nil }
            current = next
        }
        return current
    }

    /// The probe placement of manifest number `number`: the first certified placement, else the first legal move at
    /// the opening; nil when there is none.
    public static func probeMove(_ number: Int) -> MicroscopicAuroraAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [MicroscopicAuroraAction] = []
        if let first = certifiedActions(number).first { candidates.append(first) }
        candidates += legalMoves(play)
        for move in candidates where after(play, move)?.stage == .playing {
            return move
        }
        return nil
    }

    /// The second move of manifest number `number`: after the probe placement, the first legal move; nil when there is
    /// none.
    public static func secondMove(_ number: Int) -> MicroscopicAuroraAction? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return legalMoves(moved).first
    }

    /// The two input actions on the opening level: the probe placement, then the second move; empty when there is
    /// none.
    public static var inputActions: [MicroscopicAuroraAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let probe = probeMove(number), let second = secondMove(number) else { return [] }
        return [probe, second]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [MicroscopicAuroraAction] = inputActions
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

    /// The hero tick of manifest number `number`: the last tick of the certified plan's predicted swim (a winning swim
    /// swims the whole length), where every ribbon is complete over the lit stencil; nil when the level cannot be
    /// generated or its plan is refused.
    public static func heroTick(_ number: Int) -> Int? {
        guard let play = openingPlay(number), let planned = after(play, certifiedActions(number)) else { return nil }
        return planned.report.ticks
    }

    /// The entries of hero: the certified plan of the opening level without the play, then the hero tick shown, so the
    /// picture shows the winning aurora while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        let actions: [MicroscopicAuroraAction] = certifiedActions(number)
        guard !actions.isEmpty, let tick = heroTick(number) else { return [] }
        var entries: [ScenarioStep] = []
        for action in actions { entries.append(actionEntry(action)) }
        entries.append(showEntry(tick))
        return entries
    }

    /// The failing play of manifest number `number`: a proper prefix of the certified plan (shortest first), then
    /// nothing or one legal move (in the rules' order), then the play, whose failure has the code `preferred`; the
    /// first failing play found when none has it; nil when there is none. A proper prefix of a minimal plan never
    /// wins, so the bare play after every prefix fails.
    static func failingRun(_ number: Int, preferring preferred: String)
        -> (prefix: [MicroscopicAuroraAction], change: MicroscopicAuroraAction?)? {
        let actions: [MicroscopicAuroraAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [MicroscopicAuroraAction], change: MicroscopicAuroraAction?)?
        for count in 0..<max(actions.count, 1) {
            if count > 0 {
                guard let next = after(play, actions[count - 1]) else { break }
                play = next
            }
            var changes: [MicroscopicAuroraAction?] = [nil]
            for move in legalMoves(play) { changes.append(move) }
            for change in changes {
                var tried: [MicroscopicAuroraAction] = []
                if let change { tried.append(change) }
                tried.append(.play)
                guard let ran = after(play, tried), ran.stage == .failed, let failure = ran.failure else { continue }
                let found: (prefix: [MicroscopicAuroraAction], change: MicroscopicAuroraAction?) =
                    (Array(actions.prefix(count)), change)
                if failure.code == preferred { return found }
                if fallback == nil { fallback = found }
            }
        }
        return fallback
    }

    /// The entries of `fixture-run-fails`: the play with no well placed on level 1 (the play fails).
    public static var runFailsEntries: [ScenarioStep] {
        guard certified(levelNumber(forSeed: manifestSeed)) != nil else { return [] }
        return [playEntry()]
    }

    /// The entries of `fixture-undo-redo`: the probe placement, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The first cell of the dish, row-major, outside the enclosure of `level` (the kernel refuses a well there).
    public static func outsideCell(_ level: MicroscopicAuroraLevel) -> MicroscopicAuroraCell {
        for row in MicroscopicAuroraExperienceCore.cellRange {
            for column in MicroscopicAuroraExperienceCore.cellRange {
                let cell: MicroscopicAuroraCell = MicroscopicAuroraCell(row: row, column: column)
                if !MicroscopicAuroraLevel.isUsable(cell, radius: level.radius) { return cell }
            }
        }
        return MicroscopicAuroraCell(row: 0, column: 0)
    }

    /// The first usable cell of `level`, row-major, that is not one of its sites (the kernel refuses a well there);
    /// nil for a level without sites.
    public static func offSiteCell(_ level: MicroscopicAuroraLevel) -> MicroscopicAuroraCell? {
        guard level.sites != nil else { return nil }
        for row in MicroscopicAuroraExperienceCore.cellRange {
            for column in MicroscopicAuroraExperienceCore.cellRange {
                let cell: MicroscopicAuroraCell = MicroscopicAuroraCell(row: row, column: column)
                if MicroscopicAuroraLevel.isUsable(cell, radius: level.radius) && !level.allows(cell) { return cell }
            }
        }
        return nil
    }

    /// The placement in slot 0 of a strength-1 clockwise well on `level`'s first off-site cell (refused
    /// `r02-g19.action`), else on its first outside cell (refused `r02-g19.action` too).
    static func offSitePlacement(_ level: MicroscopicAuroraLevel) -> MicroscopicAuroraAction {
        let cell: MicroscopicAuroraCell = offSiteCell(level) ?? outsideCell(level)
        return .place(slot: 0, well: MicroscopicAuroraWell(cell: cell, strength: 1, sense: .clockwise))
    }

    /// The first well of `level` in the rules' order: its first site (or first usable cell) with strength 1,
    /// clockwise.
    static func firstWell(_ level: MicroscopicAuroraLevel) -> MicroscopicAuroraWell {
        let cell: MicroscopicAuroraCell = level.sites?.first ?? MicroscopicAuroraCell(row: 12, column: 12)
        return MicroscopicAuroraWell(cell: cell, strength: 1, sense: .clockwise)
    }

    /// The tick just past the ticks `play`'s report swims and the code that refuses it: `r02-g19.tick` within the
    /// declared range, `action.out-of-range` past 480.
    static func beyondTick(_ play: MicroscopicAuroraPlay) -> (tick: Int, code: String) {
        let tick: Int = play.report.ticks + 1
        return (tick, tickRange.contains(tick) ? tickCode : outOfRangeCode)
    }

    /// The extreme placements of `level` in slot 0: the first site with strength 1 clockwise and the last site with
    /// strength 4 counterclockwise; nil when the level has fewer than two sites.
    public static func extremePlacements(_ level: MicroscopicAuroraLevel)
        -> (smallest: MicroscopicAuroraAction, largest: MicroscopicAuroraAction)? {
        guard let sites = level.sites, let first = sites.first, let last = sites.last, first != last else { return nil }
        let low = MicroscopicAuroraWell(cell: first, strength: MicroscopicAuroraWell.strengths.lowerBound,
                                        sense: .clockwise)
        let high = MicroscopicAuroraWell(cell: last, strength: MicroscopicAuroraWell.strengths.upperBound,
                                         sense: .counterclockwise)
        return (.place(slot: 0, well: low), .place(slot: 0, well: high))
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number) else { return [] }
        let level: MicroscopicAuroraLevel = play.level
        let well: MicroscopicAuroraWell = firstWell(level)
        let r: Double = Double(well.cell.row)
        let c: Double = Double(well.cell.column)
        let highSlot: Double = Double(slotRange.upperBound + 1)
        let highCell: Double = Double(cellRange.upperBound + 1)
        let highStrength: Double = Double(MicroscopicAuroraWell.strengths.upperBound + 1)
        let lowStrength: Double = Double(MicroscopicAuroraWell.strengths.lowerBound - 1)
        let highSense: Double = Double(senseRange.upperBound + 1)
        let highTick: Double = Double(tickRange.upperBound + 1)
        let beyond: (tick: Int, code: String) = beyondTick(play)
        let outside: MicroscopicAuroraCell = outsideCell(level)
        var entries: [ScenarioStep] = [
            refusedEntry("well.place", [highSlot, r, c, 1, 0], outOfRangeCode),
            refusedEntry("well.place", [-1, r, c, 1, 0], outOfRangeCode),
            refusedEntry("well.place", [0, highCell, c, 1, 0], outOfRangeCode),
            refusedEntry("well.place", [0, -1, c, 1, 0], outOfRangeCode),
            refusedEntry("well.place", [0, r, highCell, 1, 0], outOfRangeCode),
            refusedEntry("well.place", [0, r, -1, 1, 0], outOfRangeCode),
            refusedEntry("well.place", [0, r, c, highStrength, 0], outOfRangeCode),
            refusedEntry("well.place", [0, r, c, lowStrength, 0], outOfRangeCode),
            refusedEntry("well.place", [0, r, c, 1, highSense], outOfRangeCode),
            refusedEntry("well.place", [0, r, c, 1, -1], outOfRangeCode),
            refusedEntry("well.remove", [highSlot], outOfRangeCode),
            refusedEntry("well.remove", [-1], outOfRangeCode),
            refusedEntry("clock.show", [highTick], outOfRangeCode),
            refusedEntry("clock.show", [-1], outOfRangeCode),
            refusedEntry("well.place", [0.5, r, c, 1, 0], notWholeCode),
            refusedEntry("well.place", [0, r + 0.5, c, 1, 0], notWholeCode),
            refusedEntry("well.place", [0, r, c, 1.5, 0], notWholeCode),
            refusedEntry("well.place", [0, r, c, 1, 0.5], notWholeCode),
            refusedEntry("well.remove", [0.5], notWholeCode),
            refusedEntry("clock.show", [0.5], notWholeCode),
            refusedEntry("well.remove", [0], kernelActionCode),
            refusedEntry("well.place", [0, Double(outside.row), Double(outside.column), 1, 0], kernelActionCode),
            refusedAction(offSitePlacement(level), kernelActionCode),
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("clock.show", [Double(beyond.tick)], beyond.code),
        ]
        entries += [
            refusedEntry("well.place", [], wrongCountCode),
            refusedEntry("well.place", [0, r, c, 1], wrongCountCode),
            refusedEntry("well.place", [0, r, c, 1, 0, 0], wrongCountCode),
            refusedEntry("well.remove", [], wrongCountCode),
            refusedEntry("well.remove", [0, 0], wrongCountCode),
            refusedEntry("swim.play", [1], wrongCountCode),
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

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 64) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (065, 072, … 100, 007, 014, … 098), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 64) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G19-QA-001` … `R2-G19-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G19-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`;
    /// for level 100, whose `level.next` is refused `r02-g19.locked` (no wrap), level 1 with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + MicroscopicAuroraExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 485).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The perturbed last placement of manifest number `number`: after the certified plan without its last placement,
    /// the first legal move there other than it after which the play fails; nil when there is none.
    public static func perturbedLast(_ number: Int) -> MicroscopicAuroraAction? {
        let actions: [MicroscopicAuroraAction] = certifiedActions(number)
        guard let opening = openingPlay(number), let last = actions.last,
              let play = after(opening, Array(actions.dropLast())) else { return nil }
        for move in legalMoves(play) where move != last {
            guard let ran = after(play, [move, .play]), ran.stage == .failed else { continue }
            return move
        }
        return nil
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or its probe is not a placement.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number),
              case let .place(slot, well) = probe else { return [] }
        var entries: [ScenarioStep] = [actionEntry(probe)]
        var values: [Double] = placeValues(slot: slot, well)
        switch (row - 1) % 5 {
        case 0:   // commit organism shape — crowd overdraw on D3: the same well again is unchanged
            entries.append(refusedAction(probe, kernelActionCode))
        case 1:   // place magnetic pole — false pattern due to blur: a well off the level's sites
            entries.append(refusedAction(offSitePlacement(play.level), kernelActionCode))
        case 2:   // tune field — chaotic nondeterminism: a fractional strength
            values[3] = well.strength < MicroscopicAuroraWell.strengths.upperBound
                ? Double(well.strength) + 0.5 : Double(well.strength) - 0.5
            entries.append(refusedEntry("well.place", values, notWholeCode, steps: 1))
        case 3:   // release swimmers — neighbor-order dependence: the probe's cell in the next slot is occupied
            let other: Int = (slot + 1) % MicroscopicAuroraLevel.slots
            entries.append(refusedAction(.place(slot: other, well: well), kernelActionCode))
        default:  // record trail — unstable high forces: a strength beyond 4
            values[3] = Double(MicroscopicAuroraWell.strengths.upperBound + 1)
            entries.append(refusedEntry("well.place", values, outOfRangeCode, steps: 1))
        }
        return entries
    }

    /// The well the exhausted path of manifest number `number` toggles in slot 0: the first one-well setting (sites
    /// row-major, strengths 1 … 4, clockwise first) whose swim does not win; nil when there is none.
    public static func losingWell(_ number: Int) -> MicroscopicAuroraWell? {
        guard let level = certified(number)?.level, let sites = level.sites else { return nil }
        for site in sites {
            for strength in MicroscopicAuroraWell.strengths {
                for sense in MicroscopicAuroraSense.allCases {
                    let well = MicroscopicAuroraWell(cell: site, strength: strength, sense: sense)
                    if !MicroscopicAuroraDish.report(level, wells: [well]).wins { return well }
                }
            }
        }
        return nil
    }

    /// The exhausted path of manifest number `number`: the whole budget spent toggling slot 0 between
    /// ``losingWell(_:)`` and empty, so the final dish (empty, or that one well) never wins; empty when there is no
    /// such well.
    public static func exhaustedPath(_ number: Int) -> [MicroscopicAuroraAction] {
        guard let level = certified(number)?.level, let well = losingWell(number) else { return [] }
        var path: [MicroscopicAuroraAction] = []
        for index in 0..<level.budget { path.append(index % 2 == 0 ? .place(slot: 0, well: well) : .remove(slot: 0)) }
        return path
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or no exhausted path exists.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [MicroscopicAuroraAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        var entries: [ScenarioStep] = []
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            for action in actions.dropLast() { entries.append(actionEntry(action)) }
            entries += [actionEntry(perturbed), playEntry(), acceptedEntry("play.undo"), acceptedEntry("play.undo"),
                        actionEntry(last), playEntry()]
            return entries
        }
        let path: [MicroscopicAuroraAction] = exhaustedPath(number)
        guard path.count >= 2 else { return [] }
        // The move the budget refuses: the placement again after an even path (an empty slot 0), else the removal.
        let further: MicroscopicAuroraAction = path.count % 2 == 0 ? path[0] : .remove(slot: 0)
        for action in path { entries.append(actionEntry(action)) }
        entries += [refusedAction(further, budgetCode), playEntry(), refusedAction(further, stageCode)]
        return entries
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has fewer than two sites.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let extremes = extremePlacements(play.level) else { return [] }
        let level: MicroscopicAuroraLevel = play.level
        let well: MicroscopicAuroraWell = firstWell(level)
        let r: Double = Double(well.cell.row)
        let c: Double = Double(well.cell.column)
        let beyond: (tick: Int, code: String) = beyondTick(play)
        var entries: [ScenarioStep] = [showEntry(play.report.ticks), showEntry(0)]
        if row % 2 == 1 {
            let highStrength: Double = Double(MicroscopicAuroraWell.strengths.upperBound + 1)
            let highSlot: Double = Double(slotRange.upperBound + 1)
            entries.append(refusedEntry("well.place", [0, r, c, highStrength, 0], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("well.place", [highSlot, r, c, 1, 0], outOfRangeCode, steps: 1))
        } else {
            let highCell: Double = Double(cellRange.upperBound + 1)
            let highSense: Double = Double(senseRange.upperBound + 1)
            entries.append(refusedEntry("well.place", [0, highCell, c, 1, 0], outOfRangeCode, steps: 1))
            entries.append(refusedEntry("well.place", [0, r, c, 1, highSense], outOfRangeCode, steps: 1))
        }
        entries += [refusedAction(.remove(slot: 0), kernelActionCode),
                    refusedAction(offSitePlacement(level), kernelActionCode),
                    refusedEntry("well.place", [0, 0.5, c, 1, 0], notWholeCode, steps: 1),
                    refusedEntry("clock.show", [Double(beyond.tick)], beyond.code, steps: 1),
                    actionEntry(extremes.smallest), acceptedEntry("play.undo"),
                    actionEntry(extremes.largest), acceptedEntry("play.undo")]
        return entries
    }

    /// The touch tick of manifest number `number`: the middle tick of the swim after its probe placement; nil when
    /// there is none.
    public static func touchTick(_ number: Int) -> Int? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return moved.report.ticks / 2
    }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe
    /// placement.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let probe = probeMove(number), let tick = touchTick(number) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                showEntry(tick), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The failure code accessibility row `row` prefers: ``preferredFailures`` at (row − 1) mod 4.
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> MicroscopicAuroraExperienceCore? {
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
            let end: MicroscopicAuroraExperienceCore? = played(seed: acceptance.seed, entries: acceptance.entries)
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
