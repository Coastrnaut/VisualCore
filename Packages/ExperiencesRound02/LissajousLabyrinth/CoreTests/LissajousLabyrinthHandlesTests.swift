// LissajousLabyrinthHandlesTests — feature 314 (R02-G02-04) T-R02G0204-002 (FR-R02G0204-001, 002, 004; clarifications
// Q1, Q3; research R2, R3). The ring layout matches the clarification (radius 0.18 R, centres 0.45 R apart along the
// authored up vector, the column 1.35 R to the right, frequencyA … phaseC from top, facing the eye); every value of every
// dial round-trips through its knob and its knob angle; turned angles round to whole steps, frequencies clamp to 1 … 9 and
// phases wrap modulo 16; the four spatial handles have ids 0 … 3, rotation kinds and knob positions; the shared picker
// picks each projected knob at 390 × 844, 96 × 64 and 1024 × 768 for several orbits. Test data uses explicit types and
// plain loops (CI type-check rule); synthetic levels only (seed 2_314).
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

@Suite struct LissajousLabyrinthHandlesTests {
    typealias Handles = LissajousLabyrinthHandles
    typealias Geometry = LissajousLabyrinthSceneGeometry

    /// Synthetic levels: the seeded fixtures plus the extreme level of the geometry tests.
    static func levels() throws -> [LissajousLabyrinthLevel] {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        var result: [LissajousLabyrinthLevel] = []
        for _ in 0..<4 { result.append(LissajousLabyrinthFixture.next(&random).level) }
        result.append(try LissajousLabyrinthSceneGeometryTests.extremeLevel(LissajousLabyrinthDials(
            frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0)))
        return result
    }

    @Test func layoutMatchesTheClarification() throws {
        #expect(abs(Handles.right.length - 1) < 1e-12 && abs(Handles.up.length - 1) < 1e-12)
        #expect(abs(Handles.right.dot(Handles.up)) < 1e-12 && abs(Handles.right.dot(Handles.ringNormal)) < 1e-12)
        #expect(abs(Handles.up.dot(Handles.ringNormal)) < 1e-12 && abs(Handles.right.y) < 1e-12 && Handles.up.y > 0)
        #expect(Handles.ringNormal == Geometry.eyeDirection)
        #expect(abs(Handles.frequencyStepAngle - 40 * Double.pi / 180) < 1e-15)
        #expect(abs(Handles.phaseStepAngle - 22.5 * Double.pi / 180) < 1e-15)
        #expect(Handles.stepAngle(.frequencyA) == Handles.frequencyStepAngle)
        #expect(Handles.stepAngle(.frequencyB) == Handles.frequencyStepAngle)
        #expect(Handles.stepAngle(.phaseA) == Handles.phaseStepAngle)
        #expect(Handles.stepAngle(.phaseC) == Handles.phaseStepAngle)
        for level in try Self.levels() {
            let stage: (centre: Vec3, radius: Double) = Geometry.stageBounds(level: level)
            let r: Double = stage.radius
            #expect(abs(Handles.ringRadius(level: level) - 0.18 * r) < 1e-12)
            let dials: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
            #expect(dials == [.frequencyA, .frequencyB, .phaseA, .phaseC])
            var heights: [Double] = []
            var mean: Vec3 = .zero
            for (row, dial) in dials.enumerated() {
                #expect(Handles.index(dial) == row && Handles.dial(id: row) == dial)
                let centre: Vec3 = Handles.ringCentre(dial, level: level)
                let offset: Vec3 = centre - stage.centre
                #expect(abs(offset.dot(Handles.right) - 1.35 * r) < 1e-9)
                #expect(abs(offset.dot(Handles.ringNormal)) < 1e-9)
                heights.append(offset.dot(Handles.up))
                mean = mean + centre * 0.25
                let plane: (centre: Vec3, normal: Vec3) = Handles.ringPlane(dial, level: level)
                #expect(plane.centre == centre && plane.normal == Handles.ringNormal)
            }
            // From top, 0.45 R apart, the column centred at stage centre + right · 1.35 R.
            for i in 0..<3 { #expect(abs((heights[i] - heights[i + 1]) - 0.45 * r) < 1e-9) }
            #expect((mean - (stage.centre + Handles.right * (1.35 * r))).length < 1e-9)
            #expect(Handles.dial(id: -1) == nil && Handles.dial(id: 4) == nil)
            // The rings and knobs lie inside the content sphere.
            let content: (centre: Vec3, radius: Double) = Geometry.contentBounds(level: level)
            for dial in dials {
                for value in dial.range {
                    let k: Vec3 = Handles.knob(dial, value: value, level: level)
                    #expect((k - content.centre).length + Handles.knobRadius(level: level) <= content.radius + 1e-9)
                }
            }
        }
    }

    @Test func everyValueRoundTripsThroughItsKnob() throws {
        for level in try Self.levels() {
            for dial in LissajousLabyrinthDial.allCases {
                let centre: Vec3 = Handles.ringCentre(dial, level: level)
                let radius: Double = Handles.ringRadius(level: level)
                for value in dial.range {
                    let k: Vec3 = Handles.knob(dial, value: value, level: level)
                    #expect(abs((k - centre).length - radius) < 1e-9)
                    #expect(abs((k - centre).dot(Handles.ringNormal)) < 1e-9)
                    let expected: Double = Double(value) * Handles.stepAngle(dial)
                    #expect(Handles.knobAngle(dial, value: value) == expected)
                    let measured: Double? = Handles.angle(of: k, dial: dial, level: level)
                    #expect(measured != nil)
                    guard let measured else { continue }
                    #expect(abs(Handles.angleDelta(from: expected, to: measured)) < 1e-9)
                    // Turning from every start value by the knob-angle difference lands on the value.
                    for start in dial.range {
                        let turned: Double = expected - Handles.knobAngle(dial, value: start)
                        #expect(Handles.value(dial, start: start, turnedAngle: turned) == value)
                    }
                }
            }
            // Clockwise as seen from the eye: frequency 1 (40°) lies right of the ring's up direction, phase 4 (90°)
            // straight to the right, phase 12 (270°) straight to the left.
            let c: Vec3 = Handles.ringCentre(.phaseA, level: level)
            #expect((Handles.knob(.frequencyA, value: 1, level: level) - Handles.ringCentre(.frequencyA, level: level))
                .dot(Handles.right) > 0)
            #expect(((Handles.knob(.phaseA, value: 4, level: level) - c).normalized - Handles.right).length < 1e-9)
            #expect(((Handles.knob(.phaseA, value: 12, level: level) - c).normalized + Handles.right).length < 1e-9)
            #expect(((Handles.knob(.phaseA, value: 0, level: level) - c).normalized - Handles.up).length < 1e-9)
            // Out-of-range values are clamped onto the ring; the centre and non-finite points have no angle.
            #expect(Handles.knob(.frequencyB, value: 0, level: level) == Handles.knob(.frequencyB, value: 1, level: level))
            #expect(Handles.knob(.phaseC, value: 99, level: level) == Handles.knob(.phaseC, value: 15, level: level))
            #expect(Handles.angle(of: c, dial: .phaseA, level: level) == nil)
            #expect(Handles.angle(of: Vec3(Double.nan, 0, 0), dial: .phaseA, level: level) == nil)
            // A point off the plane reads the angle of its projection.
            let lifted: Vec3 = Handles.knob(.phaseA, value: 5, level: level) + Handles.ringNormal * 3
            let liftedAngle: Double? = Handles.angle(of: lifted, dial: .phaseA, level: level)
            #expect(liftedAngle != nil && abs(Handles.angleDelta(from: 5 * Handles.phaseStepAngle,
                                                                 to: liftedAngle ?? 0)) < 1e-9)
        }
    }

    @Test func turnedAnglesRoundClampAndWrap() {
        let f: Double = Handles.frequencyStepAngle, p: Double = Handles.phaseStepAngle
        // Rounding to the nearest step, halves away from zero.
        #expect(Handles.value(.frequencyA, start: 4, turnedAngle: 0.49 * f) == 4)
        #expect(Handles.value(.frequencyA, start: 4, turnedAngle: 0.5 * f) == 5)
        #expect(Handles.value(.frequencyA, start: 4, turnedAngle: -0.5 * f) == 3)
        #expect(Handles.value(.frequencyA, start: 4, turnedAngle: -0.49 * f) == 4)
        #expect(Handles.value(.phaseC, start: 7, turnedAngle: 1.49 * p) == 8)
        #expect(Handles.value(.phaseC, start: 7, turnedAngle: 1.5 * p) == 9)
        // Frequencies clamp to 1 … 9, also for long turns.
        #expect(Handles.value(.frequencyB, start: 8, turnedAngle: 3 * f) == 9)
        #expect(Handles.value(.frequencyB, start: 2, turnedAngle: -5 * f) == 1)
        #expect(Handles.value(.frequencyB, start: 5, turnedAngle: 10 * Double.pi) == 9)
        #expect(Handles.value(.frequencyB, start: 5, turnedAngle: -10 * Double.pi) == 1)
        #expect(Handles.value(.frequencyA, start: 0, turnedAngle: 0) == 1)
        #expect(Handles.value(.frequencyA, start: 12, turnedAngle: 0) == 9)
        #expect(Handles.value(.frequencyA, start: 6, turnedAngle: Double.nan) == 6)
        #expect(Handles.value(.frequencyA, start: 6, turnedAngle: Double.infinity) == 6)
        // Phases wrap modulo 16 in both directions and over several turns.
        #expect(Handles.value(.phaseA, start: 15, turnedAngle: p) == 0)
        #expect(Handles.value(.phaseA, start: 0, turnedAngle: -p) == 15)
        #expect(Handles.value(.phaseA, start: 3, turnedAngle: 2 * Double.pi) == 3)
        #expect(Handles.value(.phaseA, start: 3, turnedAngle: -4 * Double.pi - 2 * p) == 1)
        #expect(Handles.value(.phaseA, start: 3, turnedAngle: 3 * 2 * Double.pi + 5 * p) == 8)
        #expect(Handles.value(.phaseC, start: -1, turnedAngle: 0) == 15)
        #expect(Handles.value(.phaseC, start: 33, turnedAngle: 0) == 1)
        #expect(Handles.value(.phaseC, start: 9, turnedAngle: Double.nan) == 9)
        // Every start and every whole step count agree with the arithmetic.
        for dial in LissajousLabyrinthDial.allCases {
            for start in dial.range {
                for steps in -40...40 {
                    let got: Int = Handles.value(dial, start: start, turnedAngle: Double(steps) * Handles.stepAngle(dial))
                    let want: Int
                    switch dial {
                    case .frequencyA, .frequencyB: want = min(max(start + steps, 1), 9)
                    case .phaseA, .phaseC: want = ((start + steps) % 16 + 16) % 16
                    }
                    #expect(got == want, "\(dial) \(start) \(steps)")
                }
            }
        }
        // Angle deltas wrap into −π … π.
        #expect(abs(Handles.angleDelta(from: 3, to: -3) - (2 * Double.pi - 6)) < 1e-12)
        #expect(abs(Handles.angleDelta(from: -3, to: 3) + (2 * Double.pi - 6)) < 1e-12)
        #expect(abs(Handles.angleDelta(from: 0.1, to: 0.3) - 0.2) < 1e-12)
        #expect(Handles.angleDelta(from: Double.nan, to: 1) == 0)
    }

    @Test func fourSpatialHandlesWithDialIds() throws {
        let settings: [LissajousLabyrinthDials] = [
            LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0),
            LissajousLabyrinthDials(frequencyA: 9, frequencyB: 8, phaseA: 15, phaseC: 15),
            LissajousLabyrinthDials(frequencyA: 5, frequencyB: 3, phaseA: 7, phaseC: 12),
        ]
        for level in try Self.levels() {
            for dials in settings {
                let handles: [SpatialHandle] = try Handles.spatialHandles(level: level, dials: dials)
                #expect(handles.count == 4)
                for (i, dial) in LissajousLabyrinthDial.allCases.enumerated() {
                    #expect(handles[i].id == i)
                    #expect(handles[i].kind == HandleKind.rotation(Handles.ringNormal))
                    #expect(handles[i].position == Handles.knob(dial, value: dials[dial], level: level))
                    #expect(handles[i].hitRadius == Handles.hitRadius)
                }
            }
        }
    }

    @Test func pickerPicksEveryProjectedKnob() throws {
        let sizes: [Vec2] = [Vec2(390, 844), Vec2(96, 64), Vec2(1_024, 768)]
        let orbits: [LissajousLabyrinthOrbit] = [
            LissajousLabyrinthOrbit.authored,
            LissajousLabyrinthOrbit(azimuthOffset: LissajousLabyrinthOrbit.azimuthRange.lowerBound,
                                    elevation: LissajousLabyrinthOrbit.elevationRange.upperBound),
            LissajousLabyrinthOrbit(azimuthOffset: LissajousLabyrinthOrbit.azimuthRange.upperBound,
                                    elevation: LissajousLabyrinthOrbit.elevationRange.lowerBound),
        ]
        var random: SeededRandom = SeededRandom(seed: 2_314)
        for level in try Self.levels() {
            let snapshot: LissajousLabyrinthSceneSnapshot = LissajousLabyrinthSceneSnapshot(
                play: LissajousLabyrinthPlay(level: level), time: 0)
            for _ in 0..<4 {
                let dials: LissajousLabyrinthDials = LissajousLabyrinthFixture.dials(&random)
                let handles: [SpatialHandle] = try Handles.spatialHandles(level: level, dials: dials)
                for size in sizes {
                    for orbit in orbits {
                        let vp: Mat4 = Geometry.viewProjection(aspect: size.x / size.y, snapshot: snapshot,
                                                               orbit: orbit)
                        for handle in handles {
                            let point: Vec2? = Geometry.project(handle.position, viewProjection: vp,
                                                                width: Int(size.x), height: Int(size.y))
                            #expect(point != nil)
                            guard let point else { continue }
                            let picked: Int? = try HandlePicker.pick(handles, at: point, viewProjection: vp,
                                                                     viewport: size)
                            #expect(picked == handle.id, "size \(size) orbit \(orbit) handle \(handle.id)")
                        }
                    }
                }
            }
        }
    }
}
