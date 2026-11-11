// ParameterEditorTests — feature 013 T-A01-202 (FR-A01-201, FR-A01-206; SC-A01-201; edge cases).
import Testing
@testable import VisualCoreParameters

private func schema() throws -> ParameterSchema {
    try ParameterSchema([
        ParameterDefinition(name: "scale", title: "Scale", unit: "×", range: 0.5...16, defaultValue: 3, transform: .logarithmic),
        ParameterDefinition(name: "warp", title: "Warp", range: 0...2, defaultValue: 0.8),
    ])
}

@Test func setClampsAndRejects() throws {
    var e = try ParameterEditor(schema: schema(), values: ["warp": 1.5])
    #expect(e.values == ["scale": 3, "warp": 1.5])
    let clamped = e.set("warp", to: 99)
    #expect(clamped && e.values["warp"] == 2)
    let nan = e.set("warp", to: .nan)
    #expect(!nan && e.values["warp"] == 2)
    let unknown = e.set("bogus", to: 1)
    #expect(!unknown)
    for t in [0.0, 1, -1, 2, .nan, .infinity, -.infinity] {
        let ok = e.set("scale", normalized: t)
        #expect(ok)
        let v = e.values["scale"]!
        #expect(v.isFinite && (0.5...16).contains(v), "position \(t) → \(v)")
    }
    e.set("scale", normalized: .nan)
    #expect(e.values["scale"] == 0.5)
    let unknownNormalized = e.set("bogus", normalized: 0.5)
    #expect(!unknownNormalized)
}

@Test func normalizedRoundTripsThroughLogTransform() throws {
    var e = try ParameterEditor(schema: schema())
    e.set("scale", normalized: 0.5)
    #expect(abs(e.normalized("scale") - 0.5) < 1e-12)
    #expect(abs(e.values["scale"]! - (0.5 * 32.0.squareRoot())) < 1e-9)
    #expect(e.normalized("bogus") == 0)
}

@Test func resetToBaselineAndModifiedFlags() throws {
    var e = try ParameterEditor(schema: schema(), values: ["warp": 1.2])
    #expect(e.modifiedNames.isEmpty)
    let before = e
    e.reset("warp")
    #expect(e == before, "resetting an unchanged parameter is a no-op")
    e.set("warp", to: 0.1); e.set("scale", to: 8)
    #expect(e.modifiedNames == ["scale", "warp"])
    e.reset("warp")
    #expect(e.values["warp"] == 1.2 && !e.isModified("warp") && e.isModified("scale"))
    e.resetAll()
    #expect(e.values == e.baseline)
    try e.rebase(["scale": 10])
    #expect(e.baseline == ["scale": 10, "warp": 0.8] && e.modifiedNames.isEmpty)
    #expect(throws: ParameterError.nonFinite("warp")) { try e.rebase(["warp": .infinity]) }
}

@Test func formatting() throws {
    var e = try ParameterEditor(schema: schema())
    #expect(e.formatted("scale") == "3 ×")
    e.set("warp", to: 1.23456)
    #expect(e.formatted("warp") == "1.23")
    #expect(e.formatted("bogus") == "")
}
