// CelestialEclipseLabScenarios — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-005, 008). The scenarios the
// verification runner plays for Celestial Eclipse Lab, a round-two game, all short (owner rule of 2026-11-13), on the
// pattern of Starlit Cartouche's (feature 453):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G17-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1 and the run, outcome `won`),
//     `fixture-run-fails` (the run at the opening phases, outcome `failed`: a valid level never wins without a phase
//     change) and `fixture-undo-redo` (the probe change, its undo and its redo).
// Every certified phase change comes from the generated level's minimal plan (`CelestialEclipseLabGenerated.plan
// .actions`, the plan `CelestialEclipseLabSolver.plan` finds for the prepared level, equal to the stored witness
// `docs/games/celestial-eclipse-lab/levels/NNN.witness.json` without its run), so a regenerated catalog cannot leave a
// stale script; the plan is won by its phase changes followed by `clock.run`. A phase change never ends the play
// (only the run does), so the probe change is the first certified phase change (the first legal one, in the rules'
// move order — movable bodies by index, offsets 0 … period − 1 — should the plan be empty) and the second change is
// the first legal phase change after it. The two input actions are the probe and the second change; input-response,
// save-restore and reset play both and undo the second; completion plays the certified plan of level 1 and the run
// and expects `won`; full-playthrough wins levels 1, 2 and 3 with `level.next` between them; hero plays the certified
// plan of level 1 without the run (a run now would win), chooses (`orbit.choose`) the last body the plan moves and
// shows (`clock.show`) the hero tick — the first tick at which an eclipse under way is total or annular (a corona
// halo), else the first tick with any eclipse, else 0 — so the picture shows glowing crescents and a halo while the
// play is still open; rejection refuses values outside the declared ranges, fractional values, actions the kernel
// refuses (a fixed body, an offset outside the body's period, the body's current offset, a body the level lacks, an
// undo or redo with nothing to revert), a chosen body or shown tick the adapter refuses (a body the level lacks, the
// horizon) and wrong value counts (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 58) mod 100 + 1 for rows 1 … 20 (059, 066, … 094, 001, 008, 015,
// 022, 029, … 092); the same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is
// prime to 100), each opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each
// scripted on the real controls with the outcome the kernel gives; the row's command cycles through the matrix's five
// (commit order, set orbital phase, adjust inclination, schedule eclipse, inspect timeline) and its illegal condition
// through the matrix's five (zero duration event, too-bright corona, false eclipse from perspective, precision at
// tangent contact, transit versus occultation confusion):
//   1 … 10  truth and state transitions — a legal command then an illegal one, by (r − 1) mod 5: the probe change,
//           then the same body set to the offset it now has, refused `r02-g17.action` (commit order; zero duration
//           event); the probe change, then an offset equal to the body's period, refused `r02-g17.action` (out of range
//           for a period of 24; set orbital phase; too-bright corona); the probe body chosen, then a body the level
//           lacks chosen, refused `r02-g17.choice` (out of range with six bodies; adjust inclination; false eclipse
//           from perspective); the probe change, then an offset of 0.5 refused `r02-g17.not-whole` (schedule eclipse;
//           precision at tangent contact); the probe change, then the horizon shown, refused `r02-g17.tick` (inspect
//           timeline; transit versus occultation confusion);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last change perturbed (the first
//           legal change there other than it after which the run fails), the run (failed), an undo (an honest retry),
//           an undo of the perturbed change, the certified last change and the run (won); even rows: an exhausted
//           path — the whole budget spent toggling the first movable body between its starting offset and the first
//           other offset that does not win (so the final setting never wins), a further change refused
//           `r02-g17.budget`, the run (failed) and a change refused `r02-g17.stage`;
//  21 … 30  numeric and geometry edges — the highest and the lowest body chosen, the last and the first tick shown
//           (the endpoints), then an offset of 24 (odd rows) or body 6 (even rows) refused out of range, body −1
//           refused out of range, the probe body set to its current offset refused `r02-g17.action`, an offset of 0.5
//           refused `r02-g17.not-whole`, a body the level lacks refused `r02-g17.action` (when the level has fewer than
//           six bodies), the horizon shown refused `r02-g17.tick`, then the probe change and its undo back to the
//           opening digest;
//  31 … 40  touch and camera semantics — the probe change, undo, redo (the moved digest again), the probe body chosen
//           and the middle tick shown (presentation: the digest does not change), then a second redo refused
//           `r02-g17.action`;
//  41 … 50  rendering — the certified plan and the run (won, every target bracket lit; the digest is the same at every
//           quality tier), then an undo refused `r02-g17.stage` (a won play is final);
//  51 … 60  accessibility and safety — a failing run named in words, then an undo: an honest retry back to the digest
//           before the run. The run follows a proper prefix of the certified plan, alone or after one legal change;
//           the first such run (prefixes shortest first, the bare run before the changes in the rules' order) whose
//           failure is `unwanted` on odd rows, `window` on rows ≡ 2 mod 4 and `horizon` on rows ≡ 0 mod 4, else the
//           first failing run found;
//  61 … 70  persistence and replay — the probe change, undo, redo, undo, then the certified plan and the run (won; the
//           saved trace replays to the same state);
//  71 … 80  integration — the certified plan and the run (won, the next level opened), `level.next` (the next certified
//           level, a fresh play), its probe change, an undo (the next level's fresh play) and a second undo refused
//           `r02-g17.action`; on level 100 (no row reaches it today) `level.next` is refused `r02-g17.locked` after the
//           win (no wrap) and the row chooses level 1 with `level.select [1]` instead.
// Feature 465 (R02-G17-05) T-R02G1705-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`; the
// integration rows (71 … 80) therefore first win their level's certified plan (a campaign win opens the next level)
// before `level.next`; rejection also refuses the progression controls' wrong value counts (`level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest is regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`).
// Feature 467 (R02-G17-07) T-R02G1707-003: digests are schema 3's ("…v3"), wins store their traces, and rejection also
// refuses the replay and sound controls' wrong value counts (`replay.start`, `replay.step`, `replay.stop`,
// `settings.sound`); the manifest was regenerated.
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension CelestialEclipseLabExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` wins in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G17-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional body, offset or tick.
    static let notWholeCode = "action.rule." + CelestialEclipseLabExperienceRule.notWhole
    /// The code of a chosen body the level lacks (`orbit.choose`).
    static let choiceCode = "action.rule." + CelestialEclipseLabExperienceRule.choice
    /// The code of a shown tick outside 0 … horizon − 1 (`clock.show`).
    static let tickCode = "action.rule." + CelestialEclipseLabExperienceRule.tick
    /// The code of the kernel's action refusal (an unknown or fixed body, an offset outside the period or equal to the
    /// current one, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + CelestialEclipseLabError.action("").reasonCode
    /// The code of the kernel's stage refusal (a phase change or run outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + CelestialEclipseLabError.stage.reasonCode
    /// The code of the kernel's budget refusal (a phase change with no action left).
    static let budgetCode = "action.rule." + CelestialEclipseLabError.budget.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last change perturbed and recovered (odd) or an exhausted path (even).
        case witness
        /// Rows 21 … 30: the body and tick endpoints and the refusals just outside them.
        case numeric
        /// Rows 31 … 40: a change, undo, redo, a body chosen, a tick shown and a refused redo.
        case touch
        /// Rows 41 … 50: the plan won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failing run, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a change undone, redone and undone, then the plan won.
        case persistence
        /// Rows 71 … 80: the plan won, the next level, its probe change, an undo and a refused undo.
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
    static func scripted(_ action: CelestialEclipseLabAction) -> ScriptedAction {
        switch action {
        case let .phase(body, offset): ScriptedAction("orbit.phase", [Double(body), Double(offset)])
        case .run: ScriptedAction("clock.run", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: CelestialEclipseLabAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The accepted entry of the run.
    static func runEntry() -> ScenarioStep { actionEntry(.run) }

    /// The refused entry of a phase change of `body` to `offset`, expecting `result`.
    static func refusedPhase(_ body: Double, _ offset: Double, _ result: String) -> ScenarioStep {
        refusedEntry("orbit.phase", [body, offset], result, steps: 1)
    }

    /// The accepted entry that chooses `body` (presentation only).
    static func chooseEntry(_ body: Int) -> ScenarioStep {
        acceptedEntry("orbit.choose", [Double(body)])
    }

    /// The accepted entry that shows `tick` (presentation only).
    static func showEntry(_ tick: Int) -> ScenarioStep {
        acceptedEntry("clock.show", [Double(tick)])
    }

    /// The body of `action` (a phase change); nil for the run.
    public static func phaseBody(of action: CelestialEclipseLabAction) -> Int? {
        switch action {
        case let .phase(body, _): body
        case .run: nil
        }
    }

    /// The offset of `action` (a phase change); nil for the run.
    public static func phaseOffset(of action: CelestialEclipseLabAction) -> Int? {
        switch action {
        case let .phase(_, offset): offset
        case .run: nil
        }
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> CelestialEclipseLabGenerated? {
        try? generated(number: number)
    }

    /// The certified plan's phase changes of manifest number `number` (the run not included); empty when the level
    /// cannot be generated.
    public static func certifiedActions(_ number: Int) -> [CelestialEclipseLabAction] {
        certified(number)?.plan.actions ?? []
    }

    /// The entries that win manifest number `number`: its certified phase changes, then the run; empty when the level
    /// cannot be generated.
    public static func winningEntries(_ number: Int) -> [ScenarioStep] {
        let actions: [CelestialEclipseLabAction] = certifiedActions(number)
        guard certified(number) != nil else { return [] }
        return actions.map { actionEntry($0) } + [runEntry()]
    }

    /// Certifies the levels of `numbers` concurrently into the process cache (certification is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The opening play of manifest number `number` (begun, past its tutorial); nil when it cannot be generated.
    static func openingPlay(_ number: Int) -> CelestialEclipseLabPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The rules' position of `play` (its phases and actions spent).
    static func position(_ play: CelestialEclipseLabPlay) -> CelestialEclipseLabRules.Position {
        CelestialEclipseLabRules.Position(phases: play.phases, actionsSpent: play.actionsSpent)
    }

    /// The legal phase changes of `play` in the rules' order (movable bodies by index, offsets 0 … period − 1 other
    /// than the current one); empty outside stage `playing` or with the budget spent.
    static func legalChanges(_ play: CelestialEclipseLabPlay) -> [CelestialEclipseLabAction] {
        guard play.stage == .playing else { return [] }
        return CelestialEclipseLabRules(level: play.level).moves(in: position(play))
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: CelestialEclipseLabPlay,
                      _ action: CelestialEclipseLabAction) -> CelestialEclipseLabPlay? {
        var next: CelestialEclipseLabPlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// `play` after `actions` in order; nil when the kernel refuses one.
    static func after(_ play: CelestialEclipseLabPlay,
                      _ actions: [CelestialEclipseLabAction]) -> CelestialEclipseLabPlay? {
        var current: CelestialEclipseLabPlay = play
        for action in actions {
            guard let next = after(current, action) else { return nil }
            current = next
        }
        return current
    }

    /// The probe change of manifest number `number`: the first certified phase change, else the first legal phase
    /// change at the opening; nil when there is none.
    public static func probeMove(_ number: Int) -> CelestialEclipseLabAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [CelestialEclipseLabAction] = []
        if let first = certifiedActions(number).first { candidates.append(first) }
        for move in candidates + legalChanges(play) where after(play, move)?.stage == .playing {
            return move
        }
        return nil
    }

    /// The second change of manifest number `number`: after the probe change, the first legal phase change; nil when
    /// there is none.
    public static func secondMove(_ number: Int) -> CelestialEclipseLabAction? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return legalChanges(moved).first
    }

    /// The two input actions on the opening level: the probe change, then the second change; empty when there is
    /// none.
    public static var inputActions: [CelestialEclipseLabAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let probe = probeMove(number), let second = secondMove(number) else { return [] }
        return [probe, second]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [CelestialEclipseLabAction] = inputActions
        guard !actions.isEmpty else { return [] }
        return actions.map { actionEntry($0, steps: 10) } + [acceptedEntry("play.undo", steps: 10)]
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

    /// The hero tick of manifest number `number` after its certified plan: the first tick at which an eclipse under
    /// way is total or annular, else the first tick with any eclipse, else 0; nil when the level cannot be generated.
    public static func heroTick(_ number: Int) -> Int? {
        guard let opening = openingPlay(number),
              let play = after(opening, certifiedActions(number)) else { return nil }
        var firstEclipse: Int?
        for tick in 0..<play.level.horizon {
            let eclipses: [CelestialEclipseLabEclipse] =
                CelestialEclipseLabSceneSnapshot.eclipses(play.level, phases: play.phases, tick: tick)
            if eclipses.contains(where: { $0.visibility != .partial }) { return tick }
            if firstEclipse == nil, !eclipses.isEmpty { firstEclipse = tick }
        }
        return firstEclipse ?? 0
    }

    /// The entries of hero: the certified plan of the opening level without the run, then the last body the plan
    /// moves chosen and the hero tick shown, so the picture shows the winning setting's crescents and a halo while
    /// the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        let actions: [CelestialEclipseLabAction] = certifiedActions(number)
        guard let last = actions.last, let body = phaseBody(of: last), let tick = heroTick(number) else { return [] }
        return actions.map { actionEntry($0) } + [chooseEntry(body), showEntry(tick)]
    }

    /// The failing run of manifest number `number`: a proper prefix of the certified plan (shortest first), then
    /// nothing or one legal change (in the rules' order), then the run, whose failure has the code `preferred`; the
    /// first failing run found when none has it; nil when there is none. A proper prefix of a minimal plan never wins,
    /// so the bare run after every prefix fails.
    static func failingRun(_ number: Int, preferring preferred: String)
        -> (prefix: [CelestialEclipseLabAction], change: CelestialEclipseLabAction?)? {
        let actions: [CelestialEclipseLabAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [CelestialEclipseLabAction], change: CelestialEclipseLabAction?)?
        for count in 0..<max(actions.count, 1) {
            if count > 0 {
                guard let next = after(play, actions[count - 1]) else { break }
                play = next
            }
            let changes: [CelestialEclipseLabAction?] = [nil] + legalChanges(play).map { Optional($0) }
            for change in changes {
                let tried: [CelestialEclipseLabAction] = (change.map { [$0] } ?? []) + [.run]
                guard let ran = after(play, tried), ran.stage == .failed, let failure = ran.failure else { continue }
                let found: (prefix: [CelestialEclipseLabAction], change: CelestialEclipseLabAction?) =
                    (Array(actions.prefix(count)), change)
                if failure.code == preferred { return found }
                if fallback == nil { fallback = found }
            }
        }
        return fallback
    }

    /// The entries of `fixture-run-fails`: the run at the opening phases of level 1 (the play fails).
    public static var runFailsEntries: [ScenarioStep] {
        guard certified(levelNumber(forSeed: manifestSeed)) != nil else { return [] }
        return [runEntry()]
    }

    /// The entries of `fixture-undo-redo`: the probe change, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The first fixed body of `level`; nil when every body is movable.
    static func fixedBody(_ level: CelestialEclipseLabLevel) -> Int? {
        level.bodies.indices.first { level.bodies[$0].fixed }
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), let probe = probeMove(number), let body = phaseBody(of: probe) else {
            return []
        }
        let level: CelestialEclipseLabLevel = play.level
        let bodies: Int = level.bodies.count
        let target: Double = Double(body)
        let current: Double = Double(play.phases[body])
        let period: Int = level.bodies[body].period
        let highBody: Double = Double(bodyRange.upperBound + 1)
        let highOffset: Double = Double(offsetRange.upperBound + 1)
        let highTick: Double = Double(tickRange.upperBound + 1)
        var entries: [ScenarioStep] = [
            refusedEntry("orbit.phase", [highBody, 0], outOfRangeCode),
            refusedEntry("orbit.phase", [-1, 0], outOfRangeCode),
            refusedEntry("orbit.phase", [target, highOffset], outOfRangeCode),
            refusedEntry("orbit.phase", [target, -1], outOfRangeCode),
            refusedEntry("orbit.choose", [highBody], outOfRangeCode),
            refusedEntry("orbit.choose", [-1], outOfRangeCode),
            refusedEntry("clock.show", [highTick], outOfRangeCode),
            refusedEntry("clock.show", [-1], outOfRangeCode),
            refusedEntry("orbit.phase", [0.5, 0], notWholeCode),
            refusedEntry("orbit.phase", [target, 0.5], notWholeCode),
            refusedEntry("orbit.choose", [0.5], notWholeCode),
            refusedEntry("clock.show", [0.5], notWholeCode),
            refusedEntry("orbit.phase", [target, current], kernelActionCode),
            refusedEntry("clock.show", [Double(level.horizon)], tickCode),
        ]
        if period <= offsetRange.upperBound {
            entries.append(refusedEntry("orbit.phase", [target, Double(period)], kernelActionCode))
        }
        if let fixed = fixedBody(level) {
            let other: Int = play.phases[fixed] == 0 ? 1 : 0
            entries.append(refusedEntry("orbit.phase", [Double(fixed), Double(other)], kernelActionCode))
        }
        if bodies <= bodyRange.upperBound {
            entries.append(refusedEntry("orbit.phase", [Double(bodies), 0], kernelActionCode))
            entries.append(refusedEntry("orbit.choose", [Double(bodies)], choiceCode))
        }
        entries += [
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("orbit.phase", [], wrongCountCode),
            refusedEntry("orbit.phase", [target], wrongCountCode),
            refusedEntry("orbit.phase", [target, 0, 0], wrongCountCode),
            refusedEntry("clock.run", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
            refusedEntry("orbit.choose", [], wrongCountCode),
            refusedEntry("orbit.choose", [target, 0], wrongCountCode),
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

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 58) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (059, 066, … 094, 001, 008, … 092), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 58) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G17-QA-001` … `R2-G17-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G17-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`;
    /// for level 100, whose `level.next` is refused `r02-g17.locked` (no wrap), level 1 with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + CelestialEclipseLabExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 465).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The perturbed last change of manifest number `number`: after the certified plan without its last change, the
    /// first legal change there other than it after which the run fails; nil when there is none.
    public static func perturbedLast(_ number: Int) -> CelestialEclipseLabAction? {
        let actions: [CelestialEclipseLabAction] = certifiedActions(number)
        guard let opening = openingPlay(number), let last = actions.last,
              let play = after(opening, Array(actions.dropLast())) else { return nil }
        for move in legalChanges(play) where move != last {
            guard let ran = after(play, [move, .run]), ran.stage == .failed else { continue }
            return move
        }
        return nil
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no probe change.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number), let body = phaseBody(of: probe),
              let moved = after(play, probe) else { return [] }
        let level: CelestialEclipseLabLevel = play.level
        let bodies: Int = level.bodies.count
        switch (row - 1) % 5 {
        case 0:   // commit order — zero duration event: a change to the offset the body already has
            return [actionEntry(probe), refusedPhase(Double(body), Double(moved.phases[body]), kernelActionCode)]
        case 1:   // set orbital phase — too-bright corona: an offset equal to the period (out of range at 24)
            let period: Int = level.bodies[body].period
            let code: String = period <= offsetRange.upperBound ? kernelActionCode : outOfRangeCode
            return [actionEntry(probe), refusedPhase(Double(body), Double(period), code)]
        case 2:   // adjust inclination — false eclipse from perspective: choosing never changes the state; a body the
                  // level lacks is no choice (out of range at six bodies)
            let code: String = bodies <= bodyRange.upperBound ? choiceCode : outOfRangeCode
            return [chooseEntry(body), refusedEntry("orbit.choose", [Double(bodies)], code, steps: 1)]
        case 3:   // schedule eclipse — precision at tangent contact: a fractional offset
            return [actionEntry(probe), refusedPhase(Double(body), 0.5, notWholeCode)]
        default:  // inspect timeline — transit versus occultation confusion: the horizon is no tick
            return [actionEntry(probe), refusedEntry("clock.show", [Double(level.horizon)], tickCode, steps: 1)]
        }
    }

    /// The exhausted path of manifest number `number`: the whole budget spent toggling the first movable body between
    /// its starting offset and the first other offset whose one-change setting does not win, so the final setting
    /// (the start, or that one change) never wins; empty when there is no such offset.
    public static func exhaustedPath(_ number: Int) -> [CelestialEclipseLabAction] {
        guard let level = certified(number)?.level else { return [] }
        let rules: CelestialEclipseLabRules = CelestialEclipseLabRules(level: level)
        guard let body = level.bodies.indices.first(where: { !level.bodies[$0].fixed }) else { return [] }
        let start: Int = level.phases[body]
        var toggle: Int?
        for offset in 0..<level.bodies[body].period where offset != start {
            var phases: [Int] = level.phases
            phases[body] = offset
            if !rules.isSolved(CelestialEclipseLabRules.Position(phases: phases, actionsSpent: 0)) {
                toggle = offset
                break
            }
        }
        guard let other = toggle else { return [] }
        var path: [CelestialEclipseLabAction] = []
        for index in 0..<level.budget { path.append(.phase(body, index % 2 == 0 ? other : start)) }
        return path
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or no exhausted path exists.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [CelestialEclipseLabAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            return actions.dropLast().map { actionEntry($0) }
                + [actionEntry(perturbed), runEntry(), acceptedEntry("play.undo"), acceptedEntry("play.undo"),
                   actionEntry(last), runEntry()]
        }
        let path: [CelestialEclipseLabAction] = exhaustedPath(number)
        guard let lastToggle = path.last, let body = phaseBody(of: lastToggle),
              let offset = phaseOffset(of: lastToggle), let level = certified(number)?.level else { return [] }
        let further: Int = offset == level.phases[body] ? (path.first.flatMap { phaseOffset(of: $0) } ?? 0)
            : level.phases[body]
        return path.map { actionEntry($0) }
            + [refusedPhase(Double(body), Double(further), budgetCode), runEntry(),
               refusedPhase(Double(body), Double(offset), stageCode)]
    }

    /// The highest and the lowest body of `play`'s level.
    static func endpointBodies(_ play: CelestialEclipseLabPlay) -> (highest: Int, lowest: Int) {
        (play.level.bodies.count - 1, 0)
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no probe change.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number), let body = phaseBody(of: probe) else {
            return []
        }
        let level: CelestialEclipseLabLevel = play.level
        let bodies: Int = level.bodies.count
        let ends: (highest: Int, lowest: Int) = endpointBodies(play)
        let target: Double = Double(body)
        var entries: [ScenarioStep] = [chooseEntry(ends.highest), chooseEntry(ends.lowest),
                                       showEntry(level.horizon - 1), showEntry(0)]
        if row % 2 == 1 {
            entries.append(refusedPhase(target, Double(offsetRange.upperBound + 1), outOfRangeCode))
        } else {
            entries.append(refusedPhase(Double(bodyRange.upperBound + 1), 0, outOfRangeCode))
        }
        entries += [refusedPhase(Double(bodyRange.lowerBound - 1), 0, outOfRangeCode),
                    refusedPhase(target, Double(play.phases[body]), kernelActionCode),
                    refusedPhase(target, 0.5, notWholeCode)]
        if bodies <= bodyRange.upperBound {
            entries.append(refusedPhase(Double(bodies), 0, kernelActionCode))
        }
        entries += [refusedEntry("clock.show", [Double(level.horizon)], tickCode, steps: 1),
                    actionEntry(probe), acceptedEntry("play.undo")]
        return entries
    }

    /// The middle tick of `level`: horizon / 2.
    static func middleTick(_ level: CelestialEclipseLabLevel) -> Int { level.horizon / 2 }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe change.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number), let body = phaseBody(of: probe) else {
            return []
        }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"), chooseEntry(body),
                showEntry(middleTick(play.level)), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The failure code accessibility row `row` prefers: `unwanted` on odd rows, `window` on rows ≡ 2 mod 4,
    /// `horizon` on rows ≡ 0 mod 4.
    static func preferredFailure(row: Int) -> String {
        if row % 2 == 1 { return "unwanted" }
        return row % 4 == 2 ? "window" : "horizon"
    }

    /// The entries of accessibility row `row` on level `number` (see the file header); empty when the level has no
    /// failing run.
    static func accessibilityEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let failing = failingRun(number, preferring: preferredFailure(row: row)) else { return [] }
        let change: [ScenarioStep] = failing.change.map { [actionEntry($0)] } ?? []
        return failing.prefix.map { actionEntry($0) } + change + [runEntry(), acceptedEntry("play.undo")]
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> CelestialEclipseLabExperienceCore? {
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
