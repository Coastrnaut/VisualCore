// EclipseGeometryTests — feature 215 (R02-F15) T-R02F15-005 (FR-R02F15-006; SC-R02F15-005; clarification Q4; research
// R8). Fixtures for every class (at least five each): the observer sits at the origin, a source of radius 1 lies 100
// along +x (αₛ ≈ 0.01) and the occluder lies 10 away at an angle β in the xy plane; hidden fixtures stand on a ground
// sphere below the observer. Refusals for an observer inside a body and for bad radii; fractions stay in [0, 1].
// Plain loops and explicit types (CI rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct EclipseGeometryTests {
    /// A point `distance` from the origin at angle `angle` from +x in the xy plane.
    private func at(_ distance: Double, _ angle: Double) -> Vec3 {
        Vec3(distance * cos(angle), distance * sin(angle), 0)
    }

    private var observer: Vec3 { .zero }
    private var source: EclipseBody { EclipseBody(center: Vec3(100, 0, 0), radius: 1) }

    private func classify(occluderRadius: Double, distance: Double = 10, angle: Double) throws -> EclipseVerdict {
        try EclipseGeometry.classify(observer: observer, source: source,
                                     occluder: EclipseBody(center: at(distance, angle), radius: occluderRadius))
    }

    @Test func noneFixtures() throws {
        // Far off the source, just past touching, behind the source, behind the observer, beyond the source, aside.
        var verdicts: [EclipseVerdict] = []
        verdicts.append(try classify(occluderRadius: 0.1, angle: 0.5))
        verdicts.append(try classify(occluderRadius: 0.1, angle: 0.0201))
        verdicts.append(try classify(occluderRadius: 5, distance: 200, angle: 0))
        verdicts.append(try classify(occluderRadius: 0.5, angle: Double.pi))
        verdicts.append(try classify(occluderRadius: 3, distance: 150, angle: 0.001))
        verdicts.append(try classify(occluderRadius: 0.2, angle: -1.2))
        for verdict in verdicts {
            #expect(verdict.eclipseClass == .none, "\(verdict)")
            #expect(verdict.coveredFraction == 0)
        }
        #expect(verdicts[2].separation == 0, "behind the source: aligned but not nearer")
        #expect(abs(verdicts[3].separation - Double.pi) < 1e-12, "behind the observer")
    }

    @Test func partialFixtures() throws {
        let angles: [Double] = [0.004, 0.008, 0.012, 0.016, 0.019, -0.01]
        for angle in angles {
            let verdict: EclipseVerdict = try classify(occluderRadius: 0.1, angle: angle)
            #expect(verdict.eclipseClass == .partial, "angle \(angle) \(verdict)")
            #expect(verdict.coveredFraction > 0 && verdict.coveredFraction < 1)
        }
    }

    @Test func annularFixtures() throws {
        let angles: [Double] = [0, 0.001, 0.002, 0.004, -0.003, 0.0045]
        for angle in angles {
            let verdict: EclipseVerdict = try classify(occluderRadius: 0.05, angle: angle)
            #expect(verdict.eclipseClass == .annular, "angle \(angle) \(verdict)")
            let ratio: Double = verdict.occluderAngularRadius / verdict.sourceAngularRadius
            #expect(abs(verdict.coveredFraction - ratio * ratio) < 1e-12)
            #expect(verdict.coveredFraction < 1)
        }
    }

    @Test func totalFixtures() throws {
        let angles: [Double] = [0, 0.002, 0.005, 0.009, -0.007, 0.0099]
        for angle in angles {
            let verdict: EclipseVerdict = try classify(occluderRadius: 0.2, angle: angle)
            #expect(verdict.eclipseClass == .total, "angle \(angle) \(verdict)")
            #expect(verdict.coveredFraction == 1)
        }
        let equal: EclipseVerdict = try EclipseGeometry.classify(
            observer: observer, source: source, occluder: EclipseBody(center: Vec3(50, 0, 0), radius: 0.5))
        #expect(equal.eclipseClass == .total, "equal angular radii, centred")
    }

    @Test func hiddenFixtures() throws {
        // Ground of radius 10 under the observer (on its surface, up = +z) and one 1 unit lower (dip acos(10/11)).
        let onSurface = EclipseBody(center: Vec3(0, 0, -10), radius: 10)
        let raised = EclipseBody(center: Vec3(0, 0, -11), radius: 10)
        let occluder = EclipseBody(center: Vec3(0, 10, 0), radius: 0.5)
        let surfaceElevations: [Double] = [-0.02, -0.3, -1.0, -1.5]
        var count: Int = 0
        for elevation in surfaceElevations {
            let body = EclipseBody(center: Vec3(100 * cos(elevation), 0, 100 * sin(elevation)), radius: 1)
            let verdict: EclipseVerdict = try EclipseGeometry.classify(observer: observer, source: body,
                                                                       occluder: occluder, ground: onSurface)
            #expect(verdict.eclipseClass == .hidden, "elevation \(elevation)")
            #expect(verdict.coveredFraction == 1)
            count += 1
        }
        let raisedElevations: [Double] = [-0.5, -0.9]
        for elevation in raisedElevations {
            let body = EclipseBody(center: Vec3(100 * cos(elevation), 0, 100 * sin(elevation)), radius: 1)
            let verdict: EclipseVerdict = try EclipseGeometry.classify(observer: observer, source: body,
                                                                       occluder: occluder, ground: raised)
            #expect(verdict.eclipseClass == .hidden, "raised, elevation \(elevation)")
            #expect(verdict.coveredFraction == 1)
            count += 1
        }
        #expect(count >= 5)
        // Visible counterparts: the rim above the horizon, and inside the raised observer's dip (≈ 0.430).
        let grazing = EclipseBody(center: Vec3(100 * cos(-0.005), 0, 100 * sin(-0.005)), radius: 1)
        let grazingVerdict = try EclipseGeometry.classify(observer: observer, source: grazing, occluder: occluder,
                                                          ground: onSurface)
        #expect(grazingVerdict.eclipseClass == .none)
        let dipped = EclipseBody(center: Vec3(100 * cos(-0.3), 0, 100 * sin(-0.3)), radius: 1)
        let dippedVerdict = try EclipseGeometry.classify(observer: observer, source: dipped, occluder: occluder,
                                                         ground: raised)
        #expect(dippedVerdict.eclipseClass == .none)
    }

    @Test func verdictReportsAnglesAndFractionInRange() throws {
        let verdict: EclipseVerdict = try classify(occluderRadius: 0.1, angle: 0.01)
        #expect(abs(verdict.sourceAngularRadius - asin(0.01)) < 1e-14)
        #expect(abs(verdict.occluderAngularRadius - asin(0.01)) < 1e-14)
        #expect(abs(verdict.separation - 0.01) < 1e-12)
        var angle: Double = -0.03
        while angle <= 0.03 {
            let swept: EclipseVerdict = try classify(occluderRadius: 0.12, angle: angle)
            #expect(swept.coveredFraction >= 0 && swept.coveredFraction <= 1)
            angle += 0.0005
        }
    }

    @Test func observerInsideIsRefused() {
        let inside = EclipseBody(center: Vec3(0.5, 0, 0), radius: 1)
        let occluder = EclipseBody(center: Vec3(10, 0, 0), radius: 0.1)
        #expect(throws: OrbitError.observerInside) {
            try EclipseGeometry.classify(observer: .zero, source: inside, occluder: occluder)
        }
        #expect(throws: OrbitError.observerInside) {
            try EclipseGeometry.classify(observer: .zero, source: source, occluder: inside)
        }
        #expect(throws: OrbitError.observerInside) {
            try EclipseGeometry.classify(observer: .zero, source: source, occluder: occluder,
                                         ground: EclipseBody(center: Vec3(0, 0, -5), radius: 10))
        }
        #expect(OrbitError.observerInside.reasonCode == "r2-f15.observer-inside")
    }

    @Test func badRadiusIsRefused() {
        let radii: [Double] = [0, -1, .nan, .infinity]
        let occluder = EclipseBody(center: Vec3(10, 0, 0), radius: 0.1)
        for bad in radii {
            let body = EclipseBody(center: Vec3(10, 0, 0), radius: bad)
            #expect(throws: OrbitError.invalidDisk) {
                try EclipseGeometry.classify(observer: .zero, source: body, occluder: occluder)
            }
            #expect(throws: OrbitError.invalidDisk) {
                try EclipseGeometry.classify(observer: .zero, source: source, occluder: body)
            }
            #expect(throws: OrbitError.invalidDisk) {
                try EclipseGeometry.classify(observer: .zero, source: source, occluder: occluder,
                                             ground: EclipseBody(center: Vec3(0, 0, -20), radius: bad))
            }
        }
        #expect(throws: OrbitError.invalidDisk) {
            try EclipseGeometry.classify(observer: Vec3(.nan, 0, 0), source: source, occluder: occluder)
        }
        #expect(OrbitError.invalidDisk.reasonCode == "r2-f15.invalid-disk")
    }

    @Test func classNamesAreStable() {
        let names: [String] = EclipseClass.allCases.map { (c: EclipseClass) -> String in c.rawValue }
        #expect(names == ["none", "partial", "annular", "total", "hidden"])
    }
}
