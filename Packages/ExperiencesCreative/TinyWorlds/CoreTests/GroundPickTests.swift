// GroundPickTests — feature 090 (A12-P02) T-A12-204 (FR-A12-221; clarification 2; research D5). The ground pick,
// host-free and short: vertical rays from above hit straight below at the sampled terrain height; oblique rays from
// above hit a point whose ray height is within 1 mm of the terrain height there; rays from the default camera through
// the target hit; sky rays (upwards, or passing above or beside the world box) give nil; the answer is deterministic.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct GroundPickTests {
    @Test(arguments: WorldPreset.all)
    func verticalRaysHitStraightBelowAtTheTerrainHeight(preset: WorldPreset) throws {
        let field = try TerrainGenerator.heightField(preset: preset, seed: 1)
        for i in 0...6 {
            for j in 0...6 {
                let x = -5.5 + 11 * Double(i) / 6, z = -5.5 + 11 * Double(j) / 6
                let ray = try #require(Ray3(origin: Vec3(x, 5, z), direction: Vec3(0, -1, 0)))
                let hit = try #require(GroundPick.hit(ray: ray, field: field))
                #expect(abs(hit.x - x) < 1e-9 && abs(hit.z - z) < 1e-9)
                #expect(abs(hit.y - field.height(atX: x, z: z)) < 1e-3)
            }
        }
    }

    @Test(arguments: WorldPreset.all)
    func obliqueRaysHitWithinOneMillimetreOfTheTerrain(preset: WorldPreset) throws {
        let field = try TerrainGenerator.heightField(preset: preset, seed: 1)
        // Each ray aims from above the world at a point on the box floor (y = −1) within 4 m of the centre, so it
        // stays over the field and must meet the terrain (never below −1 m) on the way.
        let targets = [Vec3(3, -1, 2), Vec3(-4, -1, 1), Vec3(2, -1, -3.5), Vec3(-1, -1, -4)]
        for target in targets {
            for start in [Vec3(-2, 4, -1), Vec3(1.5, 3, 2), Vec3(0, 6, 0)] {
                let ray = try #require(Ray3(origin: start, direction: target - start))
                let hit = try #require(GroundPick.hit(ray: ray, field: field), "\(target) from \(start)")
                // The ray's own height at the hit's x and z (t from the larger horizontal component).
                let t = abs(ray.direction.x) > abs(ray.direction.z)
                    ? (hit.x - ray.origin.x) / ray.direction.x : (hit.z - ray.origin.z) / ray.direction.z
                let rayPoint = ray.origin + ray.direction * t
                #expect(t >= 0)
                #expect(abs(rayPoint.y - hit.y) < 1e-3, "\(preset.id.contentId) \(target) from \(start)")
                #expect(abs(hit.y - field.height(atX: hit.x, z: hit.z)) < 1e-12)
                #expect(GroundPick.hit(ray: ray, field: field) == hit, "deterministic")
            }
        }
    }

    @Test(arguments: WorldPreset.all)
    func theDefaultCameraRayThroughTheTargetHits(preset: WorldPreset) throws {
        let field = try TerrainGenerator.heightField(preset: preset, seed: 1)
        let camera = CameraPolicy.camera(for: .default)
        let picked = camera.ray(ndc: Vec2(0, 0), aspect: 1.5)
        let ray = try #require(Ray3(origin: picked.origin, direction: picked.direction))
        let hit = try #require(GroundPick.hit(ray: ray, field: field))
        #expect(abs(hit.x) < 6 && abs(hit.z) < 6)
        #expect(WorldPreset.heightRange.contains(hit.y))
    }

    @Test func skyRaysMiss() throws {
        let field = try TerrainGenerator.heightField(preset: .island, seed: 1)
        let rays: [(Vec3, Vec3)] = [
            (Vec3(0, 5, 0), Vec3(0, 1, 0)),          // straight up from above
            (Vec3(0, 3, -20), Vec3(0, 0, 1)),        // level, above the box
            (Vec3(-20, 0.5, 9), Vec3(1, 0, 0)),      // beside the box
            (Vec3(5.9, 1.59, 5.9), Vec3(0.2, 1, 0)), // inside the box over the sea corner, leaving upwards
            (Vec3(0, 3, -20), Vec3(0, 0.1, 1)),      // rising over the world
        ]
        for (origin, direction) in rays {
            let ray = try #require(Ray3(origin: origin, direction: direction))
            #expect(GroundPick.hit(ray: ray, field: field) == nil, "\(origin) \(direction)")
        }
    }

    @Test func theWorldBoxSpansTheFieldAndTheHeightRange() throws {
        let field = try TerrainGenerator.heightField(preset: .miniatureCity, seed: 1)
        let box = GroundPick.box(of: field)
        #expect(box.min == Vec3(-6, -1, -6) && box.max == Vec3(6, 1.6, 6))
        #expect(GroundPick.bisections == 40)
    }
}
