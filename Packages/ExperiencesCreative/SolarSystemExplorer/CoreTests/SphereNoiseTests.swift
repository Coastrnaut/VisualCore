// SphereNoiseTests — feature 105 (A14-P03) T-A14-302 (FR-A14-301; SC-A14-301; clarification Q1; research D1). The
// seeded 3D value noise, host-free and short: every value lies in [0, 1] over many directions; two instances with one
// seed agree exactly and different seeds differ; equal directions give equal values (scaled vectors, longitude 0 and
// 2π, every vertex of a pole row); non-finite and zero inputs give 0.5.
import Foundation
import SolarSystemExplorerCore
import Testing
import VisualCoreMath

@Suite struct SphereNoiseTests {
    /// A spread of directions on a 64 × 32 longitude/latitude grid (poles included).
    private static func directions() -> [Vec3] {
        var result: [Vec3] = []
        for j in 0...32 {
            let theta = Double(j) / 32 * Double.pi
            for i in 0..<64 {
                let phi = Double(i) / 64 * 2 * Double.pi
                result.append(Vec3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi)))
            }
        }
        return result
    }

    @Test func valuesStayInTheUnitRange() {
        let noise = SphereNoise(seed: 0xA14_0003, frequency: 2.5)
        var low: Double = 1
        var high: Double = 0
        for direction in SphereNoiseTests.directions() {
            let v: Double = noise.value(at: direction)
            #expect(v >= 0 && v <= 1, "\(direction)")
            low = min(low, v); high = max(high, v)
        }
        #expect(high - low > 0.1, "the noise varies over the sphere")
    }

    @Test func sameSeedIsDeterministicAndSeedsDiffer() {
        let a = SphereNoise(seed: 42, frequency: 3)
        let b = SphereNoise(seed: 42, frequency: 3)
        let c = SphereNoise(seed: 43, frequency: 3)
        var differing: Int = 0
        let directions: [Vec3] = SphereNoiseTests.directions()
        for direction in directions {
            let va: Double = a.value(at: direction)
            let vb: Double = b.value(at: direction)
            #expect(va == vb)
            if va != c.value(at: direction) { differing += 1 }
        }
        #expect(differing > directions.count / 2)
        #expect(a == b && a != c)
        #expect(SphereNoise.octaves == 4 && SphereNoise.lacunarity == 2 && SphereNoise.gain == 0.5)
    }

    @Test func equalDirectionsGiveEqualValues() {
        let noise = SphereNoise(seed: 0xA14_0005, frequency: 3)
        for direction in SphereNoiseTests.directions() {
            let v: Double = noise.value(at: direction)
            #expect(noise.value(at: direction * 6_371) == v)
            #expect(noise.value(at: direction * 0.0093) == v)
        }
        for j in 0...24 {
            let theta = Double(j) / 24 * Double.pi
            let atZero = Vec3(sin(theta) * sin(0.0), cos(theta), sin(theta) * cos(0.0))
            let atTwoPi = Vec3(sin(theta) * sin(2 * Double.pi), cos(theta), sin(theta) * cos(2 * Double.pi))
            #expect(noise.value(at: atZero) == noise.value(at: atTwoPi), "ring \(j)")
        }
        for theta in [0.0, Double.pi] {
            let first: Double = noise.value(at: Vec3(0, cos(theta), sin(theta)))
            for i in 0...48 {
                let phi = Double(i) / 48 * 2 * Double.pi
                let p = Vec3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                #expect(noise.value(at: p) == first, "pole \(theta) column \(i)")
            }
        }
    }

    @Test func nonFiniteAndZeroInputsGiveOneHalf() {
        let noise = SphereNoise(seed: 7)
        let bad: [Vec3] = [Vec3(.nan, 0, 1), Vec3(0, .infinity, 0), Vec3(-.infinity, 1, 1), Vec3(0, 0, 0)]
        for p in bad {
            #expect(noise.value(at: p) == 0.5)
        }
        #expect(SphereNoise(seed: 1, frequency: .nan).frequency == 1)
        #expect(SphereNoise(seed: 1, frequency: -2).frequency == 1)
    }
}
