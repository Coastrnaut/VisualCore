// PuzzleValidatorTests — feature 223 (R02-F23) T-R02F23-004 (SC-R02F23-002, 003; clarification Q3). 200 seeded levels
// with one planted fault each fail with exactly the planted verdict, 50 sound levels pass, certificates repeat, an
// already-solved start follows the minimum length, and the search statistics stay within the puzzle's state count.
import Testing
@testable import VisualCoreSimulation

/// Lights-out with a second solved state (only the centre lit), so a goal promise can fail.
private struct TwoGoalLightsOutRules: PuzzleRules {
    let rulesID = "lights-out-two-goals"
    let base = LightsOutRules()
    func moves(in state: UInt16) -> [Int] { base.moves(in: state) }
    func apply(_ move: Int, to state: UInt16) -> UInt16? { base.apply(move, to: state) }
    func isSolved(_ state: UInt16) -> Bool { state == 0 || state == 16 }
}

@Suite("PuzzleValidator")
struct PuzzleValidatorTests {
    let lightsOut = LightsOutRules()
    let slidingRow = SlidingRowRules()

    /// A non-empty set of distinct lights-out moves in seeded order, and the start they solve.
    func lightsOutCase(_ random: inout SeededRandom, minimumSize: Int = 1) -> (start: UInt16, solution: [Int]) {
        var cells: [Int] = random.shuffled(Array(0..<9))
        let size: Int = random.int(minimumSize...9)
        cells = Array(cells.prefix(size))
        var start: UInt16 = 0
        for move in cells {
            start = lightsOut.apply(move, to: start)!
        }
        return (start, cells)
    }

    /// A sliding-row start one increasing chain of swaps away from sorted, with its unique shortest solution.
    func slidingCase(_ random: inout SeededRandom) -> (start: [Int], solution: [Int]) {
        let length: Int = random.int(1...3)
        let first: Int = random.int(0...(3 - length))
        var chain: [Int] = []
        for i in 0..<length {
            chain.append(first + i)
        }
        var start: [Int] = [0, 1, 2, 3]
        for move in chain {
            start = slidingRow.apply(move, to: start)!
        }
        return (start, Array(chain.reversed()))
    }

    /// Builds the 200 faulted lights-out and sliding-row levels and certifies each, returning planted and found verdicts.
    func faultedRuns() throws -> [(planted: PuzzleVerdict, certificate: PuzzleCertificate)] {
        var random: SeededRandom = SeededRandom(seed: 2_023)
        var runs: [(planted: PuzzleVerdict, certificate: PuzzleCertificate)] = []
        for i in 0..<200 {
            let kind: Int = i % 8
            let useLights: Bool = (i / 8) % 2 == 0
            switch kind {
            case 0:
                if useLights {
                    let c = lightsOutCase(&random)
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                                solution: c.solution, budget: FairnessBudget(maxLength: 9))
                    runs.append((.wrongRules, PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    let c = slidingCase(&random)
                    let level = try PuzzleLevel<SlidingRowRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                 solution: c.solution, budget: FairnessBudget(maxLength: 6))
                    runs.append((.wrongRules, PuzzleValidator.certify(level, rules: slidingRow)))
                }
            case 1:
                if useLights {
                    let c = lightsOutCase(&random)
                    let at: Int = random.int(0...c.solution.count)
                    var solution: [Int] = c.solution
                    solution.insert(9, at: at)
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                solution: solution, budget: FairnessBudget(maxLength: 10))
                    runs.append((.illegalMove(at), PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    let c = slidingCase(&random)
                    let at: Int = random.int(0...c.solution.count)
                    var solution: [Int] = c.solution
                    solution.insert(7, at: at)
                    let level = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                                 solution: solution, budget: FairnessBudget(maxLength: 6))
                    runs.append((.illegalMove(at), PuzzleValidator.certify(level, rules: slidingRow)))
                }
            case 2:
                // A proper prefix of a minimal solution never ends solved.
                if useLights {
                    let c = lightsOutCase(&random)
                    let keep: Int = random.int(0...(c.solution.count - 1))
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                solution: Array(c.solution.prefix(keep)),
                                                                budget: FairnessBudget(minLength: 0, maxLength: 9))
                    runs.append((.notSolved, PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    let c = slidingCase(&random)
                    let keep: Int = random.int(0...(c.solution.count - 1))
                    let level = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                                 solution: Array(c.solution.prefix(keep)),
                                                                 budget: FairnessBudget(minLength: 0, maxLength: 6))
                    runs.append((.notSolved, PuzzleValidator.certify(level, rules: slidingRow)))
                }
            case 3:
                if useLights {
                    // Lights-out moves commute: a solution of two or more moves has several shortest orderings.
                    let c = lightsOutCase(&random, minimumSize: 2)
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                solution: c.solution, uniqueness: .solution,
                                                                budget: FairnessBudget(maxLength: 9))
                    runs.append((.notUnique, PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    // A second solved state (centre lit) is reachable, so the goal promise fails.
                    let twoGoals: TwoGoalLightsOutRules = TwoGoalLightsOutRules()
                    var c = lightsOutCase(&random)
                    while c.start == 16 {
                        c = lightsOutCase(&random)
                    }
                    let level = try PuzzleLevel<TwoGoalLightsOutRules>(rulesID: twoGoals.rulesID, start: c.start,
                                                                       solution: c.solution, uniqueness: .goal,
                                                                       budget: FairnessBudget(maxLength: 9))
                    runs.append((.notUnique, PuzzleValidator.certify(level, rules: twoGoals)))
                }
            case 4:
                if useLights {
                    let c = lightsOutCase(&random)
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                solution: c.solution,
                                                                budget: FairnessBudget(minLength: 0,
                                                                                       maxLength: c.solution.count - 1))
                    runs.append((.tooLong(c.solution.count), PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    let c = slidingCase(&random)
                    let level = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                                 solution: c.solution,
                                                                 budget: FairnessBudget(minLength: 0,
                                                                                        maxLength: c.solution.count - 1))
                    runs.append((.tooLong(c.solution.count), PuzzleValidator.certify(level, rules: slidingRow)))
                }
            case 5:
                // The given solution wastes a move pair; the minimum sits above the shortest found.
                if useLights {
                    let c = lightsOutCase(&random, minimumSize: 1)
                    let wasted: Int = random.int(0...8)
                    let at: Int = random.int(0...c.solution.count)
                    var solution: [Int] = c.solution
                    solution.insert(contentsOf: [wasted, wasted], at: at)
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                solution: solution,
                                                                budget: FairnessBudget(minLength: c.solution.count + 1,
                                                                                       maxLength: solution.count))
                    runs.append((.tooShort(c.solution.count), PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    let c = slidingCase(&random)
                    let wasted: Int = random.int(0...2)
                    let at: Int = random.int(0...c.solution.count)
                    var solution: [Int] = c.solution
                    solution.insert(contentsOf: [wasted, wasted], at: at)
                    let level = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                                 solution: solution,
                                                                 budget: FairnessBudget(minLength: c.solution.count + 1,
                                                                                        maxLength: solution.count))
                    runs.append((.tooShort(c.solution.count), PuzzleValidator.certify(level, rules: slidingRow)))
                }
            case 6:
                if useLights {
                    let c = lightsOutCase(&random)
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                solution: c.solution,
                                                                budget: FairnessBudget(maxLength: 9, maxBranching: 8))
                    runs.append((.tooBranching(9), PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    let c = slidingCase(&random)
                    let level = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                                 solution: c.solution,
                                                                 budget: FairnessBudget(maxLength: 6, maxBranching: 2))
                    runs.append((.tooBranching(3), PuzzleValidator.certify(level, rules: slidingRow)))
                }
            default:
                // The full search discovers 512 (lights-out) or 24 (sliding row) states; the budget is below that.
                if useLights {
                    let c = lightsOutCase(&random)
                    let nodes: Int = random.int(1...511)
                    let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                                solution: c.solution, uniqueness: .goal,
                                                                budget: FairnessBudget(maxLength: 9, nodeBudget: nodes))
                    runs.append((.unproven, PuzzleValidator.certify(level, rules: lightsOut)))
                } else {
                    let c = slidingCase(&random)
                    let nodes: Int = random.int(1...10)
                    let level = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                                 solution: c.solution, uniqueness: .solution,
                                                                 budget: FairnessBudget(maxLength: 6, nodeBudget: nodes))
                    runs.append((.unproven, PuzzleValidator.certify(level, rules: slidingRow)))
                }
            }
        }
        return runs
    }

    /// Certifies 50 sound levels: sliding rows with a unique shortest solution, lights-out with a goal promise.
    func soundRuns() throws -> [PuzzleCertificate] {
        var random: SeededRandom = SeededRandom(seed: 2_023)
        var certificates: [PuzzleCertificate] = []
        for i in 0..<50 {
            if i % 2 == 0 {
                let c = slidingCase(&random)
                let level = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: c.start,
                                                             solution: c.solution, uniqueness: .solution,
                                                             budget: FairnessBudget(maxLength: 6))
                certificates.append(PuzzleValidator.certify(level, rules: slidingRow))
            } else {
                let c = lightsOutCase(&random)
                let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start,
                                                            solution: c.solution, uniqueness: .goal,
                                                            budget: FairnessBudget(maxLength: 9))
                certificates.append(PuzzleValidator.certify(level, rules: lightsOut))
            }
        }
        return certificates
    }

    @Test("200 planted faults fail with exactly the planted verdict")
    func plantedFaults() throws {
        let runs = try faultedRuns()
        #expect(runs.count == 200)
        var names: Set<String> = []
        for run in runs {
            #expect(run.certificate.verdict == run.planted)
            names.insert(run.planted.name)
        }
        let expected: Set<String> = ["wrongRules", "illegalMove", "notSolved", "notUnique", "tooLong", "tooShort",
                                     "tooBranching", "unproven"]
        #expect(names == expected)
    }

    @Test("50 sound levels pass")
    func soundLevelsPass() throws {
        let certificates: [PuzzleCertificate] = try soundRuns()
        #expect(certificates.count == 50)
        for certificate in certificates {
            #expect(certificate.verdict == .valid)
            #expect(certificate.isValid)
            #expect(certificate.solvedStates == 1)
        }
    }

    @Test("certificates are identical across two runs")
    func certificatesRepeat() throws {
        let firstFaults = try faultedRuns()
        let secondFaults = try faultedRuns()
        for i in 0..<firstFaults.count {
            #expect(firstFaults[i].certificate == secondFaults[i].certificate)
        }
        let firstSound: [PuzzleCertificate] = try soundRuns()
        let secondSound: [PuzzleCertificate] = try soundRuns()
        #expect(firstSound == secondSound)
    }

    @Test("an already-solved start with an empty solution follows the minimum length")
    func alreadySolvedStart() throws {
        let strict = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: 0, solution: [],
                                                     budget: FairnessBudget(minLength: 1, maxLength: 9))
        #expect(PuzzleValidator.certify(strict, rules: lightsOut).verdict == .tooShort(0))
        #expect(PuzzleValidator.certify(strict, rules: lightsOut).explored == 0)
        let lenient = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: 0, solution: [],
                                                      uniqueness: .solution,
                                                      budget: FairnessBudget(minLength: 0, maxLength: 9))
        let certificate: PuzzleCertificate = PuzzleValidator.certify(lenient, rules: lightsOut)
        #expect(certificate.verdict == .valid)
        #expect(certificate.shortest == 0)
        #expect(certificate.shortestPaths == 1)
        #expect(certificate.solvedStates == 1)
        let sorted = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: [0, 1, 2, 3], solution: [],
                                                      uniqueness: .goal, budget: FairnessBudget(minLength: 0, maxLength: 6))
        #expect(PuzzleValidator.certify(sorted, rules: slidingRow).verdict == .valid)
    }

    @Test("search statistics stay within the state count")
    func statistics() throws {
        var random: SeededRandom = SeededRandom(seed: 2_023)
        for _ in 0..<20 {
            let c = lightsOutCase(&random)
            let level = try PuzzleLevel<LightsOutRules>(rulesID: lightsOut.rulesID, start: c.start, solution: c.solution,
                                                        uniqueness: .goal, budget: FairnessBudget(maxLength: 9))
            let certificate: PuzzleCertificate = PuzzleValidator.certify(level, rules: lightsOut)
            #expect(certificate.isValid)
            #expect(certificate.explored > 0)
            #expect(certificate.explored <= 512)
            #expect(certificate.shortest == c.solution.count)
            #expect(certificate.maxBranching == 9)
            #expect(certificate.solvedStates == 1)
        }
        let swap = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: [1, 0, 2, 3], solution: [0],
                                                    uniqueness: .solution, budget: FairnessBudget(maxLength: 6))
        let certificate: PuzzleCertificate = PuzzleValidator.certify(swap, rules: slidingRow)
        #expect(certificate.verdict == .valid)
        #expect(certificate.explored <= 24)
        #expect(certificate.shortest == 1)
        #expect(certificate.shortestPaths == 1)
        #expect(certificate.maxBranching == 3)
        // An illegal move stops before the search: nothing explored.
        let illegal = try PuzzleLevel<SlidingRowRules>(rulesID: slidingRow.rulesID, start: [1, 0, 2, 3], solution: [7],
                                                       budget: FairnessBudget(maxLength: 6))
        #expect(PuzzleValidator.certify(illegal, rules: slidingRow) == PuzzleCertificate(verdict: .illegalMove(0)))
    }
}
