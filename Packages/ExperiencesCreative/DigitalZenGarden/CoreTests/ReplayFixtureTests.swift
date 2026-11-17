// ReplayFixtureTests — feature 145 (A20-P01) T-A20-109 (FR-A20-105, FR-A20-106; SC-A20-103, SC-A20-104;
// clarification Q4). The manual's regression fixture: 60 mixed commands (rakes resampled by `StrokeResampler`,
// placements, moves, rotations, removals, tone changes) built from a seeded generator are undone and redone, giving an
// identical command list, an equal document and a field within 1e-6 per cell; 150 commands fold the oldest 50 into
// the checkpoint and the field rebuilt from it equals a full replay within 1e-6. Deterministic; no clock.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct ReplayFixtureTests {
    /// The per-cell tolerance of a rebuilt field (clarification Q4).
    private static let tolerance: Float = 1e-6

    /// A small seeded linear congruential generator (Knuth's MMIX constants); no randomness API.
    private struct LCG {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state >> 33
        }

        /// A value in 0…1.
        mutating func unit() -> Double { Double(next() % 1_000_001) / 1_000_000 }

        /// A value in 0..<bound.
        mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }
    }

    private static let tones = ["pale", "warm", "grey"]
    private static let rakes = ["fine-rake", "wide-rake"]
    private static let kinds = ["river-pebble", "flat-slate", "round-granite", "tall-basalt", "moss-boulder"]

    /// A raw drag of two or three points within 0.15 of a random start, resampled to at most 100 points.
    private static func stroke(_ rng: inout LCG) throws -> RakeStroke {
        var raw = [Vec2(rng.unit(), rng.unit())]
        for _ in 0..<(2 + rng.below(2)) {
            let last = raw[raw.count - 1]
            raw.append(Vec2(last.x + (rng.unit() - 0.5) * 0.3, last.y + (rng.unit() - 0.5) * 0.3))
        }
        let out = try StrokeResampler.resample(raw, cap: 100).get()
        return RakeStroke(rake: rakes[rng.below(rakes.count)], points: out.points, capped: out.capped)
    }

    /// The kinds of the first generated commands, so every command kind occurs: rake, place, move, rotate, place,
    /// remove, tone (generator choices 0, 4, 6, 7, 4, 8, 9).
    private static let opening = [0, 4, 6, 7, 4, 8, 9]

    /// Applies one generated command to `history`: the `index`-th command takes its kind from ``opening`` and later
    /// ones from the generator; a kind that does not apply (no stone to edit, the stones full) becomes a rake. Every
    /// generated command is valid, so `done` grows by one (before folding).
    private static func step(_ history: inout GardenHistory, _ rng: inout LCG, index: Int) throws {
        let stones = history.document.stones
        let drawn = rng.below(10)
        var choice = index < opening.count ? opening[index] : drawn
        if (6...8).contains(choice) && stones.isEmpty { choice = 0 }
        switch choice {
        case 0...3:
            try history.apply(.rake(try stroke(&rng))).get()
        case 4, 5:
            if stones.count >= GardenDocument.maxStones {
                try history.apply(.rake(try stroke(&rng))).get()
            } else {
                _ = try history.placeStone(kind: kinds[rng.below(kinds.count)],
                                           position: Vec2(rng.unit(), rng.unit()),
                                           rotation: (rng.unit() - 0.5) * 8,
                                           scale: 0.5 + 1.5 * rng.unit()).get()
            }
        case 6:
            let stone = stones[rng.below(stones.count)]
            try history.moveStone(id: stone.id, to: Vec2(rng.unit(), rng.unit())).get()
        case 7:
            let stone = stones[rng.below(stones.count)]
            try history.rotateStone(id: stone.id, to: (rng.unit() - 0.5) * 8).get()
        case 8:
            let stone = stones[rng.below(stones.count)]
            try history.removeStone(id: stone.id).get()
        default:
            let current = history.document.tone
            let others = tones.filter { $0 != current }
            try history.setTone(others[rng.below(others.count)]).get()
        }
    }

    /// The history after `count` generated commands from `seed`.
    private static func build(_ count: Int, seed: UInt64) throws -> GardenHistory {
        var rng = LCG(state: seed)
        var history = GardenHistory()
        for index in 0..<count { try step(&history, &rng, index: index) }
        return history
    }

    /// The number of commands of each kind in `commands`: rake, place, move, rotate, remove, tone.
    private static func kindCounts(_ commands: [GardenCommand]) -> [Int] {
        var counts = [Int](repeating: 0, count: 6)
        for command in commands {
            switch command {
            case .rake: counts[0] += 1
            case .place: counts[1] += 1
            case .move: counts[2] += 1
            case .rotate: counts[3] += 1
            case .remove: counts[4] += 1
            case .tone: counts[5] += 1
            }
        }
        return counts
    }

    @Test func sixtyCommandsUndoneAndRedoneAreIdentical() throws {
        var history = try Self.build(60, seed: 0xA20_0145)
        #expect(history.done.count == 60)
        #expect(Self.kindCounts(history.done).allSatisfy { $0 > 0 })
        #expect(history.document.validate() == nil)
        let commands = history.done
        let document = history.document
        let original = history.field()
        #expect(original.maxDifference(SandField.replay(document.strokes)) <= Self.tolerance)

        var undoCount = 0
        while history.undo() { undoCount += 1 }
        #expect(undoCount == 60)
        #expect(history.document == GardenDocument.empty)
        #expect(history.field() == SandField())
        #expect(history.undone.count == 60)

        var redoCount = 0
        while history.redo() { redoCount += 1 }
        #expect(redoCount == 60)
        #expect(history.done == commands)
        #expect(history.document == document)
        #expect(history.field().maxDifference(original) <= Self.tolerance)
    }

    @Test func theSameCommandsGiveTheSameHistory() throws {
        let first = try Self.build(60, seed: 7)
        let second = try Self.build(60, seed: 7)
        #expect(first == second)
        #expect(first.field() == second.field())
    }

    @Test func beyondOneHundredCommandsTheOldestFoldIntoTheCheckpoint() throws {
        var rng = LCG(state: 0x5A17)
        var history = GardenHistory()
        var all: [GardenCommand] = []
        for index in 0..<150 {
            let before = history.done
            try Self.step(&history, &rng, index: index)
            // The newest command is the one just applied, whether or not the oldest folded.
            let newest = try #require(history.done.last)
            #expect(history.done.count == min(before.count + 1, GardenHistory.maxUndo))
            all.append(newest)
        }
        #expect(history.done.count == GardenHistory.maxUndo)
        #expect(Array(all.suffix(GardenHistory.maxUndo)) == history.done)
        #expect(history.document.validate() == nil)

        var strokes: [RakeStroke] = []
        for command in all {
            if case let .rake(stroke) = command { strokes.append(stroke) }
        }
        #expect(history.document.strokes == strokes)
        let rebuilt = history.field()
        #expect(rebuilt.maxDifference(SandField.replay(history.document.strokes)) <= Self.tolerance)
        #expect(rebuilt.maxDifference(SandField.replay(strokes)) <= Self.tolerance)

        // The checkpoint holds the 50 folded commands: its field is the replay of their strokes.
        var folded: [RakeStroke] = []
        for command in all.prefix(50) {
            if case let .rake(stroke) = command { folded.append(stroke) }
        }
        #expect(history.checkpoint.document.strokes == folded)
        #expect(history.checkpoint.field.maxDifference(SandField.replay(folded)) <= Self.tolerance)

        // Undo stops at the checkpoint: 100 undos reach the checkpoint document and the 101st is refused.
        var undoCount = 0
        while history.undo() { undoCount += 1 }
        #expect(undoCount == GardenHistory.maxUndo)
        #expect(history.document == history.checkpoint.document)
        #expect(history.field().maxDifference(history.checkpoint.field) <= Self.tolerance)
    }
}
