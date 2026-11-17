// RakeTests — feature 145 (A20-P01) T-A20-107 (FR-A20-104; SC-A20-102; clarification Q3). The two rake styles differ
// in tines, width and depth: the profile has one ridge per tine and a horizontal stroke touches a band of the rake's
// width; a stamp changes only cells whose centres lie in its footprint (and every such cell); the replay is
// deterministic and a later stroke overwrites an earlier one where they overlap.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct RakeTests {
    /// A height no rake writes (profiles lie in −1…1), marking untouched cells.
    private static let sentinel: Float = 5

    /// A field with every cell at ``sentinel``.
    private static func sentinelField() -> SandField {
        var field = SandField()
        for row in 0..<SandField.rows {
            for column in 0..<SandField.columns { field[column, row] = sentinel }
        }
        return field
    }

    /// The resampled stroke from `a` to `b` with `rake`.
    private static func stroke(_ rake: String, _ a: Vec2, _ b: Vec2) throws -> RakeStroke {
        let out = try StrokeResampler.resample([a, b]).get()
        return RakeStroke(rake: rake, points: out.points, capped: out.capped)
    }

    @Test func theStylesDifferInTinesWidthAndDepth() throws {
        let fine = try #require(GardenPalette.rake(id: "fine-rake"))
        let wide = try #require(GardenPalette.rake(id: "wide-rake"))
        #expect(fine.tines != wide.tines && fine.width != wide.width && fine.depth != wide.depth)
        for style in [fine, wide] {
            // Sample the profile finely across the rake and count its interior ridges (local maxima).
            let samples = 2001
            var heights: [Double] = []
            for index in 0..<samples {
                let u = -style.width / 2 + style.width * Double(index) / Double(samples - 1)
                let value = try #require(RakeBrush.height(across: u, style: style))
                heights.append(value)
            }
            var ridges = 0
            for index in 1..<(samples - 1) where heights[index] > heights[index - 1] && heights[index] >= heights[index + 1] {
                ridges += 1
            }
            #expect(ridges == style.tines)
            #expect(abs((heights.max() ?? 0) - style.depth) < 1e-9)
            #expect(RakeBrush.height(across: style.width / 2 + 1e-6, style: style) == nil)
        }
    }

    @Test func aHorizontalStrokeTouchesABandOfTheRakesWidth() throws {
        var bands: [Int] = []
        for id in ["fine-rake", "wide-rake"] {
            let style = try #require(GardenPalette.rake(id: id))
            var field = Self.sentinelField()
            field.apply(try Self.stroke(id, Vec2(0.2, 0.5), Vec2(0.8, 0.5)))
            var touched = 0
            for row in 0..<SandField.rows where field[80, row] != Self.sentinel { touched += 1 }
            // Cells are 1/160 tray widths tall in the scaled metric, so the band is width × 160 rows (± 1).
            #expect(abs(Double(touched) - style.width * Double(SandField.columns)) <= 1)
            bands.append(touched)
        }
        #expect(bands[0] < bands[1])
    }

    @Test func aStampChangesOnlyCellsInItsFootprint() throws {
        let style = try #require(GardenPalette.rake(id: "wide-rake"))
        let point = Vec2(0.5, 0.5)
        let direction = Vec2(1, 1)
        var field = Self.sentinelField()
        RakeBrush.stamp(into: &field, at: point, direction: direction, style: style)
        let along = RakeBrush.unitDirection(direction)
        let across = Vec2(-along.y, along.x)
        let scale = GardenPalette.smallTray.yScale
        var changed = 0
        for row in 0..<SandField.rows {
            for column in 0..<SandField.columns {
                let cell = SandField.cellCentre(column: column, row: row)
                let offset = Vec2(cell.x - point.x, (cell.y - point.y) * scale)
                let s = abs(offset.dot(along))
                let u = abs(offset.dot(across))
                let isChanged = field[column, row] != Self.sentinel
                if isChanged {
                    changed += 1
                    #expect(s <= StrokeResampler.spacing / 2 + 1e-9 && u <= style.width / 2 + 1e-9)
                } else {
                    #expect(!(s < StrokeResampler.spacing / 2 - 1e-9 && u < style.width / 2 - 1e-9))
                }
            }
        }
        #expect(changed > 0)
    }

    @Test func theReplayIsDeterministic() throws {
        let strokes = [try Self.stroke("fine-rake", Vec2(0.1, 0.2), Vec2(0.9, 0.7)),
                       try Self.stroke("wide-rake", Vec2(0.3, 0.9), Vec2(0.6, 0.1)),
                       RakeStroke(rake: "fine-rake", points: [Vec2(0.5, 0.5)], capped: false)]
        let first = SandField.replay(strokes)
        let second = SandField.replay(strokes)
        #expect(first == second)
        #expect(first.maxDifference(second) == 0)
        #expect(first.maxDifference(SandField()) > 0)
        #expect(SandField.replay([RakeStroke(rake: "no-such-rake", points: [Vec2(0.5, 0.5)], capped: false)])
            == SandField())
    }

    @Test func aLaterStrokeOverwritesAnEarlierOne() throws {
        let horizontal = try Self.stroke("wide-rake", Vec2(0.2, 0.5), Vec2(0.8, 0.5))
        let vertical = try Self.stroke("fine-rake", Vec2(0.5, 0.2), Vec2(0.5, 0.8))
        let both = SandField.replay([horizontal, vertical])
        let reversed = SandField.replay([vertical, horizontal])
        let onlyVertical = SandField.replay([vertical])
        var compared = 0
        for row in 0..<SandField.rows {
            for column in 0..<SandField.columns where onlyVertical[column, row] != 0 {
                #expect(both[column, row] == onlyVertical[column, row])
                compared += 1
            }
        }
        #expect(compared > 0)
        #expect(both.maxDifference(reversed) > 0)
    }
}
