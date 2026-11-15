// DecorEditingTests — feature 070 (A09-P03) T-A09-304 (FR-A09-310; SC-A09-303). Decor editing, host-free and short:
// place, move and remove give exactly the requested list; positions are clamped into the tank; a placement at 12
// pieces or of an empty kind is refused; a move or removal of a missing index is refused and changes nothing; fractions
// map onto the 16 × 9 tank and are clamped (a non-finite fraction is the middle).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import DigitalAquariumCore

@Suite struct DecorEditingTests {
    private let catalog = SpeciesCatalog.bundled

    /// The Reef starter with its decor cleared.
    private func emptyDecor() -> HabitatDocument {
        var random = SeededRandom(seed: 9)
        var doc = HabitatDocument.starter(0, catalog: catalog, random: &random)
        doc.decor = []
        return doc
    }

    private var kinds: [String] { catalog.decor.map(\.id) }

    @Test func placeMoveAndRemoveGiveExactlyTheRequestedList() throws {
        let ids = kinds
        try #require(ids.count >= 2)
        var doc = emptyDecor()
        let fish = doc.fish
        #expect(DecorEditing.place(kindId: ids[0], at: Vec2(3, 2), into: &doc))
        #expect(DecorEditing.place(kindId: ids[1], at: Vec2(10, 4), into: &doc))
        #expect(doc.decor == [DecorPlacement(kindId: ids[0], position: Vec2(3, 2), rotation: 0, scale: 1),
                              DecorPlacement(kindId: ids[1], position: Vec2(10, 4), rotation: 0, scale: 1)])

        #expect(DecorEditing.move(index: 0, to: Vec2(5, 6), in: &doc))
        #expect(doc.decor.map(\.position) == [Vec2(5, 6), Vec2(10, 4)])
        #expect(doc.decor.map(\.kindId) == [ids[0], ids[1]])

        #expect(DecorEditing.remove(index: 0, from: &doc))
        #expect(doc.decor == [DecorPlacement(kindId: ids[1], position: Vec2(10, 4), rotation: 0, scale: 1)])
        #expect(doc.fish == fish, "editing decor leaves the fish alone")
        #expect(doc.validate(catalog: catalog).isEmpty)
    }

    @Test func positionsAreClampedIntoTheTank() throws {
        let id = try #require(kinds.first)
        var doc = emptyDecor()
        #expect(DecorEditing.place(kindId: id, at: Vec2(-3, 20), into: &doc))
        #expect(doc.decor[0].position == Vec2(0, 9))
        #expect(DecorEditing.place(kindId: id, at: Vec2(40, -1), into: &doc))
        #expect(doc.decor[1].position == Vec2(16, 0))
        #expect(DecorEditing.move(index: 0, to: Vec2(17, -0.5), in: &doc))
        #expect(doc.decor[0].position == Vec2(16, 0))
        #expect(DecorEditing.move(index: 1, to: Vec2(.nan, .infinity), in: &doc))
        #expect(doc.decor[1].position == Vec2(8, 4.5))
    }

    @Test func aPlacementAtTwelvePiecesOrOfAnEmptyKindIsRefused() throws {
        let id = try #require(kinds.first)
        var doc = emptyDecor()
        for i in 0..<HabitatDocument.maxDecor {
            #expect(DecorEditing.place(kindId: id, at: Vec2(Double(i), 3), into: &doc))
        }
        #expect(doc.decor.count == 12)
        let full = doc
        #expect(!DecorEditing.place(kindId: id, at: Vec2(8, 3), into: &doc))
        #expect(doc == full)

        var empty = emptyDecor()
        let before = empty
        #expect(!DecorEditing.place(kindId: "", at: Vec2(8, 3), into: &empty))
        #expect(empty == before)
    }

    @Test(arguments: [-1, 1, 12, Int.max]) func aMissingIndexIsRefused(index: Int) throws {
        let id = try #require(kinds.first)
        var doc = emptyDecor()
        #expect(DecorEditing.place(kindId: id, at: Vec2(4, 4), into: &doc))
        let before = doc
        #expect(!DecorEditing.move(index: index, to: Vec2(1, 1), in: &doc))
        #expect(!DecorEditing.remove(index: index, from: &doc))
        #expect(doc == before)
    }

    @Test func aJustRemovedIndexIsRefused() throws {
        let id = try #require(kinds.first)
        var doc = emptyDecor()
        #expect(DecorEditing.place(kindId: id, at: Vec2(4, 4), into: &doc))
        #expect(DecorEditing.remove(index: 0, from: &doc))
        #expect(!DecorEditing.move(index: 0, to: Vec2(1, 1), in: &doc))
        #expect(!DecorEditing.remove(index: 0, from: &doc))
        #expect(doc.decor.isEmpty)
    }

    @Test func fractionsMapOntoTheTankAndAreClamped() {
        #expect(DecorEditing.tankPoint(fractionX: 0, fractionY: 0) == Vec2(0, 0))
        #expect(DecorEditing.tankPoint(fractionX: 1, fractionY: 1) == Vec2(16, 9))
        #expect(DecorEditing.tankPoint(fractionX: 0.5, fractionY: 0.5) == Vec2(8, 4.5))
        #expect(DecorEditing.tankPoint(fractionX: 0.25, fractionY: 0.25) == Vec2(4, 2.25))
        #expect(DecorEditing.tankPoint(fractionX: -2, fractionY: 3) == Vec2(0, 9))
        #expect(DecorEditing.tankPoint(fractionX: .nan, fractionY: -.infinity) == Vec2(8, 4.5))
        #expect(DecorEditing.tankPoint(fractionX: .infinity, fractionY: 0) == Vec2(8, 0))
    }
}
