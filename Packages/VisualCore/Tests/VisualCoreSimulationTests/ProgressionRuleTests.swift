// ProgressionRuleTests — feature 224 (R02-F24) T-R02F24-002 (FR-R02F24-001, 002, 006; clarifications Q1, Q2, Q5).
// Plan, stage and rule refusals with reason codes; breach positions for drops and jumps; the difficulty order and its
// certificate initialiser; coding re-validates. Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct ProgressionRuleTests {
    static func budget() throws -> FairnessBudget { try FairnessBudget(minLength: 1, maxLength: 9) }

    @Test func refusalsAndCodes() throws {
        #expect(throws: ContentError.plan("maxDrop")) { try ProgressionRule(maxDrop: -1) }
        #expect(throws: ContentError.plan("maxJump")) { try ProgressionRule(maxJump: 65) }
        #expect(throws: ContentError.plan("count")) { try PuzzleCatalogStage(count: 0, budget: Self.budget()) }
        #expect(throws: ContentError.plan("count")) { try PuzzleCatalogStage(count: 501, budget: Self.budget()) }
        #expect(throws: ContentError.plan("attempts")) { try PuzzleCatalogStage(count: 1, budget: Self.budget(), attempts: 0) }
        #expect(throws: ContentError.plan("attempts")) {
            try PuzzleCatalogStage(count: 1, budget: Self.budget(), attempts: 10_001)
        }
        let stage = try PuzzleCatalogStage(count: 500, budget: Self.budget())
        #expect(throws: ContentError.plan("id")) { try PuzzleCatalogPlan(id: "Bad Id", seed: 1, stages: [stage]) }
        #expect(throws: ContentError.plan("stages")) { try PuzzleCatalogPlan(id: "a", seed: 1, stages: []) }
        let seventeen: [PuzzleCatalogStage] = Array(repeating: try PuzzleCatalogStage(count: 1, budget: Self.budget()), count: 17)
        #expect(throws: ContentError.plan("stages")) { try PuzzleCatalogPlan(id: "a", seed: 1, stages: seventeen) }
        let three: [PuzzleCatalogStage] = [stage, stage, stage]
        #expect(throws: ContentError.plan("levels")) { try PuzzleCatalogPlan(id: "a", seed: 1, stages: three) }
        _ = try PuzzleCatalogPlan(id: "a", seed: 1, stages: [stage, stage])
        let codes: [(ContentError, String)] = [
            (.plan("x"), "r2-f24.plan"), (.planFailed(stage: 1, calls: 2), "r2-f24.plan-failed"),
            (.progression(3), "r2-f24.progression"), (.tutorial("x"), "r2-f24.tutorial"),
            (.newerSchema(2), "r2-f24.newer-schema"), (.malformed("x"), "r2-f24.malformed"), (.edited, "r2-f24.edited"),
        ]
        for (error, code) in codes { #expect(error.reasonCode == code) }
    }

    @Test func breachPositions() throws {
        let rule = ProgressionRule.standard
        #expect(rule.maxDrop == 1 && rule.maxJump == 3)
        func run(_ lengths: [Int]) -> [PuzzleDifficulty] {
            var result: [PuzzleDifficulty] = []
            for l in lengths { result.append(PuzzleDifficulty(shortest: l, explored: 1)) }
            return result
        }
        #expect(rule.breach(run([])) == nil)
        #expect(rule.breach(run([5])) == nil)
        #expect(rule.breach(run([1, 2, 1, 4, 7, 6])) == nil)
        let drop = try #require(rule.breach(run([3, 4, 2, 9])))
        #expect(drop.index == 2 && drop.isDrop)
        let jump = try #require(rule.breach(run([1, 2, 6])))
        #expect(jump.index == 2 && !jump.isDrop)
        let flat = try ProgressionRule(maxDrop: 0, maxJump: 0)
        #expect(flat.breach(run([2, 2, 2])) == nil)
        #expect(flat.breach(run([2, 2, 3]))?.index == 2)
    }

    @Test func difficultyOrderAndCertificate() throws {
        let a = PuzzleDifficulty(shortest: 2, explored: 50)
        let b = PuzzleDifficulty(shortest: 3, explored: 10)
        let c = PuzzleDifficulty(shortest: 3, explored: 11)
        #expect(a < b && b < c && !(c < b))
        let certificate = PuzzleCertificate(verdict: .valid, explored: 40, shortest: 4, solvedStates: 1, shortestPaths: 1,
                                            maxBranching: 9)
        #expect(PuzzleDifficulty(certificate: certificate) == PuzzleDifficulty(shortest: 4, explored: 40))
        #expect(PuzzleDifficulty(certificate: PuzzleCertificate(verdict: .wrongRules)) == nil)
    }

    @Test func codingRevalidates() throws {
        let plan = try PuzzleCatalogPlan(id: "first-catalog", seed: 2_024,
                                         stages: [PuzzleCatalogStage(count: 3, budget: Self.budget(), uniqueness: .goal)])
        let data = try JSONEncoder().encode(plan)
        #expect(try JSONDecoder().decode(PuzzleCatalogPlan.self, from: data) == plan)
        let badRule = Data(#"{"maxDrop":70,"maxJump":1}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ProgressionRule.self, from: badRule) }
        var text = String(decoding: data, as: UTF8.self)
        text = text.replacingOccurrences(of: "\"count\":3", with: "\"count\":0")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(PuzzleCatalogPlan.self, from: Data(text.utf8)) }
    }
}
