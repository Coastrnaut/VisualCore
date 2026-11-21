// HueCompassDialTests — feature 334 (R02-G04-04) T-R02G0404-002 (FR-R02G0404-001, 002; SC-R02G0404-001; clarifications
// Q1, Q2). The dial against independent computations: the projected centre equals the origin pushed through the
// view-projection matrix by hand, at every orbit limit and aspect; the hub radius is the largest projected rim distance
// of the 0.3-unit disc (checked against 720 rim samples) and never under 30 points at small sizes; the angle convention
// (right 0, up +π/2, left π, down −π/2 in screen-up terms) and the 20-point dead zone; the wrapping table into −47 … 48;
// accumulation across the ±π seam; half-step rounding away from zero; and 300 seeded swipes (start angle, sweep up to
// ±1.5 turns, radius, point count) whose accumulated angle gives exactly the steps of their sweep. Plain loops and
// explicit types (CI type-check rule); seed 2_334.
import Foundation
import Testing
@testable import HueCompassCore
import VisualCoreMath

@Suite struct HueCompassDialTests {
    typealias Dial = HueCompassDial
    typealias Geometry = HueCompassSceneGeometry

    /// The test seed.
    static let seed: UInt64 = 2_334

    /// The orbits at every limit and the authored one.
    static func limitOrbits() -> [HueCompassOrbit] {
        let yaws: [Double] = [-HueCompassOrbit.yawLimit, 0, HueCompassOrbit.yawLimit]
        let tilts: [Double] = [HueCompassOrbit.tiltRange.lowerBound, HueCompassOrbit.authored.tilt,
                               HueCompassOrbit.tiltRange.upperBound]
        var result: [HueCompassOrbit] = []
        for yaw in yaws {
            for tilt in tilts { result.append(HueCompassOrbit(yaw: yaw, tilt: tilt)) }
        }
        return result
    }

    /// `world` projected by hand: clip = viewProjection · (world, 1), NDC = clip.xy / clip.w, then points with the
    /// origin top left and y down.
    static func handProjected(_ world: SIMD3<Double>, camera: HueCompassCamera, size: SIMD2<Double>) -> SIMD2<Double> {
        let clip: Vec4 = camera.viewProjection * Vec4(world.x, world.y, world.z, 1)
        let nx: Double = clip.x / clip.w
        let ny: Double = clip.y / clip.w
        return SIMD2((nx + 1) / 2 * size.x, (1 - ny) / 2 * size.y)
    }

    /// A uniform double in 0 ..< 1.
    static func unit(_ random: inout HueCompassRandom) -> Double {
        Double(random.next() >> 11) / 9_007_199_254_740_992
    }

    @Test func centreIsTheProjectedOrigin() {
        let sizes: [SIMD2<Double>] = [SIMD2(400, 1_000), SIMD2(768, 1_024), SIMD2(1_152, 768), SIMD2(1_000, 400)]
        for orbit in Self.limitOrbits() {
            for size in sizes {
                let camera: HueCompassCamera = Geometry.camera(aspect: size.x / size.y, orbit: orbit)
                let expected: SIMD2<Double> = Self.handProjected(.zero, camera: camera, size: size)
                if let centre = Dial.centre(camera: camera, size: size) {
                    #expect(abs(centre.x - expected.x) < 1e-9 && abs(centre.y - expected.y) < 1e-9)
                    // The camera looks at the origin, so the centre is the middle of the view.
                    #expect(abs(centre.x - size.x / 2) < 1e-6 && abs(centre.y - size.y / 2) < 1e-6)
                } else {
                    Issue.record("no centre for \(orbit) at \(size)")
                }
            }
        }
        let camera: HueCompassCamera = Geometry.camera(aspect: 1)
        #expect(Dial.centre(camera: camera, size: SIMD2(0, 100)) == nil)
        #expect(Dial.centre(camera: camera, size: SIMD2(100, -1)) == nil)
        #expect(Dial.centre(camera: camera, size: SIMD2(.nan, 100)) == nil)
        #expect(Dial.centre(camera: camera, size: SIMD2(.infinity, 100)) == nil)
    }

    @Test func hubRadiusIsTheProjectedDiscAndAtLeastThirtyPoints() {
        #expect(Dial.deadZone == 20 && Dial.tapDistance == 10 && Dial.minimumHubRadius == 30)
        #expect(Dial.hubWorldRadius == 0.3)
        let sizes: [SIMD2<Double>] = [SIMD2(768, 1_024), SIMD2(1_152, 768), SIMD2(2_000, 800), SIMD2(800, 2_000)]
        for orbit in Self.limitOrbits() {
            for size in sizes {
                let camera: HueCompassCamera = Geometry.camera(aspect: size.x / size.y, orbit: orbit)
                let centre: SIMD2<Double> = Self.handProjected(.zero, camera: camera, size: size)
                var exact: Double = 0
                for k in 0..<720 {
                    let a: Double = 2 * Double.pi * Double(k) / 720
                    let rim: SIMD2<Double> = Self.handProjected(SIMD3(cos(a), sin(a), 0) * 0.3, camera: camera,
                                                                size: size)
                    let d: SIMD2<Double> = rim - centre
                    exact = max(exact, (d.x * d.x + d.y * d.y).squareRoot())
                }
                let hub: Double = Dial.hubRadius(camera: camera, size: size)
                let expected: Double = max(exact, 30)
                #expect(hub <= expected + 1e-9, "hub \(hub) above \(expected) for \(orbit) at \(size)")
                #expect(hub >= expected * 0.98, "hub \(hub) below \(expected) for \(orbit) at \(size)")
            }
        }
        // Small views: the projected disc is a few points, the hub stays 30.
        let small: [SIMD2<Double>] = [SIMD2(40, 40), SIMD2(60, 100), SIMD2(100, 60), SIMD2(120, 120)]
        for orbit in Self.limitOrbits() {
            for size in small {
                let camera: HueCompassCamera = Geometry.camera(aspect: size.x / size.y, orbit: orbit)
                #expect(Dial.hubRadius(camera: camera, size: size) == 30)
            }
        }
        #expect(Dial.hubRadius(camera: Geometry.camera(aspect: 1), size: SIMD2(0, 0)) == 30)
    }

    @Test func angleConventionAndDeadZone() {
        let c: SIMD2<Double> = SIMD2(200, 300)
        let cases: [(SIMD2<Double>, Double)] = [(SIMD2(300, 300), 0), (SIMD2(200, 200), Double.pi / 2),
                                                (SIMD2(100, 300), Double.pi), (SIMD2(200, 400), -Double.pi / 2),
                                                (SIMD2(250, 250), Double.pi / 4), (SIMD2(150, 350), -3 * Double.pi / 4)]
        for (point, expected) in cases {
            if let a = Dial.angle(of: point, centre: c) {
                #expect(abs(a - expected) < 1e-12, "angle of \(point) is \(a), expected \(expected)")
            } else {
                Issue.record("no angle for \(point)")
            }
        }
        // Counter-clockwise on screen (right, then up) increases the angle.
        if let right = Dial.angle(of: SIMD2(260, 299), centre: c), let up = Dial.angle(of: SIMD2(240, 260), centre: c) {
            #expect(up > right)
        } else {
            Issue.record("no angle for the counter-clockwise pair")
        }
        // The dead zone: closer than 20 points has no angle; exactly 20 has one.
        #expect(Dial.angle(of: c, centre: c) == nil)
        #expect(Dial.angle(of: SIMD2(219.999, 300), centre: c) == nil)
        #expect(Dial.angle(of: SIMD2(212, 316), centre: c) != nil)   // 12² + 16² = 400: exactly 20 points
        #expect(Dial.angle(of: SIMD2(211, 316), centre: c) == nil)
        #expect(Dial.angle(of: SIMD2(220, 300), centre: c) != nil)
        #expect(Dial.angle(of: SIMD2(200, 279), centre: c) != nil)
        #expect(Dial.angle(of: SIMD2(.nan, 300), centre: c) == nil)
        #expect(Dial.angle(of: SIMD2(400, 300), centre: SIMD2(.infinity, 0)) == nil)
    }

    @Test func wrappingTable() {
        let table: [(Int, Int)] = [(0, 0), (1, 1), (-1, -1), (47, 47), (48, 48), (-47, -47), (-48, 48), (49, -47),
                                   (-49, 47), (95, -1), (-95, 1), (96, 0), (-96, 0), (97, 1), (144, 48), (-144, 48),
                                   (192, 0), (1_000, 40), (-1_000, -40), (Int.max, 31), (Int.min, -32)]
        for (input, expected) in table {
            #expect(Dial.wrapped(input) == expected, "wrapped(\(input)) = \(Dial.wrapped(input)), expected \(expected)")
        }
        for s in -400...400 {
            let w: Int = Dial.wrapped(s)
            #expect(w >= -47 && w <= 48)
            #expect((s - w) % 96 == 0)
        }
    }

    @Test func accumulateTakesTheShortestWayAcrossTheSeam() {
        let pi: Double = Double.pi
        let cases: [(Double, Double, Double)] = [(0, 0.1, 0.1), (0.1, 0, -0.1), (3.1, -3.1, 2 * pi - 6.2),
                                                 (-3.1, 3.1, 6.2 - 2 * pi), (pi - 0.05, -pi + 0.05, 0.1),
                                                 (-pi + 0.05, pi - 0.05, -0.1), (0, pi, pi), (0, -pi, pi),
                                                 (pi / 2, -pi / 2, pi), (1, 1 + 4 * pi + 0.2, 0.2)]
        for (previous, current, expected) in cases {
            let d: Double = Dial.accumulate(previous: previous, current: current)
            #expect(abs(d - expected) < 1e-9, "accumulate(\(previous), \(current)) = \(d), expected \(expected)")
            #expect(d > -pi && d <= pi)
        }
        #expect(Dial.accumulate(previous: .nan, current: 1) == 0)
        #expect(Dial.accumulate(previous: 0, current: .infinity) == 0)
        // A full circle of 64 points from the left (angle π) accumulates one whole turn, crossing the seam twice.
        var total: Double = 0
        var previous: Double = pi
        for k in 1...64 {
            let a: Double = atan2(sin(pi + 2 * pi * Double(k) / 64), cos(pi + 2 * pi * Double(k) / 64))
            total += Dial.accumulate(previous: previous, current: a)
            previous = a
        }
        #expect(abs(total - 2 * pi) < 1e-9)
    }

    @Test func stepsRoundToTheNearestBearingHalfStepsAwayFromZero() {
        let step: Double = 2 * Double.pi / 96
        let cases: [(Double, Int)] = [(0, 0), (0.49, 0), (0.5, 1), (0.51, 1), (-0.49, 0), (-0.5, -1), (-0.51, -1),
                                      (1.5, 2), (-1.5, -2), (2.5, 3), (48, 48), (96, 96), (144.5, 145), (-144.5, -145)]
        for (bearings, expected) in cases {
            // Built from exact step multiples; the half-step cases are checked on both sides of the boundary below.
            let s: Int = Dial.steps(forAngle: bearings * step)
            if abs(bearings - bearings.rounded(.down) - 0.5) > 1e-9 {
                #expect(s == expected, "steps(\(bearings) bearings) = \(s), expected \(expected)")
            }
        }
        // Exactly half a step: rounds away from zero (the documented rule).
        let halves: [Double] = [0.5, 1.5, 2.5, 47.5, 95.5]
        for h in halves {
            let up: Double = (h * step).nextUp
            let down: Double = (h * step).nextDown
            #expect(Dial.steps(forAngle: up) == Int(h.rounded(.up)))
            #expect(Dial.steps(forAngle: -up) == -Int(h.rounded(.up)))
            #expect(Dial.steps(forAngle: down) >= Int(h.rounded(.down)))
        }
        #expect(Dial.steps(forAngle: Double.pi) == 48)
        #expect(Dial.steps(forAngle: -Double.pi) == -48)
        #expect(Dial.steps(forAngle: 2 * Double.pi) == 96)
        #expect(Dial.steps(forAngle: .nan) == 0)
        #expect(Dial.steps(forAngle: .infinity) == 0)
        #expect(Dial.steps(forAngle: 1e300) == 9_007_199_254_740_992)
    }

    @Test func seededSwipesGiveTheStepsOfTheirSweep() {
        var random: HueCompassRandom = HueCompassRandom(seed: Self.seed)
        let c: SIMD2<Double> = SIMD2(384, 512)
        var checked: Int = 0
        for _ in 0..<300 {
            let start: Double = (Self.unit(&random) * 2 - 1) * Double.pi
            let sweep: Double = (Self.unit(&random) * 2 - 1) * 3 * Double.pi
            let radius: Double = 25 + Self.unit(&random) * 300
            let count: Int = random.int(8...120)
            var total: Double = 0
            var previous: Double? = nil
            for k in 0...count {
                let a: Double = start + sweep * Double(k) / Double(count)
                let p: SIMD2<Double> = SIMD2(c.x + radius * cos(a), c.y - radius * sin(a))
                guard let current = Dial.angle(of: p, centre: c) else {
                    Issue.record("point outside the dead zone had no angle")
                    continue
                }
                if let previous { total += Dial.accumulate(previous: previous, current: current) }
                previous = current
            }
            #expect(abs(total - sweep) < 1e-9)
            let exact: Double = sweep * 96 / (2 * Double.pi)
            if abs(abs(exact - exact.rounded(.down)) - 0.5) < 1e-6 { continue }
            let expected: Int = Int(exact.rounded())
            #expect(Dial.steps(forAngle: total) == expected)
            let w: Int = Dial.wrapped(expected)
            #expect(Dial.wrapped(Dial.steps(forAngle: total)) == w && w >= -47 && w <= 48)
            checked += 1
        }
        #expect(checked >= 290)
        // Points inside the dead zone add nothing: a swipe through the centre keeps only the outer points' angles.
        let through: [SIMD2<Double>] = [SIMD2(c.x + 100, c.y), SIMD2(c.x + 10, c.y), SIMD2(c.x, c.y),
                                        SIMD2(c.x - 10, c.y - 1), SIMD2(c.x - 100, c.y - 30)]
        var angles: [Double] = []
        for p in through {
            if let a = Dial.angle(of: p, centre: c) { angles.append(a) }
        }
        #expect(angles.count == 2)
    }
}
