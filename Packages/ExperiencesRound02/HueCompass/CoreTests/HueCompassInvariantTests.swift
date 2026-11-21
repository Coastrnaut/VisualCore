// HueCompassInvariantTests — feature 331 (R02-G04-01) T-R02G0401-006 (FR-R02G0401-012; the source's invariants
// INV-01 … INV-08, round2.md section on Hue Compass). Each named test gives a direct boundary example and a seeded check
// of neighbouring inputs (seed 2,336), as the source asks. How each invariant maps onto this kernel:
// - INV-01 Time: the kernel is action-driven and reads no clock or frame; a record's tick is its index. The same actions
//   give the same fingerprints and records however long the play is paused between them; a paused play accepts nothing.
// - INV-02 Input budget: the allowance is shared by probes and the selection; turns, undo and redo spend nothing; the
//   unit that spends the allowance ends the play and nothing after it is accepted; a refused action changes nothing.
// - INV-03 Goal: a selection wins exactly when its bearing is within the bearing tolerance (circular distance equal to
//   the tolerance wins, one more fails) and its band within the band tolerance of the target's band (the same edge).
// - INV-04 Repeatability: the same trace gives the same records and fingerprints on every run and through replay; an
//   edited record is refused; a fixture rebuilt from its index is the same level.
// - INV-05 Undo: undo restores the exact earlier bearing and fingerprint, redo the later one; a new turn clears redo;
//   probes and selections are permanent and clear both stacks; nothing to undo or redo, and a finished play, refuse it.
// - INV-06 Failure honesty: the failure names what happened — `selection` for a missed selection, `probes` for a probe
//   that spent the last unit; a play never fails while units remain and no selection was made; a win has no failure.
// - INV-07 Stability: the bearing stays 0 … 95 under wrap-around turns, a clue's hue gap stays 0 … 12 and its fog depth
//   0 … 423 (47 inner bearings × density 9); out-of-range operands are refused unchanged.
// - INV-08 Save: the stored level round-trips byte for byte, damaged and newer forms are refused, and a record trace
//   stored as JSON replays to the same play.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import HueCompassCore

@Suite struct HueCompassInvariantTests {
    /// The invariant seed.
    static let seed: UInt64 = 2_336

    /// A hand-made level: offset 0, uniform fog, target 10 (band 2), start 40, bearing tolerance 2, band tolerance 1.
    static func handLevel(allowance: Int = 3, fog density: Int = 1, target: Int = 10, start: Int = 40,
                          offset: Int = 0) throws -> HueCompassLevel {
        var fog: [Int] = []
        for _ in 0..<HueCompassWheel.bearings { fog.append(density) }
        return try HueCompassLevel(id: "hand", seed: seed, band: 1, offset: offset, fog: fog, target: target,
                                   start: start, bearingTolerance: 2, bandTolerance: 1, allowance: allowance)
    }

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: HueCompassLevel) throws -> HueCompassPlay {
        var play = HueCompassPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A seeded fixture (index and tutorial flag drawn from `random`).
    static func fixture(_ random: inout HueCompassRandom) -> HueCompassFixture {
        let index: Int = random.int(0...9_999)
        return HueCompassFixtures.fixture(index, tutorial: random.int(0...1) == 1)
    }

    /// A non-zero turn in range.
    static func turn(_ random: inout HueCompassRandom) -> Int {
        let steps: Int = random.int(-48...47)
        return steps >= 0 ? steps + 1 : steps
    }

    /// The fixture's solution played from the start.
    static func solved(_ fixture: HueCompassFixture) throws -> HueCompassPlay {
        var play: HueCompassPlay = try Self.playing(fixture.level)
        for action in fixture.solution where play.stage == .playing {
            try play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// A seeded trace of turns, undos, redos, probes and (rarely) a selection, at most `steps` long.
    static func randomPlay(_ level: HueCompassLevel, steps: Int,
                           random: inout HueCompassRandom) throws -> HueCompassPlay {
        var play: HueCompassPlay = try Self.playing(level)
        var count: Int = 0
        while play.stage == .playing && count < steps {
            count += 1
            let roll: Int = random.int(0...9)
            if roll == 0 && play.canUndo {
                try play.undo()
            } else if roll == 1 && play.canRedo {
                try play.redo()
            } else if roll == 2 || roll == 3 {
                try play.apply(.probe, expecting: play.fingerprint)
            } else if roll == 4 && random.int(0...3) == 0 {
                let selection = HueCompassAction.select(bearing: random.int(0...95), band: random.int(0...23))
                try play.apply(selection, expecting: play.fingerprint)
            } else {
                try play.apply(.turn(Self.turn(&random)), expecting: play.fingerprint)
            }
        }
        return play
    }

    /// The units spent according to the records: one per probe and selection record.
    static func unitsRecorded(_ records: [HueCompassRecord]) -> Int {
        var units: Int = 0
        for record in records where record.kind == .probe || record.kind == .select { units += 1 }
        return units
    }

    // MARK: INV-01 Time

    /// INV-01 Time: no clock input — the same actions give the same fingerprints and records with or without pauses;
    /// a paused play accepts no action; a record's tick is its index.
    @Test func testHueCompassTimeBoundary() throws {
        // Direct boundary: pausing and resuming at once returns the exact play; a paused play refuses everything.
        let level: HueCompassLevel = try Self.handLevel()
        var play: HueCompassPlay = try Self.playing(level)
        try play.apply(.turn(5), expecting: play.fingerprint)
        let before: HueCompassPlay = play
        try play.handle(.pause)
        #expect(play.stage == .paused && play.fingerprint != before.fingerprint)
        let paused: HueCompassPlay = play
        #expect(throws: HueCompassError.stage) { try play.apply(.turn(1), expecting: play.fingerprint) }
        #expect(throws: HueCompassError.stage) { try play.apply(.probe, expecting: play.fingerprint) }
        #expect(throws: HueCompassError.stage) {
            try play.apply(.select(bearing: 10, band: 2), expecting: play.fingerprint)
        }
        #expect(throws: HueCompassError.stage) { try play.undo() }
        #expect(throws: HueCompassError.stage) { try play.redo() }
        #expect(throws: HueCompassError.stage) { try play.handle(.pause) }
        #expect(play == paused)
        try play.handle(.resume)
        #expect(play == before)
        // Two plays of the same level built separately (at different moments) are equal.
        #expect(try Self.playing(try Self.handLevel()) == (try Self.playing(level)))
        // Seeded neighbours: a fixture's solution and a seeded trace played straight and with seeded pause/resume
        // runs give identical records, fingerprints and outcome; record ticks are 0, 1, 2 ….
        var random = HueCompassRandom(seed: Self.seed)
        for _ in 0..<40 {
            let fixture: HueCompassFixture = Self.fixture(&random)
            let straight: HueCompassPlay = try Self.solved(fixture)
            #expect(straight.stage == .won)
            var paced: HueCompassPlay = try Self.playing(fixture.level)
            for action in fixture.solution where paced.stage == .playing {
                let pauses: Int = random.int(0...3)
                for _ in 0..<pauses {
                    let held: String = paced.fingerprint
                    try paced.handle(.pause)
                    try paced.handle(.resume)
                    #expect(paced.fingerprint == held)
                }
                try paced.apply(action, expecting: paced.fingerprint)
            }
            #expect(paced == straight)
            #expect(paced.records == straight.records)
            for i in 0..<straight.records.count {
                #expect(straight.records[i].tick == i)
            }
            // A seeded trace and the same trace with pauses agree record for record.
            var traceRandom = HueCompassRandom(seed: Self.seed &+ UInt64(random.int(0...999)))
            let trace: HueCompassPlay = try Self.randomPlay(fixture.level, steps: 16, random: &traceRandom)
            var paused2: HueCompassPlay = try Self.playing(fixture.level)
            for record in trace.records {
                try paused2.handle(.pause)
                try paused2.handle(.resume)
                switch record.kind {
                case .turn, .probe, .select: try paused2.apply(record.action, expecting: paused2.fingerprint)
                case .undo: try paused2.undo()
                case .redo: try paused2.redo()
                }
            }
            #expect(paused2 == trace)
            for i in 0..<trace.records.count {
                #expect(trace.records[i].tick == i)
            }
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: probes and the selection never spend more than the allowance; the unit that spends it ends
    /// the play and nothing after it is accepted; turns, undo and redo are free.
    @Test func testHueCompassInputbudgetBoundary() throws {
        // Direct boundary: allowance 2 — a probe, many free turns, then the second probe spends the allowance.
        let level: HueCompassLevel = try Self.handLevel(allowance: 2)
        var play: HueCompassPlay = try Self.playing(level)
        #expect(play.remaining == 2)
        try play.apply(.probe, expecting: play.fingerprint)
        #expect(play.spent == 1 && play.stage == .playing)
        for _ in 0..<30 {
            try play.apply(.turn(48), expecting: play.fingerprint)
        }
        try play.undo()
        try play.redo()
        #expect(play.spent == 1 && play.remaining == 1)
        let fresh: HueCompassPlay = play
        #expect(throws: HueCompassError.stale) {
            try play.apply(.probe, expecting: String(repeating: "0", count: 64))
        }
        #expect(throws: HueCompassError.action("range")) { try play.apply(.turn(0), expecting: play.fingerprint) }
        #expect(play == fresh)
        try play.apply(.probe, expecting: play.fingerprint)
        #expect(play.spent == 2 && play.spent == level.allowance && play.stage == .failed)
        let ended: HueCompassPlay = play
        #expect(throws: HueCompassError.stage) { try play.apply(.probe, expecting: play.fingerprint) }
        #expect(throws: HueCompassError.stage) {
            try play.apply(.select(bearing: 10, band: 2), expecting: play.fingerprint)
        }
        #expect(throws: HueCompassError.stage) { try play.apply(.turn(1), expecting: play.fingerprint) }
        #expect(play == ended)
        // The selection may spend the last unit: allowance 2, probe, then a selection is accepted.
        var last: HueCompassPlay = try Self.playing(level)
        try last.apply(.probe, expecting: last.fingerprint)
        try last.apply(.select(bearing: 10, band: 2), expecting: last.fingerprint)
        #expect(last.spent == 2 && last.stage == .won)
        // Seeded neighbours: seeded traces never spend more than the allowance; spent equals the probe and selection
        // records; every turn, undo and redo leaves spent unchanged; the play ends exactly when the allowance is spent
        // or a selection is made; a play one unit short of its allowance is still playing.
        var random = HueCompassRandom(seed: Self.seed)
        var exhausted: Int = 0
        for _ in 0..<60 {
            let fixture: HueCompassFixture = Self.fixture(&random)
            var p: HueCompassPlay = try Self.playing(fixture.level)
            var steps: Int = 0
            while p.stage == .playing && steps < 80 {
                steps += 1
                let spentBefore: Int = p.spent
                let roll: Int = random.int(0...5)
                if roll == 0 {
                    try p.apply(.probe, expecting: p.fingerprint)
                    #expect(p.spent == spentBefore + 1)
                } else if roll == 1 && p.canUndo {
                    try p.undo()
                    #expect(p.spent == spentBefore)
                } else if roll == 2 && p.canRedo {
                    try p.redo()
                    #expect(p.spent == spentBefore)
                } else {
                    try p.apply(.turn(Self.turn(&random)), expecting: p.fingerprint)
                    #expect(p.spent == spentBefore)
                }
                #expect(p.spent <= fixture.level.allowance)
                #expect(p.spent == Self.unitsRecorded(p.records))
                #expect((p.stage == .playing) == (p.spent < fixture.level.allowance))
            }
            if p.stage == .failed {
                exhausted += 1
                #expect(p.spent == fixture.level.allowance && p.remaining == 0)
                let done: HueCompassPlay = p
                #expect(throws: HueCompassError.stage) { try p.apply(.probe, expecting: p.fingerprint) }
                #expect(p == done)
            }
            // Neighbouring allowance: allowance − 1 probes leave the play running; a selection then ends it.
            var q: HueCompassPlay = try Self.playing(fixture.level)
            for _ in 0..<(fixture.level.allowance - 1) {
                try q.apply(.probe, expecting: q.fingerprint)
            }
            #expect(q.stage == .playing && q.remaining == 1)
            try q.apply(.select(bearing: fixture.level.target, band: fixture.level.targetBand), expecting: q.fingerprint)
            #expect(q.stage == .won && q.spent == fixture.level.allowance)
        }
        #expect(exhausted > 0)
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: a selection wins exactly when its bearing distance is at most the bearing tolerance and its band
    /// distance at most the band tolerance; one past either edge fails.
    @Test func testHueCompassGoalBoundary() throws {
        // Direct boundary: target 10 (band 2), bearing tolerance 2, band tolerance 1.
        let level: HueCompassLevel = try Self.handLevel()
        #expect(level.targetBand == 2)
        let cases: [(bearing: Int, band: Int, wins: Bool)] = [
            (12, 2, true), (8, 2, true), (13, 2, false), (7, 2, false),
            (10, 3, true), (10, 1, true), (10, 4, false), (10, 0, false), (12, 3, true), (13, 3, false),
        ]
        for c in cases {
            #expect(level.accepts(bearing: c.bearing, band: c.band) == c.wins)
            var play: HueCompassPlay = try Self.playing(level)
            try play.apply(.select(bearing: c.bearing, band: c.band), expecting: play.fingerprint)
            #expect(play.stage == (c.wins ? .won : .failed))
            #expect(play.failure == (c.wins ? nil : .selection))
        }
        // Wrap-around: target 1 (band 0), offset 0 — bearing 95 is 2 away and band 23 is 1 away.
        let wrap: HueCompassLevel = try Self.handLevel(target: 1, start: 48)
        #expect(wrap.accepts(bearing: 95, band: 23))
        #expect(!wrap.accepts(bearing: 94, band: 0))
        #expect(!wrap.accepts(bearing: 1, band: 22))
        // Seeded neighbours: around every fixture's target, bearings at tolerance − 1, tolerance and tolerance + 1 on
        // both sides and bands at the same band edges win exactly when within both tolerances; the play agrees.
        var random = HueCompassRandom(seed: Self.seed)
        for _ in 0..<60 {
            let fixture: HueCompassFixture = Self.fixture(&random)
            let l: HueCompassLevel = fixture.level
            let solved: HueCompassPlay = try Self.solved(fixture)
            #expect(solved.stage == .won && solved.failure == nil)
            for side in [-1, 1] {
                for d in max(0, l.bearingTolerance - 1)...(l.bearingTolerance + 1) {
                    for e in max(0, l.bandTolerance - 1)...(l.bandTolerance + 1) {
                        let bearing: Int = HueCompassWheel.mod(l.target + side * d, HueCompassWheel.bearings)
                        let band: Int = HueCompassWheel.mod(l.targetBand - side * e, HueCompassWheel.bands)
                        let expected: Bool = d <= l.bearingTolerance && e <= l.bandTolerance
                        #expect(HueCompassWheel.bearingDistance(bearing, l.target) == d)
                        #expect(HueCompassWheel.bandDistance(band, l.targetBand) == e)
                        #expect(l.accepts(bearing: bearing, band: band) == expected)
                        var play: HueCompassPlay = try Self.playing(l)
                        try play.apply(.turn(Self.turn(&random)), expecting: play.fingerprint)
                        try play.apply(.select(bearing: bearing, band: band), expecting: play.fingerprint)
                        #expect((play.stage == .won) == expected)
                    }
                }
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same trace gives the same records and fingerprints on repeated runs and via replay; an
    /// edited record is refused; a fixture rebuilt from its index is the same level.
    @Test func testHueCompassRepeatabilityBoundary() throws {
        // Direct boundary: the empty trace replays to the fresh play; the solution replays to the won play.
        let level: HueCompassLevel = try Self.handLevel()
        let fresh: HueCompassPlay = try HueCompassPlay.replay(level: level, records: [])
        #expect(fresh == (try Self.playing(level)) && fresh.records.isEmpty)
        var won: HueCompassPlay = fresh
        try won.apply(.probe, expecting: won.fingerprint)
        try won.apply(.turn(-30), expecting: won.fingerprint)
        try won.apply(.select(bearing: 10, band: 2), expecting: won.fingerprint)
        let again: HueCompassPlay = try HueCompassPlay.replay(level: level, records: won.records)
        #expect(again == won && again.stage == .won)
        #expect(again.fingerprint == won.fingerprint)
        // Seeded neighbours: a seeded trace run twice from the same seed is identical; replay reproduces it; records
        // chain; each edited record is refused.
        var random = HueCompassRandom(seed: Self.seed)
        for round in 0..<40 {
            let index: Int = random.int(0...9_999)
            let fixture: HueCompassFixture = HueCompassFixtures.fixture(index, tutorial: round % 2 == 0)
            #expect(HueCompassFixtures.fixture(index, tutorial: round % 2 == 0).level == fixture.level)
            let traceSeed: UInt64 = Self.seed &+ UInt64(index)
            var first = HueCompassRandom(seed: traceSeed)
            var second = HueCompassRandom(seed: traceSeed)
            let play: HueCompassPlay = try Self.randomPlay(fixture.level, steps: 20, random: &first)
            let twin: HueCompassPlay = try Self.randomPlay(fixture.level, steps: 20, random: &second)
            #expect(play == twin && play.records == twin.records)
            if play.records.isEmpty { continue }
            let replayed: HueCompassPlay = try HueCompassPlay.replay(level: fixture.level, records: play.records)
            #expect(replayed == play)
            #expect(replayed.fingerprint == play.fingerprint)
            #expect(replayed.stage == play.stage && replayed.failure == play.failure)
            for i in 1..<play.records.count {
                #expect(play.records[i].previous == play.records[i - 1].next)
            }
            let at: Int = random.int(0...(play.records.count - 1))
            let r: HueCompassRecord = play.records[at]
            var edits: [HueCompassRecord] = []
            edits.append(HueCompassRecord(schema: r.schema, seed: r.seed &+ 1, tick: r.tick, kind: r.kind,
                                          action: r.action, previous: r.previous, next: r.next))
            edits.append(HueCompassRecord(schema: r.schema, seed: r.seed, tick: r.tick + 1, kind: r.kind,
                                          action: r.action, previous: r.previous, next: r.next))
            edits.append(HueCompassRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                          action: r.action, previous: r.previous,
                                          next: String(repeating: "0", count: 64)))
            edits.append(HueCompassRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                          action: r.action, previous: String(repeating: "a", count: 64),
                                          next: r.next))
            if case .turn(let steps) = r.action {
                let other: Int = steps == 48 ? 47 : steps + 1 == 0 ? steps + 2 : steps + 1
                edits.append(HueCompassRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                              action: .turn(other), previous: r.previous, next: r.next))
            }
            for edited in edits {
                var records: [HueCompassRecord] = play.records
                records[at] = edited
                #expect(throws: HueCompassError.self) {
                    try HueCompassPlay.replay(level: fixture.level, records: records)
                }
            }
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo restores the exact earlier bearing and fingerprint, redo the later one; a new turn clears
    /// redo; probes and selections are not undoable; a finished play refuses undo and redo unchanged.
    @Test func testHueCompassUndoBoundary() throws {
        // Direct boundary: nothing to undo or redo at the start; one turn undone and redone; a probe clears both.
        let level: HueCompassLevel = try Self.handLevel()
        var play: HueCompassPlay = try Self.playing(level)
        let start: HueCompassPlay = play
        #expect(throws: HueCompassError.action("nothing-to-undo")) { try play.undo() }
        #expect(throws: HueCompassError.action("nothing-to-redo")) { try play.redo() }
        #expect(play == start)
        try play.apply(.turn(-41), expecting: play.fingerprint)
        let after: String = play.fingerprint
        #expect(play.bearing == 95)
        try play.undo()
        #expect(play.bearing == start.bearing && play.fingerprint == start.fingerprint)
        try play.redo()
        #expect(play.fingerprint == after && play.bearing == 95)
        try play.undo()
        try play.apply(.turn(3), expecting: play.fingerprint)
        #expect(!play.canRedo)
        try play.apply(.probe, expecting: play.fingerprint)
        let probed: HueCompassPlay = play
        #expect(!play.canUndo && !play.canRedo)
        #expect(throws: HueCompassError.action("nothing-to-undo")) { try play.undo() }
        #expect(throws: HueCompassError.action("nothing-to-redo")) { try play.redo() }
        #expect(play == probed && play.clues.count == 1 && play.spent == 1)
        try play.apply(.select(bearing: 10, band: 2), expecting: play.fingerprint)
        let won: HueCompassPlay = play
        #expect(throws: HueCompassError.stage) { try play.undo() }
        #expect(throws: HueCompassError.stage) { try play.redo() }
        #expect(play == won)
        // Seeded neighbours: seeded turns undone and redone one by one; unwinding walks the fingerprints back to the
        // last permanent action; a probe in the middle stops undo at it.
        var random = HueCompassRandom(seed: Self.seed)
        for round in 0..<60 {
            let fixture: HueCompassFixture = Self.fixture(&random)
            var p: HueCompassPlay = try Self.playing(fixture.level)
            if round % 2 == 1 {
                try p.apply(.turn(Self.turn(&random)), expecting: p.fingerprint)
                try p.apply(.probe, expecting: p.fingerprint)
                if p.stage != .playing { continue }
            }
            let anchor: HueCompassPlay = p
            var history: [String] = [p.fingerprint]
            var bearings: [Int] = [p.bearing]
            let turns: Int = random.int(1...8)
            for _ in 0..<turns {
                let before: HueCompassPlay = p
                try p.apply(.turn(Self.turn(&random)), expecting: p.fingerprint)
                let afterTurn: String = p.fingerprint
                try p.undo()
                #expect(p.bearing == before.bearing && p.fingerprint == before.fingerprint)
                #expect(p.spent == before.spent && p.clues == before.clues)
                try p.redo()
                #expect(p.fingerprint == afterTurn)
                history.append(afterTurn)
                bearings.append(p.bearing)
            }
            var k: Int = history.count - 1
            while p.canUndo {
                try p.undo()
                k -= 1
                #expect(p.fingerprint == history[k] && p.bearing == bearings[k])
            }
            #expect(k == 0 && p.fingerprint == anchor.fingerprint && p.bearing == anchor.bearing)
            #expect(p.clues == anchor.clues && p.spent == anchor.spent)
            // Redo walks forward again to the last turn.
            while p.canRedo {
                try p.redo()
                k += 1
                #expect(p.fingerprint == history[k])
            }
            #expect(k == history.count - 1)
        }
    }

    // MARK: INV-06 Failure honesty

    /// INV-06 Failure honesty: the failure is `selection` for a missed selection and `probes` for a probe that spent the
    /// last unit; a play never fails while units remain and no selection was made; a won play carries no failure.
    @Test func testHueCompassFailurehonestyBoundary() throws {
        // Direct boundary: allowance 2 — two probes fail with `probes`; a missed selection fails with `selection`.
        let level: HueCompassLevel = try Self.handLevel(allowance: 2)
        var probing: HueCompassPlay = try Self.playing(level)
        try probing.apply(.probe, expecting: probing.fingerprint)
        #expect(probing.stage == .playing && probing.failure == nil)
        try probing.apply(.probe, expecting: probing.fingerprint)
        #expect(probing.stage == .failed && probing.failure == .probes && probing.remaining == 0)
        try probing.handle(.showResult)
        #expect(probing.stage == .result && probing.failure == .probes)
        var missing: HueCompassPlay = try Self.playing(level)
        try missing.apply(.select(bearing: 13, band: 2), expecting: missing.fingerprint)
        #expect(missing.stage == .failed && missing.failure == .selection && missing.remaining == 1)
        var winner: HueCompassPlay = try Self.playing(level)
        try winner.apply(.select(bearing: 12, band: 3), expecting: winner.fingerprint)
        #expect(winner.stage == .won && winner.failure == nil)
        // Seeded neighbours: seeded plays end with the failure that matches their last record, and while playing there
        // is never a failure; a `probes` failure always has nothing left.
        var random = HueCompassRandom(seed: Self.seed)
        var bySelection: Int = 0
        var byProbes: Int = 0
        for _ in 0..<120 {
            let fixture: HueCompassFixture = Self.fixture(&random)
            var p: HueCompassPlay = try Self.playing(fixture.level)
            while p.stage == .playing {
                #expect(p.failure == nil && p.remaining > 0)
                let roll: Int = random.int(0...7)
                if roll == 0 {
                    let selection = HueCompassAction.select(bearing: random.int(0...95), band: random.int(0...23))
                    try p.apply(selection, expecting: p.fingerprint)
                } else if roll <= 3 {
                    try p.apply(.probe, expecting: p.fingerprint)
                } else {
                    try p.apply(.turn(Self.turn(&random)), expecting: p.fingerprint)
                }
            }
            let lastRecord: HueCompassRecord = p.records[p.records.count - 1]
            if p.stage == .won {
                #expect(p.failure == nil && lastRecord.kind == .select)
                continue
            }
            #expect(p.stage == .failed)
            if lastRecord.kind == .select {
                bySelection += 1
                #expect(p.failure == .selection)
                if case .select(let b, let band) = lastRecord.action {
                    #expect(!fixture.level.accepts(bearing: b, band: band))
                }
            } else {
                byProbes += 1
                #expect(lastRecord.kind == .probe)
                #expect(p.failure == .probes && p.remaining == 0)
                #expect(p.clues.count == fixture.level.allowance)
            }
            let ended: HueCompassPlay = p
            #expect(throws: HueCompassError.stage) { try p.undo() }
            #expect(p == ended)
        }
        #expect(bySelection > 0 && byProbes > 0)
    }

    // MARK: INV-07 Stability

    /// INV-07 Stability: the bearing stays 0 … 95 under wrap-around turns; clue hue gaps stay 0 … 12 and fog depths
    /// 0 … 423; out-of-range operands are refused unchanged.
    @Test func testHueCompassStabilityBoundary() throws {
        // Direct boundary: the densest fog (9 everywhere), target 48 opposite start 0 — the deepest clue is 47 × 9.
        let level: HueCompassLevel = try Self.handLevel(allowance: 24, fog: 9, target: 48, start: 0)
        var play: HueCompassPlay = try Self.playing(level)
        try play.apply(.probe, expecting: play.fingerprint)
        #expect(play.clues[0] == HueCompassClue(bearing: 0, hueGap: 12, depth: 423))
        try play.apply(.turn(-48), expecting: play.fingerprint)
        #expect(play.bearing == 48)
        try play.apply(.probe, expecting: play.fingerprint)
        #expect(play.clues[1] == HueCompassClue(bearing: 48, hueGap: 0, depth: 0))
        try play.apply(.turn(48), expecting: play.fingerprint)
        #expect(play.bearing == 0)
        try play.apply(.turn(-1), expecting: play.fingerprint)
        #expect(play.bearing == 95)
        try play.apply(.turn(1), expecting: play.fingerprint)
        #expect(play.bearing == 0)
        let held: HueCompassPlay = play
        let refused: [HueCompassAction] = [.turn(0), .turn(49), .turn(-49), .turn(Int.max), .turn(Int.min),
                                           .select(bearing: 96, band: 0), .select(bearing: -1, band: 0),
                                           .select(bearing: 0, band: 24), .select(bearing: 0, band: -1)]
        for action in refused {
            #expect(throws: HueCompassError.action("range")) { try play.apply(action, expecting: play.fingerprint) }
        }
        #expect(play == held)
        #expect(level.clue(at: -1).bearing == 95 && level.clue(at: 96).bearing == 0)
        // Seeded neighbours: seeded plays on fixtures and on fog-9 levels keep every value in bounds; a clue's parts
        // match an independent count.
        var random = HueCompassRandom(seed: Self.seed)
        var deepest: Int = 0
        for round in 0..<120 {
            let l: HueCompassLevel
            if round % 3 == 0 {
                let target: Int = random.int(0...95)
                l = try Self.handLevel(allowance: 24, fog: 9, target: target, start: (target + 48) % 96,
                                       offset: random.int(0...23))
            } else {
                l = Self.fixture(&random).level
            }
            var p: HueCompassPlay = try Self.playing(l)
            var steps: Int = 0
            while p.stage == .playing && steps < 60 {
                steps += 1
                if random.int(0...2) == 0 && p.remaining > 1 {
                    try p.apply(.probe, expecting: p.fingerprint)
                } else {
                    try p.apply(.turn(Self.turn(&random)), expecting: p.fingerprint)
                }
                #expect((0...95).contains(p.bearing))
                #expect(p.fingerprint.count == 64)
            }
            for clue in p.clues {
                #expect((0...95).contains(clue.bearing))
                #expect((0...12).contains(clue.hueGap))
                #expect((0...423).contains(clue.depth))
                let d: Int = HueCompassWheel.bearingDistance(clue.bearing, l.target)
                #expect(clue.depth <= max(0, d - 1) * 9)
                deepest = max(deepest, clue.depth)
            }
        }
        #expect(deepest > 0)
    }

    // MARK: INV-08 Save

    /// INV-08 Save: the stored level round-trips byte for byte; damaged and newer forms are refused; a record trace
    /// stored as JSON replays to the same play.
    @Test func testHueCompassSaveBoundary() throws {
        // Direct boundary: the hand level's stored form round-trips; its winning trace round-trips through JSON.
        let level: HueCompassLevel = try Self.handLevel()
        let data: Data = level.encoded()
        let decoded: HueCompassLevel = try HueCompassLevel.decode(data)
        #expect(decoded == level && decoded.encoded() == data)
        #expect(try JSONDecoder().decode(HueCompassLevel.self, from: data) == level)
        var won: HueCompassPlay = try Self.playing(level)
        try won.apply(.probe, expecting: won.fingerprint)
        try won.apply(.turn(-30), expecting: won.fingerprint)
        try won.undo()
        try won.redo()
        try won.apply(.select(bearing: 10, band: 2), expecting: won.fingerprint)
        let trace: Data = try JSONEncoder().encode(won.records)
        let records: [HueCompassRecord] = try JSONDecoder().decode([HueCompassRecord].self, from: trace)
        #expect(records == won.records)
        #expect(try HueCompassPlay.replay(level: decoded, records: records) == won)
        let text: String = String(decoding: data, as: UTF8.self)
        let newer: String = text.replacingOccurrences(of: "\"schema\":1,", with: "\"schema\":2,")
        #expect(newer != text)
        #expect(throws: HueCompassError.newerSchema(2)) { try HueCompassLevel.decode(Data(newer.utf8)) }
        // Seeded neighbours: fixtures' forms round-trip; cut and edited forms are refused; a stored seeded trace
        // replays to the play and each prefix replays to its own last fingerprint.
        var random = HueCompassRandom(seed: Self.seed)
        for _ in 0..<30 {
            let fixture: HueCompassFixture = Self.fixture(&random)
            let stored: Data = fixture.level.encoded()
            let back: HueCompassLevel = try HueCompassLevel.decode(stored)
            #expect(back == fixture.level && back.encoded() == stored)
            #expect(throws: HueCompassError.self) { try HueCompassLevel.decode(stored.prefix(stored.count - 1)) }
            let form: String = String(decoding: stored, as: UTF8.self)
            let key: String = "\"allowance\":\(fixture.level.allowance),"
            let other: Int = fixture.level.allowance == 24 ? 23 : fixture.level.allowance + 1
            let edited: String = form.replacingOccurrences(of: key, with: "\"allowance\":\(other),")
            #expect(edited != form)
            #expect(throws: HueCompassError.malformed("fingerprint")) { try HueCompassLevel.decode(Data(edited.utf8)) }
            let play: HueCompassPlay = try Self.randomPlay(fixture.level, steps: 24, random: &random)
            if play.records.isEmpty { continue }
            let saved: Data = try JSONEncoder().encode(play.records)
            let loaded: [HueCompassRecord] = try JSONDecoder().decode([HueCompassRecord].self, from: saved)
            #expect(loaded == play.records)
            let restored: HueCompassPlay = try HueCompassPlay.replay(level: back, records: loaded)
            #expect(restored == play && restored.fingerprint == play.fingerprint)
            let cut: Int = random.int(1...loaded.count)
            let partial: HueCompassPlay = try HueCompassPlay.replay(level: back, records: Array(loaded.prefix(cut)))
            #expect(partial.fingerprint == loaded[cut - 1].next)
            #expect(partial.records.count == cut)
        }
    }
}
