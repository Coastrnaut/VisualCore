// DiskOverlapTests — feature 215 (R02-F15) T-R02F15-005 (FR-R02F15-005; SC-R02F15-004; research R7). The analytic lens
// area against an independent numerical integration: over the smaller disk (radius r, centred at the origin) the
// vertical chord inside both disks is 2·min(h, k), h = √(r² − x²), k = √(R² − (x − d)²). The x range is split where h = k
// and at the larger disk's edges, so each piece integrates a single circle's chord in its own smooth angle
// (x = r·cos φ or x = d + R·cos ψ) with Simpson's rule on 4,096 intervals. Plain loops and explicit types (CI rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct DiskOverlapTests {
    /// The independent oracle: the overlap area by chord integration over the smaller disk (no lens formula).
    private func oracleArea(_ ra: Double, _ rb: Double, _ d: Double) -> Double {
        let r: Double = min(ra, rb)
        let big: Double = max(ra, rb)
        var cuts: [Double] = [-r, r]
        let edges: [Double] = [d - big, d + big]
        for e in edges where e > -r && e < r { cuts.append(e) }
        if d > 0 {
            let x0: Double = (d * d + r * r - big * big) / (2 * d)
            if x0 > -r && x0 < r { cuts.append(x0) }
        }
        cuts.sort()
        var total: Double = 0
        for index in 0..<(cuts.count - 1) {
            let a: Double = cuts[index]
            let b: Double = cuts[index + 1]
            if b - a <= 0 { continue }
            let m: Double = 0.5 * (a + b)
            let h: Double = (r * r - m * m).squareRoot()
            let inBig: Double = big * big - (m - d) * (m - d)
            if inBig <= 0 { continue }
            let k: Double = inBig.squareRoot()
            if h <= k {
                total += chordIntegral(radius: r, center: 0, from: a, to: b)
            } else {
                total += chordIntegral(radius: big, center: d, from: a, to: b)
            }
        }
        return total
    }

    /// ∫ₐᵇ 2·√(R² − (x − c)²) dx with x = c + R·cos ψ: ∫ 2R²·sin²ψ dψ by Simpson's rule on 4,096 intervals.
    private func chordIntegral(radius: Double, center: Double, from a: Double, to b: Double) -> Double {
        let psiHigh: Double = acos(min(1, max(-1, (a - center) / radius)))
        let psiLow: Double = acos(min(1, max(-1, (b - center) / radius)))
        let n: Int = 1_024
        let step: Double = (psiHigh - psiLow) / Double(n)
        var sum: Double = 0
        for i in 0...n {
            let psi: Double = psiLow + Double(i) * step
            let s: Double = sin(psi)
            let f: Double = 2 * radius * radius * s * s
            let weight: Double = (i == 0 || i == n) ? 1 : (i % 2 == 1 ? 4 : 2)
            sum += weight * f
        }
        return sum * step / 3
    }

    @Test func seededPairsMatchChordIntegration() throws {
        var generator = DiskOverlapSplitMix(state: 2_015)
        var worst: Double = 0
        for _ in 0..<1_000 {
            let ra: Double = 0.05 + 2 * generator.unit()
            let rb: Double = 0.05 + 2 * generator.unit()
            let d: Double = (ra + rb) * 1.1 * generator.unit()
            let analytic: Double = try DiskOverlap.area(radiusA: ra, radiusB: rb, distance: d)
            let oracle: Double = oracleArea(ra, rb, d)
            let smaller: Double = min(ra, rb)
            let relative: Double = abs(analytic - oracle) / (Double.pi * smaller * smaller)
            worst = max(worst, relative)
            #expect(relative <= 1e-6, "ra \(ra) rb \(rb) d \(d) analytic \(analytic) oracle \(oracle)")
            let fraction: Double = try DiskOverlap.coveredFraction(sourceRadius: ra, occluderRadius: rb, distance: d)
            #expect(fraction >= 0 && fraction <= 1)
        }
        #expect(worst <= 1e-6)
    }

    @Test func touchingEqualAndNestedDisks() throws {
        #expect(try DiskOverlap.area(radiusA: 1, radiusB: 2, distance: 3) == 0, "externally touching")
        #expect(try DiskOverlap.area(radiusA: 1, radiusB: 2, distance: 5) == 0, "disjoint")
        #expect(abs(try DiskOverlap.area(radiusA: 1.5, radiusB: 1.5, distance: 0) - Double.pi * 2.25) < 1e-14, "equal centred")
        #expect(try DiskOverlap.area(radiusA: 3, radiusB: 1, distance: 1.5) == Double.pi, "nested")
        #expect(try DiskOverlap.area(radiusA: 1, radiusB: 3, distance: 2) == Double.pi, "internally touching")
        #expect(try DiskOverlap.coveredFraction(sourceRadius: 2, occluderRadius: 1, distance: 0) == 0.25)
        #expect(try DiskOverlap.coveredFraction(sourceRadius: 1, occluderRadius: 2, distance: 0.5) == 1)
        #expect(try DiskOverlap.coveredFraction(sourceRadius: 1, occluderRadius: 1, distance: 2) == 0)
        let half: Double = try DiskOverlap.area(radiusA: 1, radiusB: 1, distance: 1)
        #expect(abs(half - (2 * Double.pi / 3 - 0.75.squareRoot())) < 1e-12, "unit disks one radius apart")
    }

    @Test func invalidDisksAreRefused() {
        let radii: [Double] = [0, -1, .nan, .infinity]
        for bad in radii {
            #expect(throws: OrbitError.invalidDisk) { try DiskOverlap.area(radiusA: bad, radiusB: 1, distance: 0) }
            #expect(throws: OrbitError.invalidDisk) { try DiskOverlap.area(radiusA: 1, radiusB: bad, distance: 0) }
            #expect(throws: OrbitError.invalidDisk) {
                try DiskOverlap.coveredFraction(sourceRadius: bad, occluderRadius: 1, distance: 0)
            }
        }
        let distances: [Double] = [-0.1, .nan, .infinity]
        for bad in distances {
            #expect(throws: OrbitError.invalidDisk) { try DiskOverlap.area(radiusA: 1, radiusB: 1, distance: bad) }
        }
        #expect(OrbitError.invalidDisk.reasonCode == "r2-f15.invalid-disk")
    }
}

/// Deterministic generator for the seeded disk pairs (SplitMix64).
fileprivate struct DiskOverlapSplitMix {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A uniform value in [0, 1).
    mutating func unit() -> Double { Double(next() >> 11) * 0x1p-53 }
}
