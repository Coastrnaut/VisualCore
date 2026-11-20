// PuzzleGeneratorTests — feature 223 (R02-F23) T-R02F23-005 (FR-R02F23-004, 005; clarification Q4; SC-R02F23-004;
// research R5). 100 seeds generate identical certified levels twice; the level's seed is the successful attempt's derived
// seed and regenerates the same candidate; rejections are counted by verdict; an impossible request fails after exactly
// its attempt budget; attempt budgets outside 1 … 10,000 are refused.
import Testing
@testable import VisualCoreSimulation

/// Lights-out candidate: 1 … 6 distinct moves toggled from the solved state. Lights-out moves are self-inverse and
/// commute, so the same moves solve the start.
private func lightsOutMaker(_ rng: inout SeededRandom) -> (start: UInt16, solution: [Int])? {
    let rules: LightsOutRules = LightsOutRules()
    let count: Int = rng.int(1...6)
    let order: [Int] = rng.shuffled(Array(0..<9))
    var moves: [Int] = []
    var state: UInt16 = 0
    for k in 0..<count {
        let move: Int = order[k]
        moves.append(move)
        guard let next = rules.apply(move, to: state) else { return nil }
        state = next
    }
    return (start: state, solution: moves)
}

/// Sliding-row candidate: a walk of 1 … 4 adjacent swaps from the sorted row; the reversed walk solves it, but it is
/// often not the only shortest solution (or not shortest at all), so many candidates break the `.solution` promise.
private func slidingRowMaker(_ rng: inout SeededRandom) -> (start: [Int], solution: [Int])? {
    let rules: SlidingRowRules = SlidingRowRules()
    let count: Int = rng.int(1...4)
    var walk: [Int] = []
    var state: [Int] = [0, 1, 2, 3]
    for _ in 0..<count {
        let move: Int = rng.int(0...2)
        walk.append(move)
        guard let next = rules.apply(move, to: state) else { return nil }
        state = next
    }
    return (start: state, solution: Array(walk.reversed()))
}

@Suite("PuzzleGenerator")
struct PuzzleGeneratorTests {
    private let lightsOut: LightsOutRules = LightsOutRules()
    private let slidingRow: SlidingRowRules = SlidingRowRules()

    private func lightsOutBudget() throws -> FairnessBudget {
        try FairnessBudget(minLength: 1, maxLength: 9, maxBranching: 9, nodeBudget: 1_000)
    }

    @Test("100 seeds: two runs give identical levels, each certifies, and its seed regenerates the candidate")
    func hundredSeedsDeterministicAndCertified() throws {
        let budget: FairnessBudget = try lightsOutBudget()
        for k in 0..<100 {
            let seed: UInt64 = UInt64(2_023 + k)
            let first: PuzzleGeneration<LightsOutRules> = try PuzzleGenerator.generate(
                seed: seed, attempts: 50, rules: lightsOut, budget: budget, uniqueness: .goal, make: lightsOutMaker)
            let second: PuzzleGeneration<LightsOutRules> = try PuzzleGenerator.generate(
                seed: seed, attempts: 50, rules: lightsOut, budget: budget, uniqueness: .goal, make: lightsOutMaker)
            #expect(first.level == second.level)
            #expect(first.level.identity == second.level.identity)
            #expect(first.certificate == second.certificate)
            #expect(first.attempts == second.attempts)
            #expect(first.rejections == second.rejections)
            #expect(first.certificate.isValid)
            #expect(first.attempts >= 1 && first.attempts <= 50)

            let recertified: PuzzleCertificate = PuzzleValidator.certify(first.level, rules: lightsOut)
            #expect(recertified.verdict == .valid)
            #expect(recertified == first.certificate)

            #expect(first.level.rulesID == "lights-out-3")
            #expect(first.level.uniqueness == .goal)
            #expect(first.level.budget == budget)
            let expectedSeed: UInt64 = SeedDerivation.derive(seed, index: UInt64(first.attempts - 1))
            #expect(first.level.seed == expectedSeed)

            let levelSeed: UInt64 = try #require(first.level.seed)
            var rng: SeededRandom = SeededRandom(seed: levelSeed)
            let again = try #require(lightsOutMaker(&rng))
            #expect(again.start == first.level.start)
            #expect(again.solution == first.level.solution)

            var total: Int = 0
            for (_, value) in first.rejections { total += value }
            #expect(total == first.attempts - 1)
        }
    }

    @Test("rejections are counted by verdict name and sum to attempts − 1")
    func rejectionsCounted() throws {
        let budget: FairnessBudget = try FairnessBudget(minLength: 1, maxLength: 6, maxBranching: 3, nodeBudget: 100)
        var notUniqueSeen: Int = 0
        var retriedSeeds: Int = 0
        for k in 0..<100 {
            let seed: UInt64 = UInt64(2_023 + k)
            let generation: PuzzleGeneration<SlidingRowRules> = try PuzzleGenerator.generate(
                seed: seed, attempts: 200, rules: slidingRow, budget: budget, uniqueness: .solution,
                make: slidingRowMaker)
            #expect(generation.certificate.isValid)
            #expect(PuzzleValidator.certify(generation.level, rules: slidingRow).isValid)
            var total: Int = 0
            for (name, value) in generation.rejections {
                #expect(value > 0)
                #expect(name != "valid")
                total += value
            }
            #expect(total == generation.attempts - 1)
            if generation.attempts > 1 { retriedSeeds += 1 }
            notUniqueSeen += generation.rejections["notUnique", default: 0]
            let expectedSeed: UInt64 = SeedDerivation.derive(seed, index: UInt64(generation.attempts - 1))
            #expect(generation.level.seed == expectedSeed)
        }
        #expect(retriedSeeds > 0)
        #expect(notUniqueSeen > 0)
    }

    @Test("a maker that never makes a candidate fails after exactly its attempt budget")
    func noCandidateFailsAfterBudget() throws {
        let budget: FairnessBudget = try lightsOutBudget()
        let budgets: [Int] = [1, 7, 64]
        for attempts in budgets {
            var calls: Int = 0
            var thrown: PuzzleError? = nil
            do {
                _ = try PuzzleGenerator.generate(
                    seed: 2_023, attempts: attempts, rules: lightsOut, budget: budget, uniqueness: .goal,
                    make: { (_: inout SeededRandom) -> (start: UInt16, solution: [Int])? in
                        calls += 1
                        return nil
                    })
            } catch {
                thrown = error
            }
            #expect(thrown == .generationFailed(attempts))
            #expect(thrown?.reasonCode == "r2-f23.generation-failed")
            #expect(calls == attempts)
        }
    }

    @Test("a minimum length above every candidate fails after exactly its attempt budget")
    func impossibleMinimumFailsAfterBudget() throws {
        let budget: FairnessBudget = try FairnessBudget(minLength: 9, maxLength: 9, maxBranching: 9, nodeBudget: 1_000)
        var calls: Int = 0
        var thrown: PuzzleError? = nil
        do {
            _ = try PuzzleGenerator.generate(
                seed: 2_024, attempts: 12, rules: lightsOut, budget: budget, uniqueness: .goal,
                make: { (rng: inout SeededRandom) -> (start: UInt16, solution: [Int])? in
                    calls += 1
                    return lightsOutMaker(&rng)
                })
        } catch {
            thrown = error
        }
        #expect(thrown == .generationFailed(12))
        #expect(calls == 12)
    }

    @Test("attempt budgets outside 1 … 10,000 are refused before the maker runs")
    func attemptRefusals() throws {
        #expect(PuzzleGenerator.maxAttempts == 10_000)
        let budget: FairnessBudget = try lightsOutBudget()
        let refused: [Int] = [0, -1, 10_001]
        for attempts in refused {
            var calls: Int = 0
            var thrown: PuzzleError? = nil
            do {
                _ = try PuzzleGenerator.generate(
                    seed: 2_023, attempts: attempts, rules: lightsOut, budget: budget, uniqueness: .goal,
                    make: { (rng: inout SeededRandom) -> (start: UInt16, solution: [Int])? in
                        calls += 1
                        return lightsOutMaker(&rng)
                    })
            } catch {
                thrown = error
            }
            #expect(thrown == .attempts)
            #expect(thrown?.reasonCode == "r2-f23.attempts")
            #expect(calls == 0)
        }
        let generation: PuzzleGeneration<LightsOutRules> = try PuzzleGenerator.generate(
            seed: 2_023, attempts: PuzzleGenerator.maxAttempts, rules: lightsOut, budget: budget, uniqueness: .goal,
            make: lightsOutMaker)
        #expect(generation.certificate.isValid)
    }

    @Test("a candidate that cannot form a level is counted as refused, and nil candidates as noCandidate")
    func refusedCandidateCounted() throws {
        let budget: FairnessBudget = try lightsOutBudget()
        let tooLong: [Int] = [Int](repeating: 0, count: FairnessBudget.maxLength + 1)
        var calls: Int = 0
        let generation: PuzzleGeneration<LightsOutRules> = try PuzzleGenerator.generate(
            seed: 2_023, attempts: 5, rules: lightsOut, budget: budget, uniqueness: .goal,
            make: { (rng: inout SeededRandom) -> (start: UInt16, solution: [Int])? in
                calls += 1
                if calls == 1 { return (start: 1, solution: tooLong) }
                if calls == 2 { return nil }
                return lightsOutMaker(&rng)
            })
        #expect(generation.attempts == 3)
        #expect(calls == 3)
        #expect(generation.rejections == ["refused": 1, "noCandidate": 1])
        #expect(generation.level.seed == SeedDerivation.derive(2_023, index: 2))
        #expect(generation.certificate.isValid)
    }
}
