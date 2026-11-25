// StarlitCartoucheScenarios — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-005, 008). The scenarios the
// verification runner plays for Starlit Cartouche, a round-two game, all short (owner rule of 2026-11-13), on the
// pattern of Voxel Origami's (feature 443):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G16-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified plan of level 1, outcome `won`), `fixture-leg-fails`
//     (the first leg of level 1 that the chart fails, outcome `failed`; level 1 cannot spend its budget without a
//     failure, so the failure fixture is a failing leg rather than a spent budget) and `fixture-undo-redo` (the probe
//     leg, its undo and its redo).
// Every certified leg comes from the generated level's minimal plan (`StarlitCartoucheGenerated.plan.legs`, equal to
// the stored witness `docs/games/starlit-cartouche/levels/NNN.witness.json`), so a regenerated catalog cannot leave a
// stale script. Starlit Cartouche has no inverse move: every leg advances the beat, and only undo reverts one. A
// scenario that must stay open uses the level's probe leg: the first certified leg when it leaves the play playing
// (neither won nor failed), else the first legal leg (the rules' move order: corridors by index, waits 0 … 8) that
// does. The two input actions are the probe leg and the first legal leg after it that still leaves the play playing
// (the second leg); input-response, save-restore and reset play both and undo the second; completion plays the
// certified plan of level 1 and expects `won`; full-playthrough solves levels 1, 2 and 3 with `level.next` between
// them; hero plays the certified plan of level 1 without its last leg and chooses (`route.choose`) that leg's
// destination and wait, so the picture shows the leg that completes the cartouche while the play is still open;
// rejection refuses values outside the declared ranges, fractional values, actions the kernel refuses (the ship's own
// star, a star the level lacks, a star without a corridor, stars out of range at departure, an undo or redo with
// nothing to revert), chosen destinations the adapter refuses (the ship's own star, a star the level lacks) and wrong
// value counts (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 55) mod 100 + 1 for rows 1 … 20 (056, 063, … 098, 005, 012, 019, 026,
// … 089); the same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to
// 100), each opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted
// on the real controls with the outcome the kernel gives; the row's command cycles through the matrix's five (commit
// glyph, place route waypoint, time launch, adjust arc, avoid hazard) and its illegal condition through the matrix's
// five (camera changes scoring, time drift, projective false glyph, offscreen hazard, route segment tunneling):
//   1 … 10  truth and state transitions — a legal command then an illegal one, by (r − 1) mod 5: the probe leg, then a
//           leg to the ship's own star, refused `r02-g16.action` (commit glyph; camera changes scoring); the probe leg,
//           then a star the level lacks, refused `r02-g16.action` (out of range with twelve stars; place route
//           waypoint; time drift); the probe leg's destination and wait chosen, then the ship's own star chosen,
//           refused `r02-g16.choice` (time launch; projective false glyph); the probe leg, then a wait of 0.5 refused
//           `r02-g16.not-whole` (adjust arc; offscreen hazard); the probe leg, then a star without a corridor to the
//           ship's star (the ship's own star when every star has one), refused `r02-g16.action` (avoid hazard; route
//           segment tunneling);
//  11 … 20  solver witness and rejection — odd rows: the certified plan with its last leg perturbed (the first legal
//           leg there other than it that does not win), an undo and the certified last leg (won); even rows: an
//           exhausted path — the budget spent without a failure when the level allows it (the first such path in the
//           rules' move order, failed `budget`), else the certified legs before the first leg the chart fails,
//           preferring `deadline` (failed) — then a leg refused `r02-g16.stage` (none of the five even rows' levels
//           can spend its budget cleanly, as the tests pin, so all five end on a failing leg);
//  21 … 30  numeric and geometry edges — the highest and the lowest star of the level chosen with waits 8 and 0 (the
//           endpoints), then a wait of 9 (odd rows) or star 12 (even rows) refused out of range, star −1 refused out of
//           range, the ship's own star refused `r02-g16.action`, the probe destination with a wait of 0.5 refused
//           `r02-g16.not-whole`, a star the level lacks refused `r02-g16.action` (when the level has fewer than 12
//           stars), then the probe leg and its undo back to the opening digest;
//  31 … 40  touch and camera semantics — the probe leg, undo, redo (the moved digest again), the start star chosen
//           with wait 0 (presentation: the digest does not change), then a second redo refused `r02-g16.action`;
//  41 … 50  rendering — the certified plan (won, the cartouche glows; the digest is the same at every quality tier),
//           then an undo refused `r02-g16.stage` (a won play is final);
//  51 … 60  accessibility and safety — the certified legs before the first leg the chart fails (`window` on odd rows,
//           `hazard` on rows ≡ 2 mod 4, `stroke` on rows ≡ 0 mod 4 when the level has one, else the first failure
//           found), named in words, then an undo: an honest retry back to the digest before the failing leg;
//  61 … 70  persistence and replay — the probe leg, undo, redo, undo, then the certified plan (won; the saved trace
//           replays to the same state);
//  71 … 80  integration — the certified plan (won, the next level opened), `level.next` (the next certified level, a
//           fresh play), its probe leg, an undo (the next level's fresh play) and a second undo refused
//           `r02-g16.action`; on level 100 (no row reaches it today) `level.next` is refused `r02-g16.locked` after the
//           win (no wrap) and the row chooses level 1 with `level.select [1]` instead.
// Feature 455 (R02-G16-05) T-R02G1605-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`; the
// integration rows (71 … 80) therefore first win their level's certified plan (a campaign win opens the next level)
// before `level.next`; rejection also refuses the progression controls' wrong value counts (`level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); the manifest was regenerated
// (`UPDATE_SCENARIO_MANIFEST=1`). Feature 457 (R02-G16-07) T-R02G1607-003: digests are schema 3's ("…v3"), wins store
// their traces, and rejection also refuses the replay and sound controls' wrong value counts (`replay.start`,
// `replay.step`, `replay.stop`, `settings.sound`); the manifest was regenerated.
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension StarlitCartoucheExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G16-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10
    /// The most route states the budget-spending search visits for one level.
    static let budgetSearchBound = 20_000

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional star or wait.
    static let notWholeCode = "action.rule." + StarlitCartoucheExperienceRule.notWhole
    /// The code of a chosen destination the level lacks or the ship's own star (`route.choose`).
    static let choiceCode = "action.rule." + StarlitCartoucheExperienceRule.choice
    /// The code of the kernel's action refusal (the ship's own star, a star the level lacks, no corridor, stars out of
    /// range, nothing to undo or redo).
    static let kernelActionCode = "action.rule." + StarlitCartoucheError.action("").reasonCode
    /// The code of the kernel's stage refusal (a leg outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + StarlitCartoucheError.stage.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the plan with its last leg perturbed and recovered (odd) or an exhausted path (even).
        case witness
        /// Rows 21 … 30: the star and wait endpoints and the refusals just outside them.
        case numeric
        /// Rows 31 … 40: a leg, undo, redo, a destination chosen and a refused redo.
        case touch
        /// Rows 41 … 50: the plan won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failing leg, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a leg undone, redone and undone, then the plan.
        case persistence
        /// Rows 71 … 80: the next level, its probe leg, an undo and a refused undo.
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
    static func scripted(_ action: StarlitCartoucheAction) -> ScriptedAction {
        switch action {
        case let .leg(star, wait): ScriptedAction("route.fly", [Double(star), Double(wait)])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: StarlitCartoucheAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a leg to `star` after `wait`, expecting `result`.
    static func refusedLeg(_ star: Double, _ wait: Double, _ result: String) -> ScenarioStep {
        refusedEntry("route.fly", [star, wait], result, steps: 1)
    }

    /// The accepted entry that chooses `star` and `wait` (presentation only).
    static func chooseEntry(_ star: Int, _ wait: Int) -> ScenarioStep {
        acceptedEntry("route.choose", [Double(star), Double(wait)])
    }

    /// The destination star of `action`.
    public static func destination(of action: StarlitCartoucheAction) -> Int {
        switch action {
        case let .leg(star, _): star
        }
    }

    /// The wait of `action`.
    public static func wait(of action: StarlitCartoucheAction) -> Int {
        switch action {
        case let .leg(_, wait): wait
        }
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> StarlitCartoucheGenerated? {
        try? generated(number: number)
    }

    /// The certified plan's legs of manifest number `number`; empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [StarlitCartoucheAction] {
        certified(number)?.plan.legs ?? []
    }

    /// Certifies the levels of `numbers` concurrently into the process cache (certification is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The opening play of manifest number `number` (begun, past its tutorial); nil when it cannot be generated.
    static func openingPlay(_ number: Int) -> StarlitCartouchePlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The rules' position of `play` (its star, beat, strokes and actions spent, still playing).
    static func position(_ play: StarlitCartouchePlay) -> StarlitCartoucheRules.Position {
        StarlitCartoucheRules.Position(star: play.star, beat: play.beat, drawn: play.drawn,
                                       actionsSpent: play.actionsSpent, outcome: .playing)
    }

    /// The legal legs of `play` in the rules' order (corridors touching the ship's star by index, waits 0 … 8); empty
    /// outside stage `playing`.
    static func legalLegs(_ play: StarlitCartouchePlay) -> [StarlitCartoucheAction] {
        guard play.stage == .playing else { return [] }
        return StarlitCartoucheRules(level: play.level).moves(in: position(play))
    }

    /// `play` after `action`, applied with its current fingerprint; nil when the kernel refuses it.
    static func after(_ play: StarlitCartouchePlay, _ action: StarlitCartoucheAction) -> StarlitCartouchePlay? {
        var next: StarlitCartouchePlay = play
        guard (try? next.apply(action, expecting: next.fingerprint)) != nil else { return nil }
        return next
    }

    /// `play` after `actions` in order; nil when the kernel refuses one.
    static func after(_ play: StarlitCartouchePlay, _ actions: [StarlitCartoucheAction]) -> StarlitCartouchePlay? {
        var current: StarlitCartouchePlay = play
        for action in actions {
            guard let next = after(current, action) else { return nil }
            current = next
        }
        return current
    }

    /// The first leg of `candidates` that leaves `play` playing; nil when there is none.
    static func firstOpenLeg(_ play: StarlitCartouchePlay,
                             among candidates: [StarlitCartoucheAction]) -> StarlitCartoucheAction? {
        for move in candidates {
            guard let moved = after(play, move), moved.stage == .playing else { continue }
            return move
        }
        return nil
    }

    /// The probe leg of manifest number `number`: the first certified leg when it leaves the play playing, else the
    /// first legal leg at the opening that does; nil when there is none.
    public static func probeMove(_ number: Int) -> StarlitCartoucheAction? {
        guard let play = openingPlay(number) else { return nil }
        var candidates: [StarlitCartoucheAction] = []
        if let first = certifiedActions(number).first { candidates.append(first) }
        return firstOpenLeg(play, among: candidates + legalLegs(play))
    }

    /// The second leg of manifest number `number`: after the probe leg, the first legal leg that still leaves the play
    /// playing; nil when there is none.
    public static func secondMove(_ number: Int) -> StarlitCartoucheAction? {
        guard let play = openingPlay(number), let probe = probeMove(number), let moved = after(play, probe) else {
            return nil
        }
        return firstOpenLeg(moved, among: legalLegs(moved))
    }

    /// The two input actions on the opening level: the probe leg, then the second leg; empty when there is none.
    public static var inputActions: [StarlitCartoucheAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let probe = probeMove(number), let second = secondMove(number) else { return [] }
        return [probe, second]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [StarlitCartoucheAction] = inputActions
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
            let actions: [StarlitCartoucheAction] = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the certified plan of the opening level without its last leg, then that leg's destination
    /// and wait chosen, so the picture shows the leg that completes the cartouche while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        let actions: [StarlitCartoucheAction] = certifiedActions(levelNumber(forSeed: manifestSeed))
        guard let last = actions.last else { return [] }
        return actions.dropLast().map { actionEntry($0) } + [chooseEntry(destination(of: last), wait(of: last))]
    }

    /// The certified legs before the first leg the chart fails, and that leg, on manifest number `number`: the plays
    /// after each proper prefix of the certified plan are searched in order (each in the rules' move order) for a leg
    /// whose check fails (`window`, `hazard`, `deadline` or `stroke`; a spent budget does not count); the first with
    /// the code `preferred` wins, else the first found; nil when the level has none.
    static func failingLeg(_ number: Int, preferring preferred: String)
        -> (prefix: [StarlitCartoucheAction], leg: StarlitCartoucheAction)? {
        let actions: [StarlitCartoucheAction] = certifiedActions(number)
        guard var play = openingPlay(number) else { return nil }
        var fallback: (prefix: [StarlitCartoucheAction], leg: StarlitCartoucheAction)?
        for count in 0..<actions.count {
            if count > 0 {
                guard let next = after(play, actions[count - 1]), next.stage == .playing else { break }
                play = next
            }
            for move in legalLegs(play) {
                guard let moved = after(play, move), moved.stage == .failed, let failure = moved.failure else {
                    continue
                }
                if case .budget = failure { continue }
                let found: (prefix: [StarlitCartoucheAction], leg: StarlitCartoucheAction) =
                    (Array(actions.prefix(count)), move)
                if failure.code == preferred { return found }
                if fallback == nil { fallback = found }
            }
        }
        return fallback
    }

    /// The legs from `state` that spend the rest of the budget with clear legs that never win, the last one failing
    /// the level `budget`: a depth-first search in the rules' move order that remembers dead states; nil when there is
    /// none or more than ``budgetSearchBound`` states were visited.
    static func spending(_ rules: StarlitCartoucheRules, from state: StarlitCartoucheRules.Position,
                         dead: inout Set<StarlitCartoucheRules.Position>,
                         work: inout Int) -> [StarlitCartoucheAction]? {
        work += 1
        guard work <= budgetSearchBound, !dead.contains(state) else { return nil }
        for move in rules.moves(in: state) {
            guard let next = rules.apply(move, to: state) else { continue }
            let moved: Bool = next.star != state.star || next.beat != state.beat
            if next.outcome == .failed, moved, next.actionsSpent == rules.level.budget { return [move] }
            guard next.outcome == .playing else { continue }
            if let rest = spending(rules, from: next, dead: &dead, work: &work) { return [move] + rest }
        }
        dead.insert(state)
        return nil
    }

    /// The legs of manifest number `number` that spend its whole budget from the opening without a chart failure or a
    /// win (failed `budget`), the first such path in the rules' move order; empty when there is none within the bound.
    static func budgetPath(_ number: Int) -> [StarlitCartoucheAction] {
        guard let level = certified(number)?.level else { return [] }
        let rules: StarlitCartoucheRules = StarlitCartoucheRules(level: level)
        var dead: Set<StarlitCartoucheRules.Position> = []
        var work: Int = 0
        return spending(rules, from: rules.initialState, dead: &dead, work: &work) ?? []
    }

    /// The entries of `fixture-leg-fails`: the certified legs before the first leg of level 1 the chart fails, then
    /// that leg (the play fails).
    public static var legFailsEntries: [ScenarioStep] {
        guard let failing = failingLeg(levelNumber(forSeed: manifestSeed), preferring: "window") else { return [] }
        return failing.prefix.map { actionEntry($0) } + [actionEntry(failing.leg)]
    }

    /// The entries of `fixture-undo-redo`: the probe leg, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let probe = probeMove(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The first star of `play`'s level other than the ship's that no corridor joins to the ship's star; nil when every
    /// star has one.
    static func unjoinedStar(_ play: StarlitCartouchePlay) -> Int? {
        for star in play.level.stars.indices where star != play.star {
            if StarlitCartoucheChart.corridor(play.level, joining: play.star, star) == nil { return star }
        }
        return nil
    }

    /// The first leg from `play`'s star (corridors by index, waits 0 … 8) that the chart refuses because the stars are
    /// out of range at departure; nil when there is none.
    static func outOfReachLeg(_ play: StarlitCartouchePlay) -> StarlitCartoucheAction? {
        let level: StarlitCartoucheLevel = play.level
        for corridor in level.corridors where corridor.a == play.star || corridor.b == play.star {
            let other: Int = corridor.a == play.star ? corridor.b : corridor.a
            for wait in StarlitCartoucheChart.waits {
                let leg: StarlitCartoucheLeg? = try? StarlitCartoucheChart.leg(level, from: play.star, at: play.beat,
                                                                               to: other, wait: wait)
                if leg == nil { return .leg(other, wait) }
            }
        }
        return nil
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), let probe = probeMove(number) else { return [] }
        let stars: Int = play.level.stars.count
        let ship: Double = Double(play.star)
        let target: Double = Double(destination(of: probe))
        let highStar: Double = Double(starRange.upperBound + 1)
        let highWait: Double = Double(waitRange.upperBound + 1)
        var entries: [ScenarioStep] = [
            refusedEntry("route.fly", [highStar, 0], outOfRangeCode),
            refusedEntry("route.fly", [-1, 0], outOfRangeCode),
            refusedEntry("route.fly", [target, highWait], outOfRangeCode),
            refusedEntry("route.fly", [target, -1], outOfRangeCode),
            refusedEntry("route.choose", [highStar, 0], outOfRangeCode),
            refusedEntry("route.choose", [-1, 0], outOfRangeCode),
            refusedEntry("route.choose", [target, highWait], outOfRangeCode),
            refusedEntry("route.fly", [0.5, 0], notWholeCode),
            refusedEntry("route.fly", [target, 0.5], notWholeCode),
            refusedEntry("route.choose", [0.5, 0], notWholeCode),
            refusedEntry("route.fly", [ship, 0], kernelActionCode),
            refusedEntry("route.choose", [ship, 0], choiceCode),
        ]
        if stars <= starRange.upperBound {
            entries.append(refusedEntry("route.fly", [Double(stars), 0], kernelActionCode))
            entries.append(refusedEntry("route.choose", [Double(stars), 0], choiceCode))
        }
        if let unjoined = unjoinedStar(play) {
            entries.append(refusedEntry("route.fly", [Double(unjoined), 0], kernelActionCode))
        }
        if let unreachable = outOfReachLeg(play) {
            entries.append(ScenarioStep(steps: 0, action: scripted(unreachable), result: kernelActionCode))
        }
        entries += [
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("route.fly", [], wrongCountCode),
            refusedEntry("route.fly", [target], wrongCountCode),
            refusedEntry("route.fly", [target, 0, 0], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
            refusedEntry("route.choose", [], wrongCountCode),
            refusedEntry("route.choose", [target], wrongCountCode),
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

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 55) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (056, 063, … 098, 005, 012, 019, 026, … 089), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 55) % 100 + 1 }

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

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G16-QA-001` … `R2-G16-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G16-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level an integration row on level `number` reaches after its campaign win: `number + 1` with `level.next`;
    /// for level 100, whose `level.next` is refused `r02-g16.locked` (no wrap), level 1 with `level.select [1]`.
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The code of the adapter's locked refusal (no next open level, a level not yet open; never a payment gate).
    static let lockedCode = "action.rule." + StarlitCartoucheExperienceRule.locked

    /// The entries that move an integration row on level `number` from its won play to ``nextLevel(after:)``:
    /// `level.next`; for level 100 a `level.next` refused ``lockedCode`` and then `level.select [1]` (feature 455).
    static func integrationMoveEntries(_ number: Int) -> [ScenarioStep] {
        guard number == levelNumbers.upperBound else { return [acceptedEntry("level.next")] }
        return [refusedEntry("level.next", [], lockedCode, steps: 1), acceptedEntry("level.select", [1])]
    }

    /// The perturbed last leg of manifest number `number`: after the certified plan without its last leg, the first
    /// legal leg there other than it that does not win; nil when there is none.
    public static func perturbedLast(_ number: Int) -> StarlitCartoucheAction? {
        let actions: [StarlitCartoucheAction] = certifiedActions(number)
        guard let opening = openingPlay(number), let last = actions.last,
              let play = after(opening, Array(actions.dropLast())) else { return nil }
        for move in legalLegs(play) where move != last {
            guard let moved = after(play, move), moved.stage != .won else { continue }
            return move
        }
        return nil
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no probe leg.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number),
              let moved = after(play, probe) else { return [] }
        let stars: Int = play.level.stars.count
        let ship: Int = moved.star
        switch (row - 1) % 5 {
        case 0:   // commit glyph — camera changes scoring: the ship's own star is no destination
            return [actionEntry(probe), refusedLeg(Double(ship), 0, kernelActionCode)]
        case 1:   // place route waypoint — time drift: a star the level lacks (out of range at twelve stars)
            let code: String = stars <= starRange.upperBound ? kernelActionCode : outOfRangeCode
            return [actionEntry(probe), refusedLeg(Double(stars), 0, code)]
        case 2:   // time launch — projective false glyph: choosing never changes the state; the ship's star is no
                  // choice
            return [chooseEntry(destination(of: probe), wait(of: probe)),
                    refusedEntry("route.choose", [Double(play.star), 0], choiceCode, steps: 1)]
        case 3:   // adjust arc — offscreen hazard: a fractional wait
            return [actionEntry(probe), refusedLeg(Double(ship), 0.5, notWholeCode)]
        default:  // avoid hazard — route segment tunneling: no corridor, no leg
            let unjoined: Int = unjoinedStar(moved) ?? ship
            return [actionEntry(probe), refusedLeg(Double(unjoined), 0, kernelActionCode)]
        }
    }

    /// The exhausted path of manifest number `number`: its budget path when it has one, else the certified legs before
    /// the first failing leg (preferring `deadline`) and that leg; empty when there is neither.
    static func exhaustedPath(_ number: Int) -> [StarlitCartoucheAction] {
        let spending: [StarlitCartoucheAction] = budgetPath(number)
        if !spending.isEmpty { return spending }
        guard let failing = failingLeg(number, preferring: "deadline") else { return [] }
        return failing.prefix + [failing.leg]
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no perturbation exists or no exhausted path exists.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        let actions: [StarlitCartoucheAction] = certifiedActions(number)
        guard let last = actions.last else { return [] }
        if row % 2 == 1 {
            guard let perturbed = perturbedLast(number) else { return [] }
            return actions.dropLast().map { actionEntry($0) }
                + [actionEntry(perturbed), acceptedEntry("play.undo"), actionEntry(last)]
        }
        let path: [StarlitCartoucheAction] = exhaustedPath(number)
        guard !path.isEmpty else { return [] }
        return path.map { actionEntry($0) } + [ScenarioStep(steps: 1, action: scripted(actions[0]), result: stageCode)]
    }

    /// The highest and the lowest star of `play`'s level other than the ship's.
    static func endpointStars(_ play: StarlitCartouchePlay) -> (highest: Int, lowest: Int) {
        let top: Int = play.level.stars.count - 1
        return (top == play.star ? top - 1 : top, play.star == 0 ? 1 : 0)
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or has no probe leg.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number) else { return [] }
        let stars: Int = play.level.stars.count
        let ends: (highest: Int, lowest: Int) = endpointStars(play)
        let target: Double = Double(destination(of: probe))
        var entries: [ScenarioStep] = [chooseEntry(ends.highest, waitRange.upperBound),
                                       chooseEntry(ends.lowest, waitRange.lowerBound)]
        if row % 2 == 1 {
            entries.append(refusedLeg(target, Double(waitRange.upperBound + 1), outOfRangeCode))
        } else {
            entries.append(refusedLeg(Double(starRange.upperBound + 1), 0, outOfRangeCode))
        }
        entries += [refusedLeg(Double(starRange.lowerBound - 1), 0, outOfRangeCode),
                    refusedLeg(Double(play.star), 0, kernelActionCode),
                    refusedLeg(target, 0.5, notWholeCode)]
        if stars <= starRange.upperBound {
            entries.append(refusedLeg(Double(stars), 0, kernelActionCode))
        }
        entries += [actionEntry(probe), acceptedEntry("play.undo")]
        return entries
    }

    /// The entries of a touch row on level `number` (see the file header); empty when the level has no probe leg.
    static func touchEntries(number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let probe = probeMove(number) else { return [] }
        return [actionEntry(probe), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                chooseEntry(play.star, 0), refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
    }

    /// The failure code accessibility row `row` prefers: `window` on odd rows, `hazard` on rows ≡ 2 mod 4, `stroke` on
    /// rows ≡ 0 mod 4.
    static func preferredFailure(row: Int) -> String {
        if row % 2 == 1 { return "window" }
        return row % 4 == 2 ? "hazard" : "stroke"
    }

    /// The entries of accessibility row `row` on level `number` (see the file header); empty when the level has no
    /// failing leg.
    static func accessibilityEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let failing = failingLeg(number, preferring: preferredFailure(row: row)) else { return [] }
        return failing.prefix.map { actionEntry($0) } + [actionEntry(failing.leg), acceptedEntry("play.undo")]
    }

    /// The entries of acceptance row `row` (1 … 80) on its level (see the file header); empty when the level cannot be
    /// generated.
    public static func acceptanceEntries(row: Int) -> [ScenarioStep] {
        let number: Int = acceptanceLevel(row)
        let actions: [StarlitCartoucheAction] = certifiedActions(number)
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
         ("fixture-leg-fails", legFailsEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> StarlitCartoucheExperienceCore? {
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
