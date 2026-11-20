// LissajousLabyrinthLap — feature 311 (R02-G02-01) T-R02G0201-002 (FR-R02G0201-002, 003; clarifications Q1, Q2; research
// R2–R4). The exact lap of the tracer: 4,096 ticks of 1/240 s; at tick n the tracer is x = A·S(a·n + 256·φ),
// y = B·S(b·n), z = C·S(c·n + 256·ψ + 1,024). Checkpoints are visited in order (a sample inside or on the ball); every
// segment between consecutive samples, the closing one included, is tested for contact with each obstacle (closest point
// strictly inside), exactly in integers.

/// A point of the tracer in integer world units.
public struct LissajousLabyrinthPoint: Sendable, Equatable, Hashable, Codable {
    /// x.
    public let x: Int
    /// y.
    public let y: Int
    /// z.
    public let z: Int

    /// A point of the given coordinates.
    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// The verdict of a lap.
public enum LissajousLabyrinthVerdict: Sendable, Equatable, Hashable {
    /// Every checkpoint was visited in order and no obstacle was touched.
    case won
    /// The first contact: the obstacle's index and the tick of the segment's start (lowest tick, then lowest obstacle).
    case contact(obstacle: Int, tick: Int)
    /// No contact, but checkpoint `checkpoint` (its index) was not reached in order.
    case missed(checkpoint: Int)
}

/// The exact lap evaluation of Lissajous Labyrinth.
public enum LissajousLabyrinthLap {
    /// Ticks per lap (the fundamental period with coprime frequencies).
    public static let ticks = 4_096
    /// Seconds per tick (1/240 s, the source's 0.004167 s).
    public static let secondsPerTick = 1.0 / 240.0
    /// Angle units per phase step (a sixteenth of a turn).
    public static let phaseStep = 256

    /// The tracer's position at `tick` for `dials` on `level`.
    public static func position(tick: Int, dials: LissajousLabyrinthDials,
                                level: LissajousLabyrinthLevel) -> LissajousLabyrinthPoint {
        let x = level.amplitudes[0] * LissajousLabyrinthSine.sin(dials.frequencyA * tick + phaseStep * dials.phaseA)
        let y = level.amplitudes[1] * LissajousLabyrinthSine.sin(dials.frequencyB * tick)
        let z = level.amplitudes[2] * LissajousLabyrinthSine.cos(level.frequencyC * tick + phaseStep * dials.phaseC)
        return LissajousLabyrinthPoint(x: x, y: y, z: z)
    }

    /// The 4,096 samples of one lap.
    /// The table is read through one buffer for the whole lap, so concurrent laps do not contend on the shared array's
    /// reference count; the values equal ``position(tick:dials:level:)`` at every tick.
    public static func samples(_ dials: LissajousLabyrinthDials,
                               level: LissajousLabyrinthLevel) -> [LissajousLabyrinthPoint] {
        let amplitudeX = level.amplitudes[0], amplitudeY = level.amplitudes[1], amplitudeZ = level.amplitudes[2]
        let a = dials.frequencyA, b = dials.frequencyB, c = level.frequencyC
        let offsetX = phaseStep * dials.phaseA
        let offsetZ = phaseStep * dials.phaseC + LissajousLabyrinthSine.unitsPerTurn / 4
        let mask = LissajousLabyrinthSine.mask
        return LissajousLabyrinthSine.table.withUnsafeBufferPointer { table in
            var result: [LissajousLabyrinthPoint] = []
            result.reserveCapacity(ticks)
            for n in 0..<ticks {
                let x = amplitudeX * Int(table[(a * n + offsetX) & mask])
                let y = amplitudeY * Int(table[(b * n) & mask])
                let z = amplitudeZ * Int(table[(c * n + offsetZ) & mask])
                result.append(LissajousLabyrinthPoint(x: x, y: y, z: z))
            }
            return result
        }
    }

    /// Whether `point` lies inside or on `ball` (squared distance ≤ r²).
    public static func contains(_ ball: LissajousLabyrinthBall, _ point: LissajousLabyrinthPoint) -> Bool {
        let dx = point.x - ball.x
        let dy = point.y - ball.y
        let dz = point.z - ball.z
        return dx * dx + dy * dy + dz * dz <= ball.radius * ball.radius
    }

    /// Whether the segment p → q touches `ball`: its closest point to the centre is strictly inside (squared distance < r²),
    /// decided exactly in integers without division.
    public static func segmentTouches(_ p: LissajousLabyrinthPoint, _ q: LissajousLabyrinthPoint,
                                      ball: LissajousLabyrinthBall) -> Bool {
        let r2 = ball.radius * ball.radius
        let dx = q.x - p.x, dy = q.y - p.y, dz = q.z - p.z
        let wx = ball.x - p.x, wy = ball.y - p.y, wz = ball.z - p.z
        let wd = wx * dx + wy * dy + wz * dz
        let ww = wx * wx + wy * wy + wz * wz
        if wd <= 0 { return ww < r2 }
        let dd = dx * dx + dy * dy + dz * dz
        if wd >= dd {
            let ex = ball.x - q.x, ey = ball.y - q.y, ez = ball.z - q.z
            return ex * ex + ey * ey + ez * ez < r2
        }
        // Closest point inside the segment: |w|² − (w·d)²/|d|² < r²  ⇔  |w|²·|d|² − (w·d)² < r²·|d|².
        return ww * dd - wd * wd < r2 * dd
    }

    /// The verdict of the lap of `dials` on `level`: the first contact (by tick, then obstacle), else the first checkpoint
    /// not reached in order, else won.
    public static func verdict(_ dials: LissajousLabyrinthDials,
                               level: LissajousLabyrinthLevel) -> LissajousLabyrinthVerdict {
        let points = samples(dials, level: level)
        let obstacles = level.obstacles
        if !obstacles.isEmpty {
            for n in 0..<ticks {
                let p = points[n]
                let q = points[n + 1 == ticks ? 0 : n + 1]
                for index in 0..<obstacles.count where segmentTouches(p, q, ball: obstacles[index]) {
                    return .contact(obstacle: index, tick: n)
                }
            }
        }
        var next = 0
        for n in 0..<ticks where next < level.checkpoints.count {
            if contains(level.checkpoints[next], points[n]) { next += 1 }
        }
        return next == level.checkpoints.count ? .won : .missed(checkpoint: next)
    }
}
