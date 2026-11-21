// WaveKnotKeeperScenarios — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-005, 008; clarification Q5). The
// scenarios the verification runner plays for Wave Knot Keeper, a round-two game, all short (owner rule of 2026-11-13),
// on the pattern of Lissajous Labyrinth's (feature 313):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios of the planning catalog (below), each with the seed of its planned level;
//   - three fixtures: `fixture-level-1-solved` (the certified solution of level 1, outcome `won`),
//     `fixture-allowance-spent` (the allowance spent on a legal move and its reverse, which never win, outcome
//     `failed`) and `fixture-undo-redo` (a move, its undo and its redo).
// Every action is derived from the generated level and the kernel's own legality test (`WaveKnotKeeperPlay.refusal`),
// so a regenerated catalog cannot leave a stale script. Input-response, save-restore and reset play two legal moves
// that do not win and an undo; completion plays the certified solution and expects `won`; full-playthrough solves
// levels 1, 2 and 3 with `level.next` between them; hero plays one move; rejection refuses a point and a direction out
// of range, fractional values, a move the kernel refuses, an undo or redo with nothing to revert and wrong value counts
// (never an undeclared control: the content audit forbids one in a manifest). The 80 acceptance scenarios
// `acceptance-001` … `acceptance-080` follow the rows R2-G03-QA-001 … 080 of the archived acceptance matrix
// (docs/archive/planning/rounds/round2.md): each opens its planned level with seed `level − 1`, issues one legal
// `point.move` (the first move of that level's certified solution) and then one illegal action — direction 6, refused
// as out of range, on odd rows; a move the kernel refuses after the legal one (a strand crossing when there is one),
// on even rows. The expected digests are derived by playing the entries on a core exactly as the engine plays them.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension WaveKnotKeeperExperienceCore {
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

    /// The direction index the `point.move` control uses for `direction` (+x 0, −x 1, +y 2, −y 3, +z 4, −z 5).
    static func directionIndex(_ direction: WaveKnotKeeperDirection) -> Int {
        directionOrder.firstIndex(of: direction) ?? 0
    }

    /// The `point.move` values of a kernel move.
    static func moveValues(_ move: WaveKnotKeeperMove) -> [Double] {
        [Double(move.point), Double(directionIndex(move.direction))]
    }

    /// The accepted `point.move` entry of a kernel move.
    static func moveEntry(_ move: WaveKnotKeeperMove, steps: Int = 1) -> ScenarioStep {
        acceptedEntry("point.move", moveValues(move), steps: steps)
    }

    /// One refused entry of `control` with `values`, expecting `result`.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The certified level and solution of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> WaveKnotKeeperGenerated? {
        try? generated(number: number)
    }

    /// Generates the certified levels of `numbers` concurrently into the process cache (generation is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The fresh play the manifest seed opens; nil when its level cannot be generated.
    static var manifestOpeningPlay: WaveKnotKeeperPlay? {
        guard let level = certified(levelNumber(forSeed: manifestSeed))?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// Every move of the control's range (point 0 … 15, direction 0 … 5), point-major.
    static var everyMove: [WaveKnotKeeperMove] {
        var moves: [WaveKnotKeeperMove] = []
        for point in 0...15 {
            for direction in directionOrder { moves.append(WaveKnotKeeperMove(point: point, direction: direction)) }
        }
        return moves
    }

    /// The moves the kernel accepts on `play` whose rope does not win, in ``everyMove`` order.
    static func losingMoves(_ play: WaveKnotKeeperPlay) -> [WaveKnotKeeperMove] {
        everyMove.filter { move in
            guard WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) == nil else {
                return false
            }
            var moved = play.points
            moved[move.point] = moved[move.point].moved(move.direction)
            return !play.level.wins(moved)
        }
    }

    /// The first move the kernel refuses on `play`'s rope — a strand crossing when there is one — or nil.
    static func refusedMove(_ play: WaveKnotKeeperPlay) -> WaveKnotKeeperMove? {
        var first: WaveKnotKeeperMove?
        for move in everyMove {
            guard let refusal = WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) else {
                continue
            }
            if refusal == .move("crossing") { return move }
            if first == nil { first = move }
        }
        return first
    }

    /// The two input moves: the first legal move of the opening rope that does not win, then the first legal move after
    /// it that does not win, on another point when there is one.
    static var inputMoves: [WaveKnotKeeperMove] {
        guard var play = manifestOpeningPlay, let first = losingMoves(play).first,
              (try? play.apply(first, expecting: play.fingerprint)) != nil, play.stage == .playing else { return [] }
        let next = losingMoves(play)
        guard let second = next.first(where: { $0.point != first.point }) ?? next.first else { return [] }
        return [first, second]
    }

    /// The actions of input-response, save-restore and reset: two legal moves that do not win, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let moves = inputMoves
        guard moves.count == 2 else { return [] }
        return [moveEntry(moves[0], steps: 10), moveEntry(moves[1], steps: 10), acceptedEntry("play.undo", steps: 10)]
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

    /// The entries of hero: the first input move, so the picture shows a changed rope.
    public static var heroEntries: [ScenarioStep] { Array(inputEntries.prefix(1)) }

    /// The entries of `fixture-allowance-spent`: the first legal move of the opening rope whose reverse is legal too and
    /// whose alternation spends the allowance without a win, alternated with its reverse until the allowance is spent,
    /// so the play fails.
    public static var allowanceEntries: [ScenarioStep] {
        guard let opening = manifestOpeningPlay else { return [] }
        for move in losingMoves(opening) {
            let back = WaveKnotKeeperMove(point: move.point, direction: move.direction.opposite)
            var play = opening
            var moves: [WaveKnotKeeperMove] = []
            for index in 0..<opening.level.allowance {
                let next = index % 2 == 0 ? move : back
                guard (try? play.apply(next, expecting: play.fingerprint)) != nil else { break }
                moves.append(next)
            }
            if moves.count == opening.level.allowance && play.stage == .failed { return moves.map { moveEntry($0) } }
        }
        return []
    }

    /// The entries of `fixture-undo-redo`: the first input move, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        Array(inputEntries.prefix(1)) + [acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + WaveKnotKeeperExperienceRule.notWhole
        let kernelMove = "action.rule." + WaveKnotKeeperError.move("").reasonCode
        var entries = [
            refusedEntry("point.move", [16, 0], outOfRange),
            refusedEntry("point.move", [0, 6], outOfRange),
            refusedEntry("point.move", [-1, 0], outOfRange),
            refusedEntry("point.move", [0.5, 0], notWhole),
            refusedEntry("point.move", [0, 2.5], notWhole),
        ]
        if let play = manifestOpeningPlay, let refused = refusedMove(play) {
            entries.append(refusedEntry("point.move", moveValues(refused), kernelMove))
        }
        entries += [
            refusedEntry("play.undo", [], kernelMove),
            refusedEntry("play.redo", [], kernelMove),
            refusedEntry("point.move", [0], "action.wrong-value-count"),
            refusedEntry("level.next", [1], "action.wrong-value-count"),
        ]
        return entries
    }

    /// The planned level of each acceptance row R2-G03-QA-001 … 080, in row order. Rows 001 … 020 name their level in
    /// the archived matrix ("Load planned level 017", "024", … "080", then "For level 087", … "050"); rows 021 … 080
    /// name none, so they continue the same progression (level = (16 + 7 × (row − 1)) mod 100 + 1), which visits 80
    /// distinct levels.
    public static var acceptanceLevels: [Int] {
        var levels: [Int] = []
        for row in 1...80 { levels.append((16 + 7 * (row - 1)) % 100 + 1) }
        return levels
    }

    /// The name of acceptance row `row` (1 … 80): `acceptance-001` … `acceptance-080`.
    public static func acceptanceName(_ row: Int) -> String {
        let digits = String(row)
        return "acceptance-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The acceptance scenarios, one per row: its name, seed and entries — the first move of the planned level's
    /// certified solution (accepted), then one illegal action whose expected result is the one the core gives after the
    /// legal move (direction 6 on odd rows, a move the kernel refuses on even rows). Empty when a level cannot be
    /// generated or has no refused move.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        prewarm(acceptanceLevels + playthroughLevels)
        for (index, number) in acceptanceLevels.enumerated() {
            let row = index + 1
            guard let generated = certified(number), let move = generated.solution.moves.first,
                  var core = try? opening(number: number) else { return [] }
            let legal = moveEntry(move)
            _ = core.apply(ExperienceAction(control: "point.move", values: moveValues(move), step: 1))
            let values: [Double]
            if row % 2 == 1 {
                values = [Double(move.point), 6]
            } else {
                guard let refused = refusedMove(core.play) else { return [] }
                values = moveValues(refused)
            }
            let result = core.apply(ExperienceAction(control: "point.move", values: values, step: 2)).code
            let illegal = ScenarioStep(steps: 1, action: ScriptedAction("point.move", values), result: result)
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
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> WaveKnotKeeperExperienceCore? {
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
