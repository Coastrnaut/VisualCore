// CurveSplineTests — feature 208 (R02-F08) T-R02F08-002 (FR-R02F08-001; SC-R02F08-001). Bézier chains and centripetal
// Catmull-Rom splines interpolate their end points, have exact derivatives (checked against central finite
// differences and an independent Hermite form) and refuse unusable control points.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// Largest component difference of two vectors.
private func gap(_ a: Vec3, _ b: Vec3) -> Double { max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z)) }

/// Central finite difference of `curve` at (segment, t) with step h (one-sided at the segment ends).
private func finiteDifference(_ curve: some ParametricCurve, _ segment: Int, _ t: Double) -> Vec3 {
    let h = 1e-5
    let lo = max(0, t - h), hi = min(1, t + h)
    return (curve.position(segment: segment, t: hi) - curve.position(segment: segment, t: lo)) / (hi - lo)
}

private let bezierPoints = [Vec3(0, 0, 0), Vec3(1, 0, 0.5), Vec3(1, 1, -0.5), Vec3(0, 1, 0), Vec3(-1, 1, 0.25),
                            Vec3(-1, 2, 0), Vec3(0, 2, 1)]
private let splinePoints = [Vec3(0, 0, 0), Vec3(1, 0.2, 0), Vec3(1.5, 1, 0.3), Vec3(3, 1.1, -0.2), Vec3(3.2, 3, 0),
                            Vec3(1, 2.5, 0.5)]

@Test func bezierChainInterpolatesItsEndControlPoints() throws {
    let open = try CubicBezierChain(points: bezierPoints, closed: false)
    #expect(open.segmentCount == 2 && !open.isClosed)
    for s in 0..<open.segmentCount {
        #expect(gap(open.position(segment: s, t: 0), bezierPoints[3 * s]) <= 1e-15)
        #expect(gap(open.position(segment: s, t: 1), bezierPoints[3 * s + 3]) <= 1e-15)
        // End derivatives are 3 (b1 − b0) and 3 (b3 − b2).
        #expect(gap(open.derivative(segment: s, t: 0), (bezierPoints[3 * s + 1] - bezierPoints[3 * s]) * 3) <= 1e-14)
        let endSlope = (bezierPoints[3 * s + 3] - bezierPoints[3 * s + 2]) * 3
        #expect(gap(open.derivative(segment: s, t: 1), endSlope) <= 1e-14)
    }
    let closed = try CubicBezierChain(points: Array(bezierPoints.prefix(6)), closed: true)
    #expect(closed.segmentCount == 2 && closed.isClosed)
    #expect(gap(closed.position(segment: 1, t: 1), bezierPoints[0]) <= 1e-15)
    // Out-of-range segments clamp.
    #expect(open.position(segment: 9, t: 1) == open.position(segment: 1, t: 1))
    #expect(open.position(segment: -3, t: 0) == open.position(segment: 0, t: 0))
}

@Test func catmullRomPassesThroughItsPoints() throws {
    for closed in [false, true] {
        let spline = try CatmullRomSpline(points: splinePoints, closed: closed)
        #expect(spline.segmentCount == (closed ? 6 : 5))
        for s in 0..<spline.segmentCount {
            #expect(gap(spline.position(segment: s, t: 0), splinePoints[s]) <= 1e-12)
            #expect(gap(spline.position(segment: s, t: 1), splinePoints[(s + 1) % splinePoints.count]) <= 1e-12)
        }
    }
}

@Test func derivativesMatchFiniteDifferences() throws {
    let curves: [any ParametricCurve] = [
        try CubicBezierChain(points: bezierPoints, closed: false),
        try CubicBezierChain(points: Array(bezierPoints.prefix(6)), closed: true),
        try CatmullRomSpline(points: splinePoints, closed: false),
        try CatmullRomSpline(points: splinePoints, closed: true),
    ]
    var worst = 0.0
    for curve in curves {
        for s in 0..<curve.segmentCount {
            for k in 0...20 {
                let t = Double(k) / 20
                let exact = curve.derivative(segment: s, t: t)
                let scale = 1 + exact.length
                worst = max(worst, gap(exact, finiteDifference(curve, s, t)) / scale)
            }
        }
    }
    #expect(worst <= 1e-4, "worst relative derivative error \(worst)")
}

/// The centripetal segment as a cubic Hermite curve with the classic tangent formula — independent of the pyramid.
@Test func catmullRomMatchesAnIndependentHermiteForm() throws {
    let spline = try CatmullRomSpline(points: splinePoints, closed: false)
    var worst = 0.0
    for s in 0..<spline.segmentCount {
        let (p0, p1, p2, p3) = spline.neighbourhood(segment: s)
        let d01 = (p1 - p0).length.squareRoot(), d12 = (p2 - p1).length.squareRoot()
        let d23 = (p3 - p2).length.squareRoot()
        let m1 = ((p1 - p0) / d01 - (p2 - p0) / (d01 + d12) + (p2 - p1) / d12) * d12
        let m2 = ((p2 - p1) / d12 - (p3 - p1) / (d12 + d23) + (p3 - p2) / d23) * d12
        for k in 0...10 {
            let t = Double(k) / 10, t2 = t * t, t3 = t2 * t
            let h00: Double = 2 * t3 - 3 * t2 + 1, h10: Double = t3 - 2 * t2 + t
            let h01: Double = -2 * t3 + 3 * t2, h11: Double = t3 - t2
            let g00: Double = 6 * t2 - 6 * t, g10: Double = 3 * t2 - 4 * t + 1
            let g01: Double = -6 * t2 + 6 * t, g11: Double = 3 * t2 - 2 * t
            let start: Vec3 = p1 * h00 + m1 * h10, end: Vec3 = p2 * h01 + m2 * h11
            let hermite: Vec3 = start + end
            let slopeStart: Vec3 = p1 * g00 + m1 * g10, slopeEnd: Vec3 = p2 * g01 + m2 * g11
            let slope: Vec3 = slopeStart + slopeEnd
            worst = max(worst, gap(hermite, spline.position(segment: s, t: t)),
                        gap(slope, spline.derivative(segment: s, t: t)))
        }
    }
    #expect(worst <= 1e-12, "worst Hermite disagreement \(worst)")
}

@Test func openCatmullRomUsesReflectedPhantomEnds() throws {
    let spline = try CatmullRomSpline(points: splinePoints, closed: false)
    let (first, _, _, _) = spline.neighbourhood(segment: 0)
    #expect(first == splinePoints[0] * 2 - splinePoints[1])
    let (_, _, _, last) = spline.neighbourhood(segment: spline.segmentCount - 1)
    #expect(last == splinePoints[5] * 2 - splinePoints[4])
    // Two points give a straight segment.
    let two = try CatmullRomSpline(points: [Vec3(0, 0, 0), Vec3(2, 0, 0)], closed: false)
    #expect(gap(two.position(segment: 0, t: 0.25), Vec3(0.5, 0, 0)) <= 1e-12)
}

@Test func catmullRomTangentDirectionIsContinuousAcrossSegments() throws {
    for closed in [false, true] {
        let spline = try CatmullRomSpline(points: splinePoints, closed: closed)
        let joints = closed ? spline.segmentCount : spline.segmentCount - 1
        for s in 0..<joints {
            let a = spline.derivative(segment: s, t: 1).normalized
            let b = spline.derivative(segment: (s + 1) % spline.segmentCount, t: 0).normalized
            #expect(gap(a, b) <= 1e-12)
        }
    }
}

@Test func catmullRomDropsRepeatedPoints() throws {
    let repeated = [splinePoints[0], splinePoints[0], splinePoints[1], splinePoints[2], splinePoints[2],
                    splinePoints[3], splinePoints[0]]
    let spline = try CatmullRomSpline(points: repeated, closed: true)
    #expect(spline.points == [splinePoints[0], splinePoints[1], splinePoints[2], splinePoints[3]])
    #expect(spline.position(segment: 1, t: 0.5).isFinite)
}

@Test func unusableControlPointsAreRefused() {
    let p = Vec3(0, 0, 0), q = Vec3(1, 0, 0), r = Vec3(1, 1, 0), s = Vec3(0, 1, 0)
    for (points, closed) in [([p, q, r], false), ([p, q, r, s, p], false), ([p, q, r, s], true), ([p, q], true),
                             ([], false), ([p, q, r, Vec3(.nan, 0, 0)], false),
                             ([p, q, Vec3(.infinity, 0, 0)], true)] as [([Vec3], Bool)] {
        #expect(throws: MeshError.self) { try CubicBezierChain(points: points, closed: closed) }
    }
    for (points, closed) in [([p], false), ([p, p, p], false), ([p, q], true), ([p, q, p], true), ([], true),
                             ([p, Vec3(0, .nan, 0)], false)] as [([Vec3], Bool)] {
        #expect(throws: MeshError.self) { try CatmullRomSpline(points: points, closed: closed) }
    }
    #expect((try? CubicBezierChain(points: [p, q, r], closed: true)) != nil)
    #expect((try? CatmullRomSpline(points: [p, q], closed: false)) != nil)
}
