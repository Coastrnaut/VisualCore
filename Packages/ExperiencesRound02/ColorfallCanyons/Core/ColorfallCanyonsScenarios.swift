// ColorfallCanyonsScenarios — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-005, 008; clarification Q5). The
// scenarios the verification runner plays for Colorfall Canyons, a round-two game, all short (owner rule of 2026-11-13),
// on the pattern of Hue Compass's (feature 333):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios of the planning catalog (below), each with the seed of its planned level;
//   - three fixtures: `fixture-level-1-solved` (the certified witness actions of level 1, outcome `won`),
//     `fixture-time-out` (the opening level run to its tick limit without edits, which never wins — the generator
//     certifies that — outcome `failed`) and `fixture-undo-redo` (a time step, its undo and its redo).
// Every certified action comes from the generated level's solution through `ColorfallCanyonsWitness.actions(for:level:)`,
// so a regenerated catalog cannot leave a stale script. Input-response, save-restore and reset play two short time steps
// (which never win at once: a level is never won without edits) and an undo; completion plays the certified actions of
// level 1 and expects `won`; full-playthrough solves levels 1, 2 and 3 with `level.next` between them; hero plays one
// time step; rejection refuses cells, springs and step counts out of range, fractional values, a carve of the spring's
// cell and a valve of a spring the level lacks (the kernel's `r02-g05.action`), an undo or redo with nothing to revert
// and wrong value counts (never an undeclared control: the content audit forbids one in a manifest). The 80 acceptance
// scenarios `acceptance-001` … `acceptance-080` follow the rows R2-G05-QA-001 … 080 of the archived acceptance matrix
// (docs/archive/planning/rounds/round2.md): each opens its planned level with seed `level − 1`, issues one legal action
// (the first of that level's certified witness actions) and then one illegal action — a step of 601 ticks, refused as
// out of range, on odd rows; a step of 0 ticks, also out of range, on even rows. The expected digests are derived by
// playing the entries on a core exactly as the engine plays them.
// Feature 345 (R02-G05-05): rejection also refuses a locked `level.select`, a level beyond 100, an impossible
// `mode.daily` date, `level.next` with no next open level (`level.next` now moves to the next open level; each
// full-playthrough win opens the next one) and wrong value counts of `mode.daily`, `mode.practice`, `mode.campaign` and
// `tutorial.dismiss`.
// Feature 347 (R02-G05-07): rejection also refuses replay without a verified result (`replay.start`), replay controls
// outside replay (`replay.step`, `replay.stop`), a replay level and a sound value out of range, a fractional sound value
// and wrong value counts of the replay and sound controls.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension ColorfallCanyonsExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The two time steps of input-response, save-restore and reset (the second is then undone).
    public static let inputSteps: [Int] = [1, 2]

    /// One accepted entry of `control` with `values` after `steps` steps.
    static func acceptedEntry(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// One refused entry of `control` with `values`, expecting `result`.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: ColorfallCanyonsAction) -> ScriptedAction {
        switch action {
        case .carve(let cell): ScriptedAction("canyon.carve", [Double(cell)])
        case .valve(let spring): ScriptedAction("canyon.valve", [Double(spring)])
        case .step(let ticks): ScriptedAction("time.step", [Double(ticks)])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: ColorfallCanyonsAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: "accepted")
    }

    /// The certified level and solution of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> ColorfallCanyonsGenerated? {
        try? generated(number: number)
    }

    /// The certified witness actions of manifest number `number` (the solution's edits, then one step of the tick
    /// limit, which stops at the win); empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [ColorfallCanyonsAction] {
        guard let generated = certified(number) else { return [] }
        return ColorfallCanyonsWitness.actions(for: generated.solution, level: generated.level)
    }

    /// Generates the certified levels of `numbers` concurrently into the process cache (generation is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The actions of input-response, save-restore and reset: the two ``inputSteps``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        [actionEntry(.step(inputSteps[0]), steps: 10), actionEntry(.step(inputSteps[1]), steps: 10),
         acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified witness actions of the opening level.
    public static var completionEntries: [ScenarioStep] {
        certifiedActions(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The entries of full-playthrough: the certified witness actions of ``playthroughLevels`` with `level.next`
    /// between them.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            let actions = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the first input step, so the picture shows fluid leaving the springs.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-time-out`: the opening level run to its tick limit without edits (in steps of at most
    /// 600 ticks), which fails.
    public static var timeOutEntries: [ScenarioStep] {
        guard let generated = certified(levelNumber(forSeed: manifestSeed)) else { return [] }
        var left = generated.level.tickLimit
        var entries: [ScenarioStep] = []
        while left > 0 {
            let ticks = min(left, ColorfallCanyonsPlay.steps.upperBound)
            entries.append(actionEntry(.step(ticks)))
            left -= ticks
        }
        return entries
    }

    /// The entries of `fixture-undo-redo`: the first input step, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + ColorfallCanyonsExperienceRule.notWhole
        let kernelAction = "action.rule." + ColorfallCanyonsError.action("").reasonCode
        let wrongCount = "action.wrong-value-count"
        var entries: [ScenarioStep] = [
            refusedEntry("canyon.carve", [120], outOfRange),
            refusedEntry("canyon.carve", [-1], outOfRange),
            refusedEntry("canyon.valve", [3], outOfRange),
            refusedEntry("time.step", [0], outOfRange),
            refusedEntry("time.step", [601], outOfRange),
            refusedEntry("canyon.carve", [1.5], notWhole),
            refusedEntry("canyon.valve", [0.5], notWhole),
            refusedEntry("time.step", [2.5], notWhole),
        ]
        if let generated = certified(levelNumber(forSeed: manifestSeed)) {
            let level = generated.level
            if let spring = level.springs.first {
                entries.append(refusedEntry("canyon.carve", [Double(spring.cell)], kernelAction))
            }
            if level.springs.count < 3 {
                entries.append(refusedEntry("canyon.valve", [Double(level.springs.count)], kernelAction))
            }
        }
        entries += [
            refusedEntry("play.undo", [], kernelAction),
            refusedEntry("play.redo", [], kernelAction),
            refusedEntry("canyon.carve", [], wrongCount),
            refusedEntry("time.step", [1, 2], wrongCount),
            refusedEntry("play.undo", [1], wrongCount),
            refusedEntry("level.next", [1], wrongCount),
            // Feature 345: a locked level, an impossible date, no next open level and wrong value counts.
            refusedEntry("level.select", [2], "action.rule." + ColorfallCanyonsExperienceRule.locked),
            refusedEntry("level.select", [101], outOfRange),
            refusedEntry("level.select", [1.5], notWhole),
            refusedEntry("mode.daily", [2026, 2, 30], "action.rule." + ColorfallCanyonsExperienceRule.date),
            refusedEntry("mode.daily", [2025, 2, 29], "action.rule." + ColorfallCanyonsExperienceRule.date),
            refusedEntry("mode.daily", [2026, 13, 1], outOfRange),
            refusedEntry("level.next", [], "action.rule." + ColorfallCanyonsExperienceRule.locked),
            refusedEntry("mode.daily", [2026, 11], wrongCount),
            refusedEntry("mode.practice", [1], wrongCount),
            refusedEntry("mode.campaign", [1], wrongCount),
            refusedEntry("tutorial.dismiss", [1], wrongCount),
            // Feature 347: replay without a verified result, outside replay, out of range; the sound choice.
            refusedEntry("replay.start", [1], "action.rule." + ColorfallCanyonsExperienceRule.noReplay),
            refusedEntry("replay.step", [], "action.rule." + ColorfallCanyonsExperienceRule.noReplay),
            refusedEntry("replay.stop", [], "action.rule." + ColorfallCanyonsExperienceRule.noReplay),
            refusedEntry("replay.start", [101], outOfRange),
            refusedEntry("replay.start", [], wrongCount),
            refusedEntry("replay.step", [1], wrongCount),
            refusedEntry("settings.sound", [2], outOfRange),
            refusedEntry("settings.sound", [0.5], notWhole),
            refusedEntry("settings.sound", [], wrongCount),
        ]
        return entries
    }

    /// The planned level of each acceptance row R2-G05-QA-001 … 080, in row order. Rows 001 … 020 name their level in
    /// the archived matrix ("Load planned level 023", "030", … "100", "007", … "056"); rows 021 … 080 name none, so they
    /// continue the same progression (level = (22 + 7 × (row − 1)) mod 100 + 1), which visits 80 distinct levels.
    public static var acceptanceLevels: [Int] {
        var levels: [Int] = []
        for row in 1...80 { levels.append((22 + 7 * (row - 1)) % 100 + 1) }
        return levels
    }

    /// The name of acceptance row `row` (1 … 80): `acceptance-001` … `acceptance-080`.
    public static func acceptanceName(_ row: Int) -> String {
        let digits = String(row)
        return "acceptance-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The acceptance scenarios, one per row: its name, seed and entries — the first of the planned level's certified
    /// witness actions (accepted), then one illegal action whose expected result is the one the core gives after the
    /// legal action (a step of 601 on odd rows, of 0 on even rows: both out of range). Empty when a level cannot be
    /// generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        prewarm(acceptanceLevels + playthroughLevels)
        for (index, number) in acceptanceLevels.enumerated() {
            let row = index + 1
            guard let first = certifiedActions(number).first else { return [] }
            let legal = actionEntry(first)
            let values: [Double] = row % 2 == 1 ? [601] : [0]
            let illegal = ScenarioStep(steps: 1, action: ScriptedAction("time.step", values),
                                       result: "action.out-of-range")
            list.append((acceptanceName(row), seed(forLevel: number), [legal, illegal]))
        }
        return list
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them (nil: none).
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String?)] {
        [("fixture-level-1-solved", completionEntries, wonCode),
         ("fixture-time-out", timeOutEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> ColorfallCanyonsExperienceCore? {
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
