// ApsidesWorkshopFixed — feature 471 (R02-G18-01) T-R02G1801-002 (FR-R02G1801-003, 014; SC-R02G1801-003;
// clarification Q1; research R2). Deterministic integer fixed point for Apsides Workshop's orbit: `Int64` values with
// 2^30 as one; sine and cosine by range reduction to a quarter turn and integer polynomials; an integer square root;
// and Kepler's equation M = E − e·sin E inverted by at most 8 Newton steps from E = M + e·sin M (stopping when the
// residual is at most 2^−24) with a 48-step bisection on [M − e, M + e] as the fallback. Only integer operations are
// used, so every device computes the same anomaly bit for bit; no platform floating point decides anything.

/// Integer fixed-point arithmetic with 2^30 as one.
public enum ApsidesWorkshopFixed {
    /// The fixed-point one, 2^30.
    public static let one: Int64 = 1 << 30
    /// π in fixed point (π · 2^30, rounded).
    public static let pi: Int64 = 3_373_259_426
    /// 2π in fixed point.
    public static let twoPi: Int64 = 6_746_518_852
    /// π/2 in fixed point.
    public static let halfPi: Int64 = 1_686_629_713
    /// The residual at which Newton's iteration stops, 2^−24.
    public static let newtonTolerance: Int64 = 1 << 6
    /// The bound every tick's residual stays within, 2^−22.
    public static let residualBound: Int64 = 1 << 8
    /// The most Newton steps before the bisection fallback.
    public static let newtonSteps: Int = 8
    /// The bisection steps of the fallback.
    public static let bisectionSteps: Int = 48
    /// sin(15j°) for j = 0 … 6 in fixed point: an exact quarter-turn table (sin 0 = 0, sin 90° = one, and sin 45° is
    /// also cos 45°), so turns by multiples of 15° are symmetric and quarter turns are exact.
    public static let quarterTurnSines: [Int64] = [0, 277_904_834, 536_870_912, 759_250_125, 929_887_697,
                                                    1_037_154_959, 1_073_741_824]

    /// The product of two fixed-point values, rounded half up: (a · b + 2^29) >> 30. Both factors stay below 2^32 in
    /// magnitude here, so the product fits.
    public static func mul(_ a: Int64, _ b: Int64) -> Int64 {
        (a * b + (1 << 29)) >> 30
    }

    /// `value` shifted right by `bits`, rounded half away from zero.
    public static func roundShift(_ value: Int64, _ bits: Int64) -> Int64 {
        let half: Int64 = 1 << (bits - 1)
        return value >= 0 ? (value + half) >> bits : -((-value + half) >> bits)
    }

    /// The sine of `angle` (radians in fixed point).
    public static func sin(_ angle: Int64) -> Int64 {
        let (quadrant, r) = reduce(angle)
        switch quadrant {
        case 0: return sinPolynomial(r)
        case 1: return cosPolynomial(r)
        case 2: return -sinPolynomial(r)
        default: return -cosPolynomial(r)
        }
    }

    /// The cosine of `angle` (radians in fixed point).
    public static func cos(_ angle: Int64) -> Int64 {
        let (quadrant, r) = reduce(angle)
        switch quadrant {
        case 0: return cosPolynomial(r)
        case 1: return -sinPolynomial(r)
        case 2: return -cosPolynomial(r)
        default: return sinPolynomial(r)
        }
    }

    /// The square root of a fixed-point value in 0 … one (negative values give 0).
    public static func sqrt(_ value: Int64) -> Int64 {
        guard value > 0 else { return 0 }
        return Int64(integerSquareRoot(UInt64(value) << 30))
    }

    /// The (cosine, sine) of a turn by `15 · step` degrees, `step` 0 … 23, from the exact quarter-turn table.
    public static func turn(_ step: Int) -> (cos: Int64, sin: Int64) {
        let quadrant: Int = (step / 6) % 4
        let j: Int = step % 6
        let c: Int64 = quarterTurnSines[6 - j]
        let s: Int64 = quarterTurnSines[j]
        switch quadrant {
        case 0: return (c, s)
        case 1: return (-s, c)
        case 2: return (-c, -s)
        default: return (s, -c)
        }
    }

    /// The mean anomaly of tick `tick` of a revolution of `period` ticks: (2π · tick) / period, truncated.
    public static func meanAnomaly(tick: Int, period: Int) -> Int64 {
        twoPi * Int64(tick) / Int64(period)
    }

    /// The eccentric anomaly E solving M = E − e·sin E for a mean anomaly `mean` in 0 … 2π and an eccentricity
    /// `eccentricity` in 0 … 0.75 (fixed point), with the residual |M − (E − e·sin E)| of the result, the Newton steps
    /// taken and whether the bisection fallback decided E.
    public static func eccentricAnomaly(mean: Int64, eccentricity: Int64) -> (anomaly: Int64, residual: Int64,
                                                                            newtonSteps: Int, bisected: Bool) {
        let low: Int64 = mean - eccentricity
        let high: Int64 = mean + eccentricity
        func f(_ e: Int64) -> Int64 { e - mul(eccentricity, sin(e)) - mean }
        var anomaly: Int64 = mean + mul(eccentricity, sin(mean))
        var steps = 0
        var converged = false
        while steps < newtonSteps {
            let value: Int64 = f(anomaly)
            if abs(value) <= newtonTolerance { converged = true; break }
            let slope: Int64 = one - mul(eccentricity, cos(anomaly))
            anomaly -= (value << 30) / slope
            steps += 1
            if anomaly < low || anomaly > high { break }
        }
        if !converged && steps == newtonSteps && anomaly >= low && anomaly <= high
            && abs(f(anomaly)) <= newtonTolerance {
            converged = true
        }
        if converged {
            return (anomaly, abs(f(anomaly)), steps, false)
        }
        // The fallback: f is increasing (its slope 1 − e·cos E stays above 1/4), so the bracket halves to the root.
        var lo: Int64 = low
        var hi: Int64 = high
        for _ in 0..<bisectionSteps {
            let mid: Int64 = lo + (hi - lo) / 2
            if f(mid) < 0 { lo = mid } else { hi = mid }
        }
        let best: Int64 = abs(f(lo)) <= abs(f(hi)) ? lo : hi
        return (best, abs(f(best)), steps, true)
    }

    /// The angle reduced to a quadrant 0 … 3 and a remainder within ±π/4: angle = quadrant · π/2 + remainder (mod 2π).
    static func reduce(_ angle: Int64) -> (Int, Int64) {
        var a: Int64 = angle % twoPi
        if a < 0 { a += twoPi }
        // The nearest multiple of π/2, rounding half up.
        let k: Int64 = (a + halfPi / 2) / halfPi
        let r: Int64 = a - k * halfPi
        return (Int(k % 4), r)
    }

    /// sin r for |r| ≤ π/4 by its series to r^11, evaluated in fixed point (error far below 2^−26).
    static func sinPolynomial(_ r: Int64) -> Int64 {
        let r2: Int64 = mul(r, r)
        var t: Int64 = one - r2 / 110
        t = one - mul(r2, t) / 72
        t = one - mul(r2, t) / 42
        t = one - mul(r2, t) / 20
        t = one - mul(r2, t) / 6
        return mul(r, t)
    }

    /// cos r for |r| ≤ π/4 by its series to r^10, evaluated in fixed point (error far below 2^−26).
    static func cosPolynomial(_ r: Int64) -> Int64 {
        let r2: Int64 = mul(r, r)
        var t: Int64 = one - r2 / 90
        t = one - mul(r2, t) / 56
        t = one - mul(r2, t) / 30
        t = one - mul(r2, t) / 12
        return one - mul(r2, t) / 2
    }

    /// ⌊√n⌋ by integer Newton iteration.
    static func integerSquareRoot(_ n: UInt64) -> UInt64 {
        guard n > 1 else { return n }
        var x: UInt64 = 1 << ((64 - UInt64(n.leadingZeroBitCount)) / 2 + 1)
        while true {
            let y: UInt64 = (x + n / x) / 2
            if y >= x { break }
            x = y
        }
        while x * x > n { x -= 1 }
        while (x + 1) * (x + 1) <= n { x += 1 }
        return x
    }
}
