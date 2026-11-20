// ConicOrbitTests — feature 215 (R02-F15) T-R02F15-003 (FR-R02F15-001 … FR-R02F15-003; SC-R02F15-001,
// SC-R02F15-002; research R4). Elliptic states equal `KeplerOrbit.position(at:)`; energy and angular momentum are
// conserved for every kind; orbits just inside and outside e = 1 stay close to the parabola; invalid elements are
// refused. Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct ConicOrbitTests {
    private func orbit(q: Double = 1, e: Double = 0, i: Double = 0, node: Double = 0, peri: Double = 0,
                       tp: Double = 0, mu: Double = 1) throws(OrbitError) -> ConicOrbit {
        try ConicOrbit(periapsisDistance: q, eccentricity: e, inclination: i, ascendingNode: node,
                       argumentOfPeriapsis: peri, timeOfPeriapsis: tp, gravitationalParameter: mu)
    }

    private func randomAngles(_ rng: inout ConicOrbitFixtureRandom) -> (Double, Double, Double) {
        let i: Double = rng.unit() * Double.pi
        let node: Double = (rng.unit() * 2 - 1) * Double.pi
        let peri: Double = (rng.unit() * 2 - 1) * Double.pi
        return (i, node, peri)
    }

    // MARK: Kinds and derived elements

    @Test func kindsAndDerivedElements() throws {
        let ellipse = try orbit(q: 1, e: 0.5, mu: 2)
        #expect(ellipse.kind == .elliptic)
        #expect(abs(ellipse.semiMajorAxis! - 2) < 1e-15)
        #expect(abs(ellipse.meanMotion - (2.0 / 8.0).squareRoot()) < 1e-15)
        #expect(abs(ellipse.period! - 2 * Double.pi / ellipse.meanMotion) < 1e-12)
        #expect(abs(ellipse.specificEnergy + 0.5) < 1e-15)
        #expect(abs(ellipse.specificAngularMomentum - 3.0.squareRoot()) < 1e-15)

        let parabola = try orbit(q: 2, e: 1 + 1e-10, mu: 4)
        #expect(parabola.kind == .parabolic)
        #expect(try orbit(e: 1).kind == .parabolic)
        #expect(parabola.semiMajorAxis == nil)
        #expect(parabola.period == nil)
        #expect(parabola.specificEnergy == 0)
        #expect(abs(parabola.meanMotion - (4.0 / 16.0).squareRoot()) < 1e-15)
        #expect(parabola.keplerOrbit == nil)

        let hyperbola = try orbit(q: 1, e: 3, mu: 1)
        #expect(hyperbola.kind == .hyperbolic)
        #expect(try orbit(e: 1 + 2e-9).kind == .hyperbolic)
        #expect(abs(hyperbola.semiMajorAxis! + 0.5) < 1e-15)
        #expect(hyperbola.period == nil)
        #expect(hyperbola.specificEnergy > 0)
        #expect(hyperbola.keplerOrbit == nil)
    }

    @Test func periapsisStateAndNonFiniteTime() throws {
        let o = try orbit(q: 1.5, e: 0.3, i: 0.4, node: 1.1, peri: -0.6, tp: 7, mu: 3)
        let atPeriapsis = o.state(at: 7)
        #expect(abs(atPeriapsis.radius - 1.5) < 1e-14)
        #expect(atPeriapsis.trueAnomaly == 0)
        #expect(abs(atPeriapsis.position.dot(atPeriapsis.velocity)) < 1e-13)
        let times: [Double] = [.nan, .infinity, -.infinity]
        for t in times {
            #expect(o.state(at: t) == atPeriapsis, "time \(t)")
        }
        #expect(o.position(at: 9) == o.state(at: 9).position)
    }

    // MARK: Agreement with KeplerOrbit

    @Test func ellipticMatchesKeplerOrbitOnSeededCases() throws {
        var rng = ConicOrbitFixtureRandom(state: 2_015)
        for index in 0..<1_000 {
            let q: Double = 0.2 + rng.unit() * 5
            let e: Double = rng.unit() * 0.95
            let (i, node, peri) = randomAngles(&rng)
            let tp: Double = (rng.unit() * 2 - 1) * 10
            let mu: Double = 0.1 + rng.unit() * 10
            let t: Double = (rng.unit() * 2 - 1) * 50
            let o = try orbit(q: q, e: e, i: i, node: node, peri: peri, tp: tp, mu: mu)
            let kepler = try #require(o.keplerOrbit)
            let scale = kepler.semiMajorAxis * (1 + e)
            let error = (o.position(at: t) - kepler.position(at: t)).length / scale
            #expect(error <= 1e-9, "case \(index) e \(e) error \(error)")
        }
    }

    @Test func initFromKeplerOrbit() throws {
        let a = 2.0
        let n = 0.7
        let kepler = try #require(KeplerOrbit(semiMajorAxis: a, eccentricity: 0.4, inclination: 0.3,
                                              ascendingNode: 1.2, argumentOfPeriapsis: -0.8,
                                              meanAnomalyAtEpoch: 0.9, meanMotion: n))
        let o = try ConicOrbit(kepler, gravitationalParameter: n * n * a * a * a)
        #expect(abs(o.periapsisDistance - 1.2) < 1e-15)
        #expect(abs(o.timeOfPeriapsis + 0.9 / n) < 1e-15)
        for k in 0..<8 {
            let t = Double(k) * 1.3 - 4
            #expect((o.position(at: t) - kepler.position(at: t)).length < 1e-12 * a, "t \(t)")
        }
        #expect(throws: OrbitError.invalidElements("gravitationalParameter")) {
            try ConicOrbit(kepler, gravitationalParameter: n * n * a * a * a * 1.01)
        }
        #expect(throws: OrbitError.invalidElements("gravitationalParameter")) {
            try ConicOrbit(kepler, gravitationalParameter: .nan)
        }
    }

    // MARK: Invariants

    @Test func invariantsHoldForEveryKind() throws {
        var rng = ConicOrbitFixtureRandom(state: 2_015)
        let kinds: [ConicKind] = [.elliptic, .parabolic, .hyperbolic]
        for kind in kinds {
            for index in 0..<200 {
                let q: Double = 0.2 + rng.unit() * 5
                let draw: Double = rng.unit()
                let e: Double
                switch kind {
                case .elliptic: e = draw * 0.9
                case .parabolic: e = 1
                case .hyperbolic: e = 1.1 + draw * 4
                }
                let (i, node, peri) = randomAngles(&rng)
                let mu: Double = 0.1 + rng.unit() * 10
                let o = try orbit(q: q, e: e, i: i, node: node, peri: peri, tp: 1, mu: mu)
                #expect(o.kind == kind)
                let t: Double = 1 + (rng.unit() * 2 - 1) * 20 / o.meanMotion
                let s = o.state(at: t)
                let v2 = s.velocity.dot(s.velocity)
                let energy = v2 / 2 - mu / s.radius
                if kind == .parabolic {
                    #expect(abs(energy) <= 1e-9 * mu / q, "\(kind) case \(index) energy \(energy)")
                } else {
                    let relative = abs(energy - o.specificEnergy) / abs(o.specificEnergy)
                    #expect(relative <= 1e-9, "\(kind) case \(index) energy error \(relative)")
                }
                let h = s.position.cross(s.velocity).length
                let hError = abs(h - o.specificAngularMomentum) / o.specificAngularMomentum
                #expect(hError <= 1e-9, "\(kind) case \(index) angular momentum error \(hError)")
            }
        }
    }

    @Test func nearParabolicOrbitsStayCloseToTheParabola() throws {
        let eccentricities: [Double] = [1 - 1e-4, 1 + 1e-4]
        let parabola = try orbit(q: 1, e: 1, i: 0.5, node: 0.3, peri: 1.2, mu: 1)
        for e in eccentricities {
            let near = try orbit(q: 1, e: e, i: 0.5, node: 0.3, peri: 1.2, mu: 1)
            for k in 0...40 {
                let t = Double(k) * 0.5 - 10
                let reference = parabola.position(at: t)
                let error = (near.position(at: t) - reference).length / reference.length
                #expect(error <= 1e-3, "e \(e) t \(t) error \(error)")
            }
        }
    }

    // MARK: Refusals

    @Test func invalidElementsAreRefused() {
        let cases: [(Double, Double, Double, Double, String)] = [
            (0, 0.5, 0, 1, "periapsisDistance"),
            (-1, 0.5, 0, 1, "periapsisDistance"),
            (.nan, 0.5, 0, 1, "periapsisDistance"),
            (1, -0.1, 0, 1, "eccentricity"),
            (1, .infinity, 0, 1, "eccentricity"),
            (1, 0.5, .nan, 1, "inclination"),
            (1, 0.5, 0, 0, "gravitationalParameter"),
            (1, 0.5, 0, -2, "gravitationalParameter"),
        ]
        for (q, e, i, mu, name) in cases {
            do {
                _ = try orbit(q: q, e: e, i: i, mu: mu)
                Issue.record("accepted \(name)")
            } catch {
                #expect(error == .invalidElements(name))
                #expect(error.reasonCode == "r2-f15.invalid-elements")
            }
        }
        #expect(throws: OrbitError.invalidElements("timeOfPeriapsis")) { try orbit(tp: .infinity) }
        #expect(throws: OrbitError.invalidElements("ascendingNode")) { try orbit(node: .nan) }
        #expect(throws: OrbitError.invalidElements("argumentOfPeriapsis")) { try orbit(peri: -.infinity) }
    }
}

/// Deterministic SplitMix64 generator for the seeded orbit cases.
fileprivate struct ConicOrbitFixtureRandom {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform value in [0, 1).
    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
}
