// PuzzleRulesTests — feature 223 (R02-F23) T-R02F23-002 (FR-R02F23-004, 008; clarifications Q1, Q4, Q5). Budget
// refusals and codes, verdict names, slug rule, and the test puzzles' rules being pure and solvable.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct PuzzleRulesTests {
    @Test func budgetRefusalsAndCodes() throws {
        #expect(throws: PuzzleError.budget("maxLength")) { try FairnessBudget(maxLength: 4_097) }
        #expect(throws: PuzzleError.budget("maxLength")) { try FairnessBudget(minLength: 0, maxLength: -1) }
        #expect(throws: PuzzleError.budget("minLength")) { try FairnessBudget(minLength: 5, maxLength: 4) }
        #expect(throws: PuzzleError.budget("minLength")) { try FairnessBudget(minLength: -1, maxLength: 4) }
        #expect(throws: PuzzleError.budget("maxBranching")) { try FairnessBudget(maxLength: 4, maxBranching: 0) }
        #expect(throws: PuzzleError.budget("maxBranching")) { try FairnessBudget(maxLength: 4, maxBranching: 1_025) }
        #expect(throws: PuzzleError.budget("nodeBudget")) { try FairnessBudget(maxLength: 4, nodeBudget: 0) }
        #expect(throws: PuzzleError.budget("nodeBudget")) { try FairnessBudget(maxLength: 4, nodeBudget: 1_000_001) }
        let widest = try FairnessBudget(minLength: 0, maxLength: 4_096, maxBranching: 1_024, nodeBudget: 1_000_000)
        let data = try JSONEncoder().encode(widest)
        #expect(try JSONDecoder().decode(FairnessBudget.self, from: data) == widest)
        let bad = Data(#"{"minLength":3,"maxLength":2,"maxBranching":4,"nodeBudget":10}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(FairnessBudget.self, from: bad) }
        let codes: [(PuzzleError, String)] = [
            (.rulesID, "r2-f23.rules-id"), (.solutionLength, "r2-f23.solution-length"), (.budget("x"), "r2-f23.budget"),
            (.attempts, "r2-f23.attempts"), (.generationFailed(3), "r2-f23.generation-failed"),
            (.newerSchema(2), "r2-f23.newer-schema"), (.malformed("x"), "r2-f23.malformed"), (.edited, "r2-f23.edited"),
        ]
        for (error, code) in codes { #expect(error.reasonCode == code) }
    }

    @Test func verdictNamesAndSlugs() {
        let verdicts: [(PuzzleVerdict, String)] = [
            (.valid, "valid"), (.wrongRules, "wrongRules"), (.illegalMove(3), "illegalMove"), (.notSolved, "notSolved"),
            (.tooShort(1), "tooShort"), (.tooLong(9), "tooLong"), (.tooBranching(9), "tooBranching"),
            (.notUnique, "notUnique"), (.unproven, "unproven"),
        ]
        for (verdict, name) in verdicts { #expect(verdict.name == name) }
        #expect(PuzzleCertificate(verdict: .valid).isValid && !PuzzleCertificate(verdict: .unproven).isValid)
        let good: [String] = ["a", "lights-out-3", "x9", String(repeating: "a", count: 64)]
        for id in good { #expect(PuzzleError.isSlug(id)) }
        let bad: [String] = ["", "-a", "a-", "a--b", "Abc", "a b", "é", String(repeating: "a", count: 65)]
        for id in bad { #expect(!PuzzleError.isSlug(id)) }
    }

    @Test func fixtureRulesArePureAndSolvable() throws {
        let lights = LightsOutRules()
        for state in UInt16(0)..<512 {
            #expect(lights.moves(in: state) == Array(0..<9))
            for move in 0..<9 {
                let next = try #require(lights.apply(move, to: state))
                #expect(lights.apply(move, to: next) == state)   // each move undoes itself
            }
        }
        #expect(lights.apply(9, to: 0) == nil && lights.apply(0, to: 600) == nil)
        let row = SlidingRowRules()
        var state: [Int] = [3, 2, 1, 0]
        let sort: [Int] = [0, 1, 2, 1, 0, 1]
        for move in sort { state = try #require(row.apply(move, to: state)) }
        #expect(row.isSolved(state))
        #expect(row.apply(3, to: state) == nil && row.moves(in: [1, 2]) == [])
    }
}
