// GeometryCameraTests — feature 041 (A05-P02) T-A05-206 (FR-A05-210, FR-A05-211, FR-A05-213; SC-A05-203). The camera
// of Infinite Geometry through the engine, with short runs only (owner rule of 2026-11-13): each camera action stays
// within its bounds (2D zoom 0.5…8, centre within ±1/scale; pitch ±80°, distance 3…12), 200 seeded random action
// sequences never leave them, invalid actions are refused with the digest unchanged, reset restores the default
// exactly, the camera is part of the digest and the snapshot, a preset selection resets it, and a schema-1 snapshot
// written as Phase 01 wrote it (no camera) restores with the default cameras through the migration chain. Host tests.
// Feature 042 (A05-P03): schema 3; a pan on the solid moves the orbit target (GeometryOrbitViewTests), the field of
// view is refused on a plane, and the nearest distance follows the bounding-sphere rule.
import Foundation
import Testing
@testable import InfiniteGeometryExperience
import InfiniteGeometryCore
import VisualCoreExperience
import VisualCoreSimulation

private let id = ExperienceID(rawValue: GeometryCore.experienceID)!

private func engine(seed: UInt64 = 7, preset kind: GeometryPreset.Kind? = nil) async throws
    -> ExperienceEngine<GeometryCore> {
    var engine = ExperienceEngine<GeometryCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    if let kind, let index = GeometryPreset.curated.firstIndex(where: { $0.kind == kind }), index != 0 {
        #expect(engine.handle(control: "preset.select", values: [Double(index)]) == .accepted)
    }
    return engine
}

private func core(_ engine: ExperienceEngine<GeometryCore>) throws -> GeometryCore {
    try #require(engine.core)
}

/// Whether the cameras of `core` lie within their bounds.
private func withinBounds(_ core: GeometryCore) -> Bool {
    let v = core.view2D, o = core.orbit3D, extent = 1 / core.preset.scale
    let pitchLimit = 80 * Double.pi / 180
    return GeometryCore.zoomRange.contains(v.zoom) && abs(v.centerX) <= extent && abs(v.centerY) <= extent
        && abs(o.pitch) <= pitchLimit + 1e-12 && (3.0...12.0).contains(o.distance)
        && abs(o.yaw) <= Double.pi + 1e-12
}

@Suite struct GeometryCameraTests {
    @Test func theDefaultsAreThePresetCameras() async throws {
        let state = try core(try await engine())
        #expect(state.view2D == GeometryCore.View2D(centerX: 0, centerY: 0, zoom: 1))
        #expect(state.orbit3D == GeometryCore.Orbit3D(yaw: 0, pitch: 0.5, distance: 6))
        #expect(GeometryCore.migrations.currentVersion == 3)
    }

    @Test func panAndZoomStopAtTheBoundsOnAPlane() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "camera.pan", values: [0.25, -0.5]) == .accepted)
        #expect(try core(engine).view2D.centerX == 0.25 && core(engine).view2D.centerY == -0.5)
        #expect(engine.handle(control: "camera.pan", values: [8, -8]) == .accepted)
        #expect(try core(engine).view2D.centerX == 1 && core(engine).view2D.centerY == -1, "extent 1/scale = 1")
        #expect(engine.handle(control: "camera.pan", values: [1, -1]) == .rejected(.rule(code: GeometryCore.unchangedCode)))
        #expect(engine.handle(control: "camera.zoom", values: [100]) == .accepted)
        #expect(try core(engine).view2D.zoom == 8)
        #expect(engine.handle(control: "camera.zoom", values: [2]) == .rejected(.rule(code: GeometryCore.unchangedCode)))
        #expect(engine.handle(control: "camera.zoom", values: [0.01]) == .accepted)
        #expect(try core(engine).view2D.zoom == 0.5)
        // A larger scale shrinks the extent and clamps the centre into it.
        #expect(engine.handle(control: "scale.set", values: [2]) == .accepted)
        #expect(try core(engine).view2D.centerX == 0.5 && core(engine).view2D.centerY == -0.5)
        #expect(try withinBounds(core(engine)))
    }

    @Test func orbitAndDistanceStopAtTheBoundsOnTheSolid() async throws {
        var engine = try await engine(preset: .solid)
        #expect(engine.handle(control: "camera.orbit", values: [0.5, 0.25]) == .accepted)
        #expect(try abs(core(engine).orbit3D.yaw - 0.5) < 1e-12 && abs(core(engine).orbit3D.pitch - 0.75) < 1e-12)
        #expect(engine.handle(control: "camera.orbit", values: [0, 6]) == .accepted)
        #expect(try core(engine).orbit3D.pitch == 80 * Double.pi / 180, "pitch stops at +80°, never flips")
        #expect(engine.handle(control: "camera.orbit", values: [0, -6]) == .accepted)
        #expect(try core(engine).orbit3D.pitch == -80 * Double.pi / 180)
        #expect(engine.handle(control: "camera.zoom", values: [100]) == .accepted)
        // The nearest distance is the larger of 3 and the bounding-sphere rule |target| + R + 2 · near (A05-P03).
        let state = try core(engine)
        let nearest = max(3, state.orbit3D.target.length + state.boundingRadius + 2 * state.orbit3D.camera.near)
        #expect(abs(state.orbit3D.distance - nearest) < 1e-9)
        #expect(engine.handle(control: "camera.zoom", values: [0.01]) == .accepted)
        #expect(try core(engine).orbit3D.distance == 12)
        for _ in 0..<5 { _ = engine.handle(control: "camera.orbit", values: [6, 0]) }
        #expect(try withinBounds(core(engine)), "yaw stays wrapped into −π…π")
    }

    @Test func invalidCameraActionsAreRefusedWithTheDigestUnchanged() async throws {
        var plane = try await engine()
        var solid = try await engine(preset: .solid)
        let planeCases: [(String, [Double], ActionResult)] = [
            ("camera.zoom", [0], .rejected(.outOfRange(index: 0))),
            ("camera.zoom", [-2], .rejected(.outOfRange(index: 0))),
            ("camera.zoom", [.nan], .rejected(.nonFinite(index: 0))),
            ("camera.zoom", [.infinity], .rejected(.nonFinite(index: 0))),
            ("camera.pan", [1], .rejected(.wrongValueCount(expected: 2, found: 1))),
            ("camera.pan", [.nan, 0], .rejected(.nonFinite(index: 0))),
            ("camera.pan", [0, 9], .rejected(.outOfRange(index: 1))),
            ("camera.orbit", [0.1, 0.1], .rejected(.rule(code: GeometryCore.orbitSolidOnlyCode))),
            ("camera.fov", [45], .rejected(.rule(code: GeometryCore.fovSolidOnlyCode))),
            ("camera.reset", [], .rejected(.rule(code: GeometryCore.unchangedCode))),
            ("camera.reset", [1], .rejected(.wrongValueCount(expected: 0, found: 1))),
            ("camera.bogus", [], .rejected(.unknownControl("camera.bogus"))),
        ]
        let solidCases: [(String, [Double], ActionResult)] = [
            ("camera.fov", [80], .rejected(.outOfRange(index: 0))),
            ("camera.orbit", [.infinity, 0], .rejected(.nonFinite(index: 0))),
            ("camera.orbit", [0, 7], .rejected(.outOfRange(index: 1))),
            ("camera.zoom", [0], .rejected(.outOfRange(index: 0))),
        ]
        func check(_ engine: inout ExperienceEngine<GeometryCore>, _ cases: [(String, [Double], ActionResult)]) throws {
            let digest = try engine.digest(), state = try core(engine)
            for (control, values, expected) in cases {
                #expect(engine.handle(control: control, values: values) == expected, "\(control) \(values)")
                #expect(try engine.digest() == digest, "\(control) keeps the digest")
            }
            #expect(try core(engine) == state)
        }
        try check(&plane, planeCases)
        try check(&solid, solidCases)
    }

    @Test func resetRestoresTheDefaultExactlyAndTheCameraIsInTheDigest() async throws {
        var plane = try await engine()
        let initial = try plane.digest()
        #expect(plane.handle(control: "camera.pan", values: [0.3, 0.1]) == .accepted)
        let panned = try plane.digest()
        #expect(panned != initial, "the centre is in the digest")
        #expect(plane.handle(control: "camera.zoom", values: [1.5]) == .accepted)
        #expect(try plane.digest() != panned, "the zoom is in the digest")
        #expect(plane.handle(control: "camera.reset") == .accepted)
        #expect(try core(plane).view2D == .default && core(plane).orbit3D == .default)
        #expect(try plane.digest() == initial)

        var solid = try await engine(preset: .solid)
        let start = try solid.digest()
        #expect(solid.handle(control: "camera.orbit", values: [1, -0.3]) == .accepted)
        #expect(try solid.digest() != start, "the orbit is in the digest")
        #expect(solid.handle(control: "camera.zoom", values: [0.5]) == .accepted)
        #expect(solid.handle(control: "camera.reset") == .accepted)
        #expect(try core(solid).orbit3D == .default)
        #expect(try solid.digest() == start)
        // Selecting a preset starts from its default cameras.
        #expect(solid.handle(control: "camera.orbit", values: [1, 0.2]) == .accepted)
        #expect(solid.handle(control: "preset.select", values: [0]) == .accepted)
        #expect(try core(solid).view2D == .default && core(solid).orbit3D == .default)
    }

    /// SC-A05-203: 200 seeded random sequences of camera and preset actions; after every action both cameras are
    /// within their bounds, and a final reset restores the defaults exactly.
    @Test func twoHundredRandomSequencesStayWithinTheBounds() async throws {
        var rng = SeededRandom(seed: 0xA05_0203)
        let controls = ["camera.pan", "camera.zoom", "camera.orbit", "camera.reset", "preset.select", "scale.set"]
        let initial = try core(try await engine())
        for sequence in 0..<200 {
            var engine = try await engine()
            for _ in 0..<12 {
                let control = controls[rng.int(0...(controls.count - 1))]
                let values: [Double]
                switch control {
                case "camera.pan": values = [rng.range(-8...8), rng.range(-8...8)]
                case "camera.zoom": values = [rng.range(0.01...100)]
                case "camera.orbit": values = [rng.range(-6...6), rng.range(-6...6)]
                case "preset.select": values = [Double(rng.int(0...(GeometryPreset.curated.count - 1)))]
                case "scale.set": values = [rng.range(GeometryPreset.scaleRange)]
                default: values = []
                }
                _ = engine.handle(control: control, values: values)
                let state = try core(engine)
                #expect(withinBounds(state), "sequence \(sequence) after \(control) \(values)")
            }
            _ = engine.handle(control: "camera.reset")
            #expect(try core(engine).view2D == .default && core(engine).orbit3D == .default, "sequence \(sequence)")
            try engine.reset()
            #expect(try core(engine) == initial, "sequence \(sequence): reset returns to the preparation")
        }
    }

    @Test func theCameraRoundTripsThroughTheSnapshot() async throws {
        var engine = try await engine(seed: 11, preset: .solid)
        #expect(engine.handle(control: "camera.orbit", values: [0.7, -0.2]) == .accepted)
        #expect(engine.handle(control: "camera.zoom", values: [1.3]) == .accepted)
        let snapshot = try engine.snapshot()
        #expect(snapshot.schemaVersion == 3)
        var restored = ExperienceEngine<GeometryCore>(id: id)
        try await restored.prepare(seed: 11)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        #expect(try restored.digest() == engine.digest())
        #expect(try core(restored).orbit3D == core(engine).orbit3D)
        // A payload whose camera lies outside its bounds is refused.
        var object = try #require(try JSONSerialization.jsonObject(with: core(engine).snapshotPayload()) as? [String: Any])
        object["orbit3D"] = ["yaw": 0.0, "pitch": 1.5, "distance": 6.0]
        let damaged = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try GeometryCore.restore(payload: damaged, seed: 11) }
    }

    /// FR-A05-213: a snapshot of schema 1, encoded as the Phase 01 code wrote it (seed, preset index and preset, no
    /// camera), restores through the migration chain with the preset's default cameras.
    @Test func aSchemaOneSnapshotRestoresWithTheDefaultCameras() async throws {
        let kaleidoscope = try #require(GeometryPreset.curated.firstIndex { $0.kind == .kaleidoscope })
        var preset = GeometryPreset.curated[kaleidoscope]
        preset.seed = 7
        preset.order = 5
        let presetObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preset))
        let payload: [String: Any] = ["seed": UInt64(7), "presetIndex": kaleidoscope, "preset": presetObject]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        #expect(String(decoding: data, as: UTF8.self).contains("view2D") == false)
        let anyDigest = try (try await engine()).digest()
        let snapshot = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: 7, stepIndex: 0,
                                              digest: anyDigest, payload: data)
        var restored = try await engine()
        #expect(restored.handle(control: "camera.pan", values: [0.5, 0.5]) == .accepted)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        let state = try core(restored)
        #expect(state.preset == preset && state.presetIndex == kaleidoscope)
        #expect(state.view2D == .default && state.orbit3D == .default)
        // The stored examples for the registry's migration check (one per earlier schema) restore to their digests.
        let examples = [try #require(GeometryCore.schemaOneExample()), try #require(GeometryCore.schemaTwoExample())]
        let problems = await SnapshotMigrationCheck.problems(for: GeometryCore.self, id: id, examples: examples)
        #expect(problems.isEmpty, "\(problems)")
    }
}
