// WaveKnotKeeperInvariantTests — feature 321 (R02-G03-01) T-R02G0301-006 (FR-R02G0301-010; the source's invariants
// R2-G03-INV-01 … 05 and 07 … 09, round2.md section on Wave Knot Keeper). Each named test gives a direct boundary example
// and a seeded check of neighbouring inputs (seed 2,326), as the source asks. INV-06 (content witnesses), INV-10
// (renderer purity) and INV-12 (novelty) belong to later features; INV-11 (monetization) is superseded (the experience
// is free). How each invariant maps onto this kernel (clarifications Q1 … Q5):
// - INV-01 Time: the kernel is move-driven and reads no clock or frame; a record's tick is its index. The same moves give
//   the same fingerprints and records however long the play is paused between them.
// - INV-02 Input budget: the allowance — the move that spends it is accepted, nothing further is; a move that would make
//   the rope invalid (range, bounds, coincident, crossing outside a gate, tension) or names a stale fingerprint is
//   refused and changes nothing; an accepted move outside a gate keeps the rope simple and within the tension bound.
// - INV-03 Goal: the play wins exactly when the xy-projection is not degenerate and its crossing count and writhe equal
//   the target's (the crossing-graph parity is the target's crossings − writhe being even).
// - INV-04 Repeatability: replaying a record trace reproduces every record, fingerprint and the outcome; an edited
//   record is refused; a fixture rebuilt from its seed is the same level.
// - INV-05 Undo: undo restores the exact prior rope, moves spent and fingerprint (success state included); redo restores
//   the after state; nothing to undo or redo, and a finished play, refuse it.
// - INV-07 Failure honesty: spending the allowance without a win fails the play with the final summary as the
//   explanation, the rope stays where the player left it (no automatic solution); refusals name their reason.
// - INV-08 Stability: ropes at the bounds ±16 with 16 points, every edge of the level ranges and the tension bound edge
//   neither crash nor leave the bounds; every determinant is bounded far below Int's range.
// - INV-09 Save: the stored level round-trips byte for byte, damaged, edited and newer forms are refused, and a record
//   trace stored as JSON replays to the same play.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import WaveKnotKeeperCore

@Suite struct WaveKnotKeeperInvariantTests {
    typealias Point = WaveKnotKeeperPoint

    /// The invariant seed.
    static let seed: UInt64 = 2_326

    /// A six-point rope whose fifth point (3, 0, 3) lies, in the xy-projection, on the first segment (0, 0) – (6, 0):
    /// zero crossings but degenerate. Stepping that point +y makes the projection clean with zero crossings.
    static let touching: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 6, y: 0, z: 0), Point(x: 6, y: 6, z: 0),
                                    Point(x: 3, y: 6, z: 0), Point(x: 3, y: 0, z: 3), Point(x: 0, y: 6, z: 0)]

    /// A level of the touching rope with target (0, 0): not won at the start, because its projection is degenerate.
    static func touchingLevel(allowance: Int = 4) throws -> WaveKnotKeeperLevel {
        try WaveKnotKeeperLevel(id: "touching", seed: seed, band: 1, points: touching, gates: [],
                                target: try WaveKnotKeeperTarget(crossings: 0, writhe: 0), tensionBound: 1_000,
                                allowance: allowance)
    }

    /// A 16-point rope on the boundary of the bounds: the xy-square ±16 walked in steps of 8, z alternating −16 and 16.
    static var boundaryRope: [Point] {
        let xy: [(Int, Int)] = [(-16, -16), (-8, -16), (0, -16), (8, -16), (16, -16), (16, -8), (16, 0), (16, 8),
                                (16, 16), (8, 16), (0, 16), (-8, 16), (-16, 16), (-16, 8), (-16, 0), (-16, -8)]
        var points: [Point] = []
        for i in 0..<xy.count {
            points.append(Point(x: xy[i].0, y: xy[i].1, z: i % 2 == 0 ? -16 : 16))
        }
        return points
    }

    /// A seeded fixture (index and gate choice drawn from `random`).
    static func fixture(_ random: inout WaveKnotKeeperRandom, gates: Bool? = nil) -> WaveKnotKeeperFixture {
        let index: Int = random.int(0...9_999)
        let withGates: Bool = gates ?? (random.int(0...1) == 1)
        return WaveKnotKeeperFixtures.fixture(index, gates: withGates)
    }

    /// `points` with point `move.point` stepped along `move.direction`.
    static func moved(_ points: [Point], _ move: WaveKnotKeeperMove) -> [Point] {
        var result: [Point] = points
        result[move.point] = result[move.point].moved(move.direction)
        return result
    }

    /// A legal move from the play's rope that does not win; nil when the seeded draws find none.
    static func losingMove(_ play: WaveKnotKeeperPlay, random: inout WaveKnotKeeperRandom) -> WaveKnotKeeperMove? {
        let count: Int = play.points.count
        for _ in 0..<160 {
            let move = WaveKnotKeeperMove(point: random.int(0...(count - 1)), direction: random.direction())
            if WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) != nil { continue }
            if play.level.wins(Self.moved(play.points, move)) { continue }
            return move
        }
        return nil
    }

    /// The fixture's solution played from the start, stopping at the win.
    static func solved(_ fixture: WaveKnotKeeperFixture) throws -> WaveKnotKeeperPlay {
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
        for move in fixture.solution where play.stage == .playing {
            try play.apply(move, expecting: play.fingerprint)
        }
        return play
    }

    /// The refusal reason written independently of the kernel's code path: range, bounds, coincidence, the sweep
    /// outside a gate, the tension bound, in the order the rules state.
    static func referenceRefusal(_ move: WaveKnotKeeperMove, points: [Point],
                                 level: WaveKnotKeeperLevel) -> WaveKnotKeeperError? {
        if move.point < 0 || move.point >= points.count { return .move("range") }
        let from: Point = points[move.point]
        let to: Point = from.moved(move.direction)
        if !(-16...16).contains(to.x) || !(-16...16).contains(to.y) || !(-16...16).contains(to.z) {
            return .move("bounds")
        }
        for p in points where p == to { return .move("coincident") }
        var gated: Bool = false
        for gate in level.gates where gate.contains(from) && gate.contains(to) { gated = true }
        if !gated && !WaveKnotKeeperGeometry.sweepIsClear(points, moving: move.point, to: to) {
            return .move("crossing")
        }
        var tension: Int = 0
        let after: [Point] = Self.moved(points, move)
        for i in 0..<after.count {
            let a: Point = after[i]
            let b: Point = after[(i + 1) % after.count]
            tension += (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y) + (b.z - a.z) * (b.z - a.z)
        }
        if tension > level.tensionBound { return .move("tension") }
        return nil
    }

    // MARK: INV-01 Time

    /// INV-01 Time: no clock input — the same moves give the same fingerprints and records, with or without pauses
    /// between them; a paused play accepts no move; a record's tick is its index.
    @Test func testWaveKnotKeeperTimeBoundary() throws {
        // Direct boundary: pausing and resuming at once returns the exact fingerprint; a paused play refuses moves.
        let level: WaveKnotKeeperLevel = try Self.touchingLevel()
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        let before: WaveKnotKeeperPlay = play
        try play.handle(.pause)
        #expect(play.stage == .paused && play.fingerprint != before.fingerprint)
        let paused: WaveKnotKeeperPlay = play
        let step = WaveKnotKeeperMove(point: 4, direction: .plusY)
        #expect(throws: WaveKnotKeeperError.stage) { try play.apply(step, expecting: play.fingerprint) }
        #expect(throws: WaveKnotKeeperError.stage) { try play.undo() }
        #expect(throws: WaveKnotKeeperError.stage) { try play.redo() }
        #expect(play == paused)
        try play.handle(.resume)
        #expect(play == before)
        // Seeded neighbours: a fixture's solution played straight and with seeded pause/resume runs gives identical
        // records, fingerprints and outcome; record ticks are 0, 1, 2 ….
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        for _ in 0..<20 {
            let fixture: WaveKnotKeeperFixture = Self.fixture(&random)
            let straight: WaveKnotKeeperPlay = try Self.solved(fixture)
            var paced: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            for move in fixture.solution where paced.stage == .playing {
                let pauses: Int = random.int(0...3)
                for _ in 0..<pauses {
                    let held: String = paced.fingerprint
                    try paced.handle(.pause)
                    try paced.handle(.resume)
                    #expect(paced.fingerprint == held)
                }
                try paced.apply(move, expecting: paced.fingerprint)
            }
            #expect(paced == straight)
            #expect(paced.records == straight.records)
            #expect(straight.stage == .won)
            for i in 0..<straight.records.count {
                #expect(straight.records[i].tick == i)
            }
            // The verdict is a pure function of the rope: evaluating it twice agrees.
            #expect(fixture.level.wins(straight.points) == fixture.level.wins(straight.points))
            #expect(WaveKnotKeeperGeometry.summary(straight.points) == straight.summary)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: the move that spends exactly the allowance is accepted and nothing after it; an invalid move
    /// is refused with its reason and changes nothing; an accepted move keeps the rope valid.
    @Test func testWaveKnotKeeperInputbudgetBoundary() throws {
        // Direct boundary: range on both sides, a stale fingerprint, then the allowance of 1 spent by one losing move.
        let level: WaveKnotKeeperLevel = try Self.touchingLevel(allowance: 1)
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        let fresh: WaveKnotKeeperPlay = play
        let fp: String = play.fingerprint
        #expect(throws: WaveKnotKeeperError.move("range")) {
            try play.apply(WaveKnotKeeperMove(point: -1, direction: .plusX), expecting: fp)
        }
        #expect(throws: WaveKnotKeeperError.move("range")) {
            try play.apply(WaveKnotKeeperMove(point: 6, direction: .plusX), expecting: fp)
        }
        #expect(throws: WaveKnotKeeperError.stale) {
            try play.apply(WaveKnotKeeperMove(point: 4, direction: .plusY), expecting: String(repeating: "0", count: 64))
        }
        #expect(play == fresh)
        try play.apply(WaveKnotKeeperMove(point: 4, direction: .minusY), expecting: fp)
        #expect(play.spent == 1 && play.spent == level.allowance)
        #expect(play.stage == .failed)
        let ended: WaveKnotKeeperPlay = play
        #expect(throws: WaveKnotKeeperError.stage) {
            try play.apply(WaveKnotKeeperMove(point: 4, direction: .plusY), expecting: play.fingerprint)
        }
        #expect(throws: WaveKnotKeeperError.stage) { try play.undo() }
        #expect(play == ended)
        // Seeded neighbours: every move from seeded ropes (including a copy whose tension bound is the start tension)
        // is refused exactly as the reference says, unchanged, or accepted with the rope still valid.
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        var reasons: [String: Int] = [:]
        var exhausted: Int = 0
        for round in 0..<24 {
            let fixture: WaveKnotKeeperFixture = Self.fixture(&random, gates: round % 3 == 0)
            var levels: [WaveKnotKeeperLevel] = [fixture.level]
            let start: Int = WaveKnotKeeperGeometry.tension(fixture.level.points)
            let tight: WaveKnotKeeperLevel = try WaveKnotKeeperLevel(
                id: "tight", seed: fixture.level.seed, band: fixture.level.band, points: fixture.level.points,
                gates: fixture.level.gates, target: fixture.level.target, tensionBound: start,
                allowance: fixture.level.allowance)
            levels.append(tight)
            for candidate in levels {
                let base: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(candidate)
                for index in -1...candidate.points.count {
                    for direction in WaveKnotKeeperDirection.allCases {
                        let move = WaveKnotKeeperMove(point: index, direction: direction)
                        var trial: WaveKnotKeeperPlay = base
                        let expected: WaveKnotKeeperError? = Self.referenceRefusal(move, points: base.points,
                                                                                    level: candidate)
                        do {
                            try trial.apply(move, expecting: trial.fingerprint)
                            #expect(expected == nil)
                            #expect(trial.spent == 1)
                            #expect(trial.tension <= candidate.tensionBound)
                            if candidate.gates.isEmpty { #expect(WaveKnotKeeperGeometry.isSimple(trial.points)) }
                        } catch {
                            #expect(error == expected)
                            #expect(trial == base)
                            if case .move(let reason) = error { reasons[reason, default: 0] += 1 }
                        }
                    }
                }
            }
            // Spend a seeded allowance on losing moves: the last accepted one fails the play, the next is refused.
            var spender: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            var spentAll: Bool = true
            for k in 0..<fixture.level.allowance {
                guard let move = Self.losingMove(spender, random: &random) else {
                    spentAll = false
                    break
                }
                try spender.apply(move, expecting: spender.fingerprint)
                #expect(spender.spent == k + 1)
            }
            if !spentAll { continue }
            exhausted += 1
            #expect(spender.stage == .failed && spender.spent == fixture.level.allowance)
            let done: WaveKnotKeeperPlay = spender
            if let move = Self.losingMove(spender, random: &random) {
                #expect(throws: WaveKnotKeeperError.stage) { try spender.apply(move, expecting: spender.fingerprint) }
            }
            #expect(spender == done)
        }
        #expect(exhausted > 0)
        #expect((reasons["range"] ?? 0) > 0 && (reasons["crossing"] ?? 0) > 0 && (reasons["tension"] ?? 0) > 0)
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: a win is awarded exactly when the projection is not degenerate and the crossing count and writhe
    /// equal the target; a degenerate projection with the target's counts never wins.
    @Test func testWaveKnotKeeperGoalBoundary() throws {
        // Direct boundary: the touching rope has the target's counts (0, 0) but is degenerate, so it does not win;
        // one step +y clears the touch and wins; one step −y crosses the first segment and does not.
        let level: WaveKnotKeeperLevel = try Self.touchingLevel()
        let start: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(Self.touching)
        #expect(start.crossings == 0 && start.writhe == 0 && start.degenerate)
        #expect(!level.wins(Self.touching))
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        try play.apply(WaveKnotKeeperMove(point: 4, direction: .minusY), expecting: play.fingerprint)
        #expect(play.stage == .playing)
        #expect(play.summary.crossings > 0)
        try play.undo()
        try play.apply(WaveKnotKeeperMove(point: 4, direction: .plusY), expecting: play.fingerprint)
        #expect(play.stage == .won)
        #expect(play.summary == WaveKnotKeeperSummary(crossings: 0, writhe: 0, degenerate: false))
        // Seeded neighbours: along each solution the play stays in play until the first winning rope; the goal rope's
        // single-step neighbours win exactly when their summary equals the target and is not degenerate; a target one
        // crossing pair away does not accept the goal rope.
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        for _ in 0..<20 {
            let fixture: WaveKnotKeeperFixture = Self.fixture(&random)
            let target: WaveKnotKeeperTarget = fixture.level.target
            var walk: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            for move in fixture.solution where walk.stage == .playing {
                try walk.apply(move, expecting: walk.fingerprint)
                let summary: WaveKnotKeeperSummary = walk.summary
                let matches: Bool = !summary.degenerate && summary.crossings == target.crossings
                    && summary.writhe == target.writhe
                #expect((walk.stage == .won) == matches)
            }
            #expect(walk.stage == .won)
            #expect(fixture.level.wins(fixture.goal))
            for index in 0..<fixture.goal.count {
                for direction in WaveKnotKeeperDirection.allCases {
                    let near: [Point] = Self.moved(fixture.goal, WaveKnotKeeperMove(point: index, direction: direction))
                    if !near[index].isInBounds { continue }
                    let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(near)
                    let matches: Bool = !summary.degenerate && summary.crossings == target.crossings
                        && summary.writhe == target.writhe
                    #expect(fixture.level.wins(near) == matches)
                }
            }
            if let other = try? WaveKnotKeeperTarget(crossings: target.crossings + 2, writhe: target.writhe),
               let level2 = try? WaveKnotKeeperLevel(id: "other", seed: fixture.level.seed, band: 1,
                                                     points: fixture.level.points, gates: [], target: other,
                                                     tensionBound: 49_152, allowance: 8) {
                #expect(!level2.wins(fixture.goal))
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: a record trace replays to the same records, fingerprints and outcome; an edited record is
    /// refused; a fixture rebuilt from its seed is the same level.
    @Test func testWaveKnotKeeperRepeatabilityBoundary() throws {
        // Direct boundary: the empty trace replays to the fresh play; the winning trace replays to the won play.
        let level: WaveKnotKeeperLevel = try Self.touchingLevel()
        let fresh: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: level, records: [])
        #expect(fresh == (try WaveKnotKeeperFixtures.playing(level)) && fresh.records.isEmpty)
        var won: WaveKnotKeeperPlay = fresh
        try won.apply(WaveKnotKeeperMove(point: 4, direction: .plusY), expecting: won.fingerprint)
        let again: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: level, records: won.records)
        #expect(again == won && again.stage == .won)
        // Seeded neighbours: seeded traces of moves, undos and redos; each record chains; edits are refused.
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        for _ in 0..<20 {
            let index: Int = random.int(0...9_999)
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index)
            #expect(WaveKnotKeeperFixtures.fixture(index).level == fixture.level)
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            var steps: Int = 0
            while play.stage == .playing && steps < 12 {
                steps += 1
                let roll: Int = random.int(0...5)
                if roll == 0 && play.canUndo {
                    try play.undo()
                } else if roll == 1 && play.canRedo {
                    try play.redo()
                } else if let move = Self.losingMove(play, random: &random) {
                    try play.apply(move, expecting: play.fingerprint)
                }
            }
            if play.records.isEmpty { continue }
            let replayed: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: fixture.level, records: play.records)
            #expect(replayed == play)
            #expect(replayed.fingerprint == play.fingerprint)
            #expect(replayed.stage == play.stage && replayed.failure == play.failure)
            for i in 1..<play.records.count {
                #expect(play.records[i].previous == play.records[i - 1].next)
            }
            let at: Int = random.int(0...(play.records.count - 1))
            let r: WaveKnotKeeperRecord = play.records[at]
            var edits: [WaveKnotKeeperRecord] = []
            edits.append(WaveKnotKeeperRecord(schema: r.schema, seed: r.seed &+ 1, tick: r.tick, kind: r.kind,
                                              point: r.point, direction: r.direction, previous: r.previous,
                                              next: r.next))
            edits.append(WaveKnotKeeperRecord(schema: r.schema, seed: r.seed, tick: r.tick + 1, kind: r.kind,
                                              point: r.point, direction: r.direction, previous: r.previous,
                                              next: r.next))
            edits.append(WaveKnotKeeperRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                              point: r.point, direction: r.direction.opposite, previous: r.previous,
                                              next: r.next))
            edits.append(WaveKnotKeeperRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                              point: (r.point + 1) % fixture.level.points.count,
                                              direction: r.direction, previous: r.previous, next: r.next))
            edits.append(WaveKnotKeeperRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                              point: r.point, direction: r.direction,
                                              previous: String(repeating: "a", count: 64), next: r.next))
            edits.append(WaveKnotKeeperRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                              point: r.point, direction: r.direction, previous: r.previous,
                                              next: String(repeating: "0", count: 64)))
            for edited in edits {
                var records: [WaveKnotKeeperRecord] = play.records
                records[at] = edited
                #expect(throws: WaveKnotKeeperError.self) {
                    try WaveKnotKeeperPlay.replay(level: fixture.level, records: records)
                }
            }
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo restores the exact prior rope, moves spent and fingerprint; redo restores the after state; a new
    /// move clears redo; nothing to undo or redo, and a finished play, refuse it unchanged.
    @Test func testWaveKnotKeeperUndoBoundary() throws {
        // Direct boundary: nothing to undo or redo at zero moves; one move undone and redone.
        let level: WaveKnotKeeperLevel = try Self.touchingLevel()
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        let start: WaveKnotKeeperPlay = play
        #expect(throws: WaveKnotKeeperError.move("nothing-to-undo")) { try play.undo() }
        #expect(throws: WaveKnotKeeperError.move("nothing-to-redo")) { try play.redo() }
        #expect(play == start)
        try play.apply(WaveKnotKeeperMove(point: 4, direction: .minusY), expecting: play.fingerprint)
        let after: String = play.fingerprint
        try play.undo()
        #expect(play.points == start.points && play.spent == 0 && play.fingerprint == start.fingerprint)
        try play.redo()
        #expect(play.fingerprint == after)
        try play.undo()
        try play.apply(WaveKnotKeeperMove(point: 4, direction: .plusY), expecting: play.fingerprint)
        #expect(play.stage == .won && !play.canRedo)
        let won: WaveKnotKeeperPlay = play
        #expect(throws: WaveKnotKeeperError.stage) { try play.undo() }
        #expect(throws: WaveKnotKeeperError.stage) { try play.redo() }
        #expect(play == won)
        // Seeded neighbours: losing moves undone and redone; a new move clears redo; unwinding walks the fingerprints
        // back to the start.
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        var cleared: Int = 0
        for _ in 0..<24 {
            let fixture: WaveKnotKeeperFixture = Self.fixture(&random)
            var p: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            var history: [String] = [p.fingerprint]
            for _ in 0..<4 {
                guard let move = Self.losingMove(p, random: &random) else { break }
                let before: WaveKnotKeeperPlay = p
                try p.apply(move, expecting: p.fingerprint)
                if p.stage != .playing { break }
                let afterMove: String = p.fingerprint
                try p.undo()
                #expect(p.points == before.points && p.spent == before.spent)
                #expect(p.fingerprint == before.fingerprint && p.stage == .playing)
                try p.redo()
                #expect(p.fingerprint == afterMove)
                history.append(afterMove)
            }
            if p.stage != .playing { continue }
            if p.canUndo {
                try p.undo()
                history.removeLast()
                if let move = Self.losingMove(p, random: &random), p.spent < fixture.level.allowance - 1 {
                    try p.apply(move, expecting: p.fingerprint)
                    history.append(p.fingerprint)
                    #expect(!p.canRedo)
                    #expect(throws: WaveKnotKeeperError.move("nothing-to-redo")) { try p.redo() }
                    cleared += 1
                }
            }
            var k: Int = history.count - 1
            while p.canUndo {
                try p.undo()
                k -= 1
                #expect(p.fingerprint == history[k])
            }
            #expect(p.points == fixture.level.points && p.spent == 0 && k == 0)
        }
        #expect(cleared > 0)
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: a failed play explains itself with the final rope's summary, which does not meet the
    /// target; the rope stays where the player left it; refusals name their reason and change nothing.
    @Test func testWaveKnotKeeperFailurehonestyBoundary() throws {
        // Direct boundary: allowance 1, one losing move fails with the crossing it made as the explanation.
        let level: WaveKnotKeeperLevel = try Self.touchingLevel(allowance: 1)
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        #expect(play.failure == nil)
        try play.apply(WaveKnotKeeperMove(point: 4, direction: .minusY), expecting: play.fingerprint)
        #expect(play.stage == .failed)
        #expect(play.failure == WaveKnotKeeperGeometry.summary(play.points))
        #expect(play.failure != WaveKnotKeeperSummary(crossings: 0, writhe: 0, degenerate: false))
        #expect(play.points[4] == Point(x: 3, y: -1, z: 3))
        try play.handle(.showResult)
        #expect(play.stage == .result && play.failure != nil)
        #expect(throws: WaveKnotKeeperError.stage) { try play.handle(.showResult) }
        // A won play carries no failure.
        var winner: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(try Self.touchingLevel())
        try winner.apply(WaveKnotKeeperMove(point: 4, direction: .plusY), expecting: winner.fingerprint)
        #expect(winner.stage == .won && winner.failure == nil)
        // Seeded neighbours: seeded losing plays fail with the final summary, never a hidden solution; seeded refused
        // moves on the way name the reference reason and change nothing.
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        var failures: Int = 0
        var refusals: Int = 0
        for _ in 0..<30 {
            let fixture: WaveKnotKeeperFixture = Self.fixture(&random)
            var p: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            var mirror: [Point] = p.points
            while p.stage == .playing {
                // A seeded probe: refused moves leave the play unchanged with the reference reason.
                let probe = WaveKnotKeeperMove(point: random.int(0...(mirror.count - 1)), direction: random.direction())
                if let reason = Self.referenceRefusal(probe, points: p.points, level: p.level) {
                    let held: WaveKnotKeeperPlay = p
                    #expect(throws: reason) { try p.apply(probe, expecting: p.fingerprint) }
                    #expect(p == held)
                    refusals += 1
                }
                guard let move = Self.losingMove(p, random: &random) else { break }
                try p.apply(move, expecting: p.fingerprint)
                mirror = Self.moved(mirror, move)
                if p.stage == .playing { #expect(p.failure == nil) }
            }
            guard p.stage == .failed else { continue }
            failures += 1
            let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(p.points)
            #expect(p.failure == summary)
            #expect(summary.degenerate || summary.crossings != fixture.level.target.crossings
                || summary.writhe != fixture.level.target.writhe)
            #expect(p.points == mirror)
            #expect(p.spent == fixture.level.allowance)
            #expect(throws: WaveKnotKeeperError.stage) { try p.undo() }
            try p.handle(.showResult)
            #expect(p.stage == .result && p.failure == summary && p.points == mirror)
        }
        #expect(failures > 0 && refusals > 0)
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: a 16-point rope on the ±16 bounds, every range edge of a level and the tension bound edge;
    /// seeded 16-point ropes across the whole cube never leave the bounds or the tension bound and never crash.
    @Test func testWaveKnotKeeperStabilityBoundary() throws {
        let rope: [Point] = Self.boundaryRope
        #expect(rope.count == 16 && WaveKnotKeeperGeometry.isSimple(rope))
        let target: WaveKnotKeeperTarget = try WaveKnotKeeperTarget(crossings: 2, writhe: 0)
        // Range edges: 16 points, tension bound 49,152, allowance 64 and 1 are accepted; one past each is refused.
        let level: WaveKnotKeeperLevel = try WaveKnotKeeperLevel(id: "edge", seed: Self.seed, band: 5, points: rope,
                                                                 gates: [], target: target, tensionBound: 49_152,
                                                                 allowance: 64)
        _ = try WaveKnotKeeperLevel(id: "edge", seed: Self.seed, band: 1, points: rope, gates: [], target: target,
                                    tensionBound: 49_152, allowance: 1)
        #expect(throws: WaveKnotKeeperError.level("tension-bound")) {
            try WaveKnotKeeperLevel(id: "edge", seed: Self.seed, band: 1, points: rope, gates: [], target: target,
                                    tensionBound: 49_153, allowance: 1)
        }
        #expect(throws: WaveKnotKeeperError.level("allowance")) {
            try WaveKnotKeeperLevel(id: "edge", seed: Self.seed, band: 1, points: rope, gates: [], target: target,
                                    tensionBound: 49_152, allowance: 65)
        }
        var seventeen: [Point] = rope
        seventeen.append(Point(x: 0, y: 0, z: 0))
        #expect(throws: WaveKnotKeeperError.level("points")) {
            try WaveKnotKeeperLevel(id: "edge", seed: Self.seed, band: 1, points: seventeen, gates: [], target: target,
                                    tensionBound: 49_152, allowance: 1)
        }
        var outside: [Point] = rope
        outside[0] = Point(x: -17, y: -16, z: -16)
        #expect(throws: WaveKnotKeeperError.level("points")) {
            try WaveKnotKeeperLevel(id: "edge", seed: Self.seed, band: 1, points: outside, gates: [], target: target,
                                    tensionBound: 49_152, allowance: 1)
        }
        #expect(throws: WaveKnotKeeperError.level("gate")) {
            try WaveKnotKeeperGate(min: Point(x: -17, y: 0, z: 0), max: Point(x: 0, y: 0, z: 0))
        }
        _ = try WaveKnotKeeperGate(min: Point(x: -16, y: -16, z: -16), max: Point(x: 16, y: 16, z: 16))
        // The largest tension of any valid rope is 16 segments × 3 × 32², the bound's upper edge; every determinant of
        // points in the bounds is at most 6 × 32³ in size.
        #expect(16 * 3 * 32 * 32 == WaveKnotKeeperLevel.tensionBounds.upperBound)
        let corner = Point(x: -16, y: -16, z: -16)
        let o: Int = WaveKnotKeeperGeometry.orientation(corner, Point(x: 16, y: -16, z: -16), Point(x: -16, y: 16, z: -16),
                                                        Point(x: -16, y: -16, z: 16))
        #expect(o == 32 * 32 * 32)
        #expect(WaveKnotKeeperGeometry.orientation(Point(x: 16, y: -16, z: -16), corner, Point(x: -16, y: 16, z: -16),
                                                   Point(x: -16, y: -16, z: 16)) == -o)
        // Direct boundary: on the boundary rope every outward z step is refused as out of bounds, unchanged; the point
        // index edges are refused as out of range.
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        let fresh: WaveKnotKeeperPlay = play
        #expect(play.fingerprint.count == 64)
        for i in 0..<rope.count {
            let outward: WaveKnotKeeperDirection = i % 2 == 0 ? .minusZ : .plusZ
            #expect(throws: WaveKnotKeeperError.move("bounds")) {
                try play.apply(WaveKnotKeeperMove(point: i, direction: outward), expecting: play.fingerprint)
            }
        }
        #expect(throws: WaveKnotKeeperError.move("range")) {
            try play.apply(WaveKnotKeeperMove(point: 16, direction: .plusX), expecting: play.fingerprint)
        }
        #expect(play == fresh)
        // The tension bound edge: a copy bounded at its start tension refuses every move that would raise it.
        let startTension: Int = WaveKnotKeeperGeometry.tension(rope)
        let tight: WaveKnotKeeperLevel = try WaveKnotKeeperLevel(id: "tight", seed: Self.seed, band: 1, points: rope,
                                                                 gates: [], target: target,
                                                                 tensionBound: startTension, allowance: 8)
        #expect(throws: WaveKnotKeeperError.level("tension-at-start")) {
            try WaveKnotKeeperLevel(id: "tight", seed: Self.seed, band: 1, points: rope, gates: [], target: target,
                                    tensionBound: startTension - 1, allowance: 8)
        }
        for i in 0..<rope.count {
            for direction in WaveKnotKeeperDirection.allCases {
                let move = WaveKnotKeeperMove(point: i, direction: direction)
                #expect(WaveKnotKeeperPlay.refusal(of: move, points: rope, level: tight)
                    == Self.referenceRefusal(move, points: rope, level: tight))
                let raised: Bool = WaveKnotKeeperGeometry.tension(Self.moved(rope, move)) > startTension
                if raised && Self.moved(rope, move)[i].isInBounds {
                    let refusal: WaveKnotKeeperError? = WaveKnotKeeperPlay.refusal(of: move, points: rope, level: tight)
                    #expect(refusal != nil)
                }
            }
        }
        // Seeded neighbours: random 16-point ropes across the whole cube under seeded moves stay in bounds, within the
        // tension bound and simple; summaries stay consistent (|writhe| ≤ crossings ≤ 16 · 13 / 2).
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        var accepted: Int = 0
        for _ in 0..<6 {
            let points: [Point] = WaveKnotKeeperFixtures.rope(&random, count: 16, spread: 16)
            let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(points)
            let goal: WaveKnotKeeperTarget = summary.crossings == 0
                ? try WaveKnotKeeperTarget(crossings: 2, writhe: 0) : try WaveKnotKeeperTarget(crossings: 0, writhe: 0)
            let wide: WaveKnotKeeperLevel = try WaveKnotKeeperLevel(id: "wide", seed: Self.seed, band: 3, points: points,
                                                                    gates: [], target: goal, tensionBound: 49_152,
                                                                    allowance: 64)
            var p: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(wide)
            for _ in 0..<120 {
                if p.stage != .playing { break }
                let move = WaveKnotKeeperMove(point: random.int(0...15), direction: random.direction())
                let held: WaveKnotKeeperPlay = p
                do {
                    try p.apply(move, expecting: p.fingerprint)
                    accepted += 1
                } catch {
                    #expect(p == held)
                }
                var inBounds: Bool = true
                for q in p.points where !q.isInBounds { inBounds = false }
                #expect(inBounds)
                #expect(p.tension <= 49_152 && p.tension > 0)
                #expect(WaveKnotKeeperGeometry.isSimple(p.points))
                let s: WaveKnotKeeperSummary = p.summary
                #expect(abs(s.writhe) <= s.crossings && s.crossings <= 16 * 13 / 2)
                #expect(p.fingerprint.count == 64)
            }
        }
        #expect(accepted > 0)
    }

    // MARK: INV-09 Save

    /// INV-09 Save: the stored level round-trips byte for byte; truncated, edited, older-than-1 and newer forms are
    /// refused, never half-loaded; a record trace stored as JSON replays to the same play.
    @Test func testWaveKnotKeeperSaveBoundary() throws {
        // Direct boundary: the touching level's complete form round-trips; the record trace of its win round-trips.
        let level: WaveKnotKeeperLevel = try Self.touchingLevel()
        let data: Data = level.encoded()
        let decoded: WaveKnotKeeperLevel = try WaveKnotKeeperLevel.decode(data)
        #expect(decoded == level && decoded.encoded() == data)
        #expect(try JSONDecoder().decode(WaveKnotKeeperLevel.self, from: data) == level)
        var won: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        try won.apply(WaveKnotKeeperMove(point: 4, direction: .plusY), expecting: won.fingerprint)
        let trace: Data = try JSONEncoder().encode(won.records)
        let records: [WaveKnotKeeperRecord] = try JSONDecoder().decode([WaveKnotKeeperRecord].self, from: trace)
        #expect(try WaveKnotKeeperPlay.replay(level: decoded, records: records) == won)
        let text: String = String(decoding: data, as: UTF8.self)
        let older: String = text.replacingOccurrences(of: "\"schema\":1,", with: "\"schema\":0,")
        #expect(older != text)
        #expect(throws: WaveKnotKeeperError.malformed("schema 0")) { try WaveKnotKeeperLevel.decode(Data(older.utf8)) }
        // Seeded neighbours: fixtures' forms round-trip; cut, edited, newer and single-byte-damaged forms are refused;
        // a stored trace replays to the play and each prefix replays to its own last fingerprint.
        var random = WaveKnotKeeperRandom(seed: Self.seed)
        for _ in 0..<16 {
            let fixture: WaveKnotKeeperFixture = Self.fixture(&random)
            let stored: Data = fixture.level.encoded()
            let back: WaveKnotKeeperLevel = try WaveKnotKeeperLevel.decode(stored)
            #expect(back == fixture.level && back.encoded() == stored)
            #expect(throws: WaveKnotKeeperError.self) { try WaveKnotKeeperLevel.decode(stored.prefix(stored.count - 1)) }
            #expect(throws: WaveKnotKeeperError.self) { try WaveKnotKeeperLevel.decode(stored.prefix(stored.count / 2)) }
            let form: String = String(decoding: stored, as: UTF8.self)
            let key: String = "\"allowance\":\(fixture.level.allowance)"
            let edited: String = form.replacingOccurrences(of: key,
                                                           with: "\"allowance\":\(fixture.level.allowance % 64 + 1)")
            #expect(edited != form)
            #expect(throws: WaveKnotKeeperError.malformed("fingerprint")) {
                try WaveKnotKeeperLevel.decode(Data(edited.utf8))
            }
            let newer: String = form.replacingOccurrences(of: "\"schema\":1,", with: "\"schema\":2,")
            #expect(newer != form)
            #expect(throws: WaveKnotKeeperError.newerSchema(2)) { try WaveKnotKeeperLevel.decode(Data(newer.utf8)) }
            var bytes: [UInt8] = Array(stored)
            for _ in 0..<10 {
                let index: Int = random.int(0...(bytes.count - 1))
                let original: UInt8 = bytes[index]
                var replacement: UInt8 = UInt8(random.int(33...126))
                if replacement == original { replacement = original == 48 ? 49 : 48 }
                bytes[index] = replacement
                #expect(throws: WaveKnotKeeperError.self) { try WaveKnotKeeperLevel.decode(Data(bytes)) }
                bytes[index] = original
            }
            let play: WaveKnotKeeperPlay = try Self.solved(fixture)
            let saved: Data = try JSONEncoder().encode(play.records)
            let loaded: [WaveKnotKeeperRecord] = try JSONDecoder().decode([WaveKnotKeeperRecord].self, from: saved)
            #expect(loaded == play.records)
            #expect(try WaveKnotKeeperPlay.replay(level: back, records: loaded) == play)
            let cut: Int = random.int(1...loaded.count)
            let partial: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: back,
                                                                           records: Array(loaded.prefix(cut)))
            #expect(partial.fingerprint == loaded[cut - 1].next)
            #expect(partial.records.count == cut)
        }
    }
}
