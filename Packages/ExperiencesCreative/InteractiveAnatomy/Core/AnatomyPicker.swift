// AnatomyPicker — feature 125 (A17-P02) T-A17-203 (FR-A17-204, FR-A17-205; clarification Q4; data-model
// "AnatomyPick"; contracts/scene.md; SC-A17-202). Which visible part a line of sight meets first, on the CPU:
// - items whose layer is not in `visible` are skipped, so a hidden part is never hit;
// - an item whose world sphere the ray misses (`Ray3.intersect(sphereCenter:radius:)`) is skipped;
// - the remaining items' world triangles are tested (`Ray3.intersect(triangle:_:_:)`, two-sided), and the nearest hit
//   wins; distances within 1e-9 of each other count as equal and go to the lower part index;
// - a miss of every visible item, a non-finite origin or direction, or a zero direction gives nil.
// `pick(ndc:camera:aspect:scene:visible:)` casts the camera's ray through a normalised device point (x, y in −1…1,
// y up) with `OrbitCamera.ray(ndc:aspect:)`. Pure and deterministic.
import Foundation
import VisualCoreMath

/// Ray picking of a region scene's visible parts (see the file header).
public enum AnatomyPicker {
    /// Distances closer than this count as equal.
    public static let tieTolerance = 1e-9

    /// The part index and distance of the nearest visible part hit by the ray from `origin` along `direction`, or nil.
    public static func pick(origin: Vec3, direction: Vec3, scene: AnatomyScene,
                            visible: Set<AnatomyLayer>) -> (index: Int, distance: Double)? {
        guard let ray = Ray3(origin: origin, direction: direction) else { return nil }
        var best: (index: Int, distance: Double)?
        for item in scene.items where visible.contains(item.layer) {
            guard ray.intersect(sphereCenter: item.worldCenter, radius: max(item.worldRadius, 1e-9)) != nil else {
                continue
            }
            let corners = item.worldTriangles
            var t = 0
            while t + 2 < corners.count {
                if let hit = ray.intersect(triangle: corners[t], corners[t + 1], corners[t + 2]) {
                    best = better(best, (item.structureIndex, hit.distance))
                }
                t += 3
            }
        }
        return best
    }

    /// The nearest visible part under the normalised device point `ndc` seen through `camera` at `aspect`
    /// (width / height), or nil when the line of sight meets none.
    public static func pick(ndc: Vec2, camera: OrbitCamera, aspect: Double, scene: AnatomyScene,
                            visible: Set<AnatomyLayer>) -> (index: Int, distance: Double)? {
        let ray = camera.ray(ndc: ndc, aspect: aspect)
        return pick(origin: ray.origin, direction: ray.direction, scene: scene, visible: visible)
    }

    /// The better of two hits: the nearer one, or on a tie (within `tieTolerance`) the lower part index.
    static func better(_ current: (index: Int, distance: Double)?,
                       _ candidate: (index: Int, distance: Double)) -> (index: Int, distance: Double) {
        guard let current else { return candidate }
        if abs(candidate.distance - current.distance) <= tieTolerance {
            return candidate.index < current.index ? candidate : current
        }
        return candidate.distance < current.distance ? candidate : current
    }
}
