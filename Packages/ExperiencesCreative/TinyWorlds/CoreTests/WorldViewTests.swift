// WorldViewTests — feature 089 (A12-P01) T-A12-103 (FR-A12-120, FR-A12-121; clarification 4; research D4). The orbit
// view, host-free and short: the default view; yaw wraps into −π…π, pitch clamps to 10°…75° and distance to 10…30 m;
// orbit steps outside −180…180 degrees, zoom factors outside 0.5…2 and non-finite input are refused and change
// nothing; reset restores the default; the JSON round trip is exact and a view outside its limits does not decode.
//
// Feature 092 (A12-P04) T-A12-402 (FR-A12-403; clarification Q3): camera limits per preset. The global limits equal
// the view's ranges; limits are clamped into them; `clamped(to:)`, `orbit(…limits:)` and `zoom(_:limits:)` keep a
// view within a preset's limits, and refused steps still change nothing.
import Foundation
import Testing
import TinyWorldsCore

@Suite struct WorldViewTests {
    private let degree = Double.pi / 180

    @Test func theDefaultViewAndTheLimits() {
        let view = WorldView.default
        #expect(view.yaw == 45 * degree && view.pitch == 35 * degree && view.distance == 18)
        #expect(view.isValid)
        #expect(WorldView.pitchRange == (10 * degree)...(75 * degree))
        #expect(WorldView.distanceRange == 10...30)
        // The eye stays outside the world (half-diagonal 8.49 m) and above its highest point at the lowest pitch.
        #expect(WorldView.distanceRange.lowerBound > (72.0).squareRoot())
        #expect(WorldView.distanceRange.lowerBound * sin(WorldView.pitchRange.lowerBound)
                > WorldPreset.heightRange.upperBound)
    }

    @Test func orbitWrapsYawAndClampsPitch() {
        var view = WorldView.default
        var accepted = view.orbit(yawDegrees: 180, pitchDegrees: 0)
        #expect(accepted && abs(view.yawDegrees - -135) < 1e-9, "45° + 180° wraps to −135°")
        accepted = view.orbit(yawDegrees: -180, pitchDegrees: 180)
        #expect(accepted && abs(view.yawDegrees - 45) < 1e-9 && view.pitch == WorldView.pitchRange.upperBound)
        accepted = view.orbit(yawDegrees: 0, pitchDegrees: -180)
        #expect(accepted && view.pitch == WorldView.pitchRange.lowerBound)
        for _ in 0..<9 { view.orbit(yawDegrees: 170, pitchDegrees: 0) }
        #expect(view.yaw >= -Double.pi && view.yaw <= Double.pi && view.isValid)
    }

    @Test func zoomDividesTheDistanceWithinItsRange() {
        var view = WorldView.default
        for (factor, distance) in [(2.0, 10.0), (2, 10), (0.5, 20), (0.5, 30), (1.5, 20)] {
            let accepted = view.zoom(factor)
            #expect(accepted && view.distance == distance, "zoom \(factor)")
        }
    }

    @Test func invalidInputIsRefusedAndChangesNothing() {
        var view = WorldView.default
        view.orbit(yawDegrees: 10, pitchDegrees: 5)
        let before = view
        for (yaw, pitch) in [(180.5, 0.0), (0, -181), (.nan, 0), (0, .infinity)] {
            let accepted = view.orbit(yawDegrees: yaw, pitchDegrees: pitch)
            #expect(!accepted, "orbit \(yaw), \(pitch)")
        }
        for factor in [0.49, 2.01, .nan, -1, .infinity] {
            let accepted = view.zoom(factor)
            #expect(!accepted, "zoom \(factor)")
        }
        #expect(view == before)
        view.reset()
        #expect(view == .default)
    }

    @Test func theInitialiserNormalisesItsInput() {
        let view = WorldView(yaw: 3 * Double.pi, pitch: 2, distance: 3)
        #expect(abs(abs(view.yaw) - Double.pi) < 1e-12)
        #expect(view.pitch == WorldView.pitchRange.upperBound && view.distance == 10)
        let fallback = WorldView(yaw: .nan, pitch: .infinity, distance: -.infinity)
        #expect(fallback == .default)
    }

    @Test func theGlobalLimitsAreTheViewsRangesAndLimitsStayInsideThem() {
        #expect(CameraLimits.global.pitch == WorldView.pitchRange && CameraLimits.global.distance == WorldView.distanceRange)
        #expect(CameraLimits.global.isInsideGlobal && CameraLimits.global.contains(.default))
        let wide = CameraLimits(pitchDegrees: 0...90, distance: 5...40)
        #expect(wide == .global)
        let beyond = CameraLimits(pitchDegrees: 80...90, distance: 31...40)
        #expect(beyond.pitch == WorldView.pitchRange.upperBound...WorldView.pitchRange.upperBound)
        #expect(beyond.distance == 30...30 && beyond.isInsideGlobal)
        let infinite = CameraLimits(pitchDegrees: -Double.infinity...Double.infinity, distance: 12...Double.infinity)
        #expect(infinite.pitch == WorldView.pitchRange && infinite.distance == 12...30)
    }

    @Test func viewsAreClampedAndSteppedWithinPresetLimits() {
        let limits = CameraLimits(pitchDegrees: 25...75, distance: 10...24)
        let low = WorldView(yaw: 0.5, pitch: 12 * degree, distance: 29)
        #expect(!limits.contains(low) && low.isValid)
        let clamped = low.clamped(to: limits)
        #expect(abs(clamped.pitchDegrees - 25) < 1e-9 && clamped.distance == 24 && clamped.yaw == 0.5)
        #expect(limits.contains(clamped) && clamped.clamped(to: limits) == clamped)
        var view = WorldView(yaw: 0, pitch: 30 * degree, distance: 20)
        let orbited = view.orbit(yawDegrees: 10, pitchDegrees: -20, limits: limits)
        #expect(orbited && abs(view.pitchDegrees - 25) < 1e-9 && abs(view.yawDegrees - 10) < 1e-9)
        let out = view.zoom(0.5, limits: limits)
        #expect(out && view.distance == 24)
        let inward = view.zoom(2, limits: limits)
        #expect(inward && view.distance == 12)
        let before = view
        let badOrbit = view.orbit(yawDegrees: 200, pitchDegrees: 0, limits: limits)
        let badZoom = view.zoom(3, limits: limits)
        #expect(!badOrbit && !badZoom && view == before)
    }

    @Test func theJSONRoundTripIsExactAndOutOfRangeViewsDoNotDecode() throws {
        var view = WorldView.default
        view.orbit(yawDegrees: -73.25, pitchDegrees: 12.5)
        view.zoom(0.8)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(view)
        #expect(try JSONDecoder().decode(WorldView.self, from: data) == view)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"distance\":"))
        for bad in ["{\"distance\":9,\"pitch\":0.5,\"yaw\":0}", "{\"distance\":18,\"pitch\":0.1,\"yaw\":0}",
                    "{\"distance\":18,\"pitch\":1.4,\"yaw\":0}", "{\"distance\":18,\"pitch\":0.5,\"yaw\":3.2}",
                    "{\"distance\":18,\"pitch\":0.5}"] {
            #expect(throws: (any Error).self) { try JSONDecoder().decode(WorldView.self, from: Data(bad.utf8)) }
        }
    }
}
