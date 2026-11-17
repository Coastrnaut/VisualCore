// HistoryTests — feature 145 (A20-P01) T-A20-109 (FR-A20-105, FR-A20-106; SC-A20-103; clarification Q4). Each command
// kind (rake, place, move, rotate, remove, tone) applies and undoes exactly; refused commands (unknown rake, strokes
// over the cap, a missing id, an out-of-range move, a wrong `from`) leave the document and both lists unchanged; undo
// and redo with empty lists return false and change nothing; a new command after an undo clears redo; `placeStone`
// assigns ids and depths.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct HistoryTests {
    /// A history holding two stones (ids 1 and 2, depths 0 and 1) and one stroke.
    private static func seeded() throws -> GardenHistory {
        var history = GardenHistory()
        _ = try history.placeStone(kind: "river-pebble", position: Vec2(0.25, 0.25), rotation: 0.5).get()
        _ = try history.placeStone(kind: "flat-slate", position: Vec2(0.75, 0.5), scale: 1.5).get()
        _ = try history.rake([Vec2(0.1, 0.1), Vec2(0.4, 0.2)]).get()
        return history
    }

    /// The refusal of `result`, or nil when it succeeded.
    private static func refusal<T>(_ result: Result<T, DocumentRefusal>) -> DocumentRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// Applies `command` to `history`, checks it succeeded, then that one undo restores the document exactly and one
    /// redo gives the applied document again.
    private static func roundTrip(_ history: inout GardenHistory, _ command: GardenCommand) throws {
        let before = history.document
        let count = history.done.count
        try history.apply(command).get()
        let after = history.document
        #expect(after != before)
        #expect(history.done.count == count + 1)
        do { let result = history.undo(); #expect(result) }
        #expect(history.document == before)
        #expect(history.done.count == count)
        do { let result = history.redo(); #expect(result) }
        #expect(history.document == after)
    }

    @Test func eachCommandKindAppliesAndUndoesExactly() throws {
        var history = try Self.seeded()
        let pebble = try #require(history.document.stones.first { $0.id == 1 })
        let stroke = RakeStroke(rake: "wide-rake", points: [Vec2(0.5, 0.5), Vec2(0.504, 0.5)])
        try Self.roundTrip(&history, .rake(stroke))
        let next = Stone(id: history.document.nextStoneID, kind: "tall-basalt", position: Vec2(0.6, 0.6),
                         rotation: -1, scale: 0.75, depth: 7)
        try Self.roundTrip(&history, .place(next))
        try Self.roundTrip(&history, .move(id: 1, from: pebble.position, to: Vec2(0.3, 0.9)))
        let moved = try #require(history.document.stones.first { $0.id == 1 })
        try Self.roundTrip(&history, .rotate(id: 1, from: moved.rotation, to: 2.5))
        let rotated = try #require(history.document.stones.first { $0.id == 1 })
        try Self.roundTrip(&history, .remove(rotated))
        try Self.roundTrip(&history, .tone(from: history.document.tone, to: "grey"))

        // Undoing everything returns to the empty garden, field at rest.
        while history.undo() {}
        #expect(history.document == GardenDocument.empty)
        #expect(history.field() == SandField())
    }

    @Test func undoOfPlaceRestoresTheNextStoneID() throws {
        var history = GardenHistory()
        let stone = try history.placeStone(kind: "moss-boulder", position: Vec2(0.5, 0.5)).get()
        #expect(history.document.nextStoneID == stone.id + 1)
        do { let result = history.undo(); #expect(result) }
        #expect(history.document.nextStoneID == stone.id)
        #expect(history.document == GardenDocument.empty)
    }

    @Test func removeAndUndoKeepTheDepthOrder() throws {
        var history = try Self.seeded()
        _ = try history.placeStone(kind: "round-granite", position: Vec2(0.5, 0.5)).get()
        let before = history.document
        try history.removeStone(id: 2).get()
        #expect(!history.document.stones.contains { $0.id == 2 })
        do { let result = history.undo(); #expect(result) }
        #expect(history.document == before)
        #expect(history.document.stones.map(\.depth) == [0, 1, 2])
    }

    @Test func placeStoneAssignsIdsAndDepths() throws {
        var history = GardenHistory()
        var ids: [UInt32] = []
        var depths: [Int] = []
        for index in 0..<4 {
            let stone = try history.placeStone(kind: "river-pebble",
                                               position: Vec2(0.1 + 0.2 * Double(index), 0.5)).get()
            ids.append(stone.id)
            depths.append(stone.depth)
        }
        #expect(ids == [1, 2, 3, 4])
        #expect(depths == [0, 1, 2, 3])
        #expect(history.document.nextStoneID == 5)
        #expect(history.document.validate() == nil)
        // A removed top stone frees neither its id nor (for a later stone) a lower depth.
        try history.removeStone(id: 4).get()
        let fifth = try history.placeStone(kind: "river-pebble", position: Vec2(0.9, 0.9)).get()
        #expect(fifth.id == 5)
        #expect(fifth.depth == 3)
    }

    @Test func aRotationIsNormalizedBeforeTheCheck() throws {
        var history = try Self.seeded()
        try history.rotateStone(id: 1, to: 3 * Double.pi / 2).get()
        let stone = try #require(history.document.stones.first { $0.id == 1 })
        #expect(abs(stone.rotation - (-Double.pi / 2)) < 1e-12)
        do {
            let result = history.rotateStone(id: 1, to: .nan)
            #expect(Self.refusal(result) == .outOfRange("rotation"))
        }
    }

    @Test func refusedCommandsChangeNothing() throws {
        var history = try Self.seeded()
        _ = history.undo()
        let reference = history
        let pebble = try #require(history.document.stones.first { $0.id == 1 })
        let refused: [(GardenCommand, DocumentRefusal)] = [
            (.rake(RakeStroke(rake: "comb", points: [Vec2(0.5, 0.5)])), .unknownRake("comb")),
            (.rake(RakeStroke(rake: "fine-rake", points: [])), .overCap("points")),
            (.rake(RakeStroke(rake: "fine-rake", points: [Vec2(1.5, 0.5)])), .outOfRange("points")),
            (.move(id: 99, from: Vec2(0, 0), to: Vec2(0.5, 0.5)), .outOfRange("id")),
            (.move(id: 1, from: pebble.position, to: Vec2(1.2, 0.5)), .outOfRange("position")),
            (.move(id: 1, from: Vec2(0.9, 0.9), to: Vec2(0.5, 0.5)), .outOfRange("position")),
            (.rotate(id: 99, from: 0, to: 1), .outOfRange("id")),
            (.rotate(id: 1, from: pebble.rotation + 0.1, to: 1), .outOfRange("rotation")),
            (.remove(Stone(id: 99, kind: "river-pebble", position: Vec2(0.5, 0.5), rotation: 0, scale: 1,
                           depth: 9)), .outOfRange("id")),
            (.tone(from: "grey", to: "warm"), .outOfRange("tone")),
            (.tone(from: history.document.tone, to: "violet"), .unknownTone("violet")),
            (.place(Stone(id: history.document.nextStoneID, kind: "obsidian", position: Vec2(0.5, 0.5),
                          rotation: 0, scale: 1, depth: 5)), .unknownStone("obsidian")),
            (.place(Stone(id: 77, kind: "river-pebble", position: Vec2(0.5, 0.5), rotation: 0, scale: 1,
                          depth: 5)), .outOfRange("id")),
            (.place(Stone(id: history.document.nextStoneID, kind: "river-pebble", position: Vec2(0.5, 0.5),
                          rotation: 0, scale: 1, depth: 0)), .outOfRange("depth")),
            (.place(Stone(id: history.document.nextStoneID, kind: "river-pebble", position: Vec2(0.5, 0.5),
                          rotation: 0, scale: 3, depth: 5)), .outOfRange("scale")),
        ]
        for (command, expected) in refused {
            do { let result = history.apply(command); #expect(Self.refusal(result) == expected) }
            #expect(history == reference)
        }
        #expect(history.canRedo)
    }

    @Test func overCapStrokesAndStonesAreRefused() throws {
        var document = GardenDocument.empty
        let dab = RakeStroke(rake: "fine-rake", points: [Vec2(0.5, 0.5)])
        document.strokes = [RakeStroke](repeating: dab, count: GardenDocument.maxStrokes)
        var history = GardenHistory(document: document)
        let reference = history
        do { let result = history.apply(.rake(dab)); #expect(Self.refusal(result) == .overCap("strokes")) }
        #expect(history == reference)

        var stones = GardenHistory()
        for index in 0..<GardenDocument.maxStones {
            _ = try stones.placeStone(kind: "river-pebble", position: Vec2(Double(index) / 24, 0.5)).get()
        }
        let full = stones
        do {
            let result = stones.placeStone(kind: "river-pebble", position: Vec2(0.5, 0.5))
            #expect(Self.refusal(result) == .overCap("stones"))
        }
        #expect(stones == full)
    }

    @Test func emptyUndoAndRedoChangeNothing() throws {
        var history = GardenHistory()
        let reference = history
        #expect(!history.canUndo && !history.canRedo)
        do { let result = history.undo(); #expect(!result) }
        do { let result = history.redo(); #expect(!result) }
        #expect(history == reference)

        var seeded = try Self.seeded()
        let top = seeded
        do { let result = seeded.redo(); #expect(!result) }
        #expect(seeded == top)
    }

    @Test func aNewCommandAfterUndoClearsRedo() throws {
        var history = try Self.seeded()
        do { let result = history.undo(); #expect(result) }
        do { let result = history.undo(); #expect(result) }
        #expect(history.undone.count == 2)
        try history.setTone("warm").get()
        #expect(history.undone.isEmpty)
        #expect(!history.canRedo)
        do { let result = history.redo(); #expect(!result) }
        #expect(history.document.tone == "warm")
    }
}
