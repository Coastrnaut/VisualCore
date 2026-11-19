// CurveFrameTests — feature 208 (R02-F08) T-R02F08-003 (FR-R02F08-003; SC-R02F08-002). Parallel-transport frames are
// orthonormal within 1e-9, turn their normal by no more than the bend (plus, on a loop, its share of the spread
// closing twist) + 1e-9 on the helix, trefoil, Lissajous figure, a 180° reversal and repeated points, close within
// 1e-9 on loops and agree with the existing internal tube frames.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// Angle between two unit vectors, robust near 0 and π.
private func angle(_ a: Vec3, _ b: Vec3) -> Double { atan2(a.cross(b).length, a.dot(b)) }

/// Largest component difference of two vectors.
private func gap(_ a: Vec3, _ b: Vec3) -> Double { max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z)) }

/// Largest deviation from orthonormality (unit lengths, zero dot products, binormal = tangent × normal).
private func orthonormalError(_ f: CurveFrame) -> Double {
    max(abs(f.tangent.length - 1), abs(f.normal.length - 1), abs(f.binormal.length - 1),
        abs(f.tangent.dot(f.normal)), abs(f.tangent.dot(f.binormal)), abs(f.normal.dot(f.binormal)),
        gap(f.tangent.cross(f.normal), f.binormal))
}

/// Largest excess of the normal's turn over the bend (plus the loop's twist share) between consecutive frames.
private func rotationExcess(_ samples: CurveSamples) throws -> Double {
    let (frames, closing) = try CurveFrames.transport(samples, initialNormal: nil)
    var excess = -Double.infinity
    for i in 1..<frames.count {
        let a = frames[i - 1], b = frames[i]
        let step = (b.position - a.position).length
        let share = samples.isClosed ? abs(closing) * step / samples.length : 0
        excess = max(excess, angle(a.normal, b.normal) - angle(a.tangent, b.tangent) - share)
    }
    return excess
}

/// A straight run out along (2, 1, 0.5) and back (a Bézier with p1 = p2 and p3 = p0, turning by exactly 180° at
/// t = 0.5, position (1.5, 0.75, 0.375)), then a curved segment away from the origin.
private func reversal() throws -> CurveSamples {
    let far = Vec3(2, 1, 0.5)
    let chain = try CubicBezierChain(points: [.zero, far, far, .zero, Vec3(0, 1, 0), Vec3(1, 1, 1), Vec3(1, 2, 1)],
                                     closed: false)
    return try CurveSampler.sample(chain, tolerance: 1e-3)
}

/// A chain whose middle segment collapses to one point (four equal control points).
private func repeatedPoints() throws -> CurveSamples {
    let p = Vec3(1, 1, 0)
    let chain = try CubicBezierChain(points: [.zero, Vec3(0.5, 0, 0), Vec3(1, 0.5, 0), p, p, p, p, Vec3(1, 1.5, 0.5),
                                              Vec3(0.5, 2, 1), Vec3(0, 2, 1)], closed: false)
    return try CurveSampler.sample(chain, tolerance: 1e-3)
}

/// The sampled reference curves plus the reversal and the repeated points.
private func frameCases() throws -> [(String, CurveSamples)] {
    var cases: [(String, CurveSamples)] = []
    for (name, curve) in try CurveFixtures.all() {
        cases.append((name, try CurveSampler.sample(curve, tolerance: 1e-3)))
    }
    cases.append(("reversal", try reversal()))
    cases.append(("repeated", try repeatedPoints()))
    return cases
}

@Test func framesAreOrthonormal() throws {
    for (name, samples) in try frameCases() {
        let frames = try CurveFrames.parallelTransport(samples)
        #expect(frames.count == samples.positions.count + (samples.isClosed ? 1 : 0))
        let worst = frames.map(orthonormalError).max() ?? 0
        #expect(worst <= 1e-9, "\(name): orthonormal error \(worst)")
        for (i, f) in frames.enumerated() {
            #expect(f.position == samples.positions[i % samples.positions.count])
            #expect(f.tangent == samples.tangents[i % samples.positions.count])
        }
    }
}

@Test func normalsTurnNoMoreThanTheBend() throws {
    for name in ["helix", "trefoil", "lissajous", "reversal", "repeated"] {
        let samples = try #require(try frameCases().first { $0.0 == name }?.1)
        let excess = try rotationExcess(samples)
        #expect(excess <= 1e-9, "\(name): rotation exceeds the bend by \(excess)")
    }
}

@Test func reversalKeepsTheNormal() throws {
    let samples = try reversal()
    // The far end is a sample where the tangent turns by 180°: the tangent is the chord ahead.
    let far = try #require(samples.positions.firstIndex { ($0 - Vec3(1.5, 0.75, 0.375)).length < 1e-12 })
    #expect(far > 0 && angle(samples.tangents[far - 1], samples.tangents[far]) > Double.pi - 1e-9)
    let frames = try CurveFrames.parallelTransport(samples)
    #expect(gap(frames[far - 1].normal, frames[far].normal) <= 1e-9)
    #expect(frames.allSatisfy { $0.normal.isFinite && $0.binormal.isFinite })
}

@Test func repeatedPointsAreDroppedBeforeFraming() throws {
    let helix = try CurveSampler.sample(try CurveFixtures.helix(), tolerance: 1e-3)
    let doubled = try CurveSamples(positions: helix.positions.flatMap { [$0, $0] }, closed: false)
    #expect(doubled == helix)
    #expect(try CurveFrames.parallelTransport(doubled) == CurveFrames.parallelTransport(helix))
    let samples = try repeatedPoints()
    for i in 1..<samples.positions.count {
        #expect((samples.positions[i] - samples.positions[i - 1]).length > 1e-9)
    }
}

@Test func closedCurvesCloseExactly() throws {
    for (name, samples) in try frameCases() where samples.isClosed {
        let frames = try CurveFrames.parallelTransport(samples)
        let first = frames[0], seam = frames[frames.count - 1]
        let worst = max(gap(first.position, seam.position), gap(first.tangent, seam.tangent),
                        gap(first.normal, seam.normal), gap(first.binormal, seam.binormal))
        #expect(worst <= 1e-9, "\(name): seam gap \(worst)")
    }
}

@Test func framesAgreeWithTheExistingTubeFrames() throws {
    for (curve, closed) in [(try CurveFixtures.helix(), false), (try CurveFixtures.trefoil(), true)] {
        let samples = try CurveSampler.sample(curve, tolerance: 1e-3)
        let ours = try CurveFrames.parallelTransport(samples)
        let theirs = Mesh.pathFrames(samples.positions, closed: closed)
        #expect(ours.count == theirs.count)
        var worst = 0.0
        for (a, b) in zip(ours, theirs) {
            worst = max(worst, gap(a.tangent, b.0), gap(a.normal, b.1), gap(a.binormal, b.2))
        }
        #expect(worst <= 1e-9, "closed \(closed): disagreement \(worst)")
    }
}

@Test func initialNormalIsHonoured() throws {
    let circle = try CurveSampler.sample(try CurveFixtures.circle(), tolerance: 1e-3)
    let up = try CurveFrames.parallelTransport(circle, initialNormal: Vec3(0, 0.3, 2))
    #expect(gap(up[0].normal, Vec3(0, 0, 1)) <= 1e-12)   // the first tangent is +y: (0, 0.3, 2) loses its y part
    // A planar loop needs no closing twist: the normal stays +z all the way round.
    #expect(up.allSatisfy { gap($0.normal, Vec3(0, 0, 1)) <= 1e-9 })
    // Zero or parallel initial normals fall back to the least-parallel axis.
    let fallback = try CurveFrames.parallelTransport(circle)
    #expect(try CurveFrames.parallelTransport(circle, initialNormal: .zero) == fallback)
    #expect(try CurveFrames.parallelTransport(circle, initialNormal: circle.tangents[0] * 3) == fallback)
    #expect(throws: MeshError.self) { try CurveFrames.parallelTransport(circle, initialNormal: Vec3(.nan, 0, 0)) }
}
