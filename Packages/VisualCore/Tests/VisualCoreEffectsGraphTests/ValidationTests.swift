// ValidationTests — feature 005 T-F402 (FR-F401–FR-F404, FR-F406, SC-F401).
import Foundation
import Testing
@testable import VisualCoreEffectsGraph

private func fixture(_ name: String) throws -> EffectGraphDescription {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(EffectGraphDescription.self, from: Data(contentsOf: url))
}

private func pass(_ id: String, _ type: String = "copy", inputs: [String: String] = ["input": "scene"],
                  out: String? = nil, scale: Double = 1, params: [String: [Double]] = [:]) -> EffectPassDescription {
    EffectPassDescription(id: id, type: type, inputs: inputs, output: out ?? id.lowercased(), scale: scale, params: params)
}

private func validate(_ g: EffectGraphDescription, quota: Int = 256 << 20) throws(EffectGraphError) -> ValidatedGraph {
    try EffectGraphValidator.validate(g, width: 100, height: 100, quotaBytes: quota)
}

@Test func chainFixtureOrdersAndEstimates() throws {
    let v = try validate(try fixture("chain"))
    #expect(v.order == ["grade", "soft", "mix"])
    // graded 100x100x4 + blurred 50x50x4 + final 100x100x4
    #expect(v.estimatedBytes == 40_000 + 10_000 + 40_000)
}

@Test func tiesBreakByDeclarationOrder() throws {
    let g = EffectGraphDescription(version: 1, passes: [
        pass("Z", inputs: ["input": "scene"], out: "z"),
        pass("A", inputs: ["input": "scene"], out: "a"),
        pass("M", "composite", inputs: ["base": "z", "overlay": "a"], out: "m"),
    ], output: "m")
    #expect(try validate(g).order == ["Z", "A", "M"])
}

@Test func cycleFixtureIsRejectedNamingTheCycle() throws {
    #expect(throws: EffectGraphError.cycle(["B", "C"])) { try validate(try fixture("cycle")) }
}

@Test func feedbackHistoryAndHDRAreEstimated() throws {
    let v = try validate(try fixture("bloom-feedback"))
    // glowing: hdr rgba16f 8 B/px; trail rgba8 + its history buffer
    #expect(v.estimatedBytes == 80_000 + 40_000 + 40_000)
}

@Test func everyRejectionCaseHasItsError() {
    #expect(throws: EffectGraphError.unsupportedVersion(2)) {
        try validate(EffectGraphDescription(version: 2, passes: [pass("A")], output: "a")) }
    #expect(throws: EffectGraphError.tooManyPasses(33)) {
        try validate(EffectGraphDescription(version: 1, passes: (0..<33).map { pass("P\($0)", out: "o\($0)") }, output: "o0")) }
    #expect(throws: EffectGraphError.duplicateID("A")) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A", out: "x"), pass("A", out: "y")], output: "x")) }
    #expect(throws: EffectGraphError.duplicateOutput("x")) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A", out: "x"), pass("B", out: "x")], output: "x")) }
    #expect(throws: EffectGraphError.unknownType("sparkle", pass: "A")) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A", "sparkle")], output: "a")) }
    #expect(throws: EffectGraphError.missingInput(pass: "A", input: "input", source: "nowhere")) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A", inputs: ["input": "nowhere"])], output: "a")) }
    #expect(throws: EffectGraphError.missingSlot(pass: "M", slot: "overlay")) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("M", "composite", inputs: ["base": "scene"])], output: "m")) }
    #expect(throws: EffectGraphError.invalidScale(pass: "A", 0)) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A", scale: 0)], output: "a")) }
    #expect(throws: EffectGraphError.invalidScale(pass: "A", 1.5)) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A", scale: 1.5)], output: "a")) }
    #expect(throws: EffectGraphError.missingOutput("final")) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A")], output: "final")) }
    #expect(throws: EffectGraphError.overQuota(bytes: 40_000, quota: 1_000)) {
        try validate(EffectGraphDescription(version: 1, passes: [pass("A")], output: "a"), quota: 1_000) }
}

@Test func parametersAreClampedAndUnknownKeysWarned() throws {
    let g = EffectGraphDescription(version: 1, passes: [
        pass("B", "blur", params: ["radius": [100], "colour": [1]]),
    ], output: "b")
    let v = try validate(g)
    #expect(v.parameters["B"]?["radius"] == [32])
    #expect(v.parameters["B"]?["sigma"] == nil)
    #expect(v.warnings == ["B: unknown parameter 'colour' ignored"])
}

@Test func defaultsFillMissingParameters() throws {
    let v = try validate(EffectGraphDescription(version: 1, passes: [pass("F", "feedback")], output: "f"))
    #expect(v.parameters["F"]?["decay"] == [0.9])
}

@Test func codableRoundTripIsLossless() throws {
    let g = try fixture("chain")
    let again = try JSONDecoder().decode(EffectGraphDescription.self, from: JSONEncoder().encode(g))
    #expect(again == g)
}

@Test func everyBuiltInTypeHasASchema() {
    for t in ["copy", "colorMatrix", "blur", "bloom", "distort", "composite", "feedback", "flashLimit"] {
        #expect(PassSchemas.schema(for: t) != nil, "\(t)")
    }
    #expect(PassSchemas.maxPasses == 32)
}

// T-F420 (US1/AC2): only passes on the cycle are named, not passes downstream of it.
@Test func cycleErrorExcludesDownstreamPasses() throws {
    let g = EffectGraphDescription(passes: [
        EffectPassDescription(id: "A", type: "copy", inputs: ["input": "scene"], output: "a"),
        EffectPassDescription(id: "B", type: "copy", inputs: ["input": "c"], output: "b"),
        EffectPassDescription(id: "C", type: "copy", inputs: ["input": "b"], output: "c"),
        EffectPassDescription(id: "D", type: "copy", inputs: ["input": "c"], output: "d"),
        EffectPassDescription(id: "E", type: "composite", inputs: ["base": "d", "overlay": "a"], output: "e"),
    ], output: "e")
    #expect(throws: EffectGraphError.cycle(["B", "C"])) { try validate(g) }
}
