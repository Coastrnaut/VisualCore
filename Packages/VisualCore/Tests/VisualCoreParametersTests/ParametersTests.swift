// ParametersTests — feature 012 T-A01-102 (FR-A01-104, FR-A01-105, FR-A01-108).
import Foundation
import Testing
@testable import VisualCoreParameters

private func def(_ name: String, _ range: ClosedRange<Double> = 0...1, _ d: Double = 0.5, _ t: ParameterTransform = .linear) throws -> ParameterDefinition {
    try ParameterDefinition(name: name, title: name, range: range, defaultValue: d, transform: t)
}

@Test func definitionValidation() throws {
    #expect(throws: ParameterError.invalidName("1bad")) { try def("1bad") }
    #expect(throws: ParameterError.invalidName(String(repeating: "a", count: 33))) { try def(String(repeating: "a", count: 33)) }
    #expect(throws: ParameterError.invalidRange("x")) { try def("x", 1...1, 1) }
    #expect(throws: ParameterError.invalidRange("x")) { try def("x", 0...10, 1, .logarithmic) }
    #expect(throws: ParameterError.defaultOutOfRange("x")) { try def("x", 0...1, 2) }
    #expect(throws: ParameterError.defaultOutOfRange("x")) { try def("x", 0...1, .nan) }
    _ = try def("zoom_2", 0.1...10, 1, .logarithmic)
}

@Test func schemaRules() throws {
    let a = try def("a"), b = try def("b", -1...1, 0)
    #expect(throws: ParameterError.duplicate("a")) { try ParameterSchema([a, a]) }
    #expect(throws: ParameterError.tooMany(65)) { try ParameterSchema((0..<65).map { try def("p\($0)") }) }
    let s = try ParameterSchema([a, b])
    let r = try s.resolve(["a": 2, "zeta": 1, "alpha": 3])
    #expect(r.values == ["a": 1, "b": 0])
    #expect(r.warnings == ["a: 2.0 clamped to 1.0", "alpha: unknown parameter dropped", "zeta: unknown parameter dropped"])
    #expect(throws: ParameterError.nonFinite("b")) { try s.resolve(["b": .infinity]) }
    #expect(throws: ParameterError.nonFinite("a")) { try s.resolve(["a": .nan]) }
    #expect(try s.resolve([:]).values == s.defaults)
}

@Test func sliderMapping() throws {
    let lin = try def("l", 0...10, 5)
    #expect(lin.normalized(2.5) == 0.25)
    #expect(lin.value(normalized: 0.25) == 2.5)
    #expect(lin.value(normalized: 2) == 10)
    let log = try def("g", 0.1...10, 1, .logarithmic)
    #expect(abs(log.normalized(1) - 0.5) < 1e-12)
    #expect(abs(log.value(normalized: 0.5) - 1) < 1e-12)
    for t in stride(from: 0.0, through: 1.0, by: 0.1) { #expect(abs(log.normalized(log.value(normalized: t)) - t) < 1e-9) }
}

@Test func paletteRules() throws {
    #expect(throws: ParameterError.invalidPalette("Bad")) { try Palette(id: "Bad", name: "x", stops: [.zero, .one]) }
    #expect(throws: ParameterError.invalidPalette("one")) { try Palette(id: "one", name: "x", stops: [.zero]) }
    #expect(throws: ParameterError.invalidPalette("hot")) { try Palette(id: "hot", name: "x", stops: [.zero, SIMD3(2, 0, 0)]) }
    let p = try Palette(id: "bw", name: "BW", stops: [.zero, .one])
    #expect(p.sample(-1) == .zero)
    #expect(p.sample(2) == .one)
    // Linear-light interpolation: midway between black and white is 0.5 linear (≈ 0.735 sRGB), not 0.5 sRGB.
    #expect(abs(p.sample(0.5).x - 0.5) < 1e-12)
    #expect(abs(Palette.sRGB(fromLinear: 0.5) - 0.7353569830524495) < 1e-12)
    for c in stride(from: 0.0, through: 1.0, by: 0.05) { #expect(abs(Palette.sRGB(fromLinear: Palette.linear(fromSRGB: c)) - c) < 1e-12) }
    #expect(Palette.builtIns.count == 6)
    #expect(Set(Palette.builtIns.map(\.id)).count == 6)
    #expect(Palette.builtIn("ocean")?.name == "Ocean")
}

@Test func codableRoundTripsRevalidate() throws {
    let d = try def("speed", 0.1...4, 1, .logarithmic)
    #expect(try JSONDecoder().decode(ParameterDefinition.self, from: JSONEncoder().encode(d)) == d)
    let p = Palette.builtIns[0]
    #expect(try JSONDecoder().decode(Palette.self, from: JSONEncoder().encode(p)) == p)
    let bad = #"{"id":"x","name":"x","stops":[[0,0,0]]}"#.data(using: .utf8)!
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Palette.self, from: bad) }
    let preset = Preset(id: "p", title: "P", seed: .max, paletteID: "ocean", values: ["speed": 2])
    let data = try JSONEncoder().encode(preset)
    #expect(String(decoding: data, as: UTF8.self).contains("\"18446744073709551615\""))
    #expect(try JSONDecoder().decode(Preset.self, from: data) == preset)
    let badSeed = #"{"id":"p","title":"P","seed":"-1","paletteID":"x","values":{}}"#.data(using: .utf8)!
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Preset.self, from: badSeed) }
}

@Test func hashStableAndSensitive() {
    let base = ParameterHash.of(scope: "noise", seed: 42, paletteID: "ocean", values: ["a": 0.5, "b": 1])
    #expect(base.count == 16)
    #expect(base == ParameterHash.of(scope: "noise", seed: 42, paletteID: "ocean", values: ["b": 1, "a": 0.5]))
    #expect(base == "\(ParameterHash.of(scope: "noise", seed: 42, paletteID: "ocean", values: ["a": 0.5, "b": 1]))")
    let variants = [ParameterHash.of(scope: "tile", seed: 42, paletteID: "ocean", values: ["a": 0.5, "b": 1]),
                    ParameterHash.of(scope: "noise", seed: 43, paletteID: "ocean", values: ["a": 0.5, "b": 1]),
                    ParameterHash.of(scope: "noise", seed: 42, paletteID: "neon", values: ["a": 0.5, "b": 1]),
                    ParameterHash.of(scope: "noise", seed: 42, paletteID: "ocean", values: ["a": 0.50001, "b": 1])]
    #expect(Set(variants + [base]).count == 5)
    // Pinned value: FNV-1a 64 of the canonical string must never change across releases (cache keys persist).
    #expect(ParameterHash.canonical(scope: "s", seed: 1, paletteID: "p", values: ["x": 0.25]) == "s|1|p|x=0.25")
    #expect(ParameterHash.of(scope: "s", seed: 1, paletteID: "p", values: ["x": 0.25]) == "78a5b4bc32dcc753")  // computed independently in Python
}
