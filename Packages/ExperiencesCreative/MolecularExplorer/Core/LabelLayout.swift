// LabelLayout — feature 112 (A15-P03) T-A15-303 (FR-A15-320; clarification Q4; data-model "LabelLayout.Label";
// contracts/selection.md; SC-A15-303). Where the element-symbol labels of Molecular Explorer sit on the canvas overlay,
// computed from the drawn camera and the scene alone (pure, host-free; modelled on Solar System Explorer's layout):
// - each atom's centre is projected with the camera the frame was drawn with; an atom gets no label when it lies
//   behind the camera (clip w ≤ 0), outside the depth range (NDC z outside −1…1), when its projected centre is outside
//   the canvas or is not finite;
// - the label's point is the projected centre moved 6 pt right and 6 pt up (canvas points, origin top-left, y down),
//   and its box is the 24 × 18 pt rectangle whose bottom-left corner is that point (x from point.x to point.x + 24,
//   y from point.y − 18 to point.y);
// - labels are placed in order — the selected atom first (when it is an index of the scene), then by increasing
//   distance of the atom's centre from the camera's eye, ties by the lower atom index — and a label whose box overlaps
//   an already placed box by a positive area (touching edges do not overlap) is skipped.
// So no two placed labels ever overlap, and the selected atom keeps its label whenever its centre is on the canvas.
import Foundation
import VisualCoreMath

/// The placement of the element-symbol labels drawn over the canvas (see the file header).
public enum LabelLayout {
    /// One placed label.
    public struct Label: Equatable, Sendable {
        /// The atom's index in the scene.
        public let index: Int
        /// The atom's element symbol ("N").
        public let symbol: String
        /// The label's anchor in canvas points (origin top-left, y down): the bottom-left corner of its box.
        public let point: Vec2

        /// Creates a label.
        public init(index: Int, symbol: String, point: Vec2) {
            self.index = index; self.symbol = symbol; self.point = point
        }

        /// The label's box in canvas points: x from `point.x` to `point.x + 24`, y from `point.y − 18` to `point.y`.
        public var box: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
            (point.x, point.y - LabelLayout.boxHeight, point.x + LabelLayout.boxWidth, point.y)
        }
    }

    /// The width of a label's box (points).
    public static let boxWidth = 24.0
    /// The height of a label's box (points).
    public static let boxHeight = 18.0
    /// How far right of and above the atom's projected centre the label's anchor sits (points).
    public static let offset = 6.0

    /// The canvas point (origin top-left, y down) of `position` through `camera` on a canvas of `canvas` points, or
    /// nil when it lies behind the camera (clip w ≤ 0), outside the depth range (NDC z outside −1…1), outside the
    /// canvas or is not finite.
    public static func canvasPoint(of position: Vec3, camera: OrbitCamera, canvas: Vec2) -> Vec2? {
        guard canvas.x > 0, canvas.y > 0, canvas.isFinite else { return nil }
        let clip = camera.viewProjection(aspect: canvas.x / canvas.y) * Vec4(position, 1)
        guard clip.w.isFinite, clip.w > 0 else { return nil }
        let x = clip.x / clip.w, y = clip.y / clip.w, z = clip.z / clip.w
        guard x.isFinite, y.isFinite, z.isFinite, z >= -1, z <= 1 else { return nil }
        let point = Vec2((x + 1) / 2 * canvas.x, (1 - y) / 2 * canvas.y)
        guard point.x >= 0, point.x <= canvas.x, point.y >= 0, point.y <= canvas.y else { return nil }
        return point
    }

    /// Whether two boxes overlap by a positive area (touching edges do not overlap).
    public static func overlaps(_ a: (minX: Double, minY: Double, maxX: Double, maxY: Double),
                                _ b: (minX: Double, minY: Double, maxX: Double, maxY: Double)) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    /// The labels of the atoms of `scene` seen through `camera` on a canvas of `canvas` points with atom `selected`
    /// (or none), in placing order (see the file header).
    public static func labels(scene: MoleculeScene, camera: OrbitCamera, canvas: Vec2, selected: Int?) -> [Label] {
        let eye = camera.eye
        var distances: [Double] = []
        distances.reserveCapacity(scene.atoms.count)
        for atom in scene.atoms { distances.append((atom.position - eye).length) }
        let chosen = selected.flatMap { scene.atoms.indices.contains($0) ? $0 : nil }
        var order: [Int] = Array(scene.atoms.indices)
        order.sort { a, b in
            if a == chosen { return b != chosen }
            if b == chosen { return false }
            if distances[a] != distances[b] { return distances[a] < distances[b] }
            return a < b
        }
        var placed: [Label] = []
        for index in order {
            let atom = scene.atoms[index]
            guard let centre = canvasPoint(of: atom.position, camera: camera, canvas: canvas) else { continue }
            let label = Label(index: index, symbol: atom.symbol, point: Vec2(centre.x + offset, centre.y - offset))
            var free = true
            for other in placed where overlaps(label.box, other.box) {
                free = false
                break
            }
            if free { placed.append(label) }
        }
        return placed
    }
}
