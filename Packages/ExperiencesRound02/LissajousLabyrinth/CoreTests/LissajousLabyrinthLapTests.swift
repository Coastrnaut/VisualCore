// LissajousLabyrinthLapTests — feature 311 (R02-G02-01) T-R02G0201-003 (FR-R02G0201-002, 003; SC-R02G0201-001). The exact
// lap: 500 seeded safe settings win; every single-dial change from the safe setting on the first 50 levels agrees with an
// independent reference evaluation written here (cross-product contact test in Int64, per-checkpoint forward scan);
// checkpoint and obstacle boundaries at r and one unit either side; the closing segment; checkpoint order; tie order;
// the lap's 4,096-tick period. Test data uses explicit types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import Testing
import VisualCoreSimulation

/// A point of the reference evaluation in Int64.
private struct LapReferencePoint: Equatable {
    let x: Int64
    let y: Int64
    let z: Int64
}

/// The independent reference evaluation: positions from the formula, contact by the squared cross product, checkpoints
/// by a forward scan per checkpoint. It shares only the sine table with the kernel.
private enum LapReference {
    static let ticks: Int = 4_096

    /// x = A·S(a·n + 256·φ), y = B·S(b·n), z = C·S(c·n + 256·ψ + 1,024).
    static func position(_ n: Int, _ dials: LissajousLabyrinthDials, _ level: LissajousLabyrinthLevel) -> LapReferencePoint {
        let x: Int = level.amplitudes[0] * LissajousLabyrinthSine.sin(dials.frequencyA * n + 256 * dials.phaseA)
        let y: Int = level.amplitudes[1] * LissajousLabyrinthSine.sin(dials.frequencyB * n)
        let z: Int = level.amplitudes[2] * LissajousLabyrinthSine.sin(level.frequencyC * n + 256 * dials.phaseC + 1_024)
        return LapReferencePoint(x: Int64(x), y: Int64(y), z: Int64(z))
    }

    static func points(_ dials: LissajousLabyrinthDials, _ level: LissajousLabyrinthLevel) -> [LapReferencePoint] {
        var result: [LapReferencePoint] = []
        result.reserveCapacity(ticks)
        var n: Int = 0
        while n < ticks {
            result.append(position(n, dials, level))
            n += 1
        }
        return result
    }

    static func squaredDistance(_ p: LapReferencePoint, _ cx: Int64, _ cy: Int64, _ cz: Int64) -> Int64 {
        let dx: Int64 = p.x - cx
        let dy: Int64 = p.y - cy
        let dz: Int64 = p.z - cz
        return dx * dx + dy * dy + dz * dz
    }

    /// Inside or on the ball.
    static func inside(_ p: LapReferencePoint, _ ball: LissajousLabyrinthBall) -> Bool {
        let r: Int64 = Int64(ball.radius)
        return squaredDistance(p, Int64(ball.x), Int64(ball.y), Int64(ball.z)) <= r * r
    }

    /// Whether the closest point of p → q to the centre is strictly inside. Interior case: the squared distance to the
    /// line is |w × d|² / |d|², compared as |w × d|² < r²·|d|²; otherwise the nearer endpoint.
    static func touches(_ p: LapReferencePoint, _ q: LapReferencePoint, _ ball: LissajousLabyrinthBall) -> Bool {
        let cx: Int64 = Int64(ball.x)
        let cy: Int64 = Int64(ball.y)
        let cz: Int64 = Int64(ball.z)
        let r: Int64 = Int64(ball.radius)
        let r2: Int64 = r * r
        let dx: Int64 = q.x - p.x
        let dy: Int64 = q.y - p.y
        let dz: Int64 = q.z - p.z
        let wx: Int64 = cx - p.x
        let wy: Int64 = cy - p.y
        let wz: Int64 = cz - p.z
        let dd: Int64 = dx * dx + dy * dy + dz * dz
        let wd: Int64 = wx * dx + wy * dy + wz * dz
        if dd > 0 && wd > 0 && wd < dd {
            let crossX: Int64 = wy * dz - wz * dy
            let crossY: Int64 = wz * dx - wx * dz
            let crossZ: Int64 = wx * dy - wy * dx
            let cross2: Int64 = crossX * crossX + crossY * crossY + crossZ * crossZ
            return cross2 < r2 * dd
        }
        let toP: Int64 = squaredDistance(p, cx, cy, cz)
        let toQ: Int64 = squaredDistance(q, cx, cy, cz)
        return min(toP, toQ) < r2
    }

    /// The first segment tick (closing segment included) that touches `ball`, or nil.
    static func firstTouch(_ pts: [LapReferencePoint], _ ball: LissajousLabyrinthBall) -> Int? {
        var n: Int = 0
        while n < ticks {
            let q: LapReferencePoint = n == ticks - 1 ? pts[0] : pts[n + 1]
            if touches(pts[n], q, ball) { return n }
            n += 1
        }
        return nil
    }

    static func verdict(_ dials: LissajousLabyrinthDials, _ level: LissajousLabyrinthLevel) -> LissajousLabyrinthVerdict {
        let pts: [LapReferencePoint] = points(dials, level)
        // First contact: for each obstacle its own first tick; keep the lowest tick, ties to the lower index.
        var bestTick: Int = Int.max
        var bestObstacle: Int = -1
        var k: Int = 0
        while k < level.obstacles.count {
            if let t = firstTouch(pts, level.obstacles[k]), t < bestTick {
                bestTick = t
                bestObstacle = k
            }
            k += 1
        }
        if bestObstacle >= 0 { return .contact(obstacle: bestObstacle, tick: bestTick) }
        // Checkpoints: each one searched forward from the tick after the previous visit.
        var from: Int = 0
        var i: Int = 0
        while i < level.checkpoints.count {
            var found: Int = -1
            var n: Int = from
            while n < ticks {
                if inside(pts[n], level.checkpoints[i]) {
                    found = n
                    break
                }
                n += 1
            }
            if found < 0 { return .missed(checkpoint: i) }
            from = found + 1
            i += 1
        }
        return .won
    }
}

@Suite struct LissajousLabyrinthLapTests {
    private static func point(_ x: Int, _ y: Int, _ z: Int) -> LissajousLabyrinthPoint {
        LissajousLabyrinthPoint(x: x, y: y, z: z)
    }

    private static func referencePoint(_ p: LissajousLabyrinthPoint) -> LapReferencePoint {
        LapReferencePoint(x: Int64(p.x), y: Int64(p.y), z: Int64(p.z))
    }

    private static func far() throws -> LissajousLabyrinthBall {
        try LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 64)
    }

    private static func level(amplitudes: [Int], frequencyC: Int, start: LissajousLabyrinthDials,
                      checkpoints: [LissajousLabyrinthBall],
                      obstacles: [LissajousLabyrinthBall]) throws -> LissajousLabyrinthLevel {
        try LissajousLabyrinthLevel(id: "lap-test", seed: 3, band: 1, amplitudes: amplitudes, frequencyC: frequencyC,
                                    start: start, checkpoints: checkpoints, obstacles: obstacles, allowance: 8)
    }

    /// Kernel and reference agree on a segment; returns the kernel's answer.
    private static func segment(_ p: LissajousLabyrinthPoint, _ q: LissajousLabyrinthPoint, _ ball: LissajousLabyrinthBall) -> Bool {
        let kernel: Bool = LissajousLabyrinthLap.segmentTouches(p, q, ball: ball)
        let reference: Bool = LapReference.touches(referencePoint(p), referencePoint(q), ball)
        #expect(kernel == reference, "segment \(p) → \(q) ball \(ball)")
        return kernel
    }

    @Test func safeSettingWinsOnFiveHundredSeededLevels() {
        var random = SeededRandom(seed: 2_313)
        var count: Int = 0
        for _ in 0..<500 {
            let f: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            #expect(LissajousLabyrinthLap.verdict(f.safe, level: f.level) == .won)
            count += 1
        }
        #expect(count == 500)
    }

    @Test func everySingleDialChangeAgreesWithTheReference() {
        var random = SeededRandom(seed: 2_313)
        var compared: Int = 0
        var notWon: Int = 0
        var contacts: Int = 0
        var misses: Int = 0
        for _ in 0..<50 {
            let f: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            #expect(LapReference.verdict(f.safe, f.level) == .won)
            for dial in LissajousLabyrinthDial.allCases {
                for value in dial.range where value != f.safe[dial] {
                    var dials: LissajousLabyrinthDials = f.safe
                    dials[dial] = value
                    if !dials.isValid { continue }
                    let kernel: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(dials, level: f.level)
                    let reference: LissajousLabyrinthVerdict = LapReference.verdict(dials, f.level)
                    #expect(kernel == reference, "level \(f.level.fingerprint) dials \(dials)")
                    compared += 1
                    switch reference {
                    case .won: break
                    case .contact:
                        notWon += 1
                        contacts += 1
                    case .missed:
                        notWon += 1
                        misses += 1
                    }
                }
            }
        }
        // 50 levels × at least 30 valid changes each; both losing kinds occur.
        #expect(compared >= 1_500)
        #expect(contacts > 0)
        #expect(misses > 0)
        #expect(notWon > compared / 2)
    }

    @Test func checkpointSurfaceIsInsideAndOneUnitOutIsNot() throws {
        let r: Int = 100
        let centre: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: 10, y: -20, z: 30, radius: r)
        // On the surface along an axis and along a 6-8 (… 10) diagonal: visited; one unit further out: not.
        let onSurface: [LissajousLabyrinthPoint] = [Self.point(10 + r, -20, 30), Self.point(10, -20 - r, 30),
                                                     Self.point(10, -20, 30 + r), Self.point(10 + 60, -20 + 80, 30),
                                                     Self.point(10, -20 - 60, 30 - 80)]
        let outside: [LissajousLabyrinthPoint] = [Self.point(10 + r + 1, -20, 30), Self.point(10, -20 - r - 1, 30),
                                                   Self.point(10, -20, 30 + r + 1), Self.point(10 + 60, -20 + 81, 30),
                                                   Self.point(10, -20 - 61, 30 - 80)]
        let inside: [LissajousLabyrinthPoint] = [Self.point(10 + r - 1, -20, 30), Self.point(10 + 60, -20 + 79, 30)]
        for p in onSurface {
            #expect(LissajousLabyrinthLap.contains(centre, p))
            #expect(LapReference.inside(Self.referencePoint(p), centre))
        }
        for p in inside { #expect(LissajousLabyrinthLap.contains(centre, p)) }
        for p in outside {
            #expect(!LissajousLabyrinthLap.contains(centre, p))
            #expect(!LapReference.inside(Self.referencePoint(p), centre))
        }

        // Through the verdict: sample 0 of (1, 2, 0, 0) with amplitudes 1 is (0, 0, 1,024) and every sample has z ≤ 1,024,
        // so a checkpoint centred at (0, 0, 1,024 + r) is reached only on its surface.
        let dials = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0)
        let start = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 4, phaseC: 0)
        #expect(LissajousLabyrinthLap.position(tick: 0, dials: dials,
                                               level: try Self.level(amplitudes: [1, 1, 1], frequencyC: 1, start: start,
                                                                     checkpoints: [try Self.far()], obstacles: []))
                == Self.point(0, 0, 1_024))
        let onBall: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: 0, y: 0, z: 1_024 + 64, radius: 64)
        let offBall: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: 0, y: 0, z: 1_024 + 65, radius: 64)
        let onLevel: LissajousLabyrinthLevel = try Self.level(amplitudes: [1, 1, 1], frequencyC: 1, start: start,
                                                              checkpoints: [onBall], obstacles: [])
        let offLevel: LissajousLabyrinthLevel = try Self.level(amplitudes: [1, 1, 1], frequencyC: 1, start: start,
                                                               checkpoints: [offBall], obstacles: [])
        #expect(LissajousLabyrinthLap.verdict(dials, level: onLevel) == .won)
        #expect(LapReference.verdict(dials, onLevel) == .won)
        #expect(LissajousLabyrinthLap.verdict(dials, level: offLevel) == .missed(checkpoint: 0))
        #expect(LapReference.verdict(dials, offLevel) == .missed(checkpoint: 0))
    }

    @Test func segmentBoundariesAreExact() throws {
        let r: Int = 100
        let ball: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: 0, y: 0, z: 0, radius: r)
        // Interior closest point, axis-aligned: exactly r → no contact; r − 1 → contact; r + 1 → none.
        #expect(!Self.segment(Self.point(-100, r, 0), Self.point(100, r, 0), ball))
        #expect(Self.segment(Self.point(-100, r - 1, 0), Self.point(100, r - 1, 0), ball))
        #expect(!Self.segment(Self.point(-100, r + 1, 0), Self.point(100, r + 1, 0), ball))
        #expect(!Self.segment(Self.point(0, -300, -r), Self.point(0, 500, -r), ball))
        #expect(Self.segment(Self.point(0, -300, -r + 1), Self.point(0, 500, -r + 1), ball))
        // Interior closest point off-axis: (·, 60, 80) is exactly at 100; (·, 60, 79) is inside.
        #expect(!Self.segment(Self.point(-300, 60, 80), Self.point(300, 60, 80), ball))
        #expect(Self.segment(Self.point(-300, 60, 79), Self.point(300, 60, 79), ball))
        // A slanted segment whose foot is (60, 80, 0): direction (4, −3, 0) is perpendicular to (60, 80, 0).
        #expect(!Self.segment(Self.point(60 - 400, 80 + 300, 0), Self.point(60 + 400, 80 - 300, 0), ball))
        #expect(Self.segment(Self.point(60 - 400, 79 + 300, 0), Self.point(60 + 400, 79 - 300, 0), ball))
        // Endpoint cases: the segment points away, so the closest point is the near endpoint.
        #expect(!Self.segment(Self.point(r, 0, 0), Self.point(r + 200, 0, 0), ball))
        #expect(Self.segment(Self.point(r - 1, 0, 0), Self.point(r + 200, 0, 0), ball))
        #expect(!Self.segment(Self.point(r + 200, 0, 0), Self.point(r, 0, 0), ball))
        #expect(Self.segment(Self.point(r + 200, 0, 0), Self.point(r - 1, 0, 0), ball))
        #expect(!Self.segment(Self.point(60, 80, 0), Self.point(120, 160, 5), ball))
        #expect(Self.segment(Self.point(60, 79, 0), Self.point(120, 160, 5), ball))
        #expect(!Self.segment(Self.point(-120, -160, 7), Self.point(-60, -80, 0), ball))
        #expect(Self.segment(Self.point(-120, -160, 7), Self.point(-60, -79, 0), ball))
        // Zero-length segments.
        #expect(!Self.segment(Self.point(60, 80, 0), Self.point(60, 80, 0), ball))
        #expect(Self.segment(Self.point(60, 79, 0), Self.point(60, 79, 0), ball))
        #expect(Self.segment(Self.point(0, 0, 0), Self.point(0, 0, 0), ball))
        #expect(!Self.segment(Self.point(r, 0, 0), Self.point(r, 0, 0), ball))
        // A segment passing straight through the centre, and one ending at it.
        #expect(Self.segment(Self.point(-500, 0, 0), Self.point(500, 0, 0), ball))
        #expect(Self.segment(Self.point(-500, 0, 0), Self.point(0, 0, 0), ball))
        // Far coordinates (the world's extent): kernel and reference agree exactly.
        let corner: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: 0, y: -5_000, z: 5_000, radius: 1_024)
        #expect(!Self.segment(Self.point(-4_096, -3_976, 5_000), Self.point(4_096, -3_976, 5_000), corner))
        #expect(Self.segment(Self.point(-4_096, -3_977, 5_000), Self.point(4_096, -3_977, 5_000), corner))
        _ = Self.segment(Self.point(-4_096, -4_096, 4_096), Self.point(4_096, 4_096, -4_096), corner)
        _ = Self.segment(Self.point(4_096, -4_096, 4_096), Self.point(4_000, -4_000, 4_000), corner)
    }

    @Test func closingSegmentContactIsReportedAtTick4095() throws {
        // Fast curve (amplitudes 4, frequencies 9, 8, 9): consecutive samples are ~75 units apart, so a radius-64 ball
        // beside the middle of segment 4,095 → 0 touches it without touching the neighbouring segments.
        let dials = LissajousLabyrinthDials(frequencyA: 9, frequencyB: 8, phaseA: 0, phaseC: 0)
        let probe: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 9, start: dials,
                                                            checkpoints: [try Self.far()], obstacles: [])
        let pts: [LapReferencePoint] = LapReference.points(dials, probe)
        let last: LapReferencePoint = pts[4_095]
        let first: LapReferencePoint = pts[0]
        let dx: Double = Double(first.x - last.x)
        let dy: Double = Double(first.y - last.y)
        let dz: Double = Double(first.z - last.z)
        let mx: Double = Double(first.x + last.x) / 2
        let my: Double = Double(first.y + last.y) / 2
        let mz: Double = Double(first.z + last.z) / 2
        // Perpendicular directions: d × each axis, both signs, plus (d × x) × d.
        var directions: [[Double]] = []
        directions.append([0, dz, -dy])
        directions.append([-dz, 0, dx])
        directions.append([dy, -dx, 0])
        let ux: Double = 0
        let uy: Double = dz
        let uz: Double = -dy
        directions.append([uy * dz - uz * dy, uz * dx - ux * dz, ux * dy - uy * dx])
        var chosen: LissajousLabyrinthBall?
        for direction in directions {
            for sign in [1.0, -1.0] {
                let length: Double = (direction[0] * direction[0] + direction[1] * direction[1] +
                                      direction[2] * direction[2]).squareRoot()
                if length == 0 { continue }
                let ball: LissajousLabyrinthBall = try LissajousLabyrinthBall(
                    x: Int((mx + sign * 62 * direction[0] / length).rounded()),
                    y: Int((my + sign * 62 * direction[1] / length).rounded()),
                    z: Int((mz + sign * 62 * direction[2] / length).rounded()), radius: 64)
                if LapReference.firstTouch(pts, ball) == 4_095 {
                    chosen = ball
                    break
                }
            }
            if chosen != nil { break }
        }
        let ball: LissajousLabyrinthBall = try #require(chosen)
        // Only the closing segment touches it.
        #expect(LapReference.touches(last, first, ball))
        #expect(LissajousLabyrinthLap.segmentTouches(LissajousLabyrinthLap.position(tick: 4_095, dials: dials, level: probe),
                                                     LissajousLabyrinthLap.position(tick: 0, dials: dials, level: probe),
                                                     ball: ball))
        let level: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 9, start: dials,
                                                            checkpoints: [try Self.far()], obstacles: [ball])
        #expect(LissajousLabyrinthLap.verdict(dials, level: level) == .contact(obstacle: 0, tick: 4_095))
        #expect(LapReference.verdict(dials, level) == .contact(obstacle: 0, tick: 4_095))
        // With an untouched obstacle listed first, the index is 1.
        let untouched: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: -5_000, y: -5_000, z: -5_000, radius: 64)
        let second: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 9, start: dials,
                                                             checkpoints: [try Self.far()], obstacles: [untouched, ball])
        #expect(LissajousLabyrinthLap.verdict(dials, level: second) == .contact(obstacle: 1, tick: 4_095))
    }

    @Test func checkpointsMustBeVisitedInOrder() throws {
        // (1, 2, 0, 0) with amplitudes 4, c = 1: x = 4·S(n), z = 4·S(n + 1,024) trace a circle of radius 4,096 once, so
        // each sample's neighbourhood is reached only near its own tick (~6.3 units per tick).
        let dials = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0)
        let start = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 8, phaseC: 0)
        let probe: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                            checkpoints: [try Self.far()], obstacles: [])
        let early: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 100, dials: dials, level: probe)
        let late: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 3_000, dials: dials, level: probe)
        let a: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: early.x, y: early.y, z: early.z, radius: 64)
        let b: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: late.x, y: late.y, z: late.z, radius: 64)
        let far: LissajousLabyrinthBall = try Self.far()
        let cases: [([LissajousLabyrinthBall], LissajousLabyrinthVerdict)] = [
            ([a, b], .won), ([b, a], .missed(checkpoint: 1)), ([a, far], .missed(checkpoint: 1)),
            ([far, a], .missed(checkpoint: 0)), ([a, b, far], .missed(checkpoint: 2)), ([a, a], .won),
            ([b, a, b], .missed(checkpoint: 1))
        ]
        for (checkpoints, expected) in cases {
            let level: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                                checkpoints: checkpoints, obstacles: [])
            #expect(LissajousLabyrinthLap.verdict(dials, level: level) == expected)
            #expect(LapReference.verdict(dials, level) == expected)
        }
        // The same ball listed twice is visited twice when two successive samples lie inside it (~20 do here).
        let tight: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 2_000, dials: dials, level: probe)
        let tiny: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: tight.x, y: tight.y, z: tight.z, radius: 64)
        let twice: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                            checkpoints: [tiny, tiny], obstacles: [])
        #expect(LissajousLabyrinthLap.verdict(dials, level: twice) == .won)
        #expect(LapReference.verdict(dials, twice) == .won)

        // Seeded fixtures with their checkpoints reversed agree with the reference.
        var random = SeededRandom(seed: 2_314)
        var reversedMisses: Int = 0
        for _ in 0..<40 {
            let f: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            if f.level.checkpoints.count < 2 { continue }
            let reversed: [LissajousLabyrinthBall] = Array(f.level.checkpoints.reversed())
            guard let level = try? LissajousLabyrinthLevel(id: "reversed", seed: 1, band: 1, amplitudes: f.level.amplitudes,
                                                           frequencyC: f.level.frequencyC, start: f.level.start,
                                                           checkpoints: reversed, obstacles: f.level.obstacles,
                                                           allowance: 8) else { continue }
            let kernel: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(f.safe, level: level)
            #expect(kernel == LapReference.verdict(f.safe, level))
            if case .missed(let index) = kernel {
                #expect(index >= 1)
                reversedMisses += 1
            }
        }
        #expect(reversedMisses > 0)
    }

    @Test func tiesGoToTheLowerObstacleAndContactBeatsMissed() throws {
        let dials = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0)
        let start = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 8, phaseC: 0)
        let probe: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                            checkpoints: [try Self.far()], obstacles: [])
        let pts: [LapReferencePoint] = LapReference.points(dials, probe)
        let s500: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 500, dials: dials, level: probe)
        let s2000: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 2_000, dials: dials, level: probe)
        let x: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: s500.x, y: s500.y, z: s500.z, radius: 64)
        let y: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: s500.x + 1, y: s500.y, z: s500.z, radius: 64)
        let later: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: s2000.x, y: s2000.y, z: s2000.z, radius: 64)
        let tickX: Int = try #require(LapReference.firstTouch(pts, x))
        let tickY: Int = try #require(LapReference.firstTouch(pts, y))
        #expect(tickX < 500)
        // Two obstacles first touched at the same tick: the lower index wins, whichever ball it is.
        let same: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                           checkpoints: [try Self.far()], obstacles: [later, x, x])
        #expect(LissajousLabyrinthLap.verdict(dials, level: same) == .contact(obstacle: 1, tick: tickX))
        #expect(LapReference.verdict(dials, same) == .contact(obstacle: 1, tick: tickX))
        if tickX == tickY {
            for order in [[x, y], [y, x]] {
                let level: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                                    checkpoints: [try Self.far()], obstacles: order)
                #expect(LissajousLabyrinthLap.verdict(dials, level: level) == .contact(obstacle: 0, tick: tickX))
            }
        }
        // The lower tick wins over the lower index.
        let byTick: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                             checkpoints: [try Self.far()], obstacles: [later, y])
        #expect(LissajousLabyrinthLap.verdict(dials, level: byTick) == .contact(obstacle: 1, tick: tickY))
        #expect(LapReference.verdict(dials, byTick) == .contact(obstacle: 1, tick: tickY))
        // Contact is reported in preference to a missed checkpoint.
        #expect(LissajousLabyrinthLap.verdict(dials, level: probe) == .missed(checkpoint: 0))
        let both: LissajousLabyrinthLevel = try Self.level(amplitudes: [4, 4, 4], frequencyC: 1, start: start,
                                                           checkpoints: [try Self.far()], obstacles: [later])
        let tickLater: Int = try #require(LapReference.firstTouch(pts, later))
        #expect(LissajousLabyrinthLap.verdict(dials, level: both) == .contact(obstacle: 0, tick: tickLater))
        #expect(LapReference.verdict(dials, both) == .contact(obstacle: 0, tick: tickLater))
    }

    @Test func theLapClosesAfter4096Ticks() {
        var random = SeededRandom(seed: 2_315)
        let f: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
        let ticks: [Int] = [0, 1, 7, 1_000, 2_048, 4_095]
        for _ in 0..<20 {
            let dials: LissajousLabyrinthDials = LissajousLabyrinthFixture.dials(&random)
            #expect(LissajousLabyrinthLap.position(tick: 4_096, dials: dials, level: f.level)
                    == LissajousLabyrinthLap.position(tick: 0, dials: dials, level: f.level))
            for n in ticks {
                let p: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: n, dials: dials, level: f.level)
                #expect(LissajousLabyrinthLap.position(tick: n + 4_096, dials: dials, level: f.level) == p)
                #expect(LissajousLabyrinthLap.position(tick: n + 2 * 4_096, dials: dials, level: f.level) == p)
                #expect(Self.referencePoint(p) == LapReference.position(n, dials, f.level))
            }
            let samples: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(dials, level: f.level)
            #expect(samples.count == LissajousLabyrinthLap.ticks)
            #expect(samples[0] == LissajousLabyrinthLap.position(tick: 4_096, dials: dials, level: f.level))
        }
    }
}
