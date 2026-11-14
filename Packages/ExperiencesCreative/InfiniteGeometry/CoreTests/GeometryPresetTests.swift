// GeometryPresetTests.swift — feature 040 (A05-P01) T-A05-103 (FR-A05-110, FR-A05-111).
import Foundation
import Testing
@testable import InfiniteGeometryCore

@Test func schemaVersionIsOne() {
    #expect(InfiniteGeometryCore.schemaVersion == 1)
}

@Test func curatedPresetsCoverEveryKindAndAreValid() throws {
    #expect(GeometryPreset.curated.map(\.kind) == GeometryPreset.Kind.allCases)
    for preset in GeometryPreset.curated {
        #expect(try preset.validated() == preset)
        #expect(preset.schemaVersion == 1)
    }
}

@Test func usesOrderOnlyForKaleidoscopeAndSolid() {
    let using = GeometryPreset.Kind.allCases.filter {
        GeometryPreset(kind: $0, order: 3, repeats: 1, scale: 1, palette: 0, seed: 0).usesOrder
    }
    #expect(using == [.kaleidoscope, .solid])
}

@Test func everyBoundIsRefusedWithItsCode() {
    let base = GeometryPreset.curated[2]
    let cases: [(String, (inout GeometryPreset) -> Void)] = [
        ("order", { $0.order = 0 }), ("order", { $0.order = 25 }),
        ("repeats", { $0.repeats = 0 }), ("repeats", { $0.repeats = 13 }),
        ("scale", { $0.scale = 0.2499 }), ("scale", { $0.scale = 4.0001 }),
        ("palette", { $0.palette = -1 }), ("palette", { $0.palette = 6 }),
    ]
    for (field, change) in cases {
        var preset = base
        change(&preset)
        let refused = preset
        #expect(throws: PresetError.outOfRange(field)) { try refused.validated() }
        #expect(PresetError.outOfRange(field).code == "a05.out-of-range")
    }
    // The bounds themselves are accepted.
    for (order, repeats, scale, palette) in [(1, 1, 0.25, 0), (24, 12, 4.0, 5)] {
        var preset = base
        preset.order = order; preset.repeats = repeats; preset.scale = scale; preset.palette = palette
        let accepted = preset
        #expect(throws: Never.self) { try accepted.validated() }
    }
}

@Test func nonFiniteScaleAndOtherVersionsAreRefused() {
    for value in [Double.nan, .infinity, -.infinity] {
        var preset = GeometryPreset.curated[0]
        preset.scale = value
        let refused = preset
        #expect(throws: PresetError.notFinite("scale")) { try refused.validated() }
    }
    var newer = GeometryPreset.curated[0]
    newer.schemaVersion = 2
    let refused = newer
    #expect(throws: PresetError.unsupportedVersion(2)) { try refused.validated() }
    #expect(PresetError.notFinite("scale").code == "a05.not-finite")
    #expect(PresetError.unsupportedVersion(2).code == "a05.unsupported-version")
}

@Test func presetsRoundTripThroughJSON() throws {
    for preset in GeometryPreset.curated {
        let data = try JSONEncoder().encode(preset)
        #expect(try JSONDecoder().decode(GeometryPreset.self, from: data) == preset)
    }
}
