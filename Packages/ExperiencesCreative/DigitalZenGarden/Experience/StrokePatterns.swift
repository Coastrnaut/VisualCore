// StrokePatterns — feature 146 (A20-P02) T-A20-204 (FR-A20-201, FR-A20-205; clarification Q3; data-model.md
// "StrokePatterns"). The four "rake a pattern" strokes of the native controls: rows (three passes back and forth),
// circle, wave and spiral, each one list of points in normalized tray coordinates whose resampled length stays below the
// stroke's point cap (512 points of 0.004 tray widths). `send(_:rake:port:)` rakes a pattern with exactly the actions
// of a drag: `stroke.begin` at the first point, `stroke.add` with twelve points at a time (unused pairs repeat the last
// point) and `stroke.end`, so every gesture action has a native alternative.
import Foundation
import DigitalZenGardenCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

/// The four pattern strokes and the actions that rake them.
enum StrokePatterns {
    /// The pattern names in the order of the controls.
    static let names = ["rows", "circle", "wave", "spiral"]
    /// The spoken titles, by index of `names`.
    static let titles = ["Rows", "Circle", "Wave", "Spiral"]

    /// Three horizontal passes back and forth across the middle of the tray, joined at the ends.
    static var rows: [Vec2] {
        var points: [Vec2] = []
        let left = 0.225
        let right = 0.775
        let samples = 24
        for pass in 0..<3 {
            let y = 0.3 + 0.2 * Double(pass)
            for index in 0...samples {
                let t = Double(index) / Double(samples)
                let x = pass % 2 == 0 ? left + (right - left) * t : right - (right - left) * t
                points.append(Vec2(x, y))
            }
        }
        return points
    }

    /// A circle of radius 0.3 tray widths around the tray's centre (0.4 of the height).
    static var circle: [Vec2] {
        let samples = 96
        return (0...samples).map { index in
            let angle = 2 * Double.pi * Double(index) / Double(samples)
            return Vec2(0.5 + 0.3 * cos(angle), 0.5 + 0.4 * sin(angle))
        }
    }

    /// Two periods of a sine wave across the tray.
    static var wave: [Vec2] {
        let samples = 96
        return (0...samples).map { index in
            let t = Double(index) / Double(samples)
            return Vec2(0.1 + 0.8 * t, 0.5 + 0.15 * sin(4 * Double.pi * t))
        }
    }

    /// A spiral of two turns from the centre outwards (radius 0.02 to 0.28 tray widths).
    static var spiral: [Vec2] {
        let samples = 160
        return (0...samples).map { index in
            let t = Double(index) / Double(samples)
            let angle = 4 * Double.pi * t
            let radius = 0.02 + 0.26 * t
            return Vec2(0.5 + radius * cos(angle), 0.5 + radius * sin(angle) / GardenPalette.smallTray.yScale)
        }
    }

    /// The points of the pattern at `index` of `names` (clamped).
    static func points(index: Int) -> [Vec2] {
        switch min(max(index, 0), names.count - 1) {
        case 0: return rows
        case 1: return circle
        case 2: return wave
        default: return spiral
        }
    }

    /// The values of the `stroke.add` actions carrying `points` (twelve points each; the last action's unused pairs
    /// repeat its last point). Empty for no points.
    static func addValues(_ points: [Vec2]) -> [[Double]] {
        var batches: [[Double]] = []
        var start = 0
        while start < points.count {
            let end = min(start + GardenCore.pointsPerAdd, points.count)
            var values: [Double] = []
            values.reserveCapacity(GardenCore.pointsPerAdd * 2)
            for point in points[start..<end] {
                values.append(point.x)
                values.append(point.y)
            }
            let last = points[end - 1]
            while values.count < GardenCore.pointsPerAdd * 2 {
                values.append(last.x)
                values.append(last.y)
            }
            batches.append(values)
            start = end
        }
        return batches
    }

    /// Rakes `points` with the rake `rake` (0 fine, 1 wide) through `port`: `stroke.begin`, the `stroke.add` batches
    /// of the points after the first and `stroke.end`. Returns the results in order; stops after a refused begin.
    @MainActor
    @discardableResult
    static func send(_ points: [Vec2], rake: Int, port: ExperienceActionPort) -> [ActionResult] {
        guard let first = points.first else { return [] }
        var results = [port.send("stroke.begin", [first.x, first.y, Double(rake)])]
        guard results[0].isAccepted else { return results }
        for values in addValues(Array(points.dropFirst())) {
            results.append(port.send("stroke.add", values))
        }
        results.append(port.send("stroke.end"))
        return results
    }
}
