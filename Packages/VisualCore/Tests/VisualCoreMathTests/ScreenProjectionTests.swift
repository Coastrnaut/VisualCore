// ScreenProjectionTests — feature 222 (R02-F22) T-R02F22-002 (FR-R02F22-001; SC-R02F22-001; clarification Q1). For
// 1,000 seeded orbit cameras and world points, the ray through the projected point passes through the world point within
// 1e-9 of the camera distance; plane hits lie on their plane within 1e-12; parallel and behind rays miss; outside,
// non-finite and degenerate inputs give nil; rays agree with `OrbitCamera.ray(ndc:aspect:)`.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct ScreenProjectionTests {
    /// SplitMix64 (VisualCoreMath has no seeded generator of its own).
    private struct SplitMix {
        var state: UInt64
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) * 0x1.0p-53
        }
        mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
    }

    /// Distance from `p` to the line of `ray`.
    private func distance(_ p: Vec3, to ray: Ray3) -> Double {
        let w = p - ray.origin
        return (w - ray.direction * w.dot(ray.direction)).length
    }

    @Test func raysPassThroughProjectedPoints() throws {
        var random = SplitMix(state: 2_022)
        var worst: Double = 0
        var checked = 0
        for _ in 0..<1_000 {
            let camera = OrbitCamera(target: Vec3(random.range(-10, 10), random.range(-10, 10), random.range(-10, 10)),
                                     distance: random.range(1, 50), yaw: random.range(-3, 3), pitch: random.range(-1.4, 1.4))
            let viewport = Vec2(random.range(320, 1_400), random.range(320, 1_400))
            let vp = camera.viewProjection(aspect: viewport.x / viewport.y)
            let inverse = try #require(vp.inverse)
            // A point in front of the camera, near the target.
            let world = camera.target + Vec3(random.range(-1, 1), random.range(-1, 1), random.range(-1, 1)) * camera.distance * 0.3
            guard let projected = ScreenProjection.project(world, viewProjection: vp, viewport: viewport) else { continue }
            let p = projected.point
            guard p.x >= 0, p.x <= viewport.x, p.y >= 0, p.y <= viewport.y else { continue }
            let ray = try #require(ScreenProjection.ray(through: p, viewport: viewport, inverseViewProjection: inverse))
            let error = distance(world, to: ray) / camera.distance
            worst = max(worst, error)
            #expect(error <= 1e-9)
            #expect(projected.depth > -1 && projected.depth < 1)
            // The same ray as the camera's own picking ray for that NDC point.
            let ndc = Vec2(2 * p.x / viewport.x - 1, 1 - 2 * p.y / viewport.y)
            let own = camera.ray(ndc: ndc, aspect: viewport.x / viewport.y)
            #expect((own.direction - ray.direction).length <= 1e-9)
            checked += 1
        }
        print("ScreenProjectionTests SC-R02F22-001: \(checked) points, worst distance / camera distance \(worst)")
        #expect(checked >= 900)
    }

    @Test func planeHitsLieOnThePlane() throws {
        var random = SplitMix(state: 2_022)
        var hits = 0
        for _ in 0..<1_000 {
            let plane = try #require(Plane3(point: Vec3(random.range(-5, 5), random.range(-5, 5), random.range(-5, 5)),
                                            normal: Vec3(random.range(-1, 1), random.range(-1, 1), random.range(-1, 1)) + Vec3(0, 0.01, 0)))
            let ray = try #require(Ray3(origin: Vec3(random.range(-20, 20), random.range(-20, 20), random.range(-20, 20)),
                                        direction: Vec3(random.range(-1, 1), random.range(-1, 1), random.range(-1, 1)) + Vec3(0.001, 0, 0)))
            #expect(abs(plane.normal.length - 1) < 1e-15)
            if let hit = ray.intersect(plane: plane) {
                hits += 1
                #expect(abs(plane.signedDistance(hit.point)) <= 1e-12 * max(1, hit.distance))
                #expect(hit.distance >= 0)
                #expect(hit.normal.dot(ray.direction) <= 0)
                #expect((hit.point - (ray.origin + ray.direction * hit.distance)).length <= 1e-12 * max(1, hit.distance))
            } else {
                // A miss means parallel or behind.
                let d = ray.direction.dot(plane.normal)
                let t = (plane.point - ray.origin).dot(plane.normal) / d
                #expect(abs(d) < 1e-12 || t < 0)
            }
        }
        #expect(hits > 300 && hits < 1_000)
    }

    @Test func parallelBehindAndOnPlane() throws {
        let ground = try #require(Plane3(point: .zero, normal: Vec3(0, 2, 0)))
        #expect(ground.normal == Vec3(0, 1, 0))
        let parallel = try #require(Ray3(origin: Vec3(0, 1, 0), direction: Vec3(1, 0, 0)))
        #expect(parallel.intersect(plane: ground) == nil)
        let away = try #require(Ray3(origin: Vec3(0, 1, 0), direction: Vec3(0, 1, 0)))
        #expect(away.intersect(plane: ground) == nil)
        let down = try #require(Ray3(origin: Vec3(3, 2, -1), direction: Vec3(0, -1, 0)))
        let hit = try #require(down.intersect(plane: ground))
        #expect(hit.distance == 2 && hit.point == Vec3(3, 0, -1) && hit.normal == Vec3(0, 1, 0))
        let from = try #require(Ray3(origin: Vec3(1, 0, 1), direction: Vec3(0, 1, 1)))
        #expect(from.intersect(plane: ground)?.distance == 0)
        let below = try #require(Ray3(origin: Vec3(0, -2, 0), direction: Vec3(0, 1, 0)))
        #expect(below.intersect(plane: ground)?.normal == Vec3(0, -1, 0))
        #expect(Plane3(point: .zero, normal: .zero) == nil)
        #expect(Plane3(point: Vec3(.nan, 0, 0), normal: Vec3(0, 1, 0)) == nil)
        #expect(Plane3(point: .zero, normal: Vec3(0, .infinity, 0)) == nil)
    }

    @Test func refusalsGiveNil() throws {
        let camera = OrbitCamera(distance: 5)
        let vp = camera.viewProjection(aspect: 1)
        let inverse = try #require(vp.inverse)
        let viewport = Vec2(400, 400)
        #expect(ScreenProjection.ray(through: Vec2(200, 200), viewport: viewport, inverseViewProjection: inverse) != nil)
        #expect(ScreenProjection.ray(through: Vec2(0, 0), viewport: viewport, inverseViewProjection: inverse) != nil)
        #expect(ScreenProjection.ray(through: Vec2(400, 400), viewport: viewport, inverseViewProjection: inverse) != nil)
        #expect(ScreenProjection.ray(through: Vec2(-0.5, 10), viewport: viewport, inverseViewProjection: inverse) == nil)
        #expect(ScreenProjection.ray(through: Vec2(10, 400.5), viewport: viewport, inverseViewProjection: inverse) == nil)
        #expect(ScreenProjection.ray(through: Vec2(.nan, 10), viewport: viewport, inverseViewProjection: inverse) == nil)
        #expect(ScreenProjection.ray(through: Vec2(10, 10), viewport: Vec2(0, 400), inverseViewProjection: inverse) == nil)
        #expect(ScreenProjection.ray(through: Vec2(10, 10), viewport: Vec2(400, .infinity), inverseViewProjection: inverse) == nil)
        let zero = Mat4(Vec4.zero, Vec4.zero, Vec4.zero, Vec4.zero)
        #expect(ScreenProjection.ray(through: Vec2(10, 10), viewport: viewport, inverseViewProjection: zero) == nil)
        // The centre of the screen looks at the target; a point behind the camera does not project.
        let centre = try #require(ScreenProjection.ray(through: Vec2(200, 200), viewport: viewport, inverseViewProjection: inverse))
        #expect((centre.direction - (camera.target - camera.eye).normalized).length < 1e-9)
        let behind = camera.eye + (camera.eye - camera.target)
        #expect(ScreenProjection.project(behind, viewProjection: vp, viewport: viewport) == nil)
        #expect(ScreenProjection.project(Vec3(.nan, 0, 0), viewProjection: vp, viewport: viewport) == nil)
        #expect(ScreenProjection.project(.zero, viewProjection: vp, viewport: Vec2(-1, 1)) == nil)
        let target = try #require(ScreenProjection.project(camera.target, viewProjection: vp, viewport: viewport))
        #expect(abs(target.point.x - 200) < 1e-9 && abs(target.point.y - 200) < 1e-9)
    }
}
