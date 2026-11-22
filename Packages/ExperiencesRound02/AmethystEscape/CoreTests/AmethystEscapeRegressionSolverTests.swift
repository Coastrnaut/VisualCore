// AmethystEscapeRegressionSolverTests — feature 368 (R02-G07-08) T-R02G0708-002 (FR-R02G0708-001, 002; SC-R02G0708-001,
// 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized tests of 10
// levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/amethyst-escape/levels (part by part and by fingerprint); the witness's actions replay on a fresh play to
// a win in exactly its smallest move count, within the budget, with exactly its per-move digests and play fingerprints;
// `AmethystEscapeSolver.solve` returns exactly the witness's actions, smallest move count and depths, and its work is
// at most `stateCount(level)`. Then the twelve alterations of clarification Q2, each applied to a copy of level 1 and
// of level 41 (its level, the solver's solution or its witness), must be reported by the same
// `firstFailure(level:witness:solution:)` with a message naming the level and the part ("level 41: budget differs"); an
// altered level the level rules refuse counts as detection named for its part. The altered indices are fixed (the
// middle digest and fingerprint), so nothing is random. Explicit types, plain loops, short runs; work is counted, never
// timed.
@testable import AmethystEscapeCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/amethyst-escape/levels", isDirectory: true)

@Suite struct AmethystEscapeRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level) and level 41 (band 3).
    static let alteredNumbers: [Int] = [1, 41]

    // MARK: Helpers

    /// The stored witness file of manifest number `number`.
    static func witnessData(_ number: Int) throws -> Data {
        let name: String = String(AmethystEscapeGenerator.levelID(number).suffix(3)) + ".witness.json"
        return try Data(contentsOf: regressionWitnessDirectory.appendingPathComponent(name))
    }

    /// The stored witness of manifest number `number`, decoded and re-verified by `AmethystEscapeWitness.decode`.
    static func witness(_ number: Int) throws -> AmethystEscapeWitness {
        try AmethystEscapeWitness.decode(try witnessData(number))
    }

    /// The generated level of manifest number `number` (generated once per process by the experience core).
    static func generated(_ number: Int) throws -> AmethystEscapeGenerated {
        try AmethystEscapeExperienceCore.generated(number: number)
    }

    /// The first disagreement of `list` with `stored` for the part `part` of shell `shell`, or nil.
    static func listFailure(_ list: [Int], stored: [Int], shell: Int, part: String, name: String) -> String? {
        if list != stored { return "\(name): shell \(shell) \(part) differs (\(list), witness \(stored))" }
        return nil
    }

    /// The first disagreement of `level` with its own witness level, naming the level and the part, or nil.
    static func levelFailure(_ level: AmethystEscapeLevel, stored: AmethystEscapeLevel, name: String) -> String? {
        if level.id != stored.id { return "\(name): id differs" }
        if level.seed != stored.seed { return "\(name): seed differs" }
        if level.difficulty != stored.difficulty { return "\(name): difficulty differs" }
        if level.sectors != stored.sectors {
            return "\(name): sector count differs (\(level.sectors), witness \(stored.sectors))"
        }
        if level.shells.count != stored.shells.count { return "\(name): shell count differs" }
        for index in 0..<level.shells.count {
            let mine: AmethystEscapeShell = level.shells[index]
            let theirs: AmethystEscapeShell = stored.shells[index]
            if let failure = listFailure(mine.apertures, stored: theirs.apertures, shell: index, part: "aperture",
                                         name: name) { return failure }
            if let failure = listFailure(mine.walls, stored: theirs.walls, shell: index, part: "wall",
                                         name: name) { return failure }
            if let failure = listFailure(mine.blocked, stored: theirs.blocked, shell: index, part: "blocked wedge",
                                         name: name) { return failure }
        }
        if level.start != stored.start {
            return "\(name): start sector differs (\(level.start), witness \(stored.start))"
        }
        if level.budget != stored.budget {
            return "\(name): budget differs (\(level.budget), witness \(stored.budget))"
        }
        if level.tutorial != stored.tutorial { return "\(name): tutorial differs" }
        if level.fingerprint != stored.fingerprint { return "\(name): level fingerprint differs" }
        return nil
    }

    /// The first disagreement between `level`, its stored `witness` and the solver's `solution` for `level`, naming the
    /// level and the part; nil when the level equals the witness's level, the witness's actions replay on a fresh play
    /// to a win in exactly its smallest move count within the budget with exactly its per-move digests and play
    /// fingerprints, and the solution's actions, smallest and depths equal the witness's with work at most
    /// `stateCount(level)`. A replay the play refuses is a named failure, never a crash.
    static func firstFailure(level: AmethystEscapeLevel, witness: AmethystEscapeWitness,
                             solution: AmethystEscapeSolution?) -> String? {
        let name: String = "level \(witness.number)"

        // The level against the witness's level, part by part, then by fingerprint.
        if let failure = levelFailure(level, stored: witness.level, name: name) { return failure }

        // The witness's actions replayed on a fresh play: a win on the last action, in exactly smallest moves.
        guard let run = AmethystEscapeWitness.replay(level, actions: witness.actions) else {
            return "\(name): witness action replay refused"
        }
        if run.endedEarly { return "\(name): witness action replay ends before the last action" }
        if run.play.stage != .won {
            return "\(name): witness action replay does not win (stage \(run.play.stage.rawValue))"
        }
        if witness.actions.count != witness.smallest {
            return "\(name): smallest move count \(witness.smallest) differs from the witness action count "
                + "\(witness.actions.count)"
        }
        if run.play.moves != witness.smallest {
            return "\(name): smallest move count \(witness.smallest) differs from the replay's \(run.play.moves) moves"
        }
        if witness.smallest > level.budget {
            return "\(name): smallest move count \(witness.smallest) exceeds the budget \(level.budget)"
        }
        if run.digests.count != witness.digests.count {
            return "\(name): per-move digest count \(witness.digests.count) differs (replay \(run.digests.count))"
        }
        for index in 0..<run.digests.count where run.digests[index] != witness.digests[index] {
            return "\(name): per-move digest \(index + 1) differs"
        }
        if run.fingerprints.count != witness.fingerprints.count {
            return "\(name): per-move fingerprint count \(witness.fingerprints.count) differs "
                + "(replay \(run.fingerprints.count))"
        }
        for index in 0..<run.fingerprints.count where run.fingerprints[index] != witness.fingerprints[index] {
            return "\(name): per-move fingerprint \(index) differs"
        }

        // The solver: exactly the witness's actions, smallest and depths; work within the state count.
        guard let solution else { return "\(name): solver finds no solution" }
        if solution.actions.count != witness.actions.count {
            return "\(name): solution action count \(solution.actions.count) differs from the witness's "
                + "\(witness.actions.count)"
        }
        for index in 0..<solution.actions.count where solution.actions[index] != witness.actions[index] {
            return "\(name): solution action \(index + 1) differs from the witness action"
        }
        if solution.smallest != witness.smallest {
            return "\(name): smallest move count \(witness.smallest) differs from the solver's \(solution.smallest)"
        }
        if solution.depths != witness.depths {
            return "\(name): depths \(witness.depths) differ from the solver's \(solution.depths)"
        }
        let bound: Int = AmethystEscapeSolver.stateCount(level)
        if solution.work > bound { return "\(name): solver work \(solution.work) exceeds the state count \(bound)" }
        return nil
    }

    /// Checks level `number` of group `group` (levels 10·(group − 1) + 1 … 10·group) through the parameterized test of
    /// that group: one level per argument.
    static func check(group: Int, number: Int) throws {
        #expect(number >= (group - 1) * 10 + 1 && number <= group * 10, "group \(group): level \(number)")
        let generated: AmethystEscapeGenerated = try generated(number)
        let witness: AmethystEscapeWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let solution: AmethystEscapeSolution? = AmethystEscapeSolver.solve(generated.level)
        let failure: String? = firstFailure(level: generated.level, witness: witness, solution: solution)
        #expect(failure == nil, Comment(rawValue: failure ?? ""))
        #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
        #expect(generated.difficulty == witness.difficulty, "level \(number): generator difficulty differs")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G0708-001; SC-R02G0708-001; Q1)

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

    // MARK: Alterations (FR-R02G0708-002; SC-R02G0708-002; clarification Q2)

    /// `level` rebuilt through the initialiser with the given parts replaced.
    static func rebuilt(_ level: AmethystEscapeLevel, sectors: Int? = nil, shells: [AmethystEscapeShell]? = nil,
                        start: Int? = nil, budget: Int? = nil) throws -> AmethystEscapeLevel {
        try AmethystEscapeLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                                sectors: sectors ?? level.sectors, shells: shells ?? level.shells,
                                start: start ?? level.start, budget: budget ?? level.budget, tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: AmethystEscapeWitness, actions: [AmethystEscapeAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil, smallest: Int? = nil,
                        depths: [Int]? = nil) -> AmethystEscapeWitness {
        AmethystEscapeWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                              digests: digests ?? witness.digests, fingerprints: fingerprints ?? witness.fingerprints,
                              smallest: smallest ?? witness.smallest, depths: depths ?? witness.depths,
                              unedited: witness.unedited, nearMiss: witness.nearMiss, difficulty: witness.difficulty,
                              skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// `values` with one sector of 0 … sectors − 1 toggled: the first sector missing added while the list stays below
    /// `limit` entries, otherwise the first entry removed.
    static func toggled(_ values: [Int], sectors: Int, limit: Int) -> [Int] {
        if values.count + 1 < limit {
            for sector in 0..<sectors where !values.contains(sector) { return values + [sector] }
        }
        return Array(values.dropFirst())
    }

    /// The outcome of one alteration: the checking function's first failure, or, when the level rules refuse the
    /// altered copy, that refusal named for the part.
    static func outcome(number: Int, part: String, witness: AmethystEscapeWitness,
                        build: () throws -> AmethystEscapeLevel) -> String? {
        let copy: AmethystEscapeLevel
        do {
            copy = try build()
        } catch {
            return "level \(number): \(part) differs (altered level refused: \(error))"
        }
        if copy.fingerprint == witness.level.fingerprint { return nil }
        return firstFailure(level: copy, witness: witness, solution: AmethystEscapeSolver.solve(copy))
    }

    /// Records an issue unless `found` names the level and `part`.
    static func expectNamed(_ found: String?, number: Int, kind: String, part: String) {
        let message: String = found ?? "(none)"
        #expect(message.hasPrefix("level \(number): ") && message.contains(part),
                "level \(number) alteration \(kind): \"\(message)\" does not name \"\(part)\"")
    }

    /// The unaltered levels, witnesses and solutions are clean, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: AmethystEscapeLevel = try Self.generated(number).level
        let found: String? = Self.firstFailure(level: level, witness: try Self.witness(number),
                                               solution: AmethystEscapeSolver.solve(level))
        #expect(found == nil, "level \(number): \(found ?? "")")
    }

    /// Level alterations: a shell's aperture, a shell's wall, a blocked wedge, the sector count, the start sector and
    /// the budget; each rebuilt through the level initialiser and reported naming its part (or refused by it).
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let level: AmethystEscapeLevel = try Self.generated(number).level
        let witness: AmethystEscapeWitness = try Self.witness(number)
        let inner: AmethystEscapeShell = level.shells[0]
        let second: AmethystEscapeShell = level.shells[1]

        // A shell's aperture: one outer aperture of the inner shell toggled (it is never the outermost shell).
        let apertures: [Int] = Self.toggled(inner.apertures, sectors: level.sectors, limit: level.sectors + 1)
        #expect(apertures != inner.apertures, "level \(number): apertures unchanged")
        var apertureShells: [AmethystEscapeShell] = level.shells
        apertureShells[0] = AmethystEscapeShell(apertures: apertures, walls: inner.walls, blocked: inner.blocked)
        Self.expectNamed(Self.outcome(number: number, part: "shell 0 aperture", witness: witness) {
            try Self.rebuilt(level, shells: apertureShells)
        }, number: number, kind: "aperture", part: "shell 0 aperture")

        // A shell's wall: one radial wall of the inner shell toggled.
        let walls: [Int] = Self.toggled(inner.walls, sectors: level.sectors, limit: level.sectors)
        #expect(walls != inner.walls, "level \(number): walls unchanged")
        var wallShells: [AmethystEscapeShell] = level.shells
        wallShells[0] = AmethystEscapeShell(apertures: inner.apertures, walls: walls, blocked: inner.blocked)
        Self.expectNamed(Self.outcome(number: number, part: "shell 0 wall", witness: witness) {
            try Self.rebuilt(level, shells: wallShells)
        }, number: number, kind: "wall", part: "shell 0 wall")

        // A blocked wedge: one blocked wedge of the second shell toggled.
        let blocked: [Int] = Self.toggled(second.blocked, sectors: level.sectors, limit: level.sectors)
        #expect(blocked != second.blocked, "level \(number): blocked wedges unchanged")
        var blockedShells: [AmethystEscapeShell] = level.shells
        blockedShells[1] = AmethystEscapeShell(apertures: second.apertures, walls: second.walls, blocked: blocked)
        Self.expectNamed(Self.outcome(number: number, part: "shell 1 blocked wedge", witness: witness) {
            try Self.rebuilt(level, shells: blockedShells)
        }, number: number, kind: "blocked wedge", part: "shell 1 blocked wedge")

        // The sector count: one more (one less at the largest count).
        let sectors: Int = level.sectors == AmethystEscapeLevel.sectorCounts.upperBound ? level.sectors - 1
            : level.sectors + 1
        Self.expectNamed(Self.outcome(number: number, part: "sector count", witness: witness) {
            try Self.rebuilt(level, sectors: sectors)
        }, number: number, kind: "sector count", part: "sector count")

        // The start sector: the next sector of the inner shell that is not blocked.
        var start: Int = level.start
        for step in 1..<level.sectors where start == level.start {
            let candidate: Int = (level.start + step) % level.sectors
            if !inner.isBlocked(candidate) { start = candidate }
        }
        #expect(start != level.start, "level \(number): no other start sector")
        Self.expectNamed(Self.outcome(number: number, part: "start sector", witness: witness) {
            try Self.rebuilt(level, start: start)
        }, number: number, kind: "start sector", part: "start sector")

        // The budget: one more (one less at the largest budget).
        let budget: Int = level.budget == AmethystEscapeLevel.budgets.upperBound ? level.budget - 1 : level.budget + 1
        Self.expectNamed(Self.outcome(number: number, part: "budget", witness: witness) {
            try Self.rebuilt(level, budget: budget)
        }, number: number, kind: "budget", part: "budget")
    }

    /// The solution alteration: the solver's first action replaced by a different move.
    @Test(arguments: alteredNumbers) func solutionAlterationIsNamed(number: Int) throws {
        let level: AmethystEscapeLevel = try Self.generated(number).level
        let witness: AmethystEscapeWitness = try Self.witness(number)
        let solution: AmethystEscapeSolution? = AmethystEscapeSolver.solve(level)
        #expect(solution != nil, "level \(number): no solution")
        guard let solution else { return }
        var actions: [AmethystEscapeAction] = solution.actions
        actions[0] = actions[0] == .rotate(0, 1) ? .rotate(0, -1) : .rotate(0, 1)
        let copy: AmethystEscapeSolution = AmethystEscapeSolution(smallest: solution.smallest, actions: actions,
                                                                  depths: solution.depths, work: solution.work)
        #expect(copy != solution, "level \(number): solution unchanged")
        Self.expectNamed(Self.firstFailure(level: level, witness: witness, solution: copy), number: number,
                         kind: "solution action", part: "solution action")
    }

    /// Witness alterations: an action, a per-move digest, a per-move fingerprint, the smallest move count and the
    /// depths.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: AmethystEscapeLevel = try Self.generated(number).level
        let witness: AmethystEscapeWitness = try Self.witness(number)
        let solution: AmethystEscapeSolution? = AmethystEscapeSolver.solve(level)
        var altered: [(String, String, AmethystEscapeWitness)] = []

        // A witness action: the closing advance replaced by a turn of the inner shell, so the replay cannot escape.
        var actions: [AmethystEscapeAction] = witness.actions
        let last: Int = actions.count - 1
        #expect(actions[last] == .advance, "level \(number): last action is not the advance")
        actions[last] = .rotate(0, 1)
        altered.append(("witness action", "witness action", Self.rebuilt(witness, actions: actions)))

        // A per-move digest: the middle move's digest with its first character changed.
        var digests: [String] = witness.digests
        let move: Int = digests.count / 2
        digests[move] = Self.flipped(digests[move])
        altered.append(("per-move digest", "per-move digest \(move + 1)", Self.rebuilt(witness, digests: digests)))

        // A per-move fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        altered.append(("per-move fingerprint", "per-move fingerprint \(index)",
                        Self.rebuilt(witness, fingerprints: fingerprints)))

        // The smallest move count, one more; the depths, the last depth's count one more.
        altered.append(("smallest", "smallest move count", Self.rebuilt(witness, smallest: witness.smallest + 1)))
        var depths: [Int] = witness.depths
        depths[depths.count - 1] += 1
        altered.append(("depths", "depths", Self.rebuilt(witness, depths: depths)))

        #expect(altered.count == 5)
        for (kind, part, copy) in altered {
            #expect(copy != witness, "level \(number) alteration \(kind): unchanged")
            Self.expectNamed(Self.firstFailure(level: level, witness: copy, solution: solution), number: number,
                             kind: kind, part: part)
        }
    }
}
