// LabelLayout — feature 106 (A14-P04) T-A14-408 (FR-A14-420; clarification Q4; data-model "LabelLayout"). Where the
// body name labels of Solar System Explorer sit on the canvas overlay, computed from the drawn camera and nothing else
// (pure, host-free):
//   - each body's centre is projected with the camera the frame was drawn with (the caller passes the camera and the
//     positions in one frame; the presenter passes its camera-relative camera, target at the origin, and the positions
//     minus the drawn target, so the labels follow exactly what was drawn);
//   - a body gets no label when it lies behind the camera (clip w ≤ 0), outside the depth range (NDC z outside −1…1)
//     or when its projected centre is outside the canvas;
//   - the label's point is the projected centre moved 8 pt right and 8 pt up (canvas points, origin top-left, y down),
//     and its box is the 90 × 20 pt rectangle whose bottom-left corner is that point;
//   - labels are placed in order — the focused body first, then by increasing distance from the eye (ties by catalog
//     index) — and a label whose box overlaps an already placed box (by a positive area) is skipped.
// So no two placed labels ever overlap, and the focused body keeps its label whenever it is visible.
import Foundation
import VisualCoreMath

/// The placement of the body labels drawn over the canvas (see the file header).
enum LabelLayout {
    /// One placed label.
    struct Label: Equatable, Sendable {
        /// The body's catalog index, 0 (the Sun) … 8 (Neptune).
        let index: Int
        /// The body's name ("Earth").
        let name: String
        /// The label's anchor in canvas points (origin top-left, y down): the bottom-left corner of its box.
        let point: Vec2

        /// The label's box in canvas points: x from `point.x` to `point.x + 90`, y from `point.y − 20` to `point.y`.
        var box: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
            (point.x, point.y - LabelLayout.boxHeight, point.x + LabelLayout.boxWidth, point.y)
        }
    }

    /// How far right of the body's projected centre the label sits (points).
    static let offsetRight = 8.0
    /// How far above the body's projected centre the label sits (points).
    static let offsetUp = 8.0
    /// The width of a label's box (points).
    static let boxWidth = 90.0
    /// The height of a label's box (points).
    static let boxHeight = 20.0

    /// The canvas point (origin top-left, y down) of `position` through `camera` on a canvas of `canvas` points, or
    /// nil when it lies behind the camera (clip w ≤ 0), outside the depth range (NDC z outside −1…1), outside the
    /// canvas or is not finite.
    static func canvasPoint(of position: Vec3, camera: OrbitCamera, canvas: Vec2) -> Vec2? {
        guard canvas.x > 0, canvas.y > 0 else { return nil }
        let clip = camera.viewProjection(aspect: canvas.x / canvas.y) * Vec4(position, 1)
        guard clip.w.isFinite, clip.w > 0 else { return nil }
        let x = clip.x / clip.w, y = clip.y / clip.w, z = clip.z / clip.w
        guard x.isFinite, y.isFinite, z.isFinite, z >= -1, z <= 1 else { return nil }
        let point = Vec2((x + 1) / 2 * canvas.x, (1 - y) / 2 * canvas.y)
        guard point.x >= 0, point.x <= canvas.x, point.y >= 0, point.y <= canvas.y else { return nil }
        return point
    }

    /// Whether two boxes overlap by a positive area (touching edges do not overlap).
    static func overlaps(_ a: (minX: Double, minY: Double, maxX: Double, maxY: Double),
                         _ b: (minX: Double, minY: Double, maxX: Double, maxY: Double)) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    /// The labels of the bodies at `positions` (catalog order) seen through `camera` from `eye` on a canvas of
    /// `canvas` points with body `focused` in focus, in placing order (see the file header). `names` gives each body's
    /// name (the catalog's by default); a position without a name is named "".
    static func labels(camera: OrbitCamera, canvas: Vec2, positions: [Vec3], focused: Int, eye: Vec3,
                       names: [String] = SolarCore.catalog.bodies.map(\.name)) -> [Label] {
        var order: [Int] = []
        for index in positions.indices { order.append(index) }
        var distances: [Double] = []
        for position in positions { distances.append((position - eye).length) }
        order.sort { a, b in
            if a == focused { return b != focused }
            if b == focused { return false }
            if distances[a] != distances[b] { return distances[a] < distances[b] }
            return a < b
        }
        var placed: [Label] = []
        for index in order {
            guard let centre = canvasPoint(of: positions[index], camera: camera, canvas: canvas) else { continue }
            let name = names.indices.contains(index) ? names[index] : ""
            let label = Label(index: index, name: name, point: Vec2(centre.x + offsetRight, centre.y - offsetUp))
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
