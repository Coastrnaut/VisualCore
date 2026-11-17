// SelectionTests — feature 147 (A20-P03) T-A20-302 (FR-A20-303; SC-A20-302; clarifications Q2, Q4; data-model.md
// "StoneSelection"). Layer-aware selection: in every overlap sample the topmost stone is picked (and it is the stone the
// layer draws on top there); empty sand gives nil; cycling wraps in depth order both ways; the place counts from the
// lowest stone. Short runs only.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct SelectionTests {
    /// Three overlapping stones listed out of depth order: ids 1 (depth 2), 2 (depth 0) and 3 (depth 1).
    private static let stones = [
        Stone(id: 1, kind: "round-granite", position: Vec2(0.50, 0.50), rotation: 0, scale: 1, depth: 2),
        Stone(id: 2, kind: "moss-boulder", position: Vec2(0.47, 0.50), rotation: 0.4, scale: 1, depth: 0),
        Stone(id: 3, kind: "flat-slate", position: Vec2(0.53, 0.52), rotation: -0.2, scale: 1, depth: 1),
    ]

    @Test func theTopmostStoneIsPickedInEveryOverlapSample() throws {
        let layer = StoneLayer(stones: Self.stones)
        let byDepth = StoneSelection.ordered(Self.stones)
        #expect(byDepth.map(\.id) == [2, 3, 1])
        var overlaps = 0
        var wrongPicks = 0
        var unseen = 0
        var row = 0
        while row < layer.rows {
            var column = 0
            while column < layer.columns {
                let point = layer.cellCentre(column: column, row: row)
                let containing = byDepth.filter { StoneShape(stone: $0)?.contains(point) == true }
                let picked = StoneSelection.topmost(at: point, in: Self.stones)
                if picked != containing.last?.id { wrongPicks += 1 }
                if containing.count > 1 { overlaps += 1 }
                if let picked, let stone = Self.stones.first(where: { $0.id == picked }),
                   let index = GardenPalette.stones.firstIndex(where: { $0.id == stone.kind }) {
                    if Int(layer.kind(column: column, row: row)) != index + 1 { unseen += 1 }
                }
                column += 3
            }
            row += 3
        }
        #expect(wrongPicks == 0, "the topmost stone in every sample")
        #expect(unseen == 0, "what is seen is what is picked")
        #expect(overlaps > 50, "the samples include overlaps")
        #expect(StoneSelection.topmost(at: Vec2(0.5, 0.5), in: Self.stones) == 1)
    }

    @Test func emptySandGivesNothing() {
        #expect(StoneSelection.topmost(at: Vec2(0.05, 0.05), in: Self.stones) == nil)
        #expect(StoneSelection.topmost(at: Vec2(0.5, 0.5), in: []) == nil)
    }

    @Test func cyclingWrapsInDepthOrder() {
        let stones = Self.stones
        #expect(StoneSelection.cycle(from: 2, direction: 1, in: stones) == 3)
        #expect(StoneSelection.cycle(from: 3, direction: 1, in: stones) == 1)
        #expect(StoneSelection.cycle(from: 1, direction: 1, in: stones) == 2, "wraps at the top")
        #expect(StoneSelection.cycle(from: 2, direction: -1, in: stones) == 1, "wraps at the bottom")
        #expect(StoneSelection.cycle(from: 1, direction: -1, in: stones) == 3)
        #expect(StoneSelection.cycle(from: nil, direction: 1, in: stones) == 2, "from none: the lowest")
        #expect(StoneSelection.cycle(from: nil, direction: -1, in: stones) == 1, "from none backwards: the highest")
        #expect(StoneSelection.cycle(from: 99, direction: 1, in: stones) == 2)
        #expect(StoneSelection.cycle(from: 1, direction: 1, in: []) == nil)
        #expect(StoneSelection.place(of: 2, in: stones) == 1 && StoneSelection.place(of: 1, in: stones) == 3)
        #expect(StoneSelection.place(of: 9, in: stones) == nil)
    }
}
