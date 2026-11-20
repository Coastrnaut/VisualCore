// AuroraLoomScenarios — feature 303 (R02-G01-03) T-R02G0103-009 (FR-R02G0103-005, FR-R02G0103-008; clarification Q5).
// The scenarios the verification runner plays for Aurora Loom, a round-two game, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - three fixtures: `fixture-level-1-solved` (the certified solution of level 1, outcome `won`),
//     `fixture-allowance-spent` (the allowance spent on moves that never win, outcome `failed`) and
//     `fixture-undo-redo` (a move, its undo and its redo).
// Every move is derived from the generated level, so a regenerated catalog cannot leave a stale script. Input-response,
// save-restore and reset play two moves and an undo; completion plays the certified solution and expects `won`;
// full-playthrough solves levels 1, 2 and 3 with `level.next` between them; hero plays one move; rejection refuses
// values out of range, fractional values, wrong value counts, an unknown control, a move to the current step and an
// undo or redo with nothing to revert. The expected digests are derived by playing the entries on a core exactly as the
// engine plays them (the steps of an entry, then its action) and digesting it with the experience id as domain.
// The 80 `acceptance-…` scenarios of the planning catalog belong to a later feature of R02-G01; the validator's
// content requirement for them is the caller's.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension AuroraLoomExperienceCore {
    /// The seed of every scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]

    /// One accepted entry of `control` with `values` after `steps` steps.
    static func acceptedEntry(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// The accepted `ribbon.move` entry of a kernel move.
    static func moveEntry(_ move: AuroraLoomMove, steps: Int = 1) -> ScenarioStep {
        acceptedEntry("ribbon.move", [Double(move.ribbon), move.control == .wave ? 0 : 1, Double(move.step)],
                      steps: steps)
    }

    /// One refused entry of `control` with `values`, expecting `result`.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The certified level and solution of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> AuroraLoomGenerated? {
        guard levelNumbers.contains(number) else { return nil }
        return try? AuroraLoomGenerator.generate(AuroraLoomManifest.entries[number - 1])
    }

    /// The level the manifest seed opens; nil when it cannot be generated.
    static var openingLevel: AuroraLoomLevel? { certified(levelNumber(forSeed: manifestSeed))?.level }

    /// The first step of `control` of ribbon `ribbon` other than `current` whose single change leaves `level` unsolved
    /// from `steps`; nil when every other step solves it.
    static func losingStep(_ steps: AuroraLoomSteps, level: AuroraLoomLevel, ribbon: Int,
                           control: AuroraLoomControl) -> Int? {
        let current = control == .wave ? steps.wave[ribbon] : steps.phase[ribbon]
        for offset in 1...15 {
            let candidate = (current + offset) % 16
            var next = steps
            if control == .wave { next.wave[ribbon] = candidate } else { next.phase[ribbon] = candidate }
            if !AuroraLoomHarmony.wins(next, level: level) { return candidate }
        }
        return nil
    }

    /// The actions of input-response, save-restore and reset: ribbon 0's wave and ribbon 1's phase changed to steps
    /// that do not win, then the second move undone.
    public static var inputEntries: [ScenarioStep] {
        guard let level = openingLevel else { return [] }
        var steps = level.startSteps
        guard let wave = losingStep(steps, level: level, ribbon: 0, control: .wave) else { return [] }
        steps.wave[0] = wave
        guard let phase = losingStep(steps, level: level, ribbon: 1, control: .phase) else { return [] }
        return [moveEntry(AuroraLoomMove(ribbon: 0, control: .wave, step: wave), steps: 10),
                moveEntry(AuroraLoomMove(ribbon: 1, control: .phase, step: phase), steps: 10),
                acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified solution of the opening level.
    public static var completionEntries: [ScenarioStep] {
        guard let generated = certified(levelNumber(forSeed: manifestSeed)) else { return [] }
        return generated.solution.moves.map { moveEntry($0) }
    }

    /// The entries of full-playthrough: the certified solutions of ``playthroughLevels`` with `level.next` between.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            guard let generated = certified(number) else { return [] }
            for move in generated.solution.moves { entries.append(moveEntry(move)) }
        }
        return entries
    }

    /// The entries of hero: the first input move, so the picture shows a changed weave.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-allowance-spent`: ribbon 0's wave moved between the start step and a step that does not
    /// win until the allowance is spent; neither setting wins, so the play fails.
    public static var allowanceEntries: [ScenarioStep] {
        guard let level = openingLevel else { return [] }
        let start = level.startSteps
        guard let other = losingStep(start, level: level, ribbon: 0, control: .wave) else { return [] }
        var entries: [ScenarioStep] = []
        for index in 0..<level.allowance {
            let step = index % 2 == 0 ? other : start.wave[0]
            entries.append(moveEntry(AuroraLoomMove(ribbon: 0, control: .wave, step: step)))
        }
        return entries
    }

    /// The entries of `fixture-undo-redo`: the first input move, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + AuroraLoomExperienceRule.notWhole
        let kernelMove = "action.rule." + AuroraLoomError.move("").reasonCode
        let current = Double(openingLevel?.startSteps.wave[0] ?? 0)
        return [
            refusedEntry("ribbon.move", [3, 0, 1], outOfRange),
            refusedEntry("ribbon.move", [0, 2, 1], outOfRange),
            refusedEntry("ribbon.move", [0, 0, 16], outOfRange),
            refusedEntry("ribbon.move", [0, 0, -1], outOfRange),
            refusedEntry("ribbon.move", [0.5, 0, 1], notWhole),
            refusedEntry("ribbon.move", [0, 0, 2.5], notWhole),
            refusedEntry("ribbon.move", [0, 0, current], kernelMove),
            refusedEntry("play.undo", [], kernelMove),
            refusedEntry("play.redo", [], kernelMove),
            refusedEntry("ribbon.move", [0, 0], "action.wrong-value-count"),
            refusedEntry("level.next", [1], "action.wrong-value-count"),
            refusedEntry("loom.spin", [], "action.unknown-control"),
        ]
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> AuroraLoomExperienceCore? {
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
