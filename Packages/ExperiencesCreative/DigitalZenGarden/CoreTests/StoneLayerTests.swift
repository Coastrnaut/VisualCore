// StoneLayerTests — feature 147 (A20-P03) T-A20-302 (FR-A20-302, FR-A20-306; clarification Q1; data-model.md
// "StoneLayer"). The rasterized stone layer: 480 × 360 by default; an empty garden gives an empty layer; each covered
// cell holds the shape's height and kind + 1; a higher stone overwrites a lower one where they overlap, whatever the
// order of the list; the layer is deterministic. Short runs only.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct StoneLayerTests {
    @Test func theDefaultLayerIsEmptyAt480By360() {
        let layer = StoneLayer(stones: [])
        #expect(layer.columns == 480 && layer.rows == 360)
        #expect(layer.isEmpty && layer.coveredCount == 0)
        #expect(layer.heights.count == 480 * 360 && layer.kinds.count == 480 * 360)
        let clamped = StoneLayer(columns: 0, rows: 5000)
        #expect(clamped.columns == 1 && clamped.rows == 1024)
    }

    @Test func coveredCellsHoldTheShapesHeightAndKind() throws {
        let stone = Stone(id: 4, kind: "round-granite", position: Vec2(0.4, 0.6), rotation: 0.3, scale: 1.2, depth: 0)
        let layer = StoneLayer(stones: [stone])
        let shape = try #require(StoneShape(stone: stone))
        #expect(!layer.isEmpty)
        var covered = 0
        var wrongKinds = 0
        var largestHeightError = 0.0
        for row in 0..<layer.rows {
            for column in 0..<layer.columns {
                let centre = layer.cellCentre(column: column, row: row)
                let inside = shape.contains(centre)
                if layer.kind(column: column, row: row) != (inside ? 3 : 0) { wrongKinds += 1 }
                let expected = inside ? shape.height(at: centre) : 0
                largestHeightError = max(largestHeightError,
                                         abs(Double(layer.height(column: column, row: row)) - expected))
                if inside { covered += 1 }
            }
        }
        #expect(wrongKinds == 0)
        #expect(largestHeightError < 1e-6)
        #expect(covered == layer.coveredCount && covered > 100)
        #expect(StoneLayer(stones: [stone]) == layer, "deterministic")
    }

    @Test func aHigherStoneOverwritesALowerOne() {
        let low = Stone(id: 1, kind: "moss-boulder", position: Vec2(0.5, 0.5), rotation: 0, scale: 1, depth: 0)
        let high = Stone(id: 2, kind: "river-pebble", position: Vec2(0.5, 0.5), rotation: 0, scale: 1, depth: 1)
        let layer = StoneLayer(stones: [low, high])
        let swapped = StoneLayer(stones: [high, low])
        #expect(layer == swapped, "drawn in depth order, not list order")
        let column = 240
        let row = 180
        #expect(layer.kind(column: column, row: row) == 1, "the pebble (kind 0) is on top")
        #expect(abs(layer.height(column: column, row: row) - 0.6) < 0.01, "the pebble's height")
        // Away from the pebble the boulder shows.
        #expect(layer.kind(column: 240 + 25, row: 180) == 5)
        // With the depths exchanged, the boulder covers the pebble completely.
        var under = high
        under.depth = -1
        let buried = StoneLayer(stones: [low, under])
        #expect(buried.kind(column: column, row: row) == 5)
        #expect(!buried.kinds.contains(1))
    }
}
