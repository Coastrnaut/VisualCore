// AuroraLoomHandlesTests — feature 304 (R02-G01-04) T-R02G0104-002 (FR-R02G0104-001, 004; SC-R02G0104-001;
// clarification Q1; research R1). Every wave step's anchor height maps back to that step, heights between steps round to
// the nearest and heights beyond ±H clamp; phase steps follow whole 22.5° turns with wrap; each dial knob lies on its
// dial circle and maps back to its step; the six spatial handles have the right ids, kinds and positions; the shared
// picker picks each handle when its projected position is touched at 96 × 64 and 390 × 844; and constrained drags
// (rail axis, dial plane) driven by screen rays land on the step the end point names.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct AuroraLoomHandlesTests {
    typealias Handles = AuroraLoomHandles
    typealias Geometry = AuroraLoomSceneGeometry

    /// Step settings the handle layout is checked at.
    static let settings: [AuroraLoomSteps] = [
        AuroraLoomSteps(wave: [0, 0, 0], phase: [0, 0, 0]),
        AuroraLoomSteps(wave: [15, 15, 15], phase: [15, 15, 15]),
        AuroraLoomSteps(wave: [15, 0, 7], phase: [3, 15, 8]),
        AuroraLoomSteps(wave: [4, 9, 12], phase: [12, 4, 0]),
    ]

    /// The view sizes (points) the picking is checked at.
    static let viewSizes: [Vec2] = [Vec2(96, 64), Vec2(390, 844)]

    @Test func handleIDsRoundTripTheirRawValues() {
        let all: [AuroraLoomHandleID] = AuroraLoomHandleID.all
        #expect(all.count == 6)
        for raw in 0..<6 {
            let id: AuroraLoomHandleID? = AuroraLoomHandleID(raw: raw)
            #expect(id != nil)
            guard let id else { continue }
            #expect(id.raw == raw)
            #expect(id.ribbon == raw / 2)
            #expect(id.control == (raw % 2 == 0 ? AuroraLoomControl.wave : AuroraLoomControl.phase))
            #expect(all[raw] == id)
            #expect(AuroraLoomHandleID(ribbon: id.ribbon, control: id.control) == id)
        }
        #expect(AuroraLoomHandleID(raw: -1) == nil)
        #expect(AuroraLoomHandleID(raw: 6) == nil)
        #expect(AuroraLoomHandleID(ribbon: 3, control: .wave) == nil)
        #expect(AuroraLoomHandleID(ribbon: -1, control: .phase) == nil)
    }

    @Test func layoutConstantsMatchTheClarification() {
        #expect(Handles.railX == Geometry.length / 2 + 0.45)
        #expect(Handles.dialX == -(Geometry.length / 2 + 0.45))
        #expect(Handles.dialRadius == 0.3)
        #expect(abs(Handles.phaseStepAngle - 22.5 * Double.pi / 180) < 1e-15)
        for r in 0..<3 {
            #expect(Handles.dialCentre(ribbon: r) == Vec3(Handles.dialX, 0, Geometry.lane(ribbon: r)))
            let bounds: (min: Vec3, max: Vec3) = Handles.railBounds(ribbon: r)
            #expect(bounds.min == Vec3(Handles.railX, -Geometry.amplitude, Geometry.lane(ribbon: r)))
            #expect(bounds.max == Vec3(Handles.railX, Geometry.amplitude, Geometry.lane(ribbon: r)))
        }
        // The rails and dials lie inside the content box.
        let h: Vec3 = Geometry.contentHalfExtents
        #expect(Handles.railX < h.x && -Handles.dialX < h.x)
        #expect(Geometry.amplitude < h.y && Geometry.laneSpacing + Handles.dialRadius < h.z)
    }

    @Test func everyWaveStepHeightMapsBackToItsStep() {
        for r in 0..<3 {
            for w in 0...15 {
                let p: Vec3 = Handles.anchorPosition(ribbon: r, wave: w)
                let y: Double = Geometry.amplitude * (2 * Double(w) / 15 - 1)
                #expect(abs(p.y - y) < 1e-12)
                #expect(p.x == Handles.railX)
                #expect(p.z == Geometry.lane(ribbon: r))
                #expect(Handles.waveStep(atHeight: p.y) == w)
            }
        }
        #expect(Handles.anchorPosition(ribbon: 1, wave: 0).y == -Geometry.amplitude)
        #expect(Handles.anchorPosition(ribbon: 1, wave: 15).y == Geometry.amplitude)
        // Out-of-range inputs are clamped.
        #expect(Handles.anchorPosition(ribbon: 1, wave: 99) == Handles.anchorPosition(ribbon: 1, wave: 15))
        #expect(Handles.anchorPosition(ribbon: -4, wave: -2) == Handles.anchorPosition(ribbon: 0, wave: 0))
    }

    @Test func heightsBetweenStepsRoundToTheNearestAndClamp() {
        let stepHeight: Double = 2 * Geometry.amplitude / 15
        for w in 0...15 {
            let y: Double = Handles.anchorPosition(ribbon: 0, wave: w).y
            let fractions: [Double] = [-0.49, -0.3, -0.1, 0.1, 0.3, 0.49]
            for f in fractions {
                let expected: Int = min(max(w, 0), 15)
                #expect(Handles.waveStep(atHeight: y + f * stepHeight) == expected, "step \(w) fraction \(f)")
            }
            if w < 15 {
                #expect(Handles.waveStep(atHeight: y + 0.51 * stepHeight) == w + 1)
                #expect(Handles.waveStep(atHeight: y + 0.99 * stepHeight) == w + 1)
            }
        }
        let beyond: [Double] = [1.01, 1.5, 3, 1e9, Double.greatestFiniteMagnitude]
        for y in beyond {
            #expect(Handles.waveStep(atHeight: y * Geometry.amplitude) == 15)
            #expect(Handles.waveStep(atHeight: -y * Geometry.amplitude) == 0)
        }
        #expect(Handles.waveStep(atHeight: Double.nan) == 0)
        #expect(Handles.waveStep(atHeight: Double.infinity) == 0)
        #expect(Handles.waveStep(atHeight: -Double.infinity) == 0)
    }

    @Test func phaseStepsFollowWholeTurnsAndWrap() {
        for start in 0...15 {
            for k in -40...40 {
                let angle: Double = Double(k) * 22.5 * Double.pi / 180
                let expected: Int = ((start + k) % 16 + 16) % 16
                #expect(Handles.phaseStep(start: start, turnedAngle: angle) == expected, "start \(start) k \(k)")
                // Less than half a step either side rounds to the same step.
                #expect(Handles.phaseStep(start: start, turnedAngle: angle + 0.45 * Handles.phaseStepAngle)
                        == expected)
                #expect(Handles.phaseStep(start: start, turnedAngle: angle - 0.45 * Handles.phaseStepAngle)
                        == expected)
            }
            #expect(Handles.phaseStep(start: start, turnedAngle: Double.nan) == start)
            #expect(Handles.phaseStep(start: start, turnedAngle: Double.infinity) == start)
            #expect(Handles.phaseStep(start: start, turnedAngle: 2 * Double.pi) == start)
            #expect(Handles.phaseStep(start: start, turnedAngle: -2 * Double.pi) == start)
        }
        #expect(Handles.phaseStep(start: 15, turnedAngle: Handles.phaseStepAngle) == 0)
        #expect(Handles.phaseStep(start: 0, turnedAngle: -Handles.phaseStepAngle) == 15)
        #expect(Handles.phaseStep(start: 17, turnedAngle: 0) == 1)
        #expect(Handles.phaseStep(start: -1, turnedAngle: 0) == 15)
        let huge: Int = Handles.phaseStep(start: 3, turnedAngle: 1e300)
        #expect(huge >= 0 && huge <= 15)
    }

    @Test func dialKnobsLieOnTheirCirclesAndMapBack() {
        for r in 0..<3 {
            let centre: Vec3 = Handles.dialCentre(ribbon: r)
            let top: Vec3 = Handles.dialKnob(ribbon: r, phase: 0)
            for p in 0...15 {
                let knob: Vec3 = Handles.dialKnob(ribbon: r, phase: p)
                let offset: Vec3 = knob - centre
                #expect(offset.x == 0)
                #expect(abs(offset.length - Handles.dialRadius) < 1e-12)
                // Angle from +y towards +z.
                let angle: Double = atan2(offset.z, offset.y)
                let expected: Double = Double(p) * Double.pi / 8
                let difference: Double = remainder(angle - expected, 2 * Double.pi)
                #expect(abs(difference) < 1e-12)
                #expect(Handles.phaseStep(start: 0, turnedAngle: angle) == p)
                // The signed turn from the top knob about +x (right-hand rule) maps back too.
                let u: Vec3 = top - centre
                let turn: Double = atan2(Handles.dialNormal.dot(u.cross(offset)), u.dot(offset))
                #expect(Handles.phaseStep(start: 0, turnedAngle: turn) == p)
            }
            #expect(Handles.dialKnob(ribbon: r, phase: 16) == Handles.dialKnob(ribbon: r, phase: 0))
            #expect(Handles.dialKnob(ribbon: r, phase: -1) == Handles.dialKnob(ribbon: r, phase: 15))
        }
        // Phase 4 is a quarter turn: the knob points to +z.
        let quarter: Vec3 = Handles.dialKnob(ribbon: 1, phase: 4) - Handles.dialCentre(ribbon: 1)
        #expect(abs(quarter.y) < 1e-12 && abs(quarter.z - Handles.dialRadius) < 1e-12)
    }

    @Test func sixHandlesHaveTheRightIdsKindsAndPositions() throws {
        for steps in Self.settings {
            let handles: [SpatialHandle] = try Handles.spatialHandles(steps: steps)
            #expect(handles.count == 6)
            for i in 0..<handles.count {
                let handle: SpatialHandle = handles[i]
                #expect(handle.id == i)
                guard let id = AuroraLoomHandleID(raw: handle.id) else {
                    Issue.record("handle id \(handle.id) has no AuroraLoomHandleID")
                    continue
                }
                #expect(handle.hitRadius == Handles.hitRadius)
                switch id.control {
                case .wave:
                    #expect(handle.kind == HandleKind.axis(Vec3(0, 1, 0)))
                    #expect(handle.position == Handles.anchorPosition(ribbon: id.ribbon, wave: steps.wave[id.ribbon]))
                case .phase:
                    #expect(handle.kind == HandleKind.rotation(Vec3(1, 0, 0)))
                    #expect(handle.position == Handles.dialKnob(ribbon: id.ribbon, phase: steps.phase[id.ribbon]))
                }
                #expect(Handles.position(of: id, steps: steps) == handle.position)
            }
        }
    }

    @Test func pickerPicksEachProjectedHandle() throws {
        for size in Self.viewSizes {
            let m: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: size.x / size.y)
            let viewProjection: Mat4 = m.projection * m.view
            for steps in Self.settings {
                let handles: [SpatialHandle] = try Handles.spatialHandles(steps: steps)
                for i in 0..<handles.count {
                    let projected: (point: Vec2, depth: Double)? =
                        ScreenProjection.project(handles[i].position, viewProjection: viewProjection, viewport: size)
                    #expect(projected != nil)
                    guard let projected else { continue }
                    #expect(projected.point.x > 0 && projected.point.x < size.x)
                    #expect(projected.point.y > 0 && projected.point.y < size.y)
                    let picked: Int? = try HandlePicker.pick(handles, at: projected.point,
                                                             viewProjection: viewProjection, viewport: size)
                    #expect(picked == i, "view \(size) steps \(steps) handle \(i) picked \(String(describing: picked))")
                }
                // Far from every handle (the view's top centre, above the loom) nothing is picked at the large view.
                if size.y > 100 {
                    let none: Int? = try HandlePicker.pick(handles, at: Vec2(size.x / 2, 2),
                                                           viewProjection: viewProjection, viewport: size)
                    #expect(none == nil)
                }
            }
        }
    }

    @Test func railDragLandsOnTheStepItsEndPointNames() throws {
        let size: Vec2 = Vec2(390, 844)
        let m: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: size.x / size.y)
        let viewProjection: Mat4 = m.projection * m.view
        guard let inverse = viewProjection.inverse else {
            Issue.record("view-projection not invertible")
            return
        }
        for r in 0..<3 {
            let starts: [Int] = [0, 7, 15]
            for start in starts {
                let anchor: Vec3 = Handles.anchorPosition(ribbon: r, wave: start)
                guard let grab = ScreenProjection.project(anchor, viewProjection: viewProjection, viewport: size),
                      let startRay = ScreenProjection.ray(through: grab.point, viewport: size,
                                                          inverseViewProjection: inverse),
                      var drag = HandleDrag(start: anchor, ray: startRay, constraint: .axis(Handles.railAxis),
                                            bounds: Handles.railBounds(ribbon: r)) else {
                    Issue.record("no drag for ribbon \(r) start \(start)")
                    continue
                }
                for target in 0...15 {
                    let end: Vec3 = Handles.anchorPosition(ribbon: r, wave: target)
                    guard let point = ScreenProjection.project(end, viewProjection: viewProjection, viewport: size),
                          let ray = ScreenProjection.ray(through: point.point, viewport: size,
                                                         inverseViewProjection: inverse) else {
                        Issue.record("no ray for ribbon \(r) target \(target)")
                        continue
                    }
                    let position: Vec3 = drag.update(ray: ray)
                    #expect(!drag.isHeld)
                    #expect(Handles.waveStep(atHeight: position.y) == target, "ribbon \(r) \(start) → \(target)")
                }
            }
        }
    }

    @Test func dialDragLandsOnTheStepItsEndPointNames() throws {
        let size: Vec2 = Vec2(390, 844)
        let m: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: size.x / size.y)
        let viewProjection: Mat4 = m.projection * m.view
        guard let inverse = viewProjection.inverse else {
            Issue.record("view-projection not invertible")
            return
        }
        for r in 0..<3 {
            let centre: Vec3 = Handles.dialCentre(ribbon: r)
            let starts: [Int] = [0, 5, 13]
            for start in starts {
                let knob: Vec3 = Handles.dialKnob(ribbon: r, phase: start)
                guard let grab = ScreenProjection.project(knob, viewProjection: viewProjection, viewport: size),
                      let startRay = ScreenProjection.ray(through: grab.point, viewport: size,
                                                          inverseViewProjection: inverse),
                      var drag = HandleDrag(start: knob, ray: startRay, constraint: .plane(Handles.dialNormal)) else {
                    Issue.record("no dial drag for ribbon \(r) start \(start)")
                    continue
                }
                // Turns of up to seven steps either way (the signed angle is unambiguous below half a turn).
                for k in -7...7 {
                    let target: Int = ((start + k) % 16 + 16) % 16
                    let end: Vec3 = Handles.dialKnob(ribbon: r, phase: target)
                    guard let point = ScreenProjection.project(end, viewProjection: viewProjection, viewport: size),
                          let ray = ScreenProjection.ray(through: point.point, viewport: size,
                                                         inverseViewProjection: inverse) else {
                        Issue.record("no ray for ribbon \(r) target \(target)")
                        continue
                    }
                    drag.update(ray: ray)
                    #expect(!drag.isHeld)
                    let turned: Double = drag.angle(around: centre)
                    #expect(Handles.phaseStep(start: start, turnedAngle: turned) == target,
                            "ribbon \(r) \(start) → \(target) angle \(turned)")
                }
            }
        }
    }
}
