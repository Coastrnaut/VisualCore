// AtomPicker — feature 112 (A15-P03) T-A15-302 (FR-A15-310; clarification Q3; data-model "AtomPicker";
// contracts/selection.md; SC-A15-301). Which atom a line of sight meets first, on the CPU and without drawing:
// - the ray (origin, direction; the direction need not be unit length) is tested against every atom item's sphere —
//   its centre and its drawn radius in the scene's mode (0.30 × or 1.00 × the van der Waals radius), so picking uses
//   exactly the sizes drawn;
// - the hit with the smallest distance along the ray wins (`Ray3.intersect(sphereCenter:radius:)`, which gives only
//   non-negative distances; an origin inside a sphere hits it at distance 0); equal distances go to the lower atom
//   index; a miss of every sphere, a non-finite origin or direction, or a zero direction gives nil;
// - `pick(ndc:camera:aspect:scene:)` casts the camera's ray through a normalised device point (x, y in −1…1, y up)
//   with `OrbitCamera.ray(ndc:aspect:)`, which starts on the near plane.
// Bonds are never picked (version 0.1). Pure and deterministic: the same ray and scene give the same atom.
import Foundation
import VisualCoreMath

/// Ray-to-sphere picking of a scene's atoms (see the file header).
public enum AtomPicker {
    /// The index of the atom of `scene` whose drawn sphere the ray from `origin` along `direction` meets first, or nil
    /// when it meets none (ties by the lower index).
    public static func pick(origin: Vec3, direction: Vec3, scene: MoleculeScene) -> Int? {
        guard let ray = Ray3(origin: origin, direction: direction) else { return nil }
        var best: (index: Int, distance: Double)?
        for (index, atom) in scene.atoms.enumerated() {
            guard let hit = ray.intersect(sphereCenter: atom.position, radius: atom.radius) else { continue }
            if best == nil || hit.distance < best!.distance { best = (index, hit.distance) }
        }
        return best?.index
    }

    /// The atom of `scene` under the normalised device point `ndc` seen through `camera` at `aspect` (width / height),
    /// or nil when the line of sight meets no atom.
    public static func pick(ndc: Vec2, camera: OrbitCamera, aspect: Double, scene: MoleculeScene) -> Int? {
        let ray = camera.ray(ndc: ndc, aspect: aspect)
        return pick(origin: ray.origin, direction: ray.direction, scene: scene)
    }
}
