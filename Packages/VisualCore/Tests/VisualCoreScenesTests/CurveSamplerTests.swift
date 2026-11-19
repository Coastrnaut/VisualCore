// CurveSamplerTests — feature 208 (R02-F08) T-R02F08-002 (FR-R02F08-002; SC-R02F08-001; analyze A1, A2). Six reference
// curves × three tolerances: the polyline stays within the tolerance of the spline itself, measured on 1,000 points
// per segment (A1). The circle, helix, trefoil and Lissajous figure are centripetal Catmull-Rom splines through points
// of the analytic shape (closed where it closes), the S curve a two-segment Bézier chain and the straight line a
// one-segment Bézier with collinear control points (A2). Also: 2 samples for the line, budget refusal, determinism.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// The reference curves of SC-R02F08-001 (shared by the frame and mesh tests of feature 208).
enum CurveFixtures {
    /// Catmull-Rom through 16 points of the unit circle in the xy plane, closed.
    static func circle() throws -> CatmullRomSpline {
        try CatmullRomSpline(points: (0..<16).map { k in
            let a = 2 * Double.pi * Double(k) / 16
            return Vec3(cos(a), sin(a), 0)
        }, closed: true)
    }

    /// Catmull-Rom through 37 points of three turns of a helix (radius 1, pitch 0.9), open.
    static func helix() throws -> CatmullRomSpline {
        try CatmullRomSpline(points: (0...36).map { k in
            let a = 2 * Double.pi * Double(k) / 12
            return Vec3(cos(a), sin(a), 0.15 * a)
        }, closed: false)
    }

    /// Catmull-Rom through 48 points of the trefoil knot (sin t + 2 sin 2t, cos t − 2 cos 2t, −sin 3t) × 0.3, closed.
    static func trefoil() throws -> CatmullRomSpline {
        try CatmullRomSpline(points: (0..<48).map { k in
            let t = 2 * Double.pi * Double(k) / 48
            return Vec3(sin(t) + 2 * sin(2 * t), cos(t) - 2 * cos(2 * t), -sin(3 * t)) * 0.3
        }, closed: true)
    }

    /// Catmull-Rom through 64 points of the Lissajous figure (sin 3t, sin 2t, cos 5t), closed.
    static func lissajous() throws -> CatmullRomSpline {
        try CatmullRomSpline(points: (0..<64).map { k in
            let t = 2 * Double.pi * Double(k) / 64
            return Vec3(sin(3 * t), sin(2 * t), cos(5 * t))
        }, closed: true)
    }

    /// A two-segment Bézier S curve.
    static func sCurve() throws -> CubicBezierChain {
        try CubicBezierChain(points: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0), Vec3(0, 1, 0), Vec3(-1, 1, 0),
                                      Vec3(-1, 2, 0), Vec3(0, 2, 0)], closed: false)
    }

    /// A one-segment Bézier with collinear, evenly spaced control points.
    static func line() throws -> CubicBezierChain {
        try CubicBezierChain(points: [Vec3(0, 0, 0), Vec3(1, 1, 1), Vec3(2, 2, 2), Vec3(3, 3, 3)], closed: false)
    }

    /// All six, named.
    static func all() throws -> [(String, any ParametricCurve)] {
        [("circle", try circle()), ("helix", try helix()), ("trefoil", try trefoil()),
         ("lissajous", try lissajous()), ("s-curve", try sCurve()), ("line", try line())]
    }

    /// The three tolerances of SC-R02F08-001.
    static let tolerances = [1e-2, 1e-3, 1e-4]
}

/// Upper bound of the largest distance from `curve` (1,000 points per segment) to the polyline of `samples`.
///
/// Curve points are visited in order and each is measured against a window of polyline edges around the edge
/// nearest the previous point; a windowed minimum is never below the true distance, so the result bounds it above.
func worstDistance(_ curve: some ParametricCurve, _ samples: CurveSamples) -> Double {
    var polyline = samples.positions
    if samples.isClosed { polyline.append(polyline[0]) }
    let edges = polyline.count - 1
    var current = 0, worst = 0.0
    for s in 0..<curve.segmentCount {
        for k in 0..<1_000 {
            let p = curve.position(segment: s, t: Double(k) / 999)
            var best = Double.infinity, bestEdge = current
            for e in max(0, current - 2)...min(edges - 1, current + 64) {
                let d = CurveSampler.distance(p, toSegment: polyline[e], polyline[e + 1])
                if d < best { best = d; bestEdge = e }
            }
            current = bestEdge
            worst = max(worst, best)
        }
    }
    return worst
}

@Test func referenceCurvesStayWithinTolerance() throws {
    var passed = 0
    for (name, curve) in try CurveFixtures.all() {
        for tolerance in CurveFixtures.tolerances {
            let samples = try CurveSampler.sample(curve, tolerance: tolerance)
            let worst = worstDistance(curve, samples)
            #expect(worst <= tolerance, "\(name) at \(tolerance): worst \(worst), \(samples.positions.count) samples")
            if worst <= tolerance { passed += 1 }
            #expect(samples.isClosed == curve.isClosed)
        }
    }
    #expect(passed == 18)
}

@Test func straightLineNeedsTwoSamples() throws {
    for tolerance in CurveFixtures.tolerances {
        let samples = try CurveSampler.sample(try CurveFixtures.line(), tolerance: tolerance)
        #expect(samples.positions == [Vec3(0, 0, 0), Vec3(3, 3, 3)])
        #expect(abs(samples.length - 3 * 3.0.squareRoot()) <= 1e-12)
    }
}

@Test func tighterToleranceNeedsMoreSamples() throws {
    for (name, curve) in try CurveFixtures.all() where name != "line" {
        let counts = try CurveFixtures.tolerances.map { try CurveSampler.sample(curve, tolerance: $0).positions.count }
        #expect(counts[0] < counts[1] && counts[1] < counts[2], "\(name): \(counts)")
    }
}

@Test func samplesCarryUnitTangentsAndCumulativeChordLengths() throws {
    for (_, curve) in try CurveFixtures.all() {
        let samples = try CurveSampler.sample(curve, tolerance: 1e-3)
        #expect(samples.tangents.count == samples.positions.count)
        #expect(samples.arcLengths.count == samples.positions.count && samples.arcLengths.first == 0)
        #expect(samples.tangents.allSatisfy { abs($0.length - 1) <= 1e-12 })
        for i in 1..<samples.positions.count {
            let chord = (samples.positions[i] - samples.positions[i - 1]).length
            #expect(chord > 0)
            #expect(abs(samples.arcLengths[i] - samples.arcLengths[i - 1] - chord) <= 1e-12)
        }
        let first = samples.positions[0], last = samples.positions[samples.positions.count - 1]
        // A closed record does not repeat its first sample.
        #expect(!samples.isClosed || (first - last).length > 1e-6)
        #expect(curve.isClosed || first == curve.position(segment: 0, t: 0))
    }
}

@Test func samplingIsDeterministic() throws {
    for (_, curve) in try CurveFixtures.all() {
        #expect(try CurveSampler.sample(curve, tolerance: 1e-4) == CurveSampler.sample(curve, tolerance: 1e-4))
    }
}

@Test func samplingRefusesTheBudgetAndBadTolerances() throws {
    let helix = try CurveFixtures.helix()
    #expect(throws: MeshError.self) { try CurveSampler.sample(helix, tolerance: 1e-4, budget: 100) }
    do {
        _ = try CurveSampler.sample(helix, tolerance: 1e-4, budget: 100)
    } catch {
        guard case .budget(let vertices, _, let budget) = error else { Issue.record("expected .budget"); return }
        #expect(vertices == 101 && budget.maxVertices == 100)
    }
    // A budget above the cap is clamped to 65,536: depth-20 subdivision of a tight curve hits it.
    #expect(throws: MeshError.self) { try CurveSampler.sample(helix, tolerance: 1e-300, budget: 1_000_000) }
    let enough = try CurveSampler.sample(helix, tolerance: 1e-4)
    #expect(try CurveSampler.sample(helix, tolerance: 1e-4, budget: enough.positions.count) == enough)
    for bad in [0, -1e-3, Double.nan, Double.infinity] {
        #expect(throws: MeshError.self) { try CurveSampler.sample(helix, tolerance: bad) }
    }
    #expect(CurveSampler.maxSamples == 65_536)
}

@Test func curveSamplesDropCollapsesAndRefuseTooFew() throws {
    let p = Vec3(0, 0, 0), q = Vec3(1, 0, 0), r = Vec3(1, 1, 0)
    let samples = try CurveSamples(positions: [p, p, q, Vec3(1 + 1e-12, 0, 0), r, p], closed: true)
    #expect(samples.positions == [p, q, r])
    #expect(abs(samples.length - (2 + 2.0.squareRoot())) <= 1e-12)
    #expect(throws: MeshError.self) { try CurveSamples(positions: [p, p], closed: false) }
    #expect(throws: MeshError.self) { try CurveSamples(positions: [p, q, p], closed: true) }
    #expect(throws: MeshError.self) { try CurveSamples(positions: [p, Vec3(.nan, 0, 0)], closed: false) }
}
