// KeplerOrbitTests — feature 104 (A14-P02) T-A14-202 (FR-A14-201, FR-A14-202; SC-A14-202; gap G-ORBIT; research D1).
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct KeplerOrbitTests {
    private func orbit(a: Double = 1, e: Double = 0, i: Double = 0, node: Double = 0, peri: Double = 0,
                       m0: Double = 0, n: Double = 1) -> KeplerOrbit {
        KeplerOrbit(semiMajorAxis: a, eccentricity: e, inclination: i, ascendingNode: node,
                    argumentOfPeriapsis: peri, meanAnomalyAtEpoch: m0, meanMotion: n)!
    }

    // MARK: Construction

    @Test func initRefusesInvalidElements() {
        #expect(KeplerOrbit(semiMajorAxis: 1, eccentricity: 1, inclination: 0, ascendingNode: 0,
                            argumentOfPeriapsis: 0, meanAnomalyAtEpoch: 0, meanMotion: 1) == nil, "e = 1")
        #expect(KeplerOrbit(semiMajorAxis: 1, eccentricity: -0.1, inclination: 0, ascendingNode: 0,
                            argumentOfPeriapsis: 0, meanAnomalyAtEpoch: 0, meanMotion: 1) == nil, "e < 0")
        #expect(KeplerOrbit(semiMajorAxis: 0, eccentricity: 0.1, inclination: 0, ascendingNode: 0,
                            argumentOfPeriapsis: 0, meanAnomalyAtEpoch: 0, meanMotion: 1) == nil, "a = 0")
        #expect(KeplerOrbit(semiMajorAxis: 1, eccentricity: 0.1, inclination: 0, ascendingNode: 0,
                            argumentOfPeriapsis: 0, meanAnomalyAtEpoch: 0, meanMotion: 0) == nil, "n = 0")
        #expect(KeplerOrbit(semiMajorAxis: 1, eccentricity: 0.1, inclination: .nan, ascendingNode: 0,
                            argumentOfPeriapsis: 0, meanAnomalyAtEpoch: 0, meanMotion: 1) == nil, "NaN")
        #expect(KeplerOrbit(semiMajorAxis: .infinity, eccentricity: 0.1, inclination: 0, ascendingNode: 0,
                            argumentOfPeriapsis: 0, meanAnomalyAtEpoch: 0, meanMotion: 1) == nil, "infinite a")
        #expect(close(orbit(n: 0.5).period, 4 * Double.pi))
    }

    // MARK: Kepler's equation

    @Test func residualIsTinyAcrossEccentricities() {
        let eccentricities: [Double] = [0, 0.2056, 0.5, 0.9, 0.95]
        for e in eccentricities {
            for k in 0..<24 {
                let m = -Double.pi + (Double(k) + 0.5) * (2 * Double.pi / 24)
                let bigE = KeplerOrbit.eccentricAnomaly(meanAnomaly: m, eccentricity: e)
                #expect(abs(bigE - e * sin(bigE) - m) < 1e-10, "e \(e) M \(m)")
            }
        }
    }

    @Test func meanAnomalyIsNormalisedAndNonFiniteTimeIsTheEpoch() {
        let o = orbit(m0: 0.5, n: 1)
        #expect(close(o.meanAnomaly(at: 2 * Double.pi), 0.5, 1e-12))
        #expect(close(o.meanAnomaly(at: -4 * Double.pi), 0.5, 1e-12))
        #expect(o.meanAnomaly(at: 3) <= Double.pi && o.meanAnomaly(at: 3) > -Double.pi)
        #expect(o.position(at: .nan) == o.position(at: 0))
        #expect(KeplerOrbit.eccentricAnomaly(meanAnomaly: .nan, eccentricity: 0.5) == 0)
    }

    // MARK: Positions

    @Test func circularOrbitKeepsItsRadius() {
        let o = orbit(a: 2, e: 0, n: 0.25)
        for k in 0..<16 {
            let t = Double(k) * o.period / 16
            #expect(close(o.position(at: t).length, 2, 1e-12))
            #expect(o.position(at: t).z == 0)
        }
    }

    @Test func periapsisAndApoapsisDistances() {
        let o = orbit(a: 1.5, e: 0.3, peri: 0.7)
        #expect(close(o.position(at: 0).length, 1.5 * 0.7, 1e-12), "periapsis at M = 0")
        #expect(close(o.position(at: Double.pi).length, 1.5 * 1.3, 1e-12), "apoapsis at M = π")
        let p = o.position(at: 0)
        #expect(close(atan2(p.y, p.x), 0.7, 1e-12), "periapsis along ω in an uninclined orbit")
    }

    @Test func periodReturnsToTheStart() {
        let o = orbit(a: 5.2, e: 0.048, i: 0.023, node: 1.75, peri: 4.78, m0: 0.35, n: 2 * Double.pi / 4332.6)
        let start = o.position(at: 0)
        let back = o.position(at: o.period)
        #expect(abs(o.meanAnomaly(at: o.period) - o.meanAnomaly(at: 0)) < 1e-6)
        #expect(close(back, start, 1e-6 * 5.2))
    }

    @Test func inclinationLiftsThePositionOutOfThePlane() {
        let flat = orbit(e: 0.1, peri: Double.pi / 2)
        let tilted = orbit(e: 0.1, i: 0.5, peri: Double.pi / 2)
        #expect(abs(flat.position(at: 0).z) < 1e-15)
        let p = tilted.position(at: 0)
        #expect(close(p.z, 0.9 * sin(0.5), 1e-12), "periapsis 90° past the node rises by r·sin i")
        #expect(close(p.length, 0.9, 1e-12), "rotation keeps the distance")
    }

    @Test func ascendingNodeRotatesAboutNorth() {
        let a = orbit(e: 0.2, node: 0)
        let b = orbit(e: 0.2, node: Double.pi / 2)
        let pa = a.position(at: 1)
        let pb = b.position(at: 1)
        #expect(close(pb, Vec3(-pa.y, pa.x, pa.z), 1e-12))
    }

    @Test func highEccentricityStaysFinite() {
        let o = orbit(a: 3, e: 0.95, n: 1)
        for k in 0..<64 {
            let p = o.position(at: Double(k) * 0.1)
            #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
            #expect(p.length >= 3 * 0.05 - 1e-9 && p.length <= 3 * 1.95 + 1e-9)
        }
    }
}
