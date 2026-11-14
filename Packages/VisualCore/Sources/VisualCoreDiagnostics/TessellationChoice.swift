// TessellationChoice.swift — segment counts per quality tier (feature 044 A05-P05 T-A05-503; gap G-MESHLOD;
// FR-A05-531; spec clarifications Q2–Q3; contract api.md). The core keeps its reference mesh at full tessellation; the
// presenter asks this type how many segments to draw for the level in force, optionally under a vertex budget.

/// Chooses a tessellation (a number of segments) from a quality share, with a floor and an optional vertex budget.
///
/// Every function is pure and non-decreasing in `share`: a better quality level never draws fewer segments.
public enum TessellationChoice {
    /// The segment count for `share` of a `full` tessellation, never below `minimum`.
    ///
    /// The result is `clamp(Int((Double(full) × share).rounded()), lo…hi)` with `lo = max(1, min(minimum, full))` and
    /// `hi = max(lo, full)`. The share is clamped to 0…1 and a non-finite share gives `lo`. A `minimum` above `full`
    /// gives `full`; the result is always at least 1. The result is non-decreasing in `share`.
    ///
    /// - Parameters:
    ///   - full: The segment count at full quality.
    ///   - minimum: The smallest segment count any level may draw.
    ///   - share: The quality share, such as `QualityLevel.elementShare` (0…1).
    /// - Returns: The segment count, in `lo…hi`.
    public static func segments(full: Int, minimum: Int, share: Double) -> Int {
        let (lo, hi) = bounds(full: full, minimum: minimum)
        guard share.isFinite else { return lo }
        let s = min(max(share, 0), 1)
        let scaled = (Double(full) * s).rounded()
        return min(max(Int(scaled), lo), hi)
    }

    /// The segment count for `share` of a `full` tessellation, lowered until the mesh fits a vertex budget.
    ///
    /// Starts from `segments(full:minimum:share:)` and decrements while `vertices(s) > budget` and `s` is above
    /// `lo = max(1, min(minimum, full))`. When even `lo` exceeds the budget, `lo` is returned: the result is the best
    /// effort, and the caller must still check `vertices(result) <= budget` when the budget is a hard limit. For a
    /// `vertices` function that is non-decreasing in the segment count, the result is non-decreasing in `share`.
    ///
    /// - Parameters:
    ///   - full: The segment count at full quality.
    ///   - minimum: The smallest segment count any level may draw.
    ///   - share: The quality share (0…1; non-finite gives the floor).
    ///   - vertices: The vertex count of the mesh built with a given segment count.
    ///   - budget: The largest vertex count the mesh should have.
    /// - Returns: The largest segment count not above the unbudgeted choice that fits, or `lo`.
    public static func segments(full: Int, minimum: Int, share: Double,
                                vertices: (Int) -> Int, budget: Int) -> Int {
        let lo = bounds(full: full, minimum: minimum).lo
        var s = segments(full: full, minimum: minimum, share: share)
        while s > lo && vertices(s) > budget { s -= 1 }
        return s
    }

    /// The segment count for a quality level, using its `elementShare`.
    ///
    /// - Parameters:
    ///   - full: The segment count at full quality.
    ///   - minimum: The smallest segment count any level may draw.
    ///   - level: The quality level in force.
    /// - Returns: `segments(full: full, minimum: minimum, share: level.elementShare)`.
    public static func segments(full: Int, minimum: Int, level: QualityLevel) -> Int {
        segments(full: full, minimum: minimum, share: level.elementShare)
    }

    /// The floor `max(1, min(minimum, full))` and the ceiling `max(floor, full)`.
    private static func bounds(full: Int, minimum: Int) -> (lo: Int, hi: Int) {
        let lo = max(1, min(minimum, full))
        return (lo, max(lo, full))
    }
}
