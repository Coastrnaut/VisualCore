// StrokeResampler — feature 145 (A20-P01) T-A20-106 (FR-A20-103; clarification Q2). Resamples a raw drag to points
// every 0.004 tray widths along its path (y scaled by the tray's 0.75), so a fast, sparse drag leaves no gap larger
// than the spacing. Repeated points (closer than 1e-6) are dropped, points outside the tray are clamped to its edge, a
// non-finite point refuses the stroke and a longer stroke ends at the cap of 512 points, marked capped. Pure arithmetic.
import Foundation
import VisualCoreMath

/// Resamples a raw drag into the evenly spaced points of a ``RakeStroke``.
public enum StrokeResampler {
    /// The spacing between neighbouring resampled points, in tray widths.
    public static let spacing = 0.004
    /// Points closer than this to the last kept point (in tray widths) are dropped as repeats.
    public static let repeatDistance = 1e-6

    /// The distance between `a` and `b` in tray widths: the x difference and the y difference scaled by the tray's
    /// ``GardenPalette/TrayDefinition/yScale``.
    public static func trayDistance(_ a: Vec2, _ b: Vec2) -> Double {
        let dx = b.x - a.x
        let dy = (b.y - a.y) * GardenPalette.smallTray.yScale
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Resamples `points` (normalized tray coordinates) to one point every `spacing` tray widths along the path.
    ///
    /// The first point is always kept and the last point ends the stroke unless the cap is reached first, in which
    /// case `capped` is true. One input point (after repeats are dropped) is a dab. An empty input, a non-finite
    /// coordinate, a spacing that is not positive and finite, or a cap below 1 refuses with
    /// ``DocumentRefusal/outOfRange(_:)``.
    public static func resample(_ points: [Vec2], spacing: Double = spacing,
                                cap: Int = RakeStroke.maxPoints) -> Result<(points: [Vec2], capped: Bool), DocumentRefusal> {
        guard !points.isEmpty, cap >= 1, spacing.isFinite, spacing > 0 else { return .failure(.outOfRange("points")) }
        var kept: [Vec2] = []
        kept.reserveCapacity(points.count)
        for point in points {
            guard point.isFinite else { return .failure(.outOfRange("points")) }
            let clamped = Vec2(min(max(point.x, 0), 1), min(max(point.y, 0), 1))
            if let last = kept.last, trayDistance(last, clamped) < repeatDistance { continue }
            kept.append(clamped)
        }
        var out: [Vec2] = [kept[0]]
        guard kept.count > 1 else { return .success((out, false)) }
        // `travelled` is the path distance from the last emitted point to the start of the current segment.
        var travelled = 0.0
        for index in 1..<kept.count {
            let a = kept[index - 1]
            let b = kept[index]
            let length = trayDistance(a, b)
            let start = spacing - travelled
            var step = 0
            var lastOffset = -travelled
            while true {
                let offset = start + Double(step) * spacing
                if offset > length { break }
                if out.count >= cap { return .success((out, true)) }
                out.append(a + (b - a) * (offset / length))
                lastOffset = offset
                step += 1
            }
            travelled = length - lastOffset
        }
        let last = kept[kept.count - 1]
        if trayDistance(out[out.count - 1], last) <= 1e-9 {
            out[out.count - 1] = last
        } else {
            if out.count >= cap { return .success((out, true)) }
            out.append(last)
        }
        return .success((out, false))
    }
}
