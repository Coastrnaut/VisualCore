// PlantGrammarTests — feature 219 (R02-F19) T-R02F19-002 (FR-R02F19-006, FR-R02F19-007; clarification Q5). Every refusal
// of rules and grammars with its reason code; the stored form round-trips byte for byte; a newer schema and damaged data
// are refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreScenes

@Suite struct PlantGrammarTests {
    static func fern() throws -> PlantGrammar {
        let x: PlantRule = try PlantRule("X", weighted: [("F[+X][-X]FX", 2), ("F[&X]^X", 1)])
        let f: PlantRule = try PlantRule("F", "FF")
        return try PlantGrammar(start: "X", rules: [x, f], generations: 4, angle: 0.4, step: 0.2, radius: 0.03,
                                radiusFactor: 0.75, seed: 2_019)
    }

    @Test func ruleRefusals() throws {
        #expect(throws: PlantError.rule("successors of A")) { try PlantRule("A", weighted: []) }
        let nine: [(String, Double)] = Array(repeating: ("A", 1), count: 9)
        #expect(throws: PlantError.rule("successors of A")) { try PlantRule("A", weighted: nine) }
        #expect(throws: PlantError.rule("word of A")) { try PlantRule("A", "") }
        #expect(throws: PlantError.rule("word of A")) { try PlantRule("A", String(repeating: "F", count: 257)) }
        #expect(throws: PlantError.weight("A")) { try PlantRule("A", weighted: [("F", 0)]) }
        #expect(throws: PlantError.weight("A")) { try PlantRule("A", weighted: [("F", .nan)]) }
        #expect(throws: PlantError.weight("A")) { try PlantRule("A", weighted: [("F", -1)]) }
    }

    @Test func grammarRefusals() throws {
        let f: PlantRule = try PlantRule("F", "FF")
        #expect(throws: PlantError.rule("start")) { try PlantGrammar(start: "", rules: [f], generations: 1, angle: 0.5, step: 1) }
        #expect(throws: PlantError.rule("duplicate F")) { try PlantGrammar(start: "F", rules: [f, f], generations: 1, angle: 0.5, step: 1) }
        #expect(throws: PlantError.generations(13)) { try PlantGrammar(start: "F", rules: [f], generations: 13, angle: 0.5, step: 1) }
        #expect(throws: PlantError.generations(-1)) { try PlantGrammar(start: "F", rules: [f], generations: -1, angle: 0.5, step: 1) }
        #expect(throws: PlantError.turtleParameter("angle")) { try PlantGrammar(start: "F", rules: [f], generations: 1, angle: 4, step: 1) }
        #expect(throws: PlantError.turtleParameter("step")) { try PlantGrammar(start: "F", rules: [f], generations: 1, angle: 0.5, step: 0) }
        #expect(throws: PlantError.turtleParameter("radius")) { try PlantGrammar(start: "F", rules: [f], generations: 1, angle: 0.5, step: 1, radius: .infinity) }
        #expect(throws: PlantError.turtleParameter("radiusFactor")) { try PlantGrammar(start: "F", rules: [f], generations: 1, angle: 0.5, step: 1, radiusFactor: 1.5) }
        var many: [PlantRule] = []
        for k in 0..<65 { many.append(try PlantRule(Character(UnicodeScalar(0x100 + k)!), "F")) }
        #expect(throws: PlantError.rule("too many rules")) { try PlantGrammar(start: "F", rules: many, generations: 1, angle: 0.5, step: 1) }
        let grammar: PlantGrammar = try Self.fern()
        #expect(grammar.rule(for: "X")?.successors.count == 2)
        #expect(grammar.rule(for: "+") == nil)
        let codes: [PlantError] = [.generations(1), .wordLimit(1), .rule("x"), .weight("x"), .brackets,
                                   .turtleParameter("x"), .shapeParameter("x"), .branchLimit(1), .scatterArea,
                                   .scatterParameter("x"), .newerSchema(2), .malformed("x")]
        let expected: [String] = ["generations", "word-limit", "rule", "weight", "brackets", "turtle-parameter",
                                  "shape-parameter", "branch-limit", "scatter-area", "scatter-parameter", "newer-schema",
                                  "malformed"]
        for k in 0..<codes.count { #expect(codes[k].reasonCode == "r2-f19." + expected[k]) }
    }

    @Test func storedFormRoundTripsByteForByte() throws {
        let grammar: PlantGrammar = try Self.fern()
        let data: Data = grammar.encoded()
        let decoded: PlantGrammar = try PlantGrammar.decode(data)
        #expect(decoded == grammar)
        #expect(decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"schema\":1") && text.contains("\"seed\":2019"))
    }

    @Test func newerAndDamagedFormsAreRefused() throws {
        var object = try #require(try JSONSerialization.jsonObject(with: try Self.fern().encoded()) as? [String: Any])
        object["schema"] = 2
        #expect(throws: PlantError.newerSchema(2)) { try PlantGrammar.decode(try JSONSerialization.data(withJSONObject: object)) }
        object["schema"] = 1
        object["generations"] = 20
        #expect(throws: PlantError.generations(20)) { try PlantGrammar.decode(try JSONSerialization.data(withJSONObject: object)) }
        object["generations"] = 2
        object["rules"] = [["predecessor": "XY", "successors": [["word": "F", "weight": 1]]]]
        #expect(throws: PlantError.malformed("predecessor XY")) { try PlantGrammar.decode(try JSONSerialization.data(withJSONObject: object)) }
        object["rules"] = [["predecessor": "X", "successors": [["word": "F", "weight": 0]]]]
        #expect(throws: PlantError.weight("X")) { try PlantGrammar.decode(try JSONSerialization.data(withJSONObject: object)) }
        let damaged: [String] = ["", "{", "[]", #"{"schema":1}"#, #"{"schema":0}"#]
        for text in damaged {
            do {
                _ = try PlantGrammar.decode(Data(text.utf8))
                Issue.record("accepted \(text)")
            } catch {
                #expect(error.reasonCode == "r2-f19.malformed", "\(text)")
            }
        }
    }
}
