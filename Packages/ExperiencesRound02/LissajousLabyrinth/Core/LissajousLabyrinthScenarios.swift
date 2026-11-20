// LissajousLabyrinthScenarios — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-005, 008; clarification Q5). The
// scenarios the verification runner plays for Lissajous Labyrinth, a round-two game, all short (owner rule of
// 2026-11-13), on the pattern of Aurora Loom's (feature 303):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios of the planning catalog (below), each with the seed of its planned level;
//   - three fixtures: `fixture-level-1-solved` (the certified solution of level 1, outcome `won`),
//     `fixture-allowance-spent` (the allowance spent on dial changes that never win, outcome `failed`) and
//     `fixture-undo-redo` (a change, its undo and its redo).
// Every action is derived from the generated level, so a regenerated catalog cannot leave a stale script. Input-
// response,
// save-restore and reset play two changes and an undo; completion plays the certified solution and expects `won`;
// full-playthrough solves levels 1, 2 and 3 with `level.next` between them; hero plays one change; rejection refuses a
// dial index and a value out of range, fractional values, a frequency outside 1 … 9 and an unchanged value (both
// refused
// by the kernel), an undo or redo with nothing to revert and wrong value counts (never an undeclared control: the
// content
// audit forbids one in a manifest). The 80 acceptance scenarios `acceptance-001` … `acceptance-080` follow the rows
// R2-G02-QA-001 … 080 of the archived acceptance matrix (docs/archive/planning/rounds/round2.md): each opens its
// planned
// level with seed `level − 1`, issues one legal `dial.set` (the first action of that level's certified solution) and
// then one illegal action — value 16, refused as out of range, on odd rows; the value just set, refused by the kernel,
// on
// even rows. The expected digests are derived by playing the entries on a core exactly as the engine plays them.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension LissajousLabyrinthExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]

    /// One accepted entry of `control` with `values` after `steps` steps.
    static func acceptedEntry(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// The dial index the `dial.set` control uses for `dial` (frequencyA 0, frequencyB 1, phaseA 2, phaseC 3).
    static func dialIndex(_ dial: LissajousLabyrinthDial) -> Int {
        LissajousLabyrinthDial.allCases.firstIndex(of: dial) ?? 0
    }

    /// The accepted `dial.set` entry of a kernel action.
    static func actionEntry(_ action: LissajousLabyrinthAction, steps: Int = 1) -> ScenarioStep {
        acceptedEntry("dial.set", [Double(dialIndex(action.dial)), Double(action.value)], steps: steps)
    }

    /// One refused entry of `control` with `values`, expecting `result`.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The certified level and solution of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> LissajousLabyrinthGenerated? {
        try? generated(number: number)
    }

    /// Generates the certified levels of `numbers` concurrently into the process cache (generation is pure and
    /// deterministic, about 0.1 s a level in a debug build), so building the manifest's 80 acceptance scenarios stays
    /// short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The level the manifest seed opens; nil when it cannot be generated.
    static var openingLevel: LissajousLabyrinthLevel? { certified(levelNumber(forSeed: manifestSeed))?.level }

    /// The first phase-A value other than the one in `dials` whose lap does not win `level`; nil when every other value
    /// wins.
    static func losingPhase(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel) -> Int? {
        for offset in 1...15 {
            var next = dials
            next.phaseA = (dials.phaseA + offset) % 16
            if LissajousLabyrinthLap.verdict(next, level: level) != .won { return next.phaseA }
        }
        return nil
    }

    /// The first phase-C value other than the one in `dials` whose lap does not win `level`; nil when every other value
    /// wins.
    static func losingPhaseC(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel) -> Int? {
        for offset in 1...15 {
            var next = dials
            next.phaseC = (dials.phaseC + offset) % 16
            if LissajousLabyrinthLap.verdict(next, level: level) != .won { return next.phaseC }
        }
        return nil
    }

    /// The actions of input-response, save-restore and reset: phase A and phase C changed to values that do not win,
    /// then the second change undone.
    public static var inputEntries: [ScenarioStep] {
        guard let level = openingLevel else { return [] }
        var dials = level.start
        guard let phaseA = losingPhase(dials, level: level) else { return [] }
        dials.phaseA = phaseA
        guard let phaseC = losingPhaseC(dials, level: level) else { return [] }
        return [actionEntry(LissajousLabyrinthAction(dial: .phaseA, value: phaseA), steps: 10),
                actionEntry(LissajousLabyrinthAction(dial: .phaseC, value: phaseC), steps: 10),
                acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified solution of the opening level.
    public static var completionEntries: [ScenarioStep] {
        guard let generated = certified(levelNumber(forSeed: manifestSeed)) else { return [] }
        return generated.solution.actions.map { actionEntry($0) }
    }

    /// The entries of full-playthrough: the certified solutions of ``playthroughLevels`` with `level.next` between.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            guard let generated = certified(number) else { return [] }
            for action in generated.solution.actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the first input change, so the picture shows a changed figure.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-allowance-spent`: phase A moved between the start value and a value that does not win
    /// until the allowance is spent; neither setting wins, so the play fails.
    public static var allowanceEntries: [ScenarioStep] {
        guard let level = openingLevel else { return [] }
        let start = level.start
        guard let other = losingPhase(start, level: level) else { return [] }
        var entries: [ScenarioStep] = []
        for index in 0..<level.allowance {
            let value = index % 2 == 0 ? other : start.phaseA
            entries.append(actionEntry(LissajousLabyrinthAction(dial: .phaseA, value: value)))
        }
        return entries
    }

    /// The entries of `fixture-undo-redo`: the first input change, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + LissajousLabyrinthExperienceRule.notWhole
        let kernelMove = "action.rule." + LissajousLabyrinthError.move("").reasonCode
        let currentPhase = Double(openingLevel?.start.phaseA ?? 0)
        return [
            refusedEntry("dial.set", [4, 1], outOfRange),
            refusedEntry("dial.set", [0, 16], outOfRange),
            refusedEntry("dial.set", [0, -1], outOfRange),
            refusedEntry("dial.set", [0.5, 1], notWhole),
            refusedEntry("dial.set", [2, 2.5], notWhole),
            refusedEntry("dial.set", [0, 10], kernelMove),
            refusedEntry("dial.set", [2, currentPhase], kernelMove),
            refusedEntry("play.undo", [], kernelMove),
            refusedEntry("play.redo", [], kernelMove),
            refusedEntry("dial.set", [0], "action.wrong-value-count"),
            refusedEntry("level.next", [1], "action.wrong-value-count"),
        ]
    }

    /// The planned level of each acceptance row R2-G02-QA-001 … 080, in row order. Rows 001 … 020 name their level in
    /// the archived matrix ("Load planned level 014", "021", … "047"); rows 021 … 080 name none, so they continue the
    /// same progression (level = (13 + 7 × (row − 1)) mod 100 + 1), which visits 80 distinct levels.
    public static var acceptanceLevels: [Int] {
        var levels: [Int] = []
        for row in 1...80 { levels.append((13 + 7 * (row - 1)) % 100 + 1) }
        return levels
    }

    /// The name of acceptance row `row` (1 … 80): `acceptance-001` … `acceptance-080`.
    public static func acceptanceName(_ row: Int) -> String {
        let digits = String(row)
        return "acceptance-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The acceptance scenarios, one per row: its name, seed and entries — the first action of the planned level's
    /// certified solution (accepted), then one illegal action whose expected result is the one the core gives after the
    /// legal action (value 16 on odd rows, the value just set on even rows). Empty when a level cannot be generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        prewarm(acceptanceLevels + playthroughLevels)
        for (index, number) in acceptanceLevels.enumerated() {
            let row = index + 1
            guard let generated = certified(number), let action = generated.solution.actions.first,
                  var core = try? opening(number: number) else { return [] }
            let legal = actionEntry(action)
            _ = core.apply(ExperienceAction(control: "dial.set", values: legal.action?.values ?? [], step: 1))
            let illegalValue: Double = row % 2 == 1 ? 16 : Double(action.value)
            let values: [Double] = [Double(dialIndex(action.dial)), illegalValue]
            let result = core.apply(ExperienceAction(control: "dial.set", values: values, step: 2)).code
            let illegal = ScenarioStep(steps: 1, action: ScriptedAction("dial.set", values), result: result)
            list.append((acceptanceName(row), seed(forLevel: number), [legal, illegal]))
        }
        return list
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them (nil: none).
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String?)] {
        [("fixture-level-1-solved", completionEntries, wonCode),
         ("fixture-allowance-spent", allowanceEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> LissajousLabyrinthExperienceCore? {
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
