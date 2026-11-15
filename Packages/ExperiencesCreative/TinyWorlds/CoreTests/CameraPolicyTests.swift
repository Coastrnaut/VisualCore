// CameraPolicyTests — feature 090 (A12-P02) T-A12-204 (FR-A12-210; clarification 3; research D3; SC-A12-201). The
// shared camera policy, host-free and short: the eye is the orbit camera's eye around (0, 0.3, 0); a sweep of 24 yaw ×
// 8 pitch × 4 distance views per preset (seed 1) stays within the limits and keeps the 0.5 m clearance after the
// clamp, which only ever raises the pitch in whole degrees; a view that already keeps the clearance is unchanged; a
// high flat terrain raises the lowest pitch to the first whole degree that clears it, and an impossible one stops at
// 75°; the preset overload equals the field overload.
//
// Feature 092 (A12-P04) T-A12-402 (FR-A12-403; clarification Q3): the overload over a bare field keeps the global
// limits (the sweep above), while the preset overload uses the preset's pack limits: it equals the field overload
// given those limits, and its results lie within them.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct CameraPolicyTests {
    private let degree = Double.pi / 180

    /// 24 yaw × 8 pitch × 4 distance views spanning the limits.
    private var sweep: [WorldView] {
        var views: [WorldView] = []
        for y in 0..<24 {
            for p in 0..<8 {
                for d in 0..<4 {
                    views.append(WorldView(yaw: (-180 + 15 * Double(y)) * degree,
                                           pitch: (10 + 65 * Double(p) / 7) * degree,
                                           distance: 10 + 20 * Double(d) / 3))
                }
            }
        }
        return views
    }

    private func flat(_ height: Double) throws -> HeightField {
        try HeightField(columns: 8, rows: 8, cellSize: 1.5, originX: -6, originZ: -6) { _, _ in height }
    }

    @Test func theEyeIsTheOrbitCamerasEyeAroundTheTarget() {
        let view = WorldView.default
        let camera = OrbitCamera(target: Vec3(0, 0.3, 0), distance: 18, yaw: 45 * degree, pitch: 35 * degree)
        #expect(CameraPolicy.target == Vec3(0, 0.3, 0) && CameraPolicy.clearance == 0.5)
        #expect(CameraPolicy.eye(of: view) == camera.eye)
        #expect(abs(CameraPolicy.eye(of: view).y - (0.3 + 18 * sin(35 * degree))) < 1e-12)
        #expect(CameraPolicy.pitchRange == (10 * degree)...(75 * degree) && CameraPolicy.distanceRange == 10...30)
    }

    @Test(arguments: WorldPreset.all)
    func theSweepStaysWithinLimitsAndKeepsTheClearance(preset: WorldPreset) throws {
        let field = try TerrainGenerator.heightField(preset: preset, seed: 1)
        let views = sweep
        #expect(views.count == 24 * 8 * 4)
        for view in views {
            let clamped = CameraPolicy.clamp(view, field: field)
            #expect(clamped.isValid)
            #expect(CameraPolicy.keepsClearance(clamped, field: field), "\(view) → \(clamped)")
            #expect(clamped.yaw == view.yaw && clamped.distance == view.distance)
            #expect(clamped.pitch >= view.pitch)
            let raised = (clamped.pitch - view.pitch) / degree
            #expect(clamped.pitch == WorldView.pitchRange.upperBound || abs(raised - raised.rounded()) < 1e-9)
            #expect(CameraPolicy.clamp(clamped, field: field) == clamped, "idempotent")
        }
    }

    @Test func aViewThatKeepsTheClearanceIsUnchanged() throws {
        let field = try TerrainGenerator.heightField(preset: .island, seed: 1)
        #expect(CameraPolicy.keepsClearance(.default, field: field))
        #expect(CameraPolicy.clamp(.default, field: field) == .default)
        #expect(CameraPolicy.clamp(.default, preset: .island, seed: 1) == .default)
    }

    @Test func aHighFlatTerrainRaisesThePitchByWholeDegrees() throws {
        // Flat at 1.6 m: the eye needs 0.3 + 10 sin p ≥ 2.1, so p ≥ asin(0.18) ≈ 10.37°, reached at 11°.
        let field = try flat(1.6)
        let low = WorldView(yaw: 0.3, pitch: 10 * degree, distance: 10)
        #expect(!CameraPolicy.keepsClearance(low, field: field))
        let clamped = CameraPolicy.clamp(low, field: field)
        #expect(abs(clamped.pitchDegrees - 11) < 1e-9 && clamped.distance == 10 && clamped.yaw == 0.3)
        #expect(CameraPolicy.keepsClearance(clamped, field: field))
        // Unreachable clearance: the pitch stops at 75°.
        let wall = try flat(50)
        #expect(CameraPolicy.clamp(low, field: wall).pitch == WorldView.pitchRange.upperBound)
    }

    @Test func theNeighbourhoodMaximumSeesAPeakWithinOneMetre() throws {
        // A single peak of 5 m at the grid point (1, 1); every other point 0.
        let field = try HeightField(columns: 12, rows: 12, cellSize: 1, originX: -6, originZ: -6) { x, z in
            x == 1 && z == 1 ? 5 : 0
        }
        #expect(CameraPolicy.neighbourhoodMaximum(field: field, x: 0.5, z: 0.5) == 5, "(1, 1) is a corner sample")
        #expect(CameraPolicy.neighbourhoodMaximum(field: field, x: 1, z: 1) == 5)
        #expect(CameraPolicy.neighbourhoodMaximum(field: field, x: 0, z: 0) == 1.25, "bilinear at (0.5, 0.5)")
        #expect(CameraPolicy.neighbourhoodMaximum(field: field, x: -1, z: -1) == 0)
    }

    @Test(arguments: WorldPreset.all)
    func thePresetOverloadEqualsTheFieldOverloadWithThePresetsLimits(preset: WorldPreset) throws {
        let field = try TerrainGenerator.heightField(preset: preset, seed: 1)
        let limits = CameraPolicy.limits(for: preset)
        #expect(limits == WorldPack.pack(for: preset.id).limits && limits.isInsideGlobal)
        for view in sweep.prefix(48) {
            let clamped = CameraPolicy.clamp(view, preset: preset, seed: 1)
            #expect(clamped == CameraPolicy.clamp(view, field: field, limits: limits))
            #expect(limits.contains(clamped) && CameraPolicy.keepsClearance(clamped, field: field, limits: limits))
            let state = WorldState(presetIndex: preset.id.rawValue, seed: 1, view: view,
                                   random: WorldState.initial.random)
            #expect(CameraPolicy.clamp(view, state: state) == clamped, "no props: the state overload agrees")
        }
        #expect(CameraPolicy.limits(for: preset).pitch.lowerBound > WorldView.pitchRange.lowerBound)
    }
}
