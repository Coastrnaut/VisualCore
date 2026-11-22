// NocturneGardenScenarios — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-005, 008; clarification Q5). The
// scenarios the verification runner plays for Nocturne Garden, a round-two game, all short (owner rule of 2026-11-13),
// on the pattern of Faceted Forge's (feature 373):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios of the planning catalog (below), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified solution of level 1, outcome `won`),
//     `fixture-budget-out` (sun moves between the level's two lowest elevations for the whole budget, the last one
//     failing the play by budget, outcome `failed`; an empty bed never leaks or wins) and `fixture-undo-redo` (a plant,
//     its undo and its redo).
// Every certified action comes from the generated level's solution (`NocturneGardenGenerated.solution.actions`), so a
// regenerated catalog cannot leave a stale script. A neutral plant plants the first supplied kind at the smallest
// allowed size at the first anchor (rows, then columns, ascending) after which the play stays in `playing`; it is
// derived by playing it on a core, so it never wins or leaks beyond the allowance. Input-response, save-restore and
// reset make a neutral plant and a sun move and undo the sun move; completion plays the certified solution of level 1
// and expects `won`; full-playthrough solves levels 1, 2 and 3 with `level.next` between them; hero makes the neutral
// plant; rejection refuses kinds, columns, rows, sizes, blooms and elevations out of the declared ranges, fractional
// values, an anchor outside the level's bed and a size or elevation the level does not allow (the kernel's
// `r02-g09.action`), a kind the level does not supply (`r02-g09.supply`), the sun at its current elevation
// (`r02-g09.noop`), a move, resize or removal of a bloom that is not planted, an undo or redo with nothing to revert and
// wrong value counts (never an undeclared control: the content audit forbids one in a manifest). The 80 acceptance
// scenarios `acceptance-001` … `acceptance-080` follow the rows R2-G09-QA-001 … 080 of the archived acceptance matrix
// (docs/archive/planning/rounds/round2.md): the rows name no level, so row r opens level (7 × (r − 1)) mod 100 + 1 (80
// distinct levels, 7 being prime to 100) with seed `level − 1`, issues one legal action (the first action of that
// level's certified solution) and then one illegal action — a plant of kind 6, out of range, on odd rows; the sun at
// elevation 5, also out of range, on even rows. The expected digests are derived by playing the entries on a core
// exactly as the engine plays them.
// Feature 385 (R02-G09-05) T-R02G0905-004: the digests are now schema 2's ("…v2": level, play, progress and mode), and
// `level.next` moves to the next open level, which full-playthrough's campaign wins open before each `level.next`;
// rejection also refuses the progression controls' wrong value counts (`level.select`, `mode.daily`, `mode.practice`,
// `mode.campaign`, `tutorial.dismiss`); the manifest was regenerated (`UPDATE_SCENARIO_MANIFEST=1`).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension NocturneGardenExperienceCore {
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
    static func scripted(_ action: NocturneGardenAction) -> ScriptedAction {
        switch action {
        case let .plant(kind, column, row, size):
            ScriptedAction("bloom.plant", [Double(kind.order), Double(column), Double(row), Double(size)])
        case let .move(bloom, column, row):
            ScriptedAction("bloom.move", [Double(bloom), Double(column), Double(row)])
        case let .resize(bloom, size):
            ScriptedAction("bloom.resize", [Double(bloom), Double(size)])
        case let .remove(bloom):
            ScriptedAction("bloom.remove", [Double(bloom)])
        case let .sun(elevation):
            ScriptedAction("sun.set", [Double(elevation)])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: NocturneGardenAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: "accepted")
    }

    /// The certified level and solution of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> NocturneGardenGenerated? {
        try? generated(number: number)
    }

    /// The certified solution's actions of manifest number `number`; empty when the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [NocturneGardenAction] {
        certified(number)?.solution.actions ?? []
    }

    /// Generates the certified levels of `numbers` concurrently into the process cache (generation is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The neutral plant of `play` (see the file header); nil when none keeps the play in `playing`.
    public static func neutralPlant(_ play: NocturneGardenPlay) -> NocturneGardenAction? {
        guard play.stage == .playing else { return nil }
        let level: NocturneGardenLevel = play.level
        guard let kind = NocturneGardenKind.allCases.first(where: { play.available($0) > 0 }),
              let size = level.sizes.min() else { return nil }
        for row in 0..<level.height {
            for column in 0..<level.width {
                let action: NocturneGardenAction = .plant(kind, column, row, size)
                var copy: NocturneGardenPlay = play
                guard (try? copy.apply(action, expecting: copy.fingerprint)) != nil else { continue }
                if copy.stage == .playing { return action }
            }
        }
        return nil
    }

    /// A sun move of `play` to its lowest allowed elevation other than the current one; nil when there is none.
    public static func sunMove(_ play: NocturneGardenPlay) -> NocturneGardenAction? {
        guard let elevation = play.level.elevations.sorted().first(where: { $0 != play.elevation }) else { return nil }
        return .sun(elevation)
    }

    /// The two actions of input-response, save-restore and reset on the opening level: a neutral plant, then a sun move
    /// that keeps the play in `playing`; empty when the level cannot be generated or no such action exists.
    public static var inputActions: [NocturneGardenAction] {
        guard let core = try? opening(number: levelNumber(forSeed: manifestSeed)) else { return [] }
        var play: NocturneGardenPlay = core.play
        guard let plant = neutralPlant(play), (try? play.apply(plant, expecting: play.fingerprint)) != nil,
              let sun = sunMove(play) else { return [] }
        var after: NocturneGardenPlay = play
        guard (try? after.apply(sun, expecting: after.fingerprint)) != nil, after.stage == .playing else {
            return []
        }
        return [plant, sun]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [NocturneGardenAction] = inputActions
        guard !actions.isEmpty else { return [] }
        return actions.map { actionEntry($0, steps: 10) } + [acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified solution of the opening level.
    public static var completionEntries: [ScenarioStep] {
        certifiedActions(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The entries of full-playthrough: the certified solutions of ``playthroughLevels`` with `level.next` between
    /// them.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            let actions: [NocturneGardenAction] = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the neutral plant, so the picture shows a bloom and its shadow.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-budget-out`: sun moves between the opening level's two lowest elevations for its whole
    /// budget, the last one failing the play by budget (an empty bed never leaks or wins).
    public static var budgetOutEntries: [ScenarioStep] {
        guard let core = try? opening(number: levelNumber(forSeed: manifestSeed)) else { return [] }
        var play: NocturneGardenPlay = core.play
        var entries: [ScenarioStep] = []
        for _ in 0..<play.level.budget {
            guard let move = sunMove(play), (try? play.apply(move, expecting: play.fingerprint)) != nil else {
                return []
            }
            entries.append(actionEntry(move))
        }
        return play.failure == .budget ? entries : []
    }

    /// The entries of `fixture-undo-redo`: the neutral plant, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state of level 1 (a 16 × 12 bed, size 2 only, elevations 2 and 3;
    /// see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + NocturneGardenExperienceRule.notWhole
        let kernelAction = "action.rule." + NocturneGardenError.action("").reasonCode
        let supply = "action.rule." + NocturneGardenError.supply.reasonCode
        let noop = "action.rule." + NocturneGardenError.noop.reasonCode
        let wrongCount = "action.wrong-value-count"
        guard let core = try? opening(number: levelNumber(forSeed: manifestSeed)) else { return [] }
        let level: NocturneGardenLevel = core.play.level
        let supplied: Int = NocturneGardenKind.allCases.first(where: { level.supplyCount($0) > 0 })?.order ?? 0
        let unsupplied: Int = NocturneGardenKind.allCases.first(where: { level.supplyCount($0) == 0 })?.order ?? 0
        let size: Double = Double(level.sizes.min() ?? 1)
        let badSize: Double = Double(NocturneGardenBloom.sizes.first(where: { !level.sizes.contains($0) }) ?? 1)
        let badElevation: Double = Double(NocturneGardenBloom.elevations.first(where: {
            !level.elevations.contains($0) }) ?? 1)
        let kind: Double = Double(supplied)
        return [
            refusedEntry("bloom.plant", [6, 0, 0, size], outOfRange),
            refusedEntry("bloom.plant", [kind, 32, 0, size], outOfRange),
            refusedEntry("bloom.plant", [kind, 0, 24, size], outOfRange),
            refusedEntry("bloom.plant", [kind, 0, 0, 4], outOfRange),
            refusedEntry("bloom.move", [12, 0, 0], outOfRange),
            refusedEntry("sun.set", [5], outOfRange),
            refusedEntry("bloom.plant", [0.5, 0, 0, size], notWhole),
            refusedEntry("bloom.plant", [kind, 0, 0.5, size], notWhole),
            refusedEntry("bloom.plant", [kind, Double(level.width), 0, size], kernelAction),
            refusedEntry("bloom.plant", [kind, 0, 0, badSize], kernelAction),
            refusedEntry("bloom.plant", [Double(unsupplied), 0, 0, size], supply),
            refusedEntry("sun.set", [badElevation], kernelAction),
            refusedEntry("sun.set", [Double(level.sun)], noop),
            refusedEntry("bloom.move", [0, 1, 1], kernelAction),
            refusedEntry("bloom.resize", [0, size], kernelAction),
            refusedEntry("bloom.remove", [0], kernelAction),
            refusedEntry("play.undo", [], kernelAction),
            refusedEntry("play.redo", [], kernelAction),
            refusedEntry("bloom.plant", [kind], wrongCount),
            refusedEntry("play.undo", [1], wrongCount),
            refusedEntry("play.redo", [1], wrongCount),
            refusedEntry("level.next", [1], wrongCount),
            refusedEntry("level.select", [], wrongCount),
            refusedEntry("mode.daily", [2026, 1], wrongCount),
            refusedEntry("mode.practice", [1], wrongCount),
            refusedEntry("mode.campaign", [1], wrongCount),
            refusedEntry("tutorial.dismiss", [1], wrongCount),
        ]
    }

    /// The level of each acceptance row R2-G09-QA-001 … 080, in row order: the rows name no level, so row r opens
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
    /// solution (accepted), then one illegal action (a plant of kind 6 on odd rows, the sun at elevation 5 on even rows:
    /// both out of range). Empty when a level cannot be generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        prewarm(acceptanceLevels + playthroughLevels)
        for (index, number) in acceptanceLevels.enumerated() {
            let row = index + 1
            guard let first = certifiedActions(number).first else { return [] }
            let legal = actionEntry(first)
            let illegal: ScenarioStep = row % 2 == 1
                ? ScenarioStep(steps: 1, action: ScriptedAction("bloom.plant", [6, 0, 0, 1]),
                               result: "action.out-of-range")
                : ScenarioStep(steps: 1, action: ScriptedAction("sun.set", [5]), result: "action.out-of-range")
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> NocturneGardenExperienceCore? {
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
