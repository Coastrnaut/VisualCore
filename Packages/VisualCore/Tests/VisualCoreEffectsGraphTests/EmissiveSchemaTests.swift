// EmissiveSchemaTests — feature 207 R02-F07 T-R02F07-003 (FR-R02F07-003, -004, -005): the emissive schema's
// defaults and ranges, refusal of non-finite and out-of-range values, composite mode 2, flashLimit `linear`, the
// memory estimate with two blur targets, and the feature 005 schemas otherwise unchanged.
import Testing
@testable import VisualCoreEffectsGraph

private func emissive(_ params: [String: [Double]] = [:], scale: Double = 1) -> EffectGraphDescription {
    EffectGraphDescription(version: 1, passes: [
        EffectPassDescription(id: "E", type: "emissive", inputs: ["input": "scene"], output: "e", scale: scale, params: params),
    ], output: "e")
}

@Test func emissiveSchemaDeclaresDefaultsAndRanges() throws {
    let s = try #require(PassSchemas.schema(for: "emissive"))
    #expect(s.inputs == ["input"])
    #expect(s.refusesOutOfRange)
    let want: [String: ParameterSpec] = [
        "threshold": ParameterSpec([1], 0...16), "knee": ParameterSpec([0.5], 0...1),
        "intensity": ParameterSpec([1], 0...4), "radius": ParameterSpec([4], 1...16),
        "quality": ParameterSpec([0], 0...1), "exposure": ParameterSpec([0], -4...4),
        "tonemap": ParameterSpec([0], 0...2)]
    #expect(s.parameters == want)
    let v = try EffectGraphValidator.validate(emissive(), width: 64, height: 64)
    #expect(v.parameters["E"] == want.mapValues(\.defaultValue))
    #expect(v.warnings.isEmpty)
}

@Test func validatorRefusesOutOfRangeEmissiveParameters() {
    let cases: [(String, Double)] = [("threshold", 16.5), ("threshold", -0.1), ("knee", 1.01), ("intensity", 5),
                                     ("radius", 0.5), ("quality", 2), ("exposure", -4.5), ("tonemap", 3)]
    for (key, value) in cases {
        #expect(throws: EffectGraphError.parameterOutOfRange(pass: "E", parameter: key, value: value)) {
            try EffectGraphValidator.validate(emissive([key: [value]]), width: 64, height: 64)
        }
    }
    // Bounds themselves are accepted.
    #expect(throws: Never.self) {
        try EffectGraphValidator.validate(emissive(["threshold": [16], "exposure": [-4], "tonemap": [2]]), width: 64, height: 64)
    }
}

@Test func validatorRefusesNonFiniteParameters() {
    for value in [Double.nan, .infinity, -.infinity] {
        #expect(throws: EffectGraphError.nonFiniteParameter(pass: "E", parameter: "intensity")) {
            try EffectGraphValidator.validate(emissive(["intensity": [value]]), width: 64, height: 64)
        }
    }
    let blur = EffectGraphDescription(version: 1, passes: [
        EffectPassDescription(id: "B", type: "blur", inputs: ["input": "scene"], output: "b", params: ["radius": [.nan]]),
    ], output: "b")
    #expect(throws: EffectGraphError.nonFiniteParameter(pass: "B", parameter: "radius")) {
        try EffectGraphValidator.validate(blur, width: 64, height: 64)
    }
}

@Test func compositeModeTwoIsAcceptedAndThreeClamps() throws {
    func composite(_ mode: Double) -> EffectGraphDescription {
        EffectGraphDescription(version: 1, passes: [
            EffectPassDescription(id: "M", type: "composite", inputs: ["base": "scene", "overlay": "scene"], output: "m",
                                  params: ["mode": [mode]]),
        ], output: "m")
    }
    #expect(PassSchemas.all["composite"]?.parameters["mode"] == ParameterSpec([0], 0...2))
    #expect(try EffectGraphValidator.validate(composite(2), width: 8, height: 8).parameters["M"]?["mode"] == [2])
    // Feature 005 passes keep clamping: mode 3 is outside 0…2 and resolves to 2, never to a new mode.
    #expect(try EffectGraphValidator.validate(composite(3), width: 8, height: 8).parameters["M"]?["mode"] == [2])
}

@Test func flashLimitAcceptsLinear() throws {
    #expect(PassSchemas.all["flashLimit"]?.parameters["linear"] == ParameterSpec([0], 0...1))
    let g = EffectGraphDescription(version: 1, passes: [
        EffectPassDescription(id: "L", type: "flashLimit", inputs: ["input": "scene"], output: "l", params: ["linear": [1]]),
    ], output: "l")
    let v = try EffectGraphValidator.validate(g, width: 8, height: 8)
    #expect(v.parameters["L"] == ["limit": [0.3], "linear": [1]])
    #expect(v.warnings.isEmpty)
}

@Test func emissiveEstimateCountsOutputAndTwoBlurTargets() throws {
    let half = try EffectGraphValidator.validate(emissive(), width: 512, height: 512)
    #expect(half.estimatedBytes == 512 * 512 * 4 + 2 * 256 * 256 * 8)
    let quarter = try EffectGraphValidator.validate(emissive(["quality": [1]]), width: 512, height: 512)
    #expect(quarter.estimatedBytes == 512 * 512 * 4 + 2 * 128 * 128 * 8)
    // Each blur side is max(1, side / divisor), rounded down: 3 × 1 at quarter quality has 1 × 1 blur targets.
    let tiny = try EffectGraphValidator.validate(emissive(["quality": [1]]), width: 3, height: 1)
    #expect(tiny.estimatedBytes == 3 * 1 * 4 + 2 * 1 * 1 * 8)
    // The pass's scale sizes the output first: 0.5 of 512² is 256², blur targets 128² at half quality.
    let scaled = try EffectGraphValidator.validate(emissive(scale: 0.5), width: 512, height: 512)
    #expect(scaled.estimatedBytes == 256 * 256 * 4 + 2 * 128 * 128 * 8)
    #expect(throws: EffectGraphError.overQuota(bytes: 512 * 512 * 4 + 2 * 256 * 256 * 8, quota: 1_000_000)) {
        try EffectGraphValidator.validate(emissive(), width: 512, height: 512, quotaBytes: 1_000_000)
    }
}

@Test func featureFiveSchemasAreOtherwiseUnchanged() {
    let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    let snapshot: [String: [String: ParameterSpec]] = [
        "copy": [:],
        "colorMatrix": ["matrix": ParameterSpec(identity, -10...10), "offset": ParameterSpec([0, 0, 0, 0], -1...1)],
        "blur": ["radius": ParameterSpec([4], 1...32)],
        "bloom": ["threshold": ParameterSpec([0.8], 0...1), "intensity": ParameterSpec([1], 0...4),
                  "radius": ParameterSpec([8], 1...32), "hdr": ParameterSpec([0], 0...1)],
        "distort": ["strength": ParameterSpec([0.02], 0...0.2), "frequency": ParameterSpec([8], 0...64),
                    "speed": ParameterSpec([1], 0...10)],
        "composite": ["mode": ParameterSpec([0], 0...2), "opacity": ParameterSpec([1], 0...1)],
        "feedback": ["decay": ParameterSpec([0.9], 0...1)],
        "flashLimit": ["limit": ParameterSpec([0.3], 0.05...1), "linear": ParameterSpec([0], 0...1)],
    ]
    #expect(Set(PassSchemas.all.keys) == Set(snapshot.keys).union(["emissive"]))
    for (type, params) in snapshot {
        #expect(PassSchemas.all[type]?.parameters == params, "\(type)")
        #expect(PassSchemas.all[type]?.refusesOutOfRange == false, "\(type)")
    }
    #expect(PassSchemas.all["composite"]?.inputs == ["base", "overlay"])
    // Bloom's estimate is unchanged: 8 B/px with hdr, 4 B/px without, no extra targets.
    let bloom = EffectGraphDescription(version: 1, passes: [
        EffectPassDescription(id: "G", type: "bloom", inputs: ["input": "scene"], output: "g", params: ["hdr": [1]]),
    ], output: "g")
    #expect(try! EffectGraphValidator.validate(bloom, width: 100, height: 100).estimatedBytes == 80_000)
}
