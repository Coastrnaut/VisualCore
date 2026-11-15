// BroadPhase2D.swift — axis-aligned bounding boxes and a sweep-and-prune broad phase along x that reports exactly the
// overlapping pairs brute force would (feature 083 (A11-P02) T-A11-202 (FR-A11-202); contract specs/083-pp-p02-springs/
// contracts/api.md; research D2). Overlap is inclusive within 1e-9; boxes with a non-finite value never pair. Pure and
// deterministic: a stable order with an index tiebreak and output sorted by (a, b).
import Foundation
import VisualCoreMath

/// An axis-aligned bounding box in world units.
public struct AABB2D: Sendable, Equatable {
    /// Slack added to every overlap comparison so that touching boxes count as overlapping despite rounding.
    public static let tolerance: Double = 1e-9

    /// The lower-left corner (smallest x and y).
    public var min: Vec2
    /// The upper-right corner (largest x and y).
    public var max: Vec2

    /// Creates a box from its lower-left and upper-right corners.
    public init(min: Vec2, max: Vec2) {
        self.min = min
        self.max = max
    }

    /// True when every corner value is finite.
    public var isFinite: Bool { min.isFinite && max.isFinite }

    /// True when both boxes are finite and overlap or touch on both axes within `tolerance`.
    public func overlaps(_ other: AABB2D) -> Bool {
        guard isFinite, other.isFinite else { return false }
        return min.x <= other.max.x + Self.tolerance && other.min.x <= max.x + Self.tolerance
            && min.y <= other.max.y + Self.tolerance && other.min.y <= max.y + Self.tolerance
    }
}

/// A pair of overlapping boxes by index, with `a < b`.
public struct BroadPhasePair2D: Sendable, Equatable, Hashable {
    /// The smaller index.
    public var a: Int
    /// The larger index.
    public var b: Int

    /// Creates a pair from two indices (the caller passes `a < b`).
    public init(a: Int, b: Int) {
        self.a = a
        self.b = b
    }
}

/// A deterministic sweep-and-prune broad phase.
public enum BroadPhase2D {
    /// Returns every pair (a, b), a < b, of boxes that overlap per `AABB2D.overlaps(_:)`, sorted ascending by a then b.
    /// The boxes are swept in order of `min.x` (ties by index); a box leaves the active list once its `max.x` plus the
    /// tolerance falls below the current `min.x`. Boxes with a non-finite value are left out.
    public static func pairs(_ boxes: [AABB2D]) -> [BroadPhasePair2D] {
        let order = boxes.indices.filter { boxes[$0].isFinite }.sorted { i, j in
            boxes[i].min.x != boxes[j].min.x ? boxes[i].min.x < boxes[j].min.x : i < j
        }
        var active: [Int] = []
        var result: [BroadPhasePair2D] = []
        for i in order {
            let box = boxes[i]
            active.removeAll { boxes[$0].max.x + AABB2D.tolerance < box.min.x }
            for j in active where box.overlaps(boxes[j]) {
                result.append(BroadPhasePair2D(a: Swift.min(i, j), b: Swift.max(i, j)))
            }
            active.append(i)
        }
        result.sort { $0.a != $1.a ? $0.a < $1.a : $0.b < $1.b }
        return result
    }
}
