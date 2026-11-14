// GeometryDocumentTests — feature 043 (A05-P04) T-A05-402 (FR-A05-401, FR-A05-402; contracts/api.md). The saved
// composition and the atomic `composition.open`, short runs only (owner rule of 2026-11-13): for every curated preset
// kind a document taken after preset and camera changes opens on a fresh and on a changed state with the digest of the
// original; a wrong count, a non-finite value, a fractional order, an out-of-range palette or seed half, a kind that is
// not the named preset's and a camera outside the built composition's bounds are refused with the digest unchanged;
// reopening the same state is refused as unchanged; the 18-value layout (seed halves exact); the Codable round trip;
// name cleaning. Host tests; the action is applied to the core directly.
import Foundation
import Testing
@testable import InfiniteGeometryExperience
import InfiniteGeometryCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: GeometryCore.experienceID)!

private func prepared(seed: UInt64 = 7) async throws -> ExperienceEngine<GeometryCore> {
    var engine = ExperienceEngine<GeometryCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

/// The digest of `core` as the engine computes it (the experience id as domain).
private func digest(_ core: GeometryCore) throws -> StateDigest {
    var builder = DigestBuilder(domain: id.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish()
}

/// Applies `composition.open` with `values` to `core`.
private func open(_ core: inout GeometryCore, _ values: [Double]) -> ActionResult {
    core.apply(ExperienceAction(control: "composition.open", values: values, step: 0))
}

/// Preset and camera changes that move every part of the state of `kind` away from its defaults.
private func changes(for kind: GeometryPreset.Kind) -> [(String, [Double])] {
    let preset: [(String, [Double])] = [("reseed", []), ("palette.set", [5]), ("repeats.set", [2])]
    switch kind {
    case .solid:
        return preset + [("camera.orbit", [0.3, 0.1]), ("camera.pan", [0.1, 0.05]), ("camera.fov", [45]),
                         ("camera.zoom", [0.9])]
    default:
        return preset + [("scale.set", [1.5]), ("camera.pan", [0.1, -0.05]), ("camera.zoom", [1.5])]
    }
}

/// An engine on the curated preset of `kind` with `changes(for:)` applied.
private func changedEngine(_ kind: GeometryPreset.Kind) async throws -> ExperienceEngine<GeometryCore> {
    var engine = try await prepared()
    let index = try #require(GeometryPreset.curated.firstIndex { $0.kind == kind })
    if index != 0 { #expect(engine.handle(control: "preset.select", values: [Double(index)]) == .accepted) }
    for (control, values) in changes(for: kind) {
        #expect(engine.handle(control: control, values: values) == .accepted, "\(control) on \(kind)")
    }
    return engine
}

/// The core of `changedEngine(kind)`.
private func changedCore(_ kind: GeometryPreset.Kind) async throws -> GeometryCore {
    let engine = try await changedEngine(kind)
    return try #require(engine.core)
}

/// The core of a fresh preparation with seed 7.
private func freshCore() async throws -> GeometryCore {
    let engine = try await prepared()
    return try #require(engine.core)
}

@Suite struct GeometryDocumentTests {
    @Test func everyKindReopensWithTheOriginalDigest() async throws {
        let fresh = try await freshCore()
        for kind in GeometryPreset.Kind.allCases {
            let original = try await changedCore(kind)
            let document = GeometryDocument(core: original, name: "Saved \(kind)")
            #expect(document.version == 1 && document.presetIndex == original.presetIndex)
            #expect(document.preset == original.preset && document.view2D == original.view2D
                    && document.orbit3D == original.orbit3D)
            // A changed state of another kind as the second target.
            let other: GeometryPreset.Kind = kind == .solid ? .hexTiling : .solid
            let changed = try await changedCore(other)
            for start in [fresh, changed] {
                var target = start
                #expect(open(&target, document.openValues) == .accepted, "open \(kind)")
                #expect(try digest(target) == digest(original), "digest after opening \(kind)")
                #expect(target.compositionDigest == original.compositionDigest)
                #expect(open(&target, document.openValues) == .rejected(.rule(code: GeometryCore.unchangedCode)))
                #expect(try digest(target) == digest(original))
            }
        }
    }

    @Test func invalidValuesAreRefusedWithTheDigestUnchanged() async throws {
        let base = try await changedCore(.kaleidoscope)
        let values = GeometryDocument(core: try await changedCore(.solid), name: "").openValues
        func with(_ index: Int, _ value: Double) -> [Double] {
            var copy = values
            copy[index] = value
            return copy
        }
        let cases: [([Double], ActionResult)] = [
            (Array(values.prefix(17)), .rejected(.wrongValueCount(expected: 18, found: 17))),
            (values + [0], .rejected(.wrongValueCount(expected: 18, found: 19))),
            ([], .rejected(.wrongValueCount(expected: 18, found: 0))),
            (with(4, .nan), .rejected(.nonFinite(index: 4))),
            (with(12, .infinity), .rejected(.nonFinite(index: 12))),
            (with(2, 4.5), .rejected(.outOfRange(index: 2))),
            (with(2, 25), .rejected(.outOfRange(index: 2))),
            (with(5, 9), .rejected(.outOfRange(index: 5))),
            (with(0, 4), .rejected(.outOfRange(index: 0))),
            (with(1, 4), .rejected(.outOfRange(index: 1))),
            (with(6, 4_294_967_296), .rejected(.outOfRange(index: 6))),
            (with(7, -1), .rejected(.outOfRange(index: 7))),
            (with(17, 80), .rejected(.outOfRange(index: 17))),
            // The solid's preset index with a tiling's kind.
            (with(1, 0), .rejected(.rule(code: GeometryCore.openOutOfBoundsCode))),
            // A target y of 1 with the panned x and z lies beyond the target radius 1.
            (with(15, 1), .rejected(.rule(code: GeometryCore.openOutOfBoundsCode))),
        ]
        let before = try digest(base)
        for (candidate, expected) in cases {
            var target = base
            #expect(open(&target, candidate) == expected, "\(candidate)")
            #expect(try digest(target) == before)
            #expect(GeometryDocument(openValues: candidate, name: "") == nil || expected == .rejected(
                .rule(code: GeometryCore.openOutOfBoundsCode)))
        }
    }

    @Test func aPlaneCameraOutsideTheBuiltExtentIsARule() async throws {
        let base = try await freshCore()
        var document = GeometryDocument(core: try await changedCore(.squareTiling), name: "")
        document.view2D.centerX = 3          // the extent at scale 1.5 is ±2/3; ±4 is only the coarse range
        var target = base
        #expect(open(&target, document.openValues) == .rejected(.rule(code: GeometryCore.openOutOfBoundsCode)))
        #expect(try digest(target) == digest(base))
    }

    @Test func theOpenLayoutCarriesEveryValueExactly() throws {
        var document = GeometryDocument(core: try GeometryCore(seed: 7), name: "Layout")
        document.preset.seed = 0xFFFF_FFFF_0000_0001
        document.view2D = GeometryCore.View2D(centerX: 0.125, centerY: -0.3, zoom: 2.5)
        let values = document.openValues
        #expect(values.count == GeometryDocument.openValueCount)
        #expect(values[6] == Double(UInt32.max) && values[7] == 1, "the seed in two exact 32-bit halves")
        #expect(values[1] == 0, "kind index of squareTiling")
        #expect(values[8] == 0.125 && values[9] == -0.3 && values[10] == 2.5)
        #expect(GeometryDocument(openValues: values, name: "Layout") == document)
        #expect(GeometryDocument(openValues: values, name: "  ")?.name == GeometryDocument.untitledName)
    }

    @Test func theDocumentSurvivesACodableRoundTrip() throws {
        var core = try GeometryCore(seed: 0xDEAD_BEEF_CAFE_F00D)
        #expect(core.apply(ExperienceAction(control: "preset.select", values: [3], step: 0)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "camera.fov", values: [40], step: 0)) == .accepted)
        let document = GeometryDocument(core: core, name: "Round trip")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        #expect(try JSONDecoder().decode(GeometryDocument.self, from: data) == document)
        #expect(try encoder.encode(JSONDecoder().decode(GeometryDocument.self, from: data)) == data)
    }

    @Test func namesAreTrimmedCutAndNeverEmpty() {
        #expect(GeometryDocument.clean("  Spiral \n") == "Spiral")
        #expect(GeometryDocument.clean("") == "Untitled")
        #expect(GeometryDocument.clean(" \t\n ") == "Untitled")
        #expect(GeometryDocument.clean(String(repeating: "a", count: 80)) == String(repeating: "a", count: 60))
        #expect(GeometryDocument.clean(String(repeating: "é", count: 61)).count == 60)
        #expect(GeometryDocument.clean("Name 2") == "Name 2")
    }
}
