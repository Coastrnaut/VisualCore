// SandFieldSizeTests — feature 146 (A20-P02) T-A20-203 (FR-A20-202, FR-A20-203; clarification Q1; data-model.md
// "SandField"). A field has a size: the default equals the A20-P01 field (160 × 120), a 480 × 360 field replays
// deterministically, a stroke covers the same tray region at both sizes within one cell of the coarse field, sizes are
// clamped into 1…1024 and fields of different sizes never compare as close. Short runs only.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct SandFieldSizeTests {
    /// A height no rake writes (profiles lie in −1…1), marking untouched cells.
    private static let sentinel: Float = 5

    /// A field of `columns` × `rows` with every cell at ``sentinel``.
    private static func sentinelField(columns: Int, rows: Int) -> SandField {
        var field = SandField(columns: columns, rows: rows)
        for row in 0..<rows {
            for column in 0..<columns { field[column, row] = sentinel }
        }
        return field
    }

    /// The resampled stroke through `points` with `rake`.
    private static func stroke(_ rake: String, _ points: [Vec2]) throws -> RakeStroke {
        let out = try StrokeResampler.resample(points).get()
        return RakeStroke(rake: rake, points: out.points, capped: out.capped)
    }

    /// The normalized bounding box (min x, min y, max x, max y of the touched cell centres) of `field`'s cells that
    /// differ from ``sentinel``; nil when none does.
    private static func touchedBox(_ field: SandField) -> (Double, Double, Double, Double)? {
        var box: (Double, Double, Double, Double)?
        for row in 0..<field.rows {
            for column in 0..<field.columns where field[column, row] != sentinel {
                let centre = field.cellCentre(column: column, row: row)
                if let current = box {
                    box = (min(current.0, centre.x), min(current.1, centre.y), max(current.2, centre.x),
                           max(current.3, centre.y))
                } else {
                    box = (centre.x, centre.y, centre.x, centre.y)
                }
            }
        }
        return box
    }

    @Test func theDefaultFieldIsTheA20P01Field() throws {
        let field = SandField()
        #expect(field.columns == 160 && field.rows == 120)
        #expect(field.columns == SandField.columns && field.rows == SandField.rows)
        #expect(field == SandField(columns: 160, rows: 120))
        #expect(field.heights.count == 160 * 120 && field.heights.allSatisfy { $0 == 0 })
        let strokes = [try Self.stroke("fine-rake", [Vec2(0.1, 0.2), Vec2(0.8, 0.7)]),
                       try Self.stroke("wide-rake", [Vec2(0.5, 0.1), Vec2(0.4, 0.9)])]
        #expect(SandField.replay(strokes) == SandField.replay(strokes, columns: 160, rows: 120))
        for (column, row) in [(0, 0), (17, 93), (159, 119)] {
            #expect(field.cellCentre(column: column, row: row) == SandField.cellCentre(column: column, row: row))
        }
    }

    @Test func aLargeFieldReplaysDeterministically() throws {
        let strokes = [try Self.stroke("fine-rake", [Vec2(0.1, 0.5), Vec2(0.9, 0.5)]),
                       try Self.stroke("wide-rake", [Vec2(0.3, 0.1), Vec2(0.6, 0.9)])]
        let first = SandField.replay(strokes, columns: 480, rows: 360)
        let second = SandField.replay(strokes, columns: 480, rows: 360)
        #expect(first.columns == 480 && first.rows == 360 && first.heights.count == 480 * 360)
        #expect(first == second)
        #expect(first.maxDifference(second) == 0)
        #expect(first.maxDifference(SandField(columns: 480, rows: 360)) > 0)
        let centre = first.cellCentre(column: 479, row: 359)
        #expect(abs(centre.x - 479.5 / 480) < 1e-12 && abs(centre.y - 359.5 / 360) < 1e-12)
    }

    @Test func aStrokeCoversTheSameRegionAtBothSizesWithinOneCell() throws {
        let strokes = [try Self.stroke("fine-rake", [Vec2(0.2, 0.3), Vec2(0.7, 0.6)]),
                       try Self.stroke("wide-rake", [Vec2(0.15, 0.8), Vec2(0.85, 0.75)])]
        for stroke in strokes {
            var coarse = Self.sentinelField(columns: 160, rows: 120)
            coarse.apply(stroke)
            var fine = Self.sentinelField(columns: 480, rows: 360)
            fine.apply(stroke)
            let small = try #require(Self.touchedBox(coarse))
            let large = try #require(Self.touchedBox(fine))
            let cellX = 1.0 / 160
            let cellY = 1.0 / 120
            #expect(abs(small.0 - large.0) <= cellX && abs(small.2 - large.2) <= cellX, "\(stroke.rake) x")
            #expect(abs(small.1 - large.1) <= cellY && abs(small.3 - large.3) <= cellY, "\(stroke.rake) y")
        }
    }

    @Test func sizesAreClampedAndDifferentSizesNeverCompareClose() {
        let tiny = SandField(columns: 0, rows: -3)
        #expect(tiny.columns == 1 && tiny.rows == 1 && tiny.heights.count == 1)
        let tall = SandField(columns: 5000, rows: 1024)
        #expect(tall.columns == 1024 && tall.rows == 1024)
        #expect(SandField(columns: 480, rows: 360).maxDifference(SandField()) == .infinity)
        #expect(SandField(columns: 480, rows: 360) != SandField())
    }
}
