// GeometryOrbitViewTests — feature 042 (A05-P03) T-A05-305, T-A05-306 (FR-A05-310–315; SC-A05-304). The orbit view of
// the 3D composition through the engine, short runs only (owner rule of 2026-11-13): a pan moves the target along the
// camera's right and up vectors and stops at |target| = 1; the field of view is accepted at 30° and 75° and refused
// beyond or when not finite; after a pan and the largest zoom the eye stays outside the bounding sphere by the rule
// distance ≥ |target| + R + 2 · near; 200 seeded random sequences keep every bound; reset restores the default exactly;
// a schema-2 snapshot (no target, no field of view) restores with the defaults; a restored camera outside the bounds is
// refused; the canvas description states the field of view on the solid; the two-finger pan conversion and the
// field-of-view buttons' clamp. Host tests.
import Foundation
import Testing
@testable import InfiniteGeometryExperience
import InfiniteGeometryCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

private let id = ExperienceID(rawValue: GeometryCore.experienceID)!

private func solidIndex() throws -> Int {
    try #require(GeometryPreset.curated.firstIndex { $0.kind == .solid })
}

private func engine(seed: UInt64 = 7, solid: Bool = true) async throws -> ExperienceEngine<GeometryCore> {
    var engine = ExperienceEngine<GeometryCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    if solid {
        #expect(engine.handle(control: "preset.select", values: [Double(try solidIndex())]) == .accepted)
    }
    return engine
}

private func core(_ engine: ExperienceEngine<GeometryCore>) throws -> GeometryCore {
    try #require(engine.core)
}

/// The nearest distance the bounding-sphere rule allows for `core`'s orbit camera: max(3, |t| + R + 2 · near).
private func ruleDistance(_ core: GeometryCore) -> Double {
    max(3, core.orbit3D.target.length + core.boundingRadius + 2 * core.orbit3D.camera.near)
}

/// Whether the orbit camera of `core` satisfies every bound of FR-A05-310–312 (with rounding slack).
private func withinOrbitView(_ core: GeometryCore) -> Bool {
    let o = core.orbit3D
    return o.target.length <= 1 + 1e-9 && GeometryCore.fovRange.contains(o.fovDegrees)
        && abs(o.pitch) <= 80 * Double.pi / 180 + 1e-12 && abs(o.yaw) <= Double.pi + 1e-12
        && o.distance <= 12 + 1e-9 && o.distance >= ruleDistance(core) - 1e-9
}

@Suite struct GeometryOrbitViewTests {
    @Test func theSolidHasABoundingRadiusAndTheDefaultView() async throws {
        let state = try core(try await engine())
        #expect(state.boundingRadius > 0, "R comes from the built mesh")
        #expect(state.orbit3D == .default)
        #expect(state.orbit3D.target == .zero && state.orbit3D.fovDegrees == 60)
        #expect(abs(state.orbit3D.camera.fovY - Double.pi / 3) < 1e-15)
        #expect(withinOrbitView(state))
        let plane = try core(try await engine(solid: false))
        #expect(plane.boundingRadius == 0, "a plane has no bounding sphere")
    }

    @Test func aPanMovesTheTargetAlongRightAndUpAndStopsAtTheLimit() async throws {
        var engine = try await engine()
        let camera = try core(engine).orbit3D.camera
        let right = camera.right, up = camera.up
        #expect(engine.handle(control: "camera.pan", values: [0.25, 0]) == .accepted)
        #expect(try (core(engine).orbit3D.target - right * 0.25).length < 1e-12, "dx moves along the right vector")
        #expect(engine.handle(control: "camera.pan", values: [0, 0.25]) == .accepted)
        #expect(try (core(engine).orbit3D.target - (right + up) * 0.25).length < 1e-12, "dy moves along the up vector")
        #expect(engine.handle(control: "camera.pan", values: [8, 8]) == .accepted)
        let limit = try core(engine).orbit3D.target.length
        #expect(abs(limit - 1) < 1e-9, "the target stops at |t| = 1, found \(limit)")
        let digest = try engine.digest()
        #expect(engine.handle(control: "camera.pan", values: [8, 8]) == .rejected(.rule(code: GeometryCore.unchangedCode)))
        #expect(try engine.digest() == digest)
        #expect(try withinOrbitView(core(engine)))
        // The pan does not turn the camera: yaw, pitch and field of view are unchanged.
        let state = try core(engine)
        #expect(state.orbit3D.yaw == 0 && state.orbit3D.pitch == 0.5 && state.orbit3D.fovDegrees == 60)
    }

    @Test func theFieldOfViewIsAcceptedAtItsBoundsAndRefusedBeyond() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "camera.fov", values: [30]) == .accepted)
        #expect(try core(engine).orbit3D.fovDegrees == 30)
        #expect(engine.handle(control: "camera.fov", values: [30]) == .rejected(.rule(code: GeometryCore.unchangedCode)))
        #expect(engine.handle(control: "camera.fov", values: [75]) == .accepted)
        #expect(try core(engine).orbit3D.fovDegrees == 75)
        #expect(try abs(core(engine).orbit3D.camera.fovY - 75 * Double.pi / 180) < 1e-15)
        let digest = try engine.digest(), state = try core(engine)
        let refused: [([Double], ActionResult)] = [
            ([75.5], .rejected(.outOfRange(index: 0))),
            ([29.9], .rejected(.outOfRange(index: 0))),
            ([.nan], .rejected(.nonFinite(index: 0))),
            ([.infinity], .rejected(.nonFinite(index: 0))),
            ([], .rejected(.wrongValueCount(expected: 1, found: 0))),
        ]
        for (values, expected) in refused {
            #expect(engine.handle(control: "camera.fov", values: values) == expected, "\(values)")
        }
        #expect(try engine.digest() == digest && core(engine) == state, "a refusal changes nothing")
        // The core refuses an out-of-range angle on its own too (a direct apply bypasses the engine's ranges).
        var direct = state
        #expect(direct.apply(ExperienceAction(control: "camera.fov", values: [80], step: 0)) == .rejected(.outOfRange(index: 0)))
        #expect(direct == state)
        // On a plane the field of view is refused by rule.
        var plane = try await self.engineOnPlane()
        #expect(plane.handle(control: "camera.fov", values: [45]) == .rejected(.rule(code: GeometryCore.fovSolidOnlyCode)))
    }

    private func engineOnPlane() async throws -> ExperienceEngine<GeometryCore> { try await engine(solid: false) }

    @Test func afterAPanTheLargestZoomKeepsTheEyeOutsideTheBoundingSphere() async throws {
        var engine = try await engine()
        for (pan, orbit) in [([8.0, 0.0], [0.0, 0.0]), ([-3.0, 5.0], [1.2, -0.4]), ([0.4, -0.2], [-2.5, 0.9])] {
            _ = engine.handle(control: "camera.orbit", values: orbit)
            _ = engine.handle(control: "camera.pan", values: pan)
            _ = engine.handle(control: "camera.zoom", values: [100])
            let state = try core(engine)
            let o = state.orbit3D
            let rule = o.target.length + state.boundingRadius + 2 * o.camera.near
            #expect(o.distance >= rule - 1e-9, "distance \(o.distance) ≥ |t| + R + 2·near = \(rule)")
            #expect(abs(o.distance - ruleDistance(state)) < 1e-9, "the zoom stops exactly at the rule")
            // The eye lies outside the composition's bounding sphere by at least the near-plane distance.
            #expect(o.camera.eye.length >= state.boundingRadius + o.camera.near - 1e-9)
            #expect(withinOrbitView(state))
        }
        // A different solid (another order, another bounding radius) applies its own rule at once.
        for order in [2.0, 12.0] {
            #expect(engine.handle(control: "symmetry.order", values: [order]) == .accepted)
            _ = engine.handle(control: "camera.zoom", values: [100])
            #expect(try withinOrbitView(core(engine)), "order \(order)")
        }
    }

    /// SC-A05-304: 200 seeded random sequences of pan, zoom, field-of-view, orbit and order actions on the solid;
    /// every state satisfies every bound and a reset restores the default exactly.
    @Test func twoHundredRandomSequencesKeepTheOrbitViewBounds() async throws {
        // One engine for all sequences (reset between them) and a symmetry change every tenth sequence, which rebuilds
        // the solid and its bounding radius (the expensive step); the camera actions are cheap. Short-test rule (owner,
        // 2026-11-13).
        var rng = SeededRandom(seed: 0xA05_0304)
        let controls = ["camera.pan", "camera.zoom", "camera.fov", "camera.orbit"]
        var engine = try await engine()
        for sequence in 0..<200 {
            if sequence % 10 == 0 {
                let order = Double(rng.int(GeometryPreset.orderRange))
                _ = engine.handle(control: "symmetry.order", values: [order])
                #expect(try withinOrbitView(core(engine)), "sequence \(sequence) after symmetry.order \(order)")
            }
            for _ in 0..<12 {
                let control = controls[rng.int(0...(controls.count - 1))]
                let values: [Double]
                switch control {
                case "camera.pan": values = [rng.range(-8...8), rng.range(-8...8)]
                case "camera.zoom": values = [rng.range(0.01...100)]
                case "camera.fov": values = [rng.range(30...75)]
                case "camera.orbit": values = [rng.range(-6...6), rng.range(-6...6)]
                default: values = [rng.range(-6...6), rng.range(-6...6)]
                }
                _ = engine.handle(control: control, values: values)
                #expect(try withinOrbitView(core(engine)), "sequence \(sequence) after \(control) \(values)")
            }
            _ = engine.handle(control: "camera.reset")
            #expect(try core(engine).orbit3D == .default, "sequence \(sequence)")
        }
    }

    @Test func resetRestoresTargetDistanceAnglesAndFieldOfViewExactly() async throws {
        var engine = try await engine()
        let start = try engine.digest()
        #expect(engine.handle(control: "camera.pan", values: [0.3, -0.2]) == .accepted)
        let panned = try engine.digest()
        #expect(panned != start, "the target is in the digest")
        #expect(engine.handle(control: "camera.fov", values: [40]) == .accepted)
        #expect(try engine.digest() != panned, "the field of view is in the digest")
        #expect(engine.handle(control: "camera.orbit", values: [0.8, 0.1]) == .accepted)
        #expect(engine.handle(control: "camera.zoom", values: [1.7]) == .accepted)
        #expect(engine.handle(control: "camera.reset") == .accepted)
        #expect(try core(engine).orbit3D == .default)
        #expect(try engine.digest() == start)
    }

    @Test func targetAndFieldOfViewRoundTripThroughTheSnapshot() async throws {
        var engine = try await engine(seed: 11)
        #expect(engine.handle(control: "camera.pan", values: [0.5, 0.25]) == .accepted)
        #expect(engine.handle(control: "camera.fov", values: [47.3]) == .accepted)
        let snapshot = try engine.snapshot()
        #expect(snapshot.schemaVersion == 3)
        var restored = ExperienceEngine<GeometryCore>(id: id)
        try await restored.prepare(seed: 11)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        #expect(try restored.digest() == engine.digest())
        #expect(try core(restored).orbit3D == core(engine).orbit3D)
    }

    /// FR-A05-314: a snapshot of schema 2, encoded as the Phase 02 code wrote it (orbit camera without target and field
    /// of view), restores with its camera values and the default target and field of view.
    @Test func aSchemaTwoSnapshotRestoresWithTheDefaultTargetAndFieldOfView() async throws {
        let solid = try solidIndex()
        var preset = GeometryPreset.curated[solid]
        preset.seed = 7
        let presetObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preset))
        let payload: [String: Any] = [
            "seed": UInt64(7), "presetIndex": solid, "preset": presetObject,
            "view2D": ["centerX": 0.0, "centerY": 0.0, "zoom": 1.0],
            "orbit3D": ["yaw": 0.7, "pitch": -0.2, "distance": 7.0],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let anyDigest = try (try await engine()).digest()
        let snapshot = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: 7, stepIndex: 0,
                                              digest: anyDigest, payload: data)
        var restored = try await engine()
        #expect(restored.handle(control: "camera.fov", values: [35]) == .accepted)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        let state = try core(restored)
        #expect(state.presetIndex == solid)
        #expect(state.orbit3D == GeometryCore.Orbit3D(yaw: 0.7, pitch: -0.2, distance: 7))
        #expect(state.orbit3D.target == .zero && state.orbit3D.fovDegrees == 60)
        // The stored examples for the registry's migration check restore to their recorded digests.
        let examples = try [#require(GeometryCore.schemaOneExample()), #require(GeometryCore.schemaTwoExample())]
        #expect(examples.map(\.version) == [1, 2])
        let problems = await SnapshotMigrationCheck.problems(for: GeometryCore.self, id: id, examples: examples)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func aRestoredCameraOutsideTheBoundsIsRefused() async throws {
        let engine = try await engine(seed: 11)
        let state = try core(engine)
        let payload = try state.snapshotPayload()
        #expect(try GeometryCore.restore(payload: payload, seed: 11) == state, "the valid payload restores")
        let base = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let nearest = ruleDistance(state)
        let damaged: [[String: Double]] = [
            ["targetX": 2],                          // |target| > 1
            ["fovDegrees": 80],                      // field of view beyond 75°
            ["fovDegrees": 20],                      // field of view below 30°
            ["targetX": 1, "distance": 3],           // inside the bounding-sphere rule (|t| + R + 2·near > 3)
        ]
        #expect(1 + state.boundingRadius + 0.2 > 3, "the rule case is really below the rule")
        for change in damaged {
            var object = base
            var orbit = try #require(object["orbit3D"] as? [String: Any])
            for (key, value) in change { orbit[key] = value }
            object["orbit3D"] = orbit
            let data = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: (any Error).self, "\(change)") { try GeometryCore.restore(payload: data, seed: 11) }
        }
        #expect(nearest >= 3)
    }

    @MainActor @Test func theCanvasDescriptionStatesTheFieldOfViewOnTheSolid() async throws {
        let presenter = GeometryPresenter(experienceID: id)
        var engine = try await engine()
        #expect(presenter.describe(try core(engine)).contains("field of view 60°"))
        #expect(engine.handle(control: "camera.fov", values: [45]) == .accepted)
        let text = presenter.describe(try core(engine))
        #expect(text.contains("field of view 45°"), "\(text)")
        let plane = try core(try await self.engineOnPlane())
        #expect(!presenter.describe(plane).contains("field of view"), "a plane has no field of view")
        // Every gesture action has a native control; the field of view has buttons and no gesture.
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        #expect(presenter.nativeActions.contains("camera.fov") && !presenter.gestureActions.contains("camera.fov"))
    }

    @MainActor @Test func twoFingerMovementPansTheTargetAndTheButtonsClampTheFieldOfView() throws {
        let orbit = GeometryCore.Orbit3D.default
        let perPoint = 2 * orbit.distance * tan(Double.pi / 6) / 400
        let right = try #require(GeometryPresenter.solidPan(centroidMove: Vec2(10, 0), viewHeight: 400, orbit: orbit))
        #expect(abs(right[0] + 10 * perPoint) < 1e-12 && right[1] == 0, "fingers right → target left")
        let down = try #require(GeometryPresenter.solidPan(centroidMove: Vec2(0, 10), viewHeight: 400, orbit: orbit))
        #expect(down[0] == 0 && abs(down[1] - 10 * perPoint) < 1e-12, "fingers down (screen y) → target up")
        #expect(GeometryPresenter.solidPan(centroidMove: .zero, viewHeight: 400, orbit: orbit) == nil)
        #expect(GeometryPresenter.solidPan(centroidMove: Vec2(1, 1), viewHeight: 0, orbit: orbit) == nil)
        #expect(GeometryControls.steppedFieldOfView(60, direction: 1) == 65)
        #expect(GeometryControls.steppedFieldOfView(72, direction: 1) == 75)
        #expect(GeometryControls.steppedFieldOfView(33, direction: -1) == 30)
    }
}
