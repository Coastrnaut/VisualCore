// ChronoConstellatorRegressionSolverTests — feature 358 (R02-G06-08) T-R02G0608-002 (FR-R02G0608-001, 002;
// SC-R02G0608-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/chrono-constellator/levels (part by part and by fingerprint); the witness's actions are in their canonical
// form (phase changes in star order, then one step of the tick limit) and replay on a fresh play to a win at exactly its
// win tick with exactly its per-tick position digests and play fingerprints; `ChronoConstellatorSolver.solve` returns a
// solution whose phase changes are exactly the witness's phase-change actions, with the witness's lower bound, window,
// windows and blocked count, and whose work is at most the tick limit plus the sum of the window ticks (the ticks T with
// m(T) equal to the lower bound). Then the twelve alterations of clarification Q2, each applied to a copy of level 1 and
// of level 41 (its level, the solver's solution or its witness), must be reported by the same
// `firstFailure(level:witness:solution:)` with a message naming the level and the part ("level 41: budget differs"); an
// altered level the level rules refuse counts as detection named for its part. Seed 2_358 picks the altered tick and
// fingerprint. Explicit types, plain loops, short runs; work is counted, never timed.
@testable import ChronoConstellatorCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/chrono-constellator/levels", isDirectory: true)

@Suite struct ChronoConstellatorRegressionSolverTests {
    /// The seed of this feature's choices (the altered digest tick and fingerprint index).
    static let seed: UInt64 = 2_358

    /// The levels altered: level 1 (band 1, a tutorial level) and level 41 (band 3).
    static let alteredNumbers: [Int] = [1, 41]

    // MARK: Helpers

    /// The stored witness file of manifest number `number`.
    static func witnessData(_ number: Int) throws -> Data {
        let name: String = String(ChronoConstellatorGenerator.levelID(number).suffix(3)) + ".witness.json"
        return try Data(contentsOf: regressionWitnessDirectory.appendingPathComponent(name))
    }

    /// The stored witness of manifest number `number`, decoded field by field without re-verification (this file
    /// verifies it).
    static func witness(_ number: Int) throws -> ChronoConstellatorWitness {
        try JSONDecoder().decode(ChronoConstellatorWitness.self, from: try witnessData(number))
    }

    /// The generated level of manifest number `number`, from its manifest entry.
    static func generated(_ number: Int) throws -> ChronoConstellatorGenerated {
        try ChronoConstellatorGenerator.generate(ChronoConstellatorManifest.entries[number - 1])
    }

    /// The window ticks of `level` for lower bound `lowerBound`: the ticks T in 1 … tick limit with m(T) = lowerBound.
    static func windowTicks(_ level: ChronoConstellatorLevel, lowerBound: Int) -> [Int] {
        var ticks: [Int] = []
        for tick in 1...level.tickLimit where ChronoConstellatorSolver.misaligned(level, at: tick) == lowerBound {
            ticks.append(tick)
        }
        return ticks
    }

    /// The first disagreement of `level` with its own witness level, naming the level and the part, or nil.
    static func levelFailure(_ level: ChronoConstellatorLevel, stored: ChronoConstellatorLevel, name: String) -> String? {
        if level.id != stored.id { return "\(name): id differs" }
        if level.seed != stored.seed { return "\(name): seed differs" }
        if level.difficulty != stored.difficulty { return "\(name): difficulty differs" }
        if level.columns != stored.columns || level.rows != stored.rows {
            return "\(name): grid size differs (\(level.columns) × \(level.rows), witness "
                + "\(stored.columns) × \(stored.rows))"
        }
        if level.stars.count != stored.stars.count { return "\(name): star count differs" }
        for index in 0..<level.stars.count {
            let mine: ChronoConstellatorStar = level.stars[index]
            let theirs: ChronoConstellatorStar = stored.stars[index]
            if mine.loop.count != theirs.loop.count { return "\(name): star \(index) loop length differs" }
            for cell in 0..<mine.loop.count where mine.loop[cell] != theirs.loop[cell] {
                return "\(name): star \(index) loop cell \(cell) differs (\(mine.loop[cell]), witness "
                    + "\(theirs.loop[cell]))"
            }
            if mine.phase != theirs.phase { return "\(name): star \(index) start phase differs" }
            if mine.target != theirs.target { return "\(name): star \(index) target differs" }
        }
        if level.budget != stored.budget { return "\(name): budget differs" }
        if level.tickLimit != stored.tickLimit { return "\(name): tick limit differs" }
        if level.tutorial != stored.tutorial { return "\(name): tutorial differs" }
        if level.fingerprint != stored.fingerprint { return "\(name): level fingerprint differs" }
        return nil
    }

    /// The first disagreement of `actions` with the canonical form on `level` (`.phase(star, offset)` in increasing
    /// star order, each in range and different from the star's default phase, then `.step(level.tickLimit)`), or nil.
    static func actionFailure(_ actions: [ChronoConstellatorAction], level: ChronoConstellatorLevel,
                              name: String) -> String? {
        if actions.isEmpty { return "\(name): witness action list is empty" }
        var previous: Int = -1
        for index in 0..<actions.count {
            let action: ChronoConstellatorAction = actions[index]
            if index == actions.count - 1 {
                if action != .step(level.tickLimit) {
                    return "\(name): witness action \(index + 1) differs from step(\(level.tickLimit))"
                }
            } else if case .phase(let star, let offset) = action,
                      star > previous, ChronoConstellatorPlay.inRange(action, level: level),
                      offset != level.stars[star].phase {
                previous = star
            } else {
                return "\(name): witness action \(index + 1) differs from a canonical phase change"
            }
        }
        return nil
    }

    /// The first disagreement between `level`, its stored `witness` and the solver's `solution` for `level`, naming the
    /// level and the part; nil when the level equals the witness's level, the witness's actions are canonical and replay
    /// on a fresh play to a win at exactly its win tick with exactly its per-tick digests and play fingerprints, and the
    /// solution's phase changes, lower bound, window, windows and blocked equal the witness's with its work within the
    /// tick limit plus the window ticks.
    static func firstFailure(level: ChronoConstellatorLevel, witness: ChronoConstellatorWitness,
                             solution: ChronoConstellatorSolution?) -> String? {
        let name: String = "level \(witness.number)"

        // The level against the witness's level, part by part, then by fingerprint.
        if let failure = levelFailure(level, stored: witness.level, name: name) { return failure }

        // The witness's actions in their canonical form.
        if let failure = actionFailure(witness.actions, level: level, name: name) { return failure }

        // The witness replayed on a fresh play, tick by tick inside the step: the play fingerprints after the start and
        // after each action, the per-tick position digests, then a win at exactly the witness's win tick.
        var play: ChronoConstellatorPlay = ChronoConstellatorPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for index in 0..<witness.actions.count {
                if play.stage != .playing { return "\(name): replay stage \(play.stage.rawValue) before action \(index + 1)" }
                let action: ChronoConstellatorAction = witness.actions[index]
                if case .step(let ticks) = action {
                    for _ in 0..<ticks where play.stage == .playing {
                        try play.apply(.step(1), expecting: play.fingerprint)
                        digests.append(ChronoConstellatorWitness.digest(play.positions))
                    }
                } else {
                    try play.apply(action, expecting: play.fingerprint)
                }
                fingerprints.append(play.fingerprint)
            }
        } catch {
            return "\(name): replay refused (\(error.reasonCode))"
        }
        if play.stage != .won { return "\(name): replay does not win (stage \(play.stage.rawValue))" }
        if play.tick != witness.winTick {
            return "\(name): replay win tick \(play.tick) differs from the witness's \(witness.winTick)"
        }
        if witness.digests.count != digests.count {
            return "\(name): per-tick digest count \(witness.digests.count) differs (replay \(digests.count))"
        }
        for index in 0..<digests.count where digests[index] != witness.digests[index] {
            return "\(name): per-tick digest \(index + 1) differs"
        }
        if witness.fingerprints.count != fingerprints.count {
            return "\(name): play fingerprint count \(witness.fingerprints.count) differs (replay \(fingerprints.count))"
        }
        for index in 0..<fingerprints.count where fingerprints[index] != witness.fingerprints[index] {
            return "\(name): play fingerprint \(index) differs"
        }

        // The solver: exactly the witness's phase changes, lower bound, window, windows and blocked; work within bound.
        guard let solution else { return "\(name): solver finds no solution" }
        let changes: [ChronoConstellatorAction] = ChronoConstellatorWitness.phaseChanges(for: solution, level: level)
        let witnessChanges: [ChronoConstellatorAction] = Array(witness.actions.dropLast())
        if changes.count != witnessChanges.count {
            return "\(name): solution phase change count \(changes.count) differs from the witness's "
                + "\(witnessChanges.count)"
        }
        for index in 0..<changes.count where changes[index] != witnessChanges[index] {
            return "\(name): solution phase change \(index + 1) differs from the witness action"
        }
        if solution.lowerBound != witness.lowerBound {
            return "\(name): solver lower bound \(solution.lowerBound) differs from the witness's \(witness.lowerBound)"
        }
        if changes.count != solution.lowerBound {
            return "\(name): solution phase change count \(changes.count) differs from its lower bound"
        }
        if solution.window != witness.window {
            return "\(name): solver window tick \(solution.window) differs from the witness's \(witness.window)"
        }
        if solution.windows != witness.windows {
            return "\(name): solver window count \(solution.windows) differs from the witness's \(witness.windows)"
        }
        if solution.blocked != witness.blocked {
            return "\(name): solver blocked count \(solution.blocked) differs from the witness's \(witness.blocked)"
        }
        let ticks: [Int] = windowTicks(level, lowerBound: solution.lowerBound)
        if ticks.count != solution.windows {
            return "\(name): window tick count \(ticks.count) differs from the solver's \(solution.windows)"
        }
        var bound: Int = level.tickLimit
        for tick in ticks { bound += tick }
        if solution.work > bound { return "\(name): solver work \(solution.work) exceeds its bound \(bound)" }
        if witness.difficulty.smallest != witness.lowerBound { return "\(name): difficulty smallest differs" }
        if witness.difficulty.winTick != witness.winTick { return "\(name): difficulty win tick differs" }
        return nil
    }

    /// Checks the ten levels of group `group` (levels 10·(group − 1) + 1 … 10·group) through the parameterized test of
    /// that group: one level `number` per argument.
    static func check(group: Int, number: Int) throws {
        #expect(number >= (group - 1) * 10 + 1 && number <= group * 10, "group \(group): level \(number)")
        let generated: ChronoConstellatorGenerated = try generated(number)
        let data: Data = try witnessData(number)
        let witness: ChronoConstellatorWitness = try JSONDecoder().decode(ChronoConstellatorWitness.self, from: data)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(witness.encoded() == data, "level \(number): witness file is not in its stored form")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let solution: ChronoConstellatorSolution? = ChronoConstellatorSolver.solve(generated.level)
        let failure: String? = firstFailure(level: generated.level, witness: witness, solution: solution)
        #expect(failure == nil, Comment(rawValue: failure ?? ""))
        #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
        #expect(generated.difficulty == witness.difficulty, "level \(number): generator difficulty differs")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G0608-001; SC-R02G0608-001; Q1)

    @Test(arguments: Array(1...10)) func group01(number: Int) throws { try Self.check(group: 1, number: number) }
    @Test(arguments: Array(11...20)) func group02(number: Int) throws { try Self.check(group: 2, number: number) }
    @Test(arguments: Array(21...30)) func group03(number: Int) throws { try Self.check(group: 3, number: number) }
    @Test(arguments: Array(31...40)) func group04(number: Int) throws { try Self.check(group: 4, number: number) }
    @Test(arguments: Array(41...50)) func group05(number: Int) throws { try Self.check(group: 5, number: number) }
    @Test(arguments: Array(51...60)) func group06(number: Int) throws { try Self.check(group: 6, number: number) }
    @Test(arguments: Array(61...70)) func group07(number: Int) throws { try Self.check(group: 7, number: number) }
    @Test(arguments: Array(71...80)) func group08(number: Int) throws { try Self.check(group: 8, number: number) }
    @Test(arguments: Array(81...90)) func group09(number: Int) throws { try Self.check(group: 9, number: number) }
    @Test(arguments: Array(91...100)) func group10(number: Int) throws { try Self.check(group: 10, number: number) }

    // MARK: Alterations (FR-R02G0608-002; SC-R02G0608-002; clarification Q2)

    /// `level` rebuilt through the initialiser with the given parts replaced.
    static func rebuilt(_ level: ChronoConstellatorLevel, rows: Int? = nil, stars: [ChronoConstellatorStar]? = nil,
                        budget: Int? = nil, tickLimit: Int? = nil) throws -> ChronoConstellatorLevel {
        try ChronoConstellatorLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, columns: level.columns,
                                    rows: rows ?? level.rows, stars: stars ?? level.stars, budget: budget ?? level.budget,
                                    tickLimit: tickLimit ?? level.tickLimit, tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: ChronoConstellatorWitness, actions: [ChronoConstellatorAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil, lowerBound: Int? = nil,
                        window: Int? = nil) -> ChronoConstellatorWitness {
        ChronoConstellatorWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                                  winTick: witness.winTick, digests: digests ?? witness.digests,
                                  fingerprints: fingerprints ?? witness.fingerprints,
                                  lowerBound: lowerBound ?? witness.lowerBound, window: window ?? witness.window,
                                  windows: witness.windows, blocked: witness.blocked, unedited: witness.unedited,
                                  nearMiss: witness.nearMiss, difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// A star's loop with one cell changed and still a valid loop: the first corner cell c (whose neighbours p and n
    /// meet at a right angle) moved to the opposite cell p + n − c of their 2 × 2 square when that cell is in the grid,
    /// off the loop and c is not the target; otherwise the loop turned one cell on (every cell index changes).
    static func alteredLoop(_ star: ChronoConstellatorStar, columns: Int, rows: Int) -> [Int] {
        let loop: [Int] = star.loop
        let length: Int = loop.count
        for k in 0..<length where loop[k] != star.target {
            let c: Int = loop[k]
            let p: Int = loop[(k + length - 1) % length]
            let n: Int = loop[(k + 1) % length]
            let row: Int = p / columns + n / columns - c / columns
            let column: Int = p % columns + n % columns - c % columns
            guard p / columns != n / columns, p % columns != n % columns else { continue }
            guard (0..<rows).contains(row), (0..<columns).contains(column) else { continue }
            let d: Int = row * columns + column
            if loop.contains(d) { continue }
            var result: [Int] = loop
            result[k] = d
            return result
        }
        return Array(loop.dropFirst()) + [loop[0]]
    }

    /// The outcome of one alteration: the checking function's first failure, or, when the level rules refuse the
    /// altered copy, that refusal named for the part.
    static func outcome(number: Int, part: String, witness: ChronoConstellatorWitness,
                        build: () throws -> ChronoConstellatorLevel) -> String? {
        let copy: ChronoConstellatorLevel
        do {
            copy = try build()
        } catch {
            return "level \(number): \(part) differs (altered level refused: \(error))"
        }
        if copy.fingerprint == witness.level.fingerprint { return nil }
        return firstFailure(level: copy, witness: witness, solution: ChronoConstellatorSolver.solve(copy))
    }

    /// Records an issue unless `found` names the level and `part`.
    static func expectNamed(_ found: String?, number: Int, kind: String, part: String) {
        let message: String = found ?? "(none)"
        #expect(message.hasPrefix("level \(number): ") && message.contains(part),
                "level \(number) alteration \(kind): \"\(message)\" does not name \"\(part)\"")
    }

    /// The unaltered levels, witnesses and solutions are clean, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: ChronoConstellatorLevel = try Self.generated(number).level
        let found: String? = Self.firstFailure(level: level, witness: try Self.witness(number),
                                               solution: ChronoConstellatorSolver.solve(level))
        #expect(found == nil, "level \(number): \(found ?? "")")
    }

    /// Level alterations: a star's loop cell, a star's start phase, a star's target, the budget, the tick limit and the
    /// grid size; each rebuilt through the level initialiser and reported naming its part (or refused by it).
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let level: ChronoConstellatorLevel = try Self.generated(number).level
        let witness: ChronoConstellatorWitness = try Self.witness(number)
        let star: ChronoConstellatorStar = level.stars[0]

        // A star's loop cell: one corner of star 0's loop moved (or the loop turned one cell on).
        let loop: [Int] = Self.alteredLoop(star, columns: level.columns, rows: level.rows)
        #expect(loop != star.loop, "level \(number): loop unchanged")
        var loopStars: [ChronoConstellatorStar] = level.stars
        loopStars[0] = ChronoConstellatorStar(loop: loop, phase: star.phase, target: star.target)
        Self.expectNamed(Self.outcome(number: number, part: "star 0 loop cell", witness: witness) {
            try Self.rebuilt(level, stars: loopStars)
        }, number: number, kind: "loop cell", part: "star 0 loop cell")

        // A star's start phase: star 0 one phase on.
        var phaseStars: [ChronoConstellatorStar] = level.stars
        phaseStars[0] = ChronoConstellatorStar(loop: star.loop, phase: (star.phase + 1) % star.length, target: star.target)
        Self.expectNamed(Self.outcome(number: number, part: "star 0 start phase", witness: witness) {
            try Self.rebuilt(level, stars: phaseStars)
        }, number: number, kind: "start phase", part: "star 0 start phase")

        // A star's target: star 0's target moved to the next loop cell that is no other star's target.
        var used: Set<Int> = []
        for other in level.stars { used.insert(other.target) }
        var target: Int = star.target
        let targetIndex: Int = star.loop.firstIndex(of: star.target) ?? 0
        for step in 1..<star.length where target == star.target {
            let candidate: Int = star.loop[(targetIndex + step) % star.length]
            if !used.contains(candidate) { target = candidate }
        }
        #expect(target != star.target, "level \(number): no free target cell")
        var targetStars: [ChronoConstellatorStar] = level.stars
        targetStars[0] = ChronoConstellatorStar(loop: star.loop, phase: star.phase, target: target)
        Self.expectNamed(Self.outcome(number: number, part: "star 0 target", witness: witness) {
            try Self.rebuilt(level, stars: targetStars)
        }, number: number, kind: "target", part: "star 0 target")

        // The budget and the tick limit, each one step within its range.
        let budget: Int = level.budget == ChronoConstellatorLevel.budgets.upperBound ? level.budget - 1 : level.budget + 1
        Self.expectNamed(Self.outcome(number: number, part: "budget", witness: witness) {
            try Self.rebuilt(level, budget: budget)
        }, number: number, kind: "budget", part: "budget")
        let tickLimit: Int = level.tickLimit == ChronoConstellatorLevel.tickLimits.upperBound ? level.tickLimit - 1
            : level.tickLimit + 1
        Self.expectNamed(Self.outcome(number: number, part: "tick limit", witness: witness) {
            try Self.rebuilt(level, tickLimit: tickLimit)
        }, number: number, kind: "tick limit", part: "tick limit")

        // The grid size: one row more (one less at the largest row count).
        let rows: Int = level.rows == ChronoConstellatorLevel.rowRange.upperBound ? level.rows - 1 : level.rows + 1
        Self.expectNamed(Self.outcome(number: number, part: "grid size", witness: witness) {
            try Self.rebuilt(level, rows: rows)
        }, number: number, kind: "grid size", part: "grid size")
    }

    /// The solution alteration: the solver's phase of star 0 moved one phase on.
    @Test(arguments: alteredNumbers) func solutionAlterationIsNamed(number: Int) throws {
        let level: ChronoConstellatorLevel = try Self.generated(number).level
        let witness: ChronoConstellatorWitness = try Self.witness(number)
        let solution: ChronoConstellatorSolution? = ChronoConstellatorSolver.solve(level)
        #expect(solution != nil, "level \(number): no solution")
        guard let solution else { return }
        var phases: [Int] = solution.phases
        phases[0] = (phases[0] + 1) % level.stars[0].length
        let copy: ChronoConstellatorSolution = ChronoConstellatorSolution(
            lowerBound: solution.lowerBound, phases: phases, window: solution.window, windows: solution.windows,
            blocked: solution.blocked, work: solution.work)
        #expect(copy != solution, "level \(number): solution unchanged")
        Self.expectNamed(Self.firstFailure(level: level, witness: witness, solution: copy), number: number,
                         kind: "solution phase", part: "solution phase")
    }

    /// Witness alterations: an action, a per-tick digest, a play fingerprint, the lower bound and the window.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: ChronoConstellatorLevel = try Self.generated(number).level
        let witness: ChronoConstellatorWitness = try Self.witness(number)
        let solution: ChronoConstellatorSolution? = ChronoConstellatorSolver.solve(level)
        var random: ChronoConstellatorRandom = ChronoConstellatorRandom(seed: Self.seed &+ UInt64(number))
        var altered: [(String, String, ChronoConstellatorWitness)] = []

        // A witness action: the closing step one tick shorter (longer at one tick).
        var actions: [ChronoConstellatorAction] = witness.actions
        let last: Int = actions.count - 1
        if case .step(let ticks) = actions[last] {
            actions[last] = .step(ticks > 1 ? ticks - 1 : ticks + 1)
        } else {
            Issue.record("level \(number): last action is not a step")
        }
        altered.append(("witness action", "witness action \(last + 1)", Self.rebuilt(witness, actions: actions)))

        // A per-tick digest: a seeded tick's digest with its first character changed.
        var digests: [String] = witness.digests
        let tick: Int = random.int(0..<max(digests.count, 1))
        digests[tick] = Self.flipped(digests[tick])
        altered.append(("per-tick digest", "per-tick digest \(tick + 1)", Self.rebuilt(witness, digests: digests)))

        // A play fingerprint: a seeded fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = random.int(0..<max(fingerprints.count, 1))
        fingerprints[index] = Self.flipped(fingerprints[index])
        altered.append(("play fingerprint", "play fingerprint \(index)",
                        Self.rebuilt(witness, fingerprints: fingerprints)))

        // The lower bound and the window, each one more.
        altered.append(("lower bound", "lower bound", Self.rebuilt(witness, lowerBound: witness.lowerBound + 1)))
        altered.append(("window", "window tick", Self.rebuilt(witness, window: witness.window + 1)))

        #expect(altered.count == 5)
        for (kind, part, copy) in altered {
            #expect(copy != witness, "level \(number) alteration \(kind): unchanged")
            Self.expectNamed(Self.firstFailure(level: level, witness: copy, solution: solution), number: number,
                             kind: kind, part: part)
        }
    }
}
