// AnchoredLabelLayout — feature 127 (A17-P04) T-A17-402 (FR-A17-402, FR-A17-403; clarification Q2; data-model
// "AnchoredLabelLayout.Candidate", "AnchoredLabelLayout.Placement"; contracts/accessibility-pack.md; SC-A17-402).
// The generic form of the label layouts of Solar System Explorer (feature 106) and Molecular Explorer (feature 112):
// where text labels anchored to model-space points sit on a 2D canvas overlay, computed from the camera alone (pure,
// host-free, deterministic):
// - candidates are taken in a stable order by increasing priority, then increasing id;
// - each anchor is projected with the camera; one behind the camera (clip w ≤ 0), outside clip depth (NDC z outside
//   −1…1) or not finite is culled;
// - the box sits 6 points right of and 6 points up from the projected anchor (canvas points, origin top-left, y down):
//   minX = x + 6, maxY = y − 6, minY = maxY − height, maxX = minX + width; a box not wholly inside the canvas
//   [0, canvas.x] × [0, canvas.y] is dropped;
// - a box that overlaps an already placed box by a positive area (touching edges do not overlap) is skipped;
// - at most `budget` boxes are placed (a budget ≤ 0 places none); candidates with a non-finite anchor or a
//   non-finite or non-positive size are skipped.
// So no two placements ever overlap, and the first candidate in order is placed whenever its box fits the canvas.
import Foundation

/// The placement of labels anchored to model-space points on a canvas overlay (see the file header).
public enum AnchoredLabelLayout {
    /// One label that may be placed.
    public struct Candidate: Equatable, Sendable {
        /// The caller's identifier of the label (also the second sort key).
        public let id: Int
        /// The model-space point the label belongs to.
        public let anchor: Vec3
        /// The label box's width (`x`) and height (`y`) in canvas points.
        public let size: Vec2
        /// The placing priority: lower values are placed first.
        public let priority: Int

        /// Creates a candidate.
        public init(id: Int, anchor: Vec3, size: Vec2, priority: Int) {
            self.id = id; self.anchor = anchor; self.size = size; self.priority = priority
        }
    }

    /// One placed label, in canvas points (origin top-left, y down).
    public struct Placement: Equatable, Sendable {
        /// The identifier of the candidate that was placed.
        public let id: Int
        /// The projected anchor on the canvas.
        public let point: Vec2
        /// The left edge of the label's box.
        public let minX: Double
        /// The top edge of the label's box.
        public let minY: Double
        /// The right edge of the label's box.
        public let maxX: Double
        /// The bottom edge of the label's box.
        public let maxY: Double

        /// Creates a placement.
        public init(id: Int, point: Vec2, minX: Double, minY: Double, maxX: Double, maxY: Double) {
            self.id = id; self.point = point
            self.minX = minX; self.minY = minY; self.maxX = maxX; self.maxY = maxY
        }
    }

    /// How far right of and above the projected anchor the label's box sits (points).
    public static let offset = 6.0

    /// The canvas point (origin top-left, y down) of `position` through `camera` with `aspect` on a canvas of
    /// `canvas` points, or nil when it lies behind the camera (clip w ≤ 0), outside clip depth (NDC z outside −1…1),
    /// when the canvas is not positive and finite or a value is not finite. The point may lie outside the canvas.
    public static func canvasPoint(of position: Vec3, camera: OrbitCamera, aspect: Double, canvas: Vec2) -> Vec2? {
        guard position.isFinite, canvas.isFinite, canvas.x > 0, canvas.y > 0 else { return nil }
        let clip = camera.viewProjection(aspect: aspect) * Vec4(position, 1)
        guard clip.w.isFinite, clip.w > 0 else { return nil }
        let x = clip.x / clip.w, y = clip.y / clip.w, z = clip.z / clip.w
        guard x.isFinite, y.isFinite, z.isFinite, z >= -1, z <= 1 else { return nil }
        let point = Vec2((x + 1) / 2 * canvas.x, (1 - y) / 2 * canvas.y)
        return point.isFinite ? point : nil
    }

    /// Whether two placed boxes overlap by a positive area (touching edges do not overlap).
    public static func overlaps(_ a: Placement, _ b: Placement) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    /// The placements of `candidates` seen through `camera` with `aspect` on a canvas of `canvas` points, at most
    /// `budget` of them, in placing order (priority, then id; see the file header).
    public static func place(_ candidates: [Candidate], camera: OrbitCamera, aspect: Double, canvas: Vec2,
                             budget: Int) -> [Placement] {
        guard budget > 0, canvas.isFinite, canvas.x > 0, canvas.y > 0 else { return [] }
        // Sorting indices with the input position as the last key keeps equal (priority, id) pairs in input order.
        let order = candidates.indices.sorted { i, j in
            let a = candidates[i], b = candidates[j]
            if a.priority != b.priority { return a.priority < b.priority }
            if a.id != b.id { return a.id < b.id }
            return i < j
        }
        var placed: [Placement] = []
        for index in order {
            let candidate = candidates[index]
            if placed.count >= budget { break }
            let size = candidate.size
            guard size.isFinite, size.x > 0, size.y > 0 else { continue }
            guard let point = canvasPoint(of: candidate.anchor, camera: camera, aspect: aspect, canvas: canvas)
            else { continue }
            let minX = point.x + offset
            let maxY = point.y - offset
            let minY = maxY - size.y
            let maxX = minX + size.x
            guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite,
                  minX >= 0, minY >= 0, maxX <= canvas.x, maxY <= canvas.y else { continue }
            let placement = Placement(id: candidate.id, point: point, minX: minX, minY: minY, maxX: maxX, maxY: maxY)
            var free = true
            for other in placed where overlaps(placement, other) {
                free = false
                break
            }
            if free { placed.append(placement) }
        }
        return placed
    }
}
