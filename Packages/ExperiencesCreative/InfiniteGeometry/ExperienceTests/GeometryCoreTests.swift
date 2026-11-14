// GeometryCoreTests — feature 040 (A05-P01) T-A05-104 (FR-A05-120, SC-A05-103). The adapter core of Infinite Geometry
// against the experience contract, with short runs only (owner rule of 2026-11-13): conformance over four seeds, each
// valid action changing the state and the digest, each invalid one refused with the digest unchanged (an order on a
// tiling included), the snapshot round trip, a damaged payload refused, reset, steps changing nothing and the outcome.
import Foundation
import Testing
@testable import InfiniteGeometryExperience
import InfiniteGeometryCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: GeometryCore.experienceID)!

private func engine(seed: UInt64 = 7) async throws -> ExperienceEngine<GeometryCore> {
    var engine = ExperienceEngine<GeometryCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<GeometryCore>) throws -> GeometryCore {
    try #require(engine.core)
}

/// The index of the first curated preset of `kind`.
private func curatedIndex(_ kind: GeometryPreset.Kind) -> Int {
    GeometryPreset.curated.firstIndex { $0.kind == kind } ?? 0
}

/// Valid actions on curated preset 0, each with a value that differs from the preset's own.
private var tilingActions: [ScriptedAction] {
    let start = GeometryPreset.curated[0]
    return [ScriptedAction("repeats.set", [Double(start.repeats == 2 ? 3 : 2)]),
            ScriptedAction("scale.set", [start.scale == 1.5 ? 2 : 1.5]),
            ScriptedAction("palette.set", [Double((start.palette + 1) % 6)]),
            ScriptedAction("reseed")]
}

@Suite struct GeometryCoreTests {
    @Test func curatedPresetsComeInKindOrder() {
        #expect(GeometryPreset.curated.map(\.kind) == [.squareTiling, .hexTiling, .kaleidoscope, .solid])
        #expect(GeometryCore.controls.map(\.id)
                == ["preset.select", "symmetry.order", "repeats.set", "scale.set", "palette.set", "reseed"])
    }

    @Test func conformancePassesOverFourSeeds() async {
        let kaleidoscope = curatedIndex(.kaleidoscope)
        let order = GeometryPreset.curated[kaleidoscope].order == 5 ? 7 : 5
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 4,
            actions: tilingActions + [ScriptedAction("preset.select", [Double(kaleidoscope)]),
                                      ScriptedAction("symmetry.order", [Double(order)])],
            rejected: [ScriptedAction("palette.set", [9]), ScriptedAction("scale.set", [.nan]),
                       ScriptedAction("repeats.set", [1, 2]), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(GeometryCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func eachValidActionChangesTheStateAndTheDigest() async throws {
        var engine = try await engine()
        for action in tilingActions {
            let before = try engine.digest(), state = try core(engine)
            #expect(engine.handle(control: action.control, values: action.values) == .accepted, "\(action.control)")
            #expect(try engine.digest() != before, "\(action.control) changes the digest")
            #expect(try core(engine) != state, "\(action.control) changes the state")
        }
        // Every curated preset can be selected; the order changes on the kaleidoscope and the solid.
        for kind in [GeometryPreset.Kind.hexTiling, .kaleidoscope, .solid] {
            let index = curatedIndex(kind)
            let before = try engine.digest()
            #expect(engine.handle(control: "preset.select", values: [Double(index)]) == .accepted, "\(kind)")
            #expect(try core(engine).presetIndex == index && core(engine).preset.kind == kind)
            #expect(try engine.digest() != before)
            guard kind != .hexTiling else { continue }
            let order = try core(engine).preset.order == 4 ? 5 : 4
            let ordered = try engine.digest()
            #expect(engine.handle(control: "symmetry.order", values: [Double(order)]) == .accepted, "order on \(kind)")
            #expect(try core(engine).preset.order == order)
            #expect(try engine.digest() != ordered)
        }
        let seed = try core(engine).preset.seed
        #expect(engine.handle(control: "reseed") == .accepted)
        #expect(try core(engine).preset.seed == seed &+ GeometryCore.seedStep, "reseed adds the fixed step")
    }

    @Test func eachInvalidActionIsRefusedWithTheDigestUnchanged() async throws {
        var engine = try await engine()
        let tiling = try core(engine).preset
        #expect(!tiling.usesOrder)
        let cases: [(String, [Double], ActionResult)] = [
            ("symmetry.order", [6], .rejected(.rule(code: "a05.order-fixed-by-lattice"))),
            ("preset.select", [0], .rejected(.rule(code: GeometryCore.unchangedCode))),
            ("repeats.set", [Double(tiling.repeats)], .rejected(.rule(code: GeometryCore.unchangedCode))),
            ("palette.set", [9], .rejected(.outOfRange(index: 0))),
            ("preset.select", [4], .rejected(.outOfRange(index: 0))),
            ("symmetry.order", [25], .rejected(.outOfRange(index: 0))),
            ("repeats.set", [0], .rejected(.outOfRange(index: 0))),
            ("scale.set", [4.5], .rejected(.outOfRange(index: 0))),
            ("scale.set", [.infinity], .rejected(.nonFinite(index: 0))),
            ("reseed", [1], .rejected(.wrongValueCount(expected: 0, found: 1))),
            ("bogus", [], .rejected(.unknownControl("bogus"))),
        ]
        let digest = try engine.digest(), state = try core(engine)
        for (control, values, expected) in cases {
            #expect(engine.handle(control: control, values: values) == expected, "\(control) \(values)")
            #expect(try engine.digest() == digest, "\(control) keeps the digest")
        }
        #expect(try core(engine) == state)
        // The order is refused on the hexagonal tiling as well.
        #expect(engine.handle(control: "preset.select", values: [Double(curatedIndex(.hexTiling))]) == .accepted)
        let hex = try engine.digest()
        #expect(engine.handle(control: "symmetry.order", values: [8])
                == .rejected(.rule(code: GeometryCore.orderFixedCode)))
        #expect(try engine.digest() == hex)
    }

    @Test func theSnapshotRoundTripsToTheSameDigest() async throws {
        var engine = try await engine(seed: 11)
        for action in tilingActions + [ScriptedAction("preset.select", [Double(curatedIndex(.solid))])] {
            #expect(engine.handle(control: action.control, values: action.values) == .accepted, "\(action.control)")
        }
        let digest = try engine.digest()
        let snapshot = try engine.snapshot()
        var restored = ExperienceEngine<GeometryCore>(id: id)
        try await restored.prepare(seed: 11)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        #expect(try restored.digest() == digest)
        #expect(try core(restored) == core(engine))
        // The payload itself decodes to an equal core.
        let state = try core(engine)
        #expect(try GeometryCore.restore(payload: try state.snapshotPayload(), seed: 11) == state)
    }

    @Test func aDamagedPayloadIsRefused() async throws {
        let state = try core(try await engine())
        var object = try #require(try JSONSerialization.jsonObject(with: state.snapshotPayload()) as? [String: Any])
        object["presetIndex"] = 99
        let damaged = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try GeometryCore.restore(payload: damaged, seed: 7) }
    }

    @Test func resetReturnsToThePreparedState() async throws {
        var engine = try await engine()
        let initial = try engine.digest()
        for action in tilingActions {
            #expect(engine.handle(control: action.control, values: action.values) == .accepted)
        }
        #expect(try engine.digest() != initial)
        try engine.reset()
        #expect(try engine.digest() == initial)
        #expect(try core(engine).presetIndex == 0 && core(engine).preset.seed == 7)
    }

    @Test func stepsChangeNothing() async throws {
        var engine = try await engine()
        let digest = try engine.digest()
        try engine.run(steps: 120)
        #expect(try engine.digest() == digest, "a composition is static")
    }

    @Test func theOutcomeIsCompositionBuilt() async throws {
        var engine = try await engine()
        #expect(engine.outcome?.code == "composition-built", "after the preparation")
        #expect(engine.handle(control: "preset.select", values: [Double(curatedIndex(.solid))]) == .accepted)
        #expect(engine.outcome?.code == "composition-built", "after an accepted change")
        #expect(engine.handle(control: "bogus", values: []) != .accepted)
        #expect(engine.outcome?.code == "composition-built", "a refusal keeps it")
        #expect(try core(engine).elementCount > 0)
    }
}
