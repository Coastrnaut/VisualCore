// EchoCartographerScenarios — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-005, 008; clarification Q5). The
// scenarios the verification runner plays for Echo Cartographer, a round-two game, all short (owner rule of 2026-11-13),
// on the pattern of Backwards Aurora's (feature 393):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios of the planning catalog (below), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified witness of level 1, outcome `won`),
//     `fixture-budget-out` (pulses from the entry until the energy runs out, the last one failing the play, outcome
//     `failed`) and `fixture-undo-redo` (a pulse from the entry, its undo and its redo).
// Every certified action comes from the generated level's witness (`EchoCartographerGenerated.actions`), so a
// regenerated catalog cannot leave a stale script. The two neutral actions are a pulse from the entry (it never wins and,
// with energy above 1, never fails) and a marker on the entry (free, never deciding); input-response, save-restore and
// reset play both and undo the second; completion plays the certified witness of level 1 and expects `won`;
// full-playthrough solves levels 1, 2 and 3 with `level.next` between them; hero sends the pulse, so the picture shows
// the rays and rings; rejection refuses cells out of the declared range (16), fractional values, actions the kernel
// refuses (a pulse from a cell not known open, an undo or redo with nothing to revert: `r02-g11.action`) and wrong value
// counts (never an undeclared control: the content audit forbids one in a manifest). The 80 acceptance scenarios
// `acceptance-001` … `acceptance-080` follow the rows R2-G11-QA-001 … 080 of the archived acceptance matrix
// (docs/archive/planning/rounds/round2.md): the rows name no level, so row r opens level (7 × (r − 1)) mod 100 + 1 (80
// distinct levels, 7 being prime to 100) with seed `level − 1`, issues one legal action (the first action of that
// level's certified witness, a pulse) and then one illegal action — a pulse at column 16 (out of range) on odd rows, one
// at row 16 on even rows. The expected digests are derived by playing the entries on a core exactly as the engine plays
// them.
// Feature 405 (R02-G11-05) T-R02G1105-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`;
// rejection also refuses the progression controls' wrong value counts (`level.select`, `mode.daily`, `mode.practice`,
// `mode.campaign`, `tutorial.dismiss`); the manifest was regenerated (`UPDATE_SCENARIO_MANIFEST=1`).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension EchoCartographerExperienceCore {
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
    static func scripted(_ action: EchoCartographerAction) -> ScriptedAction {
        switch action {
        case let .pulse(x, y): ScriptedAction("cell.pulse", [Double(x), Double(y)])
        case let .claim(x, y): ScriptedAction("cell.claim", [Double(x), Double(y)])
        case let .mark(x, y): ScriptedAction("cell.mark", [Double(x), Double(y)])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: EchoCartographerAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: "accepted")
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> EchoCartographerGenerated? {
        try? generated(number: number)
    }

    /// The certified witness's actions of manifest number `number`; empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [EchoCartographerAction] {
        certified(number)?.actions ?? []
    }

    /// Generates the certified levels of `numbers` concurrently into the process cache (generation is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The two neutral actions on the opening level: a pulse from the entry and a marker on the entry; empty when the
    /// level cannot be generated or its energy is below 2.
    public static var inputActions: [EchoCartographerAction] {
        guard let core = try? opening(number: levelNumber(forSeed: manifestSeed)) else { return [] }
        let entry: EchoCartographerCell = core.play.level.entry
        guard core.play.energy >= 2 else { return [] }
        return [.pulse(entry.x, entry.y), .mark(entry.x, entry.y)]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [EchoCartographerAction] = inputActions
        guard !actions.isEmpty else { return [] }
        return actions.map { actionEntry($0, steps: 10) } + [acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified witness of the opening level.
    public static var completionEntries: [ScenarioStep] {
        certifiedActions(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The entries of full-playthrough: the certified witnesses of ``playthroughLevels`` with `level.next` between
    /// them.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            let actions: [EchoCartographerAction] = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the pulse from the entry, so the picture shows the rays and rings.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-budget-out`: pulses from the entry for the whole energy, the last one failing the play.
    public static var budgetOutEntries: [ScenarioStep] {
        guard let core = try? opening(number: levelNumber(forSeed: manifestSeed)) else { return [] }
        var play: EchoCartographerPlay = core.play
        let entry: EchoCartographerCell = play.level.entry
        let move: EchoCartographerAction = .pulse(entry.x, entry.y)
        var entries: [ScenarioStep] = []
        while play.stage == .playing {
            guard (try? play.apply(move, expecting: play.fingerprint)) != nil else { return [] }
            entries.append(actionEntry(move))
        }
        if case .energy = play.failure { return entries }
        return []
    }

    /// The entries of `fixture-undo-redo`: the pulse from the entry, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + EchoCartographerExperienceRule.notWhole
        let kernelAction = "action.rule." + EchoCartographerError.action("").reasonCode
        let wrongCount = "action.wrong-value-count"
        guard let core = try? opening(number: levelNumber(forSeed: manifestSeed)) else { return [] }
        let play: EchoCartographerPlay = core.play
        var unknown: EchoCartographerCell? = nil
        for index in 0..<play.level.chamber.cellCount where play.knowledge[index] == .unknown {
            unknown = play.level.chamber.cell(index)
            break
        }
        var entries: [ScenarioStep] = [
            refusedEntry("cell.pulse", [16, 0], outOfRange),
            refusedEntry("cell.pulse", [0, 16], outOfRange),
            refusedEntry("cell.pulse", [0.5, 2], notWhole),
            refusedEntry("cell.claim", [1, 1.5], notWhole),
        ]
        if let unknown { entries.append(refusedEntry("cell.pulse", [Double(unknown.x), Double(unknown.y)], kernelAction)) }
        let outside: Double = Double(play.level.chamber.width)
        if outside <= 15 { entries.append(refusedEntry("cell.mark", [outside, 0], kernelAction)) }
        entries += [
            refusedEntry("play.undo", [], kernelAction),
            refusedEntry("play.redo", [], kernelAction),
            refusedEntry("cell.pulse", [1], wrongCount),
            refusedEntry("play.undo", [1], wrongCount),
            refusedEntry("play.redo", [1], wrongCount),
            refusedEntry("level.next", [1], wrongCount),
            refusedEntry("level.select", [], wrongCount),
            refusedEntry("mode.daily", [2026, 1], wrongCount),
            refusedEntry("mode.practice", [1], wrongCount),
            refusedEntry("mode.campaign", [1], wrongCount),
            refusedEntry("tutorial.dismiss", [1], wrongCount),
        ]
        return entries
    }

    /// The level of each acceptance row R2-G11-QA-001 … 080, in row order: the rows name no level, so row r opens
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

    /// The acceptance scenarios, one per row: its name, seed and entries — the first action of the level's certified
    /// witness (accepted), then one illegal action (a pulse at column 16 on odd rows, one at row 16 on even rows: both
    /// out of range). Empty when a level cannot be generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        prewarm(acceptanceLevels + playthroughLevels)
        for (index, number) in acceptanceLevels.enumerated() {
            let row = index + 1
            guard let first = certifiedActions(number).first else { return [] }
            let legal = actionEntry(first)
            let illegal: ScenarioStep = row % 2 == 1
                ? ScenarioStep(steps: 1, action: ScriptedAction("cell.pulse", [16, 0]),
                               result: "action.out-of-range")
                : ScenarioStep(steps: 1, action: ScriptedAction("cell.pulse", [0, 16]),
                               result: "action.out-of-range")
            list.append((acceptanceName(row), seed(forLevel: number), [legal, illegal]))
        }
        return list
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them (nil: none).
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String?)] {
        [("fixture-level-1-solved", completionEntries, wonCode),
         ("fixture-budget-out", budgetOutEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> EchoCartographerExperienceCore? {
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
