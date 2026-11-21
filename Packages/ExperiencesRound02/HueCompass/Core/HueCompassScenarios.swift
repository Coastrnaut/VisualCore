// HueCompassScenarios — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-005, 008; clarification Q5). The scenarios
// the verification runner plays for Hue Compass, a round-two game, all short (owner rule of 2026-11-13), on the pattern
// of Wave Knot Keeper's (feature 323):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios of the planning catalog (below), each with the seed of its planned level;
//   - three fixtures: `fixture-level-1-solved` (the certified witness actions of level 1, outcome `won`),
//     `fixture-probes-spent` (probes at the start bearing until the allowance is spent, which never win, outcome
//     `failed` with failure `probes`) and `fixture-undo-redo` (a turn, its undo and its redo).
// Every certified action comes from the generated level's solution through `HueCompassWitness.actions(for:level:)`, so a
// regenerated catalog cannot leave a stale script. Input-response, save-restore and reset play two turns (which spend
// nothing and never win) and an undo; completion plays the certified actions of level 1 and expects `won`;
// full-playthrough solves levels 1, 2 and 3 with `level.next` between them; hero plays one turn; rejection refuses
// turns, bearings and bands out of range, fractional values, a turn of 0 (the kernel's `r02-g04.action`), an undo or
// redo with nothing to revert and wrong value counts (never an undeclared control: the content audit forbids one in a
// manifest). The 80 acceptance scenarios `acceptance-001` … `acceptance-080` follow the rows R2-G04-QA-001 … 080 of the
// archived acceptance matrix (docs/archive/planning/rounds/round2.md): each opens its planned level with seed
// `level − 1`, issues one legal action (the first of that level's certified witness actions) and then one illegal
// action — a turn of 49, refused as out of range, on odd rows; a turn of 0, which the kernel refuses, on even rows. The
// expected digests are derived by playing the entries on a core exactly as the engine plays them.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension HueCompassExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The two turns of input-response, save-restore and reset (the second is then undone).
    public static let inputTurns: [Int] = [12, -5]

    /// One accepted entry of `control` with `values` after `steps` steps.
    static func acceptedEntry(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// One refused entry of `control` with `values`, expecting `result`.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: HueCompassAction) -> ScriptedAction {
        switch action {
        case .turn(let steps): ScriptedAction("compass.turn", [Double(steps)])
        case .probe: ScriptedAction("compass.probe", [])
        case .select(let bearing, let band): ScriptedAction("compass.select", [Double(bearing), Double(band)])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: HueCompassAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: "accepted")
    }

    /// The certified level and solution of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> HueCompassGenerated? {
        try? generated(number: number)
    }

    /// The certified witness actions of manifest number `number` (the solution's turns and probes, then the
    /// selection); empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [HueCompassAction] {
        guard let generated = certified(number) else { return [] }
        return HueCompassWitness.actions(for: generated.solution, level: generated.level)
    }

    /// Generates the certified levels of `numbers` concurrently into the process cache (generation is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The actions of input-response, save-restore and reset: the two ``inputTurns``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        [actionEntry(.turn(inputTurns[0]), steps: 10), actionEntry(.turn(inputTurns[1]), steps: 10),
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

    /// The entries of hero: the first input turn, so the picture shows a turned compass.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-probes-spent`: a probe at the start bearing for every unit of the opening level's
    /// allowance; the last probe spends the last unit, so the play fails with `probes`.
    public static var probesEntries: [ScenarioStep] {
        guard let generated = certified(levelNumber(forSeed: manifestSeed)) else { return [] }
        return Array(repeating: actionEntry(.probe), count: generated.level.allowance)
    }

    /// The entries of `fixture-undo-redo`: the first input turn, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + HueCompassExperienceRule.notWhole
        let kernelAction = "action.rule." + HueCompassError.action("").reasonCode
        let wrongCount = "action.wrong-value-count"
        return [
            refusedEntry("compass.turn", [49], outOfRange),
            refusedEntry("compass.turn", [-49], outOfRange),
            refusedEntry("compass.select", [96, 0], outOfRange),
            refusedEntry("compass.select", [0, 24], outOfRange),
            refusedEntry("compass.select", [-1, 0], outOfRange),
            refusedEntry("compass.turn", [1.5], notWhole),
            refusedEntry("compass.select", [0.5, 0], notWhole),
            refusedEntry("compass.select", [0, 2.5], notWhole),
            refusedEntry("compass.turn", [0], kernelAction),
            refusedEntry("play.undo", [], kernelAction),
            refusedEntry("play.redo", [], kernelAction),
            refusedEntry("compass.turn", [], wrongCount),
            refusedEntry("compass.probe", [1], wrongCount),
            refusedEntry("compass.select", [0], wrongCount),
            refusedEntry("level.next", [1], wrongCount),
        ]
    }

    /// The planned level of each acceptance row R2-G04-QA-001 … 080, in row order. Rows 001 … 020 name their level in
    /// the archived matrix ("Load planned level 020", "027", … "083", then "For level 090", … "053"); rows 021 … 080
    /// name none, so they continue the same progression (level = (19 + 7 × (row − 1)) mod 100 + 1), which visits 80
    /// distinct levels.
    public static var acceptanceLevels: [Int] {
        var levels: [Int] = []
        for row in 1...80 { levels.append((19 + 7 * (row - 1)) % 100 + 1) }
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
    /// legal action (a turn of 49 on odd rows, a turn of 0 on even rows). Empty when a level cannot be generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        prewarm(acceptanceLevels + playthroughLevels)
        for (index, number) in acceptanceLevels.enumerated() {
            let row = index + 1
            guard let first = certifiedActions(number).first, var core = try? opening(number: number) else { return [] }
            let legal = actionEntry(first)
            let script = scripted(first)
            _ = core.apply(ExperienceAction(control: script.control, values: script.values, step: 1))
            let values: [Double] = row % 2 == 1 ? [49] : [0]
            let result = core.apply(ExperienceAction(control: "compass.turn", values: values, step: 2)).code
            let illegal = ScenarioStep(steps: 1, action: ScriptedAction("compass.turn", values), result: result)
            list.append((acceptanceName(row), seed(forLevel: number), [legal, illegal]))
        }
        return list
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them (nil: none).
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String?)] {
        [("fixture-level-1-solved", completionEntries, wonCode),
         ("fixture-probes-spent", probesEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> HueCompassExperienceCore? {
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
