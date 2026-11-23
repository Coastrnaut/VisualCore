// BackwardsAuroraSolverTests — feature 392 (R02-G10-02) T-R02G1002-003 (FR-R02G1002-002; SC-R02G1002-002, 005). The
// seam-count solver: hand-built levels with known answers (a straight target with one section reversed solves in 1,
// with two separated sections reversed in 2; bad bends and the bound counted by hand); generated levels of every band
// solve in exactly the bound, the solution wins through `wins(_:actions:)` and replays to a win through the play; the
// independent check (bad bends recomputed from the second differences of the sample array, a brute force over every
// single reversal from the opening and every witness state showing none removes more than 4, and an exhaustive search
// of every shorter sequence on the band-1 levels finding no win); determinism; the work bound honoured; and a level
// whose bound exceeds its budget has no solution. Fixture seed 2_392. Deterministic, explicit types, plain loops.
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

@Suite struct BackwardsAuroraSolverTests {
    /// The fixture seed of this feature.
    static let seed: UInt64 = 2_392

    /// The straight target 0, 2, 4, … 22 (every bend 0).
    static let straight: [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]

    /// The manifest indices sampled: two levels per band.
    static let sampled: [Int] = [0, 1, 20, 21, 40, 41, 60, 61, 80, 81]

    /// `samples` with the sections reversed in order.
    static func reversing(_ samples: [Int], _ sections: [(start: Int, end: Int)]) -> [Int] {
        var result: [Int] = samples
        for section in sections {
            var a: Int = section.start
            var b: Int = section.end
            while a < b {
                let t: Int = result[a]
                result[a] = result[b]
                result[b] = t
                a += 1
                b -= 1
            }
        }
        return result
    }

    /// A hand-built level on the straight target with `sections` reversed in the opening; fails on an invalid level.
    static func level(sections: [(start: Int, end: Int)], checkpoints: [Int], bendLimit: Int = 1,
                      breakingLimit: Int = 128, shortest: Int = 2, longest: Int = 12,
                      budget: Int = 3) throws -> BackwardsAuroraLevel {
        let opening: BackwardsAuroraWave = try BackwardsAuroraWave(reversing(straight, sections))
        let target: BackwardsAuroraWave = try BackwardsAuroraWave(straight)
        return try BackwardsAuroraLevel(id: "solver-test", seed: seed, difficulty: 1, opening: opening,
                                        target: target, checkpoints: checkpoints, bendLimit: bendLimit,
                                        breakingLimit: breakingLimit, shortest: shortest, longest: longest,
                                        budget: budget)
    }

    /// The one-section level: [3, 5] reversed (opening 0, 2, 4, 10, 8, 6, 12, …; bends 4, −8, 8, −4 at 2, 3, 5, 6).
    static func oneSection(budget: Int = 3) throws -> BackwardsAuroraLevel {
        try level(sections: [(start: 3, end: 5)], checkpoints: [3, 5], budget: budget)
    }

    /// The two-section level: [2, 3] and [7, 9] reversed (opening 0, 2, 6, 4, 8, 10, 12, 18, 16, 14, 20, 22; bends 2,
    /// −6, 6, −2 at 1 … 4 and 4, −8, 8, −4 at 6, 7, 9, 10).
    static func twoSections(budget: Int = 3) throws -> BackwardsAuroraLevel {
        try level(sections: [(start: 2, end: 3), (start: 7, end: 9)], checkpoints: [3, 7], budget: budget)
    }

    /// The bad bends of `samples` under `limit`, recomputed from the array of second differences (index i holds the
    /// difference centred on sample i + 1).
    static func secondDifferenceBad(_ samples: [Int], limit: Int) -> Int {
        var first: [Int] = []
        for i in 0..<(samples.count - 1) { first.append(samples[i + 1] - samples[i]) }
        var count: Int = 0
        for i in 0..<(first.count - 1) where abs(first[i + 1] - first[i]) > limit { count += 1 }
        return count
    }

    /// The opening and the wave after each action of `actions`.
    static func witnessStates(_ level: BackwardsAuroraLevel,
                              _ actions: [BackwardsAuroraAction]) -> [BackwardsAuroraWave] {
        var states: [BackwardsAuroraWave] = [level.opening]
        var wave: BackwardsAuroraWave = level.opening
        for action in actions {
            guard case let .reverse(start, end) = action else { continue }
            wave = wave.reversed(start: start, end: end)
            states.append(wave)
        }
        return states
    }

    /// The generated levels of the sampled manifest entries.
    static func generatedSample() throws -> [BackwardsAuroraGenerated] {
        var result: [BackwardsAuroraGenerated] = []
        for index in sampled {
            result.append(try BackwardsAuroraGenerator.generate(BackwardsAuroraManifest.entries[index]))
        }
        return result
    }

    /// Whether some sequence of at most `depth` reversals from `samples` wins `level`, searched exhaustively with the
    /// test's own reversal, seam and tear arithmetic (section lengths respected, palindromes skipped, a torn wave a
    /// leaf).
    static func someWin(_ level: BackwardsAuroraLevel, _ samples: [Int], depth: Int) throws -> Bool {
        if depth == 0 { return false }
        let count: Int = samples.count
        for start in 0..<(count - 1) {
            for end in (start + 1)..<count {
                guard level.sectionLengths.contains(end - start + 1) else { continue }
                var palindrome: Bool = true
                var a: Int = start
                var b: Int = end
                while a < b {
                    if samples[a] != samples[b] { palindrome = false }
                    a += 1
                    b -= 1
                }
                if palindrome { continue }
                let next: [Int] = reversing(samples, [(start: start, end: end)])
                var torn: Bool = false
                for k in [start - 1, start, end, end + 1] where k >= 1 && k <= count - 2 {
                    if abs(next[k - 1] - 2 * next[k] + next[k + 1]) > level.breakingLimit { torn = true }
                }
                if torn { continue }
                if level.wins(try BackwardsAuroraWave(next)) { return true }
                if try someWin(level, next, depth: depth - 1) { return true }
            }
        }
        return false
    }

    @Test func handBuiltOneSectionSolvesInOne() throws {
        let level: BackwardsAuroraLevel = try Self.oneSection()
        #expect(BackwardsAuroraSolver.badBends(level.opening, limit: 1) == 4)
        #expect(BackwardsAuroraSolver.badBends(level.target, limit: 1) == 0)
        #expect(BackwardsAuroraSolver.badBends(level.opening, limit: 8) == 0)
        #expect(BackwardsAuroraSolver.badBends(level.opening, limit: 4) == 2)
        let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
        #expect(bound.badBends == 4)
        #expect(bound.smallest == 1)
        let solution: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level))
        #expect(solution.smallest == 1)
        #expect(solution.actions == [.reverse(3, 5)])
        #expect(solution.work >= 1 && solution.work <= BackwardsAuroraSolver.workBound)
        #expect(BackwardsAuroraSolver.wins(level, actions: solution.actions))
    }

    @Test func handBuiltTwoSectionsSolveInTwo() throws {
        let level: BackwardsAuroraLevel = try Self.twoSections()
        #expect(level.opening.samples == [0, 2, 6, 4, 8, 10, 12, 18, 16, 14, 20, 22])
        #expect(level.opening.bends == [2, -6, 6, -2, 0, 4, -8, 0, 8, -4])
        let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
        #expect(bound.badBends == 8)
        #expect(bound.smallest == 2)
        let solution: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level))
        #expect(solution.smallest == 2)
        #expect(solution.actions == [.reverse(2, 3), .reverse(7, 9)])
        #expect(BackwardsAuroraSolver.wins(level, actions: solution.actions))
        #expect(!BackwardsAuroraSolver.wins(level, actions: [.reverse(2, 3)]))
        #expect(!(try Self.someWin(level, level.opening.samples, depth: 1)))
    }

    @Test func boundArithmetic() {
        let expected: [(bad: Int, smallest: Int)] = [(0, 0), (1, 1), (4, 1), (5, 2), (8, 2), (9, 3), (12, 3),
                                                     (13, 4), (28, 7)]
        for pair in expected {
            #expect(BackwardsAuroraBound(badBends: pair.bad).smallest == pair.smallest)
        }
    }

    @Test func boundAboveBudgetHasNoSolution() throws {
        let level: BackwardsAuroraLevel = try Self.twoSections(budget: 1)
        #expect(BackwardsAuroraSolver.lowerBound(level).smallest == 2)
        #expect(BackwardsAuroraSolver.solve(level) == nil)
        let longer: [BackwardsAuroraAction] = [.reverse(2, 3), .reverse(7, 9)]
        #expect(!BackwardsAuroraSolver.wins(level, actions: longer))
    }

    @Test func sectionLengthsLimitTheSolver() throws {
        // Only sections of exactly 2 samples: the three-sample section [3, 5] cannot be undone in one reversal; the
        // swaps that restore the target pass through waves with no fewer bad bends, so the bound is not reached.
        let level: BackwardsAuroraLevel = try Self.level(sections: [(start: 3, end: 5)], checkpoints: [3, 5],
                                                         shortest: 2, longest: 2, budget: 3)
        #expect(BackwardsAuroraSolver.lowerBound(level).smallest == 1)
        if let solution = BackwardsAuroraSolver.solve(level) {
            #expect(solution.smallest > 1)
            #expect(solution.actions.count == solution.smallest)
            #expect(BackwardsAuroraSolver.wins(level, actions: solution.actions))
            for action in solution.actions {
                guard case let .reverse(start, end) = action else { continue }
                #expect(end - start + 1 == 2)
            }
        }
        #expect(!(try Self.someWin(level, level.opening.samples, depth: 1)))
    }

    @Test func tearingReversalsAreNotUsed() throws {
        // A breaking limit of 4 on the one-section level: reversing [4, 5] leaves a seam bend of −10 at position 3 and
        // tears, so a sequence through it never wins; the known answer lands on the straight target (seam bends 0) and
        // still solves in one.
        let level: BackwardsAuroraLevel = try Self.level(sections: [(start: 3, end: 5)], checkpoints: [3, 5],
                                                         breakingLimit: 4)
        let torn: BackwardsAuroraWave = level.opening.reversed(start: 4, end: 5)
        #expect(torn.bend(at: 3) == -10)
        #expect(BackwardsAuroraSolver.tears(level, torn, start: 4, end: 5))
        #expect(!BackwardsAuroraSolver.wins(level, actions: [.reverse(4, 5), .reverse(3, 5)]))
        let solution: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level))
        #expect(solution.actions == [.reverse(3, 5)])
    }

    @Test func determinismAndWorkBound() throws {
        let level: BackwardsAuroraLevel = try Self.twoSections()
        let first: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level))
        let second: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level))
        #expect(first == second)
        #expect(first.work <= BackwardsAuroraSolver.workBound)
        #expect(first.work >= 2)
        #expect(BackwardsAuroraSolver.solve(level, workBound: 1) == nil)
        #expect(BackwardsAuroraSolver.solve(level, workBound: first.work - 1) == nil)
        let exact: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level, workBound: first.work))
        #expect(exact == first)
        #expect(exact.work <= first.work)
    }

    @Test func generatedLevelsSolveInTheBoundAndReplay() throws {
        let generated: [BackwardsAuroraGenerated] = try Self.generatedSample()
        #expect(generated.count == Self.sampled.count)
        for item in generated {
            let level: BackwardsAuroraLevel = item.level
            let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
            #expect(bound == item.bound)
            #expect(bound.badBends == 4 * bound.smallest)
            let solution: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level))
            #expect(solution == item.solution)
            #expect(solution.smallest == bound.smallest)
            #expect(solution.actions.count == bound.smallest)
            #expect(solution.work <= BackwardsAuroraSolver.workBound)
            #expect(BackwardsAuroraSolver.wins(level, actions: solution.actions))
            var play: BackwardsAuroraPlay = BackwardsAuroraPlay(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for action in solution.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(play.spent == bound.smallest)
            #expect(play.failure == nil)
        }
    }

    @Test func badBendsAgreeWithSecondDifferences() throws {
        for item in try Self.generatedSample() {
            let level: BackwardsAuroraLevel = item.level
            for wave in Self.witnessStates(level, item.solution.actions) {
                let separate: Int = Self.secondDifferenceBad(wave.samples, limit: level.bendLimit)
                #expect(separate == BackwardsAuroraSolver.badBends(wave, limit: level.bendLimit))
            }
        }
        let hand: BackwardsAuroraLevel = try Self.twoSections()
        #expect(Self.secondDifferenceBad(hand.opening.samples, limit: 1) == 8)
    }

    @Test func noSingleReversalRemovesMoreThanFour() throws {
        var checked: Int = 0
        var bestDrop: Int = 0
        for item in try Self.generatedSample() {
            let level: BackwardsAuroraLevel = item.level
            for wave in Self.witnessStates(level, item.solution.actions) {
                let before: Int = Self.secondDifferenceBad(wave.samples, limit: level.bendLimit)
                let count: Int = wave.count
                for start in 0..<(count - 1) {
                    for end in (start + 1)..<count {
                        let next: [Int] = Self.reversing(wave.samples, [(start: start, end: end)])
                        let after: Int = Self.secondDifferenceBad(next, limit: level.bendLimit)
                        #expect(before - after <= 4)
                        bestDrop = max(bestDrop, before - after)
                        checked += 1
                    }
                }
            }
        }
        #expect(checked > 0)
        #expect(bestDrop == 4)
    }

    @Test func noShorterSequenceWinsBandOneLevels() throws {
        for index in [0, 1] {
            let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[index]
            #expect(entry.band == 1)
            let item: BackwardsAuroraGenerated = try BackwardsAuroraGenerator.generate(entry)
            let smallest: Int = item.solution.smallest
            #expect(smallest >= 2)
            let found: Bool = try Self.someWin(item.level, item.level.opening.samples, depth: smallest - 1)
            #expect(!found)
        }
    }

    @Test func seededRandomOpeningsMeetTheBound() throws {
        // Seed 2_392: random straight-target levels with one section of 3 … 5 samples reversed away from the ends;
        // whenever the opening has four bad bends the solver answers in one reversal, and that reversal wins.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var solvedInOne: Int = 0
        for _ in 0..<24 {
            let length: Int = random.int(3...5)
            let start: Int = random.int(2...(Self.straight.count - 2 - length))
            let end: Int = start + length - 1
            let level: BackwardsAuroraLevel = try Self.level(sections: [(start: start, end: end)],
                                                             checkpoints: [start, end])
            let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
            #expect(bound.badBends == 4)
            let solution: BackwardsAuroraSolution = try #require(BackwardsAuroraSolver.solve(level))
            #expect(solution.smallest == 1)
            #expect(solution.actions == [.reverse(start, end)])
            if solution.smallest == 1 { solvedInOne += 1 }
        }
        #expect(solvedInOne == 24)
    }
}
