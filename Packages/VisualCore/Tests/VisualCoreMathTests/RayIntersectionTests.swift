// RayIntersectionTests — feature 090 (A12-P02) T-A12-202 (FR-A12-202; SC-A12-202; gap G-PICKING; research D2).
import Foundation
import Testing
@testable import VisualCoreMath

private func ray(_ o: Vec3, _ d: Vec3) -> Ray3 { Ray3(origin: o, direction: d)! }

private func facesAgainst(_ hit: RayHit3, _ r: Ray3) -> Bool {
    close(hit.normal.length, 1, 1e-12) && hit.normal.dot(r.direction) <= 0
}

// MARK: Ray3 construction

@Test func rayInitNormalisesDirection() {
    let r = ray(Vec3(1, 2, 3), Vec3(0, 3, 4))
    #expect(close(r.direction, Vec3(0, 0.6, 0.8)))
    #expect(r.origin == Vec3(1, 2, 3))
}

@Test func rayInitRefusesInvalidValues() {
    #expect(Ray3(origin: .zero, direction: .zero) == nil)
    #expect(Ray3(origin: Vec3(.nan, 0, 0), direction: Vec3(1, 0, 0)) == nil)
    #expect(Ray3(origin: Vec3(0, .infinity, 0), direction: Vec3(1, 0, 0)) == nil)
    #expect(Ray3(origin: .zero, direction: Vec3(0, 0, .nan)) == nil)
    #expect(Ray3(origin: .zero, direction: Vec3(-.infinity, 0, 0)) == nil)
    #expect(Ray3(origin: .zero, direction: Vec3(1e-320, 0, 0)) == nil, "direction too small to normalise")
}

// MARK: Box

@Test func boxAxisAlignedHit() {
    let r = ray(Vec3(-2, 0.5, 0.5), Vec3(1, 0, 0))
    let hit = r.intersect(boxMin: .zero, boxMax: Vec3(1, 1, 1))
    #expect(hit != nil)
    guard let hit else { return }
    #expect(close(hit.distance, 2, 1e-9))
    #expect(close(hit.point, Vec3(0, 0.5, 0.5), 1e-9))
    #expect(close(hit.normal, Vec3(-1, 0, 0), 1e-9))
    #expect(facesAgainst(hit, r))
}

@Test func boxDiagonalHitOnOffsetBox() {
    // Offset box [2, 4]³ hit by the diagonal from the origin: enters at the corner (2, 2, 2), distance 2√3.
    let r = ray(.zero, Vec3(1, 1, 1))
    let hit = r.intersect(boxMin: Vec3(2, 2, 2), boxMax: Vec3(4, 4, 4))
    #expect(hit != nil)
    guard let hit else { return }
    #expect(close(hit.distance, 2 * 3.0.squareRoot(), 1e-9))
    #expect(close(hit.point, Vec3(2, 2, 2), 1e-9))
    #expect(facesAgainst(hit, r))
    // A diagonal ray in the xz plane hitting the top face from above.
    let down = ray(Vec3(0, 5, 0), Vec3(1, -1, 0))
    let top = down.intersect(boxMin: Vec3(2, 0, -1), boxMax: Vec3(6, 2, 1))
    #expect(top != nil)
    guard let top else { return }
    #expect(close(top.distance, 3 * 2.0.squareRoot(), 1e-9))
    #expect(close(top.point, Vec3(3, 2, 0), 1e-9))
    #expect(close(top.normal, Vec3(0, 1, 0), 1e-9))
}

@Test func boxGrazingEdgeAndFace() {
    // Through the edge x = 0, y = 1 of the unit box at 45°: hits exactly once at the edge.
    let r = ray(Vec3(-1, 2, 0.5), Vec3(1, -1, 0))
    let hit = r.intersect(boxMin: .zero, boxMax: Vec3(1, 1, 1))
    #expect(hit != nil)
    guard let hit else { return }
    #expect(close(hit.distance, 2.0.squareRoot(), 1e-9))
    #expect(close(hit.point, Vec3(0, 1, 0.5), 1e-9))
    #expect(facesAgainst(hit, r))
    // Parallel to the y slab and lying in its boundary plane y = 1: still inside the slab, hits the x = 0 face.
    let along = ray(Vec3(-2, 1, 0.5), Vec3(1, 0, 0))
    let face = along.intersect(boxMin: .zero, boxMax: Vec3(1, 1, 1))
    #expect(face != nil)
    #expect(close(face?.distance ?? -1, 2, 1e-9))
    #expect(close(face?.normal ?? .zero, Vec3(-1, 0, 0), 1e-9))
    // Parallel to the y slab but just outside it: miss.
    #expect(ray(Vec3(-2, 1 + 1e-6, 0.5), Vec3(1, 0, 0)).intersect(boxMin: .zero, boxMax: Vec3(1, 1, 1)) == nil)
}

@Test func boxInsideStartsAtZero() {
    let r = ray(Vec3(0.5, 0.5, 0.5), Vec3(0, 0, 1))
    let hit = r.intersect(boxMin: .zero, boxMax: Vec3(1, 1, 1))
    #expect(hit?.distance == 0)
    #expect(hit?.point == Vec3(0.5, 0.5, 0.5))
    #expect(close(hit?.normal ?? .zero, Vec3(0, 0, -1)))
}

@Test func boxMissesAndInvalidBoxes() {
    let unitMin = Vec3.zero, unitMax = Vec3(1, 1, 1)
    #expect(ray(Vec3(-2, 0.5, 0.5), Vec3(-1, 0, 0)).intersect(boxMin: unitMin, boxMax: unitMax) == nil, "box behind")
    #expect(ray(Vec3(-2, 3, 0.5), Vec3(1, 0, 0)).intersect(boxMin: unitMin, boxMax: unitMax) == nil, "passes above")
    #expect(ray(Vec3(-2, 0, 0), Vec3(1, 1.5, 0)).intersect(boxMin: unitMin, boxMax: unitMax) == nil, "passes the corner")
    let r = ray(Vec3(-2, 0.5, 0.5), Vec3(1, 0, 0))
    #expect(r.intersect(boxMin: unitMax, boxMax: unitMin) == nil, "min above max")
    #expect(r.intersect(boxMin: Vec3(.nan, 0, 0), boxMax: unitMax) == nil)
    #expect(r.intersect(boxMin: unitMin, boxMax: Vec3(1, .infinity, 1)) == nil)
}

// MARK: Sphere

@Test func sphereAxisAndDiagonalHits() {
    let r = ray(Vec3(0, 0, 10), Vec3(0, 0, -1))
    let hit = r.intersect(sphereCenter: .zero, radius: 2)
    #expect(hit != nil)
    guard let hit else { return }
    #expect(close(hit.distance, 8, 1e-9))
    #expect(close(hit.point, Vec3(0, 0, 2), 1e-9))
    #expect(close(hit.normal, Vec3(0, 0, 1), 1e-9))
    #expect(facesAgainst(hit, r))
    // Offset sphere at (3, 3, 3), radius 1, hit along the diagonal: distance 3√3 − 1.
    let d = ray(.zero, Vec3(1, 1, 1))
    let diag = d.intersect(sphereCenter: Vec3(3, 3, 3), radius: 1)
    #expect(diag != nil)
    guard let diag else { return }
    let s = 1 / 3.0.squareRoot()
    #expect(close(diag.distance, 3 * 3.0.squareRoot() - 1, 1e-9))
    #expect(close(diag.normal, Vec3(-s, -s, -s), 1e-9))
    #expect(facesAgainst(diag, d))
}

@Test func sphereTangentHitsOnce() {
    let r = ray(Vec3(-5, 1, 0), Vec3(1, 0, 0))
    let hit = r.intersect(sphereCenter: .zero, radius: 1)
    #expect(hit != nil)
    guard let hit else { return }
    #expect(close(hit.distance, 5, 1e-9))
    #expect(close(hit.point, Vec3(0, 1, 0), 1e-9))
    #expect(close(hit.normal, Vec3(0, 1, 0), 1e-9))
    #expect(facesAgainst(hit, r))
    #expect(ray(Vec3(-5, 1 + 1e-6, 0), Vec3(1, 0, 0)).intersect(sphereCenter: .zero, radius: 1) == nil)
}

@Test func sphereInsideStartsAtZero() {
    let r = ray(Vec3(0.2, 0, 0), Vec3(0, 1, 0))
    let hit = r.intersect(sphereCenter: .zero, radius: 1)
    #expect(hit?.distance == 0)
    #expect(hit?.point == Vec3(0.2, 0, 0))
    #expect(close(hit?.normal ?? .zero, Vec3(0, -1, 0)))
}

@Test func sphereMissesAndInvalidSpheres() {
    let r = ray(Vec3(0, 0, 10), Vec3(0, 0, -1))
    #expect(ray(Vec3(0, 0, 10), Vec3(0, 0, 1)).intersect(sphereCenter: .zero, radius: 2) == nil, "sphere behind")
    #expect(r.intersect(sphereCenter: Vec3(5, 0, 0), radius: 2) == nil, "passes beside")
    #expect(r.intersect(sphereCenter: .zero, radius: 0) == nil)
    #expect(r.intersect(sphereCenter: .zero, radius: -1) == nil)
    #expect(r.intersect(sphereCenter: .zero, radius: .nan) == nil)
    #expect(r.intersect(sphereCenter: .zero, radius: .infinity) == nil)
    #expect(r.intersect(sphereCenter: Vec3(.nan, 0, 0), radius: 1) == nil)
}

// MARK: Triangle

@Test func triangleHitsFromBothSides() {
    let a = Vec3(0, 0, 0), b = Vec3(2, 0, 0), c = Vec3(0, 2, 0)
    let front = ray(Vec3(0.5, 0.5, 3), Vec3(0, 0, -1))
    let f = front.intersect(triangle: a, b, c)
    #expect(f != nil)
    #expect(close(f?.distance ?? -1, 3, 1e-9))
    #expect(close(f?.point ?? .zero, Vec3(0.5, 0.5, 0), 1e-9))
    #expect(close(f?.normal ?? .zero, Vec3(0, 0, 1), 1e-9))
    let back = ray(Vec3(0.5, 0.5, -4), Vec3(0, 0, 1))
    let k = back.intersect(triangle: a, b, c)
    #expect(close(k?.distance ?? -1, 4, 1e-9))
    #expect(close(k?.normal ?? .zero, Vec3(0, 0, -1), 1e-9), "two-sided: normal faces the ray")
    // Diagonal ray onto an offset tilted triangle in the plane x + y + z = 3.
    let d = ray(.zero, Vec3(1, 1, 1))
    let t = d.intersect(triangle: Vec3(3, 0, 0), Vec3(0, 3, 0), Vec3(0, 0, 3))
    #expect(t != nil)
    guard let t else { return }
    let s = 1 / 3.0.squareRoot()
    #expect(close(t.distance, 3.0.squareRoot(), 1e-9))
    #expect(close(t.point, Vec3(1, 1, 1), 1e-9))
    #expect(close(t.normal, Vec3(-s, -s, -s), 1e-9))
    #expect(facesAgainst(t, d))
}

@Test func triangleParallelDegenerateAndMisses() {
    let a = Vec3(0, 0, 0), b = Vec3(2, 0, 0), c = Vec3(0, 2, 0)
    #expect(ray(Vec3(-1, 0.5, 0), Vec3(1, 0, 0)).intersect(triangle: a, b, c) == nil, "in the plane")
    #expect(ray(Vec3(-1, 0.5, 1), Vec3(1, 0, 0)).intersect(triangle: a, b, c) == nil, "parallel above")
    let down = ray(Vec3(0.5, 0.5, 3), Vec3(0, 0, -1))
    #expect(down.intersect(triangle: a, b, Vec3(4, 0, 0)) == nil, "collinear")
    #expect(down.intersect(triangle: a, a, c) == nil, "repeated vertex")
    #expect(down.intersect(triangle: a, b, Vec3(.nan, 0, 0)) == nil)
    #expect(ray(Vec3(1.5, 1.5, 3), Vec3(0, 0, -1)).intersect(triangle: a, b, c) == nil, "outside the hypotenuse")
    #expect(ray(Vec3(0.5, 0.5, 3), Vec3(0, 0, 1)).intersect(triangle: a, b, c) == nil, "behind")
}

// MARK: Nearest and camera

@Test func nearestOfSeveral() {
    let r = ray(Vec3(0, 0, 10), Vec3(0, 0, -1))
    let hits: [RayHit3?] = [
        r.intersect(sphereCenter: Vec3(0, 0, -5), radius: 1),
        nil,
        r.intersect(boxMin: Vec3(-1, -1, 2), boxMax: Vec3(1, 1, 4)),
        r.intersect(triangle: Vec3(-1, -1, 0), Vec3(1, -1, 0), Vec3(0, 1, 0)),
        r.intersect(sphereCenter: Vec3(9, 0, 0), radius: 1),
    ]
    let best = Ray3.nearest(hits)
    #expect(close(best?.distance ?? -1, 6, 1e-9))
    #expect(close(best?.normal ?? .zero, Vec3(0, 0, 1), 1e-9))
    #expect(Ray3.nearest([]) == nil)
    #expect(Ray3.nearest([nil, nil]) == nil)
}

@Test func orbitCameraCentreRayHitsBoxAtTarget() {
    let target = Vec3(0, 0.3, 0)
    for (yaw, pitch) in [(0.0, 0.0), (0.7, 0.5), (-2.1, 1.2), (3.0, 0.2)] {
        let cam = OrbitCamera(target: target, distance: 20, yaw: yaw, pitch: pitch)
        let (origin, direction) = cam.ray(ndc: .zero, aspect: 1.5)
        let r = Ray3(origin: origin, direction: direction)
        #expect(r != nil)
        guard let r else { continue }
        let half = Vec3(0.5, 0.5, 0.5)
        let hit = r.intersect(boxMin: target - half, boxMax: target + half)
        #expect(hit != nil, "yaw \(yaw) pitch \(pitch)")
        guard let hit else { continue }
        #expect(facesAgainst(hit, r))
        #expect(hit.distance > 0 && hit.distance < 20)
        // The entry point lies on the eye–target line, between 0.5 and 0.5√3 m from the target.
        let fromTarget = (hit.point - target).length
        #expect(fromTarget >= 0.5 - 1e-9 && fromTarget <= 0.5 * 3.0.squareRoot() + 1e-9)
        #expect((hit.point - target).cross(direction).length < 1e-9)
    }
}
