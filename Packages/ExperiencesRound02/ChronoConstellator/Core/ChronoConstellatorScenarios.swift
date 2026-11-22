// ChronoConstellatorScenarios — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-005, 008; clarification Q5). The
// scenarios the verification runner plays for Chrono Constellator, a round-two game, all short (owner rule of
// 2026-11-13), on the pattern of Colorfall Canyons's (feature 343):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios of the planning catalog (below), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified witness actions of level 1, outcome `won`),
//     `fixture-time-out` (the opening level replayed without edits, which never wins — the generator certifies that —
//     outcome `failed`, by collision or by time) and `fixture-undo-redo` (a phase change, its undo and its redo).
// Every certified action comes from the generated level's solution through `ChronoConstellatorWitness.actions(for:level:)`,
// so a regenerated catalog cannot leave a stale script. Input-response, save-restore and reset change star 1's start
// phase by one cell of its loop, then change it back, and undo the second change (edits at tick 0 never decide the play);
// completion plays the certified actions of level 1 and expects `won`; full-playthrough solves levels 1, 2 and 3 with
// `level.next` between them; hero plays the first phase change; rejection refuses stars, phases, holds and step counts
// out of range, fractional values, a phase change of a star the level lacks, a phase change to the phase in use, a
// release of a hold that does not exist (the kernel's `r02-g06.action`), an undo or redo with nothing to revert and wrong
// value counts (never an undeclared control: the content audit forbids one in a manifest). The 80 acceptance scenarios
// `acceptance-001` … `acceptance-080` follow the rows R2-G06-QA-001 … 080 of the archived acceptance matrix
// (docs/archive/planning/rounds/round2.md): the rows name no level, so row r opens level (7 × (r − 1)) mod 100 + 1 (80
// distinct levels, 7 being prime to 100) with seed `level − 1`, issues one legal action (the first of that level's
// certified witness actions) and then one illegal action — a step of 1,201 ticks, refused as out of range, on odd rows; a
// step of 0 ticks, also out of range, on even rows. The expected digests are derived by playing the entries on a core
// exactly as the engine plays them.
// Feature 355 (R02-G06-05) T-R02G0605-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`; the
// manifest was regenerated (`UPDATE_SCENARIO_MANIFEST=1`).
// Feature 357 (R02-G06-07) T-R02G0607-003: the digests are schema 3's ("…v3": the same parts with traced results), the
// controls gain replay and the sound setting; the manifest was regenerated.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension ChronoConstellatorExperienceCore {
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

    /// One refused entry of `control` with `values`, expecting `result`.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: ChronoConstellatorAction) -> ScriptedAction {
        switch action {
        case .phase(let star, let offset): ScriptedAction("star.phase", [Double(star), Double(offset)])
        case .hold(let star, let start, let length):
            ScriptedAction("star.hold", [Double(star), Double(start), Double(length)])
        case .release(let star, let start): ScriptedAction("star.release", [Double(star), Double(start)])
        case .step(let ticks): ScriptedAction("time.step", [Double(ticks)])
        case .rewind: ScriptedAction("time.rewind", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: ChronoConstellatorAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: "accepted")
    }

    /// The certified level and solution of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> ChronoConstellatorGenerated? {
        try? generated(number: number)
    }

    /// The certified witness actions of manifest number `number` (the solution's phase changes, then one step of the
    /// tick limit, which stops at the win); empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [ChronoConstellatorAction] {
        guard let generated = certified(number) else { return [] }
        return ChronoConstellatorWitness.actions(for: generated.solution, level: generated.level)
    }

    /// Generates the certified levels of `numbers` concurrently into the process cache (generation is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The two phase changes of input-response, save-restore and reset on the opening level: star 1 one cell further
    /// round its loop, then back to its default phase.
    public static var inputActions: [ChronoConstellatorAction] {
        guard let level = certified(levelNumber(forSeed: manifestSeed))?.level, let star = level.stars.first else {
            return []
        }
        let moved = (star.phase + 1) % star.loop.count
        return [.phase(0, moved), .phase(0, star.phase)]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        inputActions.map { actionEntry($0, steps: 10) } + [acceptedEntry("play.undo", steps: 10)]
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

    /// The entries of hero: the first input phase change, so the picture shows a star moved off its default start.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-time-out`: the opening level replayed without edits for its tick limit (one step), which
    /// fails by collision or by time.
    public static var timeOutEntries: [ScenarioStep] {
        guard let generated = certified(levelNumber(forSeed: manifestSeed)) else { return [] }
        return [actionEntry(.step(generated.level.tickLimit))]
    }

    /// The entries of `fixture-undo-redo`: the first input phase change, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + ChronoConstellatorExperienceRule.notWhole
        let kernelAction = "action.rule." + ChronoConstellatorError.action("").reasonCode
        let wrongCount = "action.wrong-value-count"
        var entries: [ScenarioStep] = [
            refusedEntry("star.phase", [5, 0], outOfRange),
            refusedEntry("star.phase", [0, 32], outOfRange),
            refusedEntry("star.hold", [0, 0, 1], outOfRange),
            refusedEntry("star.hold", [0, 1, 61], outOfRange),
            refusedEntry("star.release", [0, 1_201], outOfRange),
            refusedEntry("time.step", [0], outOfRange),
            refusedEntry("time.step", [1_201], outOfRange),
            refusedEntry("star.phase", [0, 1.5], notWhole),
            refusedEntry("star.hold", [0, 2.5, 1], notWhole),
            refusedEntry("time.step", [2.5], notWhole),
        ]
        if let level = certified(levelNumber(forSeed: manifestSeed))?.level, let first = level.stars.first {
            if level.stars.count < 5 {
                entries.append(refusedEntry("star.phase", [Double(level.stars.count), 0], kernelAction))
            }
            entries.append(refusedEntry("star.phase", [0, Double(first.phase)], kernelAction))
            entries.append(refusedEntry("star.release", [0, 1], kernelAction))
        }
        entries += [
            refusedEntry("play.undo", [], kernelAction),
            refusedEntry("play.redo", [], kernelAction),
            refusedEntry("star.phase", [0], wrongCount),
            refusedEntry("time.step", [1, 2], wrongCount),
            refusedEntry("time.rewind", [1], wrongCount),
            refusedEntry("play.undo", [1], wrongCount),
            refusedEntry("level.next", [1], wrongCount),
        ]
        return entries
    }

    /// The level of each acceptance row R2-G06-QA-001 … 080, in row order: the rows name no level, so row r opens
    /// level (7 × (r − 1)) mod 100 + 1, which visits 80 distinct levels.
    public static var acceptanceLevels: [Int] {
        var levels: [Int] = []
        for row in 1...80 { levels.append((7 * (row - 1)) % 100 + 1) }
        return levels
    }

    /// The name of acceptance row `row` (1 … 80): `acceptance-001` … `acceptance-080`.
    public static func acceptanceName(_ row: Int) -> String {
        let digits = String(row)
        return "acceptance-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The acceptance scenarios, one per row: its name, seed and entries — the first of the level's certified witness
    /// actions (accepted), then one illegal action whose expected result is the one the core gives after the legal
    /// action (a step of 1,201 on odd rows, of 0 on even rows: both out of range). Empty when a level cannot be
    /// generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        prewarm(acceptanceLevels + playthroughLevels)
        for (index, number) in acceptanceLevels.enumerated() {
            let row = index + 1
            guard let first = certifiedActions(number).first else { return [] }
            let legal = actionEntry(first)
            let values: [Double] = row % 2 == 1 ? [1_201] : [0]
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> ChronoConstellatorExperienceCore? {
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
