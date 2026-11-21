// HueCompassPlayTests — feature 331 (R02-G04-01) T-R02G0401-004 (FR-R02G0401-003 … 007; SC-R02G0401-001, 002, 004;
// clarifications Q3, Q4, Q5). Host checks of the play: for 500 seeded fixtures the known solution wins exactly at the
// selection and records the level's clues; every refusal (stage, stale fingerprint, range, nothing to undo or redo, in
// the order stage → stale → range) names its reason and leaves the play unchanged; a selection outside either
// tolerance fails with `selection`, a probe that spends the last unit fails with `probes`, a selection on the last unit
// is still judged by tolerance; undo restores every earlier fingerprint and bearing, redo re-applies, a new turn clears
// redo, a probe or selection clears both and undo and redo never change units or clues; 500 seeded action traces
// replay to an equal play with a chained record trace, and tampered traces are refused; the full stage machine table;
// the fingerprint against an independent statement of its bytes. Synthetic data, explicit types, plain loops, short
// runs. Fixture seed 2_331; trace seeds 2_331 + i.
import Testing
import VisualCoreMath
@testable import HueCompassCore

@Suite struct HueCompassPlayTests {
    /// The five events in a fixed order.
    static let events: [HueCompassEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    /// The 500 seeded fixtures (every 3rd with a tutorial), drawn once.
    static let pool: [HueCompassFixture] = {
        var fixtures: [HueCompassFixture] = []
        for index in 0..<500 { fixtures.append(HueCompassFixtures.fixture(index, tutorial: index % 3 == 0)) }
        return fixtures
    }()

    /// A hand-made level: target 10, start 50, bearing tolerance 1, band tolerance 0, offset 0, fog k mod 10.
    static func level(allowance: Int = 6, tutorial: Bool = false, bearingTolerance: Int = 1,
                      bandTolerance: Int = 0) throws -> HueCompassLevel {
        var fog: [Int] = []
        for k in 0..<96 { fog.append(k % 10) }
        return try HueCompassLevel(id: "hand", seed: 2_331, band: 1, offset: 0, fog: fog, target: 10, start: 50,
                                   bearingTolerance: bearingTolerance, bandTolerance: bandTolerance,
                                   allowance: allowance, tutorial: tutorial)
    }

    /// The error `body` throws, or nil.
    static func error(_ body: () throws(HueCompassError) -> Void) -> HueCompassError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// A play of `level` begun (and its tutorial dismissed) so it is `playing`.
    static func playing(_ level: HueCompassLevel) throws -> HueCompassPlay {
        var play: HueCompassPlay = HueCompassPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A play of the hand-made level (tutorial) in `stage`.
    static func play(in stage: HueCompassStage) throws -> HueCompassPlay {
        let level: HueCompassLevel = try Self.level(tutorial: true)
        var play: HueCompassPlay = HueCompassPlay(level: level)
        switch stage {
        case .loading:
            break
        case .tutorial:
            try play.handle(.begin)
        case .playing:
            try play.handle(.begin)
            try play.handle(.dismissTutorial)
            try play.apply(.turn(3), expecting: play.fingerprint)
        case .paused:
            play = try Self.play(in: .playing)
            try play.handle(.pause)
        case .won:
            play = try Self.play(in: .playing)
            try play.apply(.select(bearing: 10, band: level.targetBand), expecting: play.fingerprint)
        case .failed:
            play = try Self.play(in: .playing)
            try play.apply(.select(bearing: 40, band: level.targetBand), expecting: play.fingerprint)
        case .result:
            play = try Self.play(in: .won)
            try play.handle(.showResult)
        }
        #expect(play.stage == stage)
        return play
    }

    /// An independent statement of the fingerprint bytes.
    static func oracle(_ play: HueCompassPlay, failure: HueCompassFailure?) -> String {
        var bytes: [UInt8] = [1]
        for b in play.level.fingerprint.utf8 { bytes.append(b) }
        bytes.append(UInt8(play.bearing))
        bytes.append(UInt8(play.spent))
        for clue in play.clues {
            bytes.append(UInt8(clue.bearing))
            bytes.append(UInt8(clue.hueGap))
            bytes.append(UInt8(clue.depth / 256))
            bytes.append(UInt8(clue.depth % 256))
        }
        for b in play.stage.rawValue.utf8 { bytes.append(b) }
        if let failure { for b in failure.rawValue.utf8 { bytes.append(b) } }
        if let selection = play.selection {
            bytes.append(0)
            bytes.append(UInt8(selection.bearing))
            bytes.append(UInt8(selection.band))
        }
        return StableHash.sha256Hex(bytes)
    }

    // MARK: - SC-001: the known solution

    @Test func theKnownSolutionWinsExactlyAtTheSelection() throws {
        for fixture in Self.pool {
            let level: HueCompassLevel = fixture.level
            var play: HueCompassPlay = HueCompassPlay(level: level)
            try play.handle(.begin)
            if level.tutorial {
                #expect(play.stage == .tutorial)
                try play.handle(.dismissTutorial)
            }
            #expect(play.stage == .playing && play.bearing == level.start)
            var expectedClues: [HueCompassClue] = []
            for index in fixture.solution.indices {
                let action: HueCompassAction = fixture.solution[index]
                #expect(play.stage == .playing)
                if case .probe = action { expectedClues.append(level.clue(at: play.bearing)) }
                try play.apply(action, expecting: play.fingerprint)
                if index < fixture.solution.count - 1 {
                    #expect(play.stage == .playing && play.failure == nil)
                }
            }
            #expect(play.stage == .won && play.failure == nil, "fixture \(level.id)")
            #expect(play.clues == expectedClues)
            #expect(play.clues.count == 1 && play.clues[0] == level.clue(at: level.start))
            #expect(play.bearing == level.target && play.spent == 2)
            #expect(play.records.count == fixture.solution.count)
            try play.handle(.showResult)
            #expect(play.stage == .result)
        }
    }

    // MARK: - FR-005: refusals

    @Test func everyStageRefusesActionsOutsidePlayingWithoutChange() throws {
        let stages: [HueCompassStage] = [.loading, .tutorial, .paused, .won, .failed, .result]
        for stage in stages {
            var play: HueCompassPlay = try Self.play(in: stage)
            let copy: HueCompassPlay = play
            let current: String = play.fingerprint
            #expect(Self.error { () throws(HueCompassError) in try play.apply(.turn(1), expecting: current) } == .stage)
            #expect(Self.error { () throws(HueCompassError) in try play.apply(.probe, expecting: current) } == .stage)
            #expect(Self.error { () throws(HueCompassError) in
                try play.apply(.select(bearing: 10, band: 2), expecting: current)
            } == .stage)
            // Stage comes before stale and range.
            #expect(Self.error { () throws(HueCompassError) in try play.apply(.turn(0), expecting: "stale") } == .stage)
            #expect(Self.error { () throws(HueCompassError) in try play.undo() } == .stage)
            #expect(Self.error { () throws(HueCompassError) in try play.redo() } == .stage)
            #expect(play == copy, "stage \(stage)")
            #expect(!play.canUndo && !play.canRedo)
        }
    }

    @Test func staleAndRangeRefusalsInOrderWithoutChange() throws {
        var play: HueCompassPlay = try Self.playing(try Self.level())
        try play.apply(.turn(5), expecting: play.fingerprint)
        let copy: HueCompassPlay = play
        let current: String = play.fingerprint
        // Stale before range.
        #expect(Self.error { () throws(HueCompassError) in try play.apply(.turn(1), expecting: "x") } == .stale)
        #expect(Self.error { () throws(HueCompassError) in try play.apply(.turn(0), expecting: "x") } == .stale)
        #expect(Self.error { () throws(HueCompassError) in
            try play.apply(.probe, expecting: copy.records[0].previous)
        } == .stale)
        let range: HueCompassError = .action("range")
        let outOfRange: [HueCompassAction] = [.turn(0), .turn(49), .turn(-49), .select(bearing: 96, band: 0),
                                              .select(bearing: -1, band: 0), .select(bearing: 10, band: 24),
                                              .select(bearing: 10, band: -1)]
        for action in outOfRange {
            #expect(Self.error { () throws(HueCompassError) in try play.apply(action, expecting: current) } == range)
            #expect(!HueCompassPlay.inRange(action))
        }
        let inRange: [HueCompassAction] = [.turn(48), .turn(-48), .turn(1), .probe, .select(bearing: 0, band: 0),
                                           .select(bearing: 95, band: 23)]
        for action in inRange { #expect(HueCompassPlay.inRange(action)) }
        #expect(play == copy)
        // Nothing to redo with a fresh turn; nothing to undo on a fresh play.
        #expect(Self.error { () throws(HueCompassError) in try play.redo() } == .action("nothing-to-redo"))
        #expect(play == copy)
        var fresh: HueCompassPlay = try Self.playing(try Self.level())
        let freshCopy: HueCompassPlay = fresh
        #expect(Self.error { () throws(HueCompassError) in try fresh.undo() } == .action("nothing-to-undo"))
        #expect(Self.error { () throws(HueCompassError) in try fresh.redo() } == .action("nothing-to-redo"))
        #expect(fresh == freshCopy)
        #expect(HueCompassError.stage.reasonCode == "r02-g04.stage")
        #expect(HueCompassError.stale.reasonCode == "r02-g04.stale")
        #expect(range.reasonCode == "r02-g04.action")
    }

    // MARK: - SC-004: failures

    @Test func aSelectionOutsideEitherToleranceFails() throws {
        let level: HueCompassLevel = try Self.level()
        let band: Int = level.targetBand
        let cases: [(bearing: Int, band: Int, wins: Bool)] = [
            (10, band, true), (11, band, true), (9, band, true), (12, band, false), (8, band, false),
            (10, (band + 1) % 24, false), (10, (band + 23) % 24, false), (60, band, false),
        ]
        for c in cases {
            var play: HueCompassPlay = try Self.playing(level)
            try play.apply(.select(bearing: c.bearing, band: c.band), expecting: play.fingerprint)
            #expect(play.spent == 1 && play.clues.isEmpty)
            if c.wins {
                #expect(play.stage == .won && play.failure == nil)
            } else {
                #expect(play.stage == .failed && play.failure == .selection, "select \(c.bearing) \(c.band)")
            }
        }
        // A wider band tolerance accepts the neighbouring band.
        let wide: HueCompassLevel = try Self.level(bandTolerance: 1)
        var play: HueCompassPlay = try Self.playing(wide)
        try play.apply(.select(bearing: 10, band: (wide.targetBand + 1) % 24), expecting: play.fingerprint)
        #expect(play.stage == .won)
    }

    @Test func theLastProbeFailsAndTheLastSelectionIsJudged() throws {
        for allowance in HueCompassLevel.allowances {
            let level: HueCompassLevel = try Self.level(allowance: allowance)
            var play: HueCompassPlay = try Self.playing(level)
            for k in 1..<allowance {
                try play.apply(.probe, expecting: play.fingerprint)
                #expect(play.stage == .playing && play.spent == k && play.remaining == allowance - k)
            }
            let beforeLast: HueCompassPlay = play
            try play.apply(.probe, expecting: play.fingerprint)
            #expect(play.stage == .failed && play.failure == .probes && play.remaining == 0)
            #expect(play.clues.count == allowance)
            var win: HueCompassPlay = beforeLast
            try win.apply(.select(bearing: 10, band: level.targetBand), expecting: win.fingerprint)
            #expect(win.stage == .won && win.failure == nil && win.remaining == 0)
            var miss: HueCompassPlay = beforeLast
            try miss.apply(.select(bearing: 30, band: level.targetBand), expecting: miss.fingerprint)
            #expect(miss.stage == .failed && miss.failure == .selection)
        }
    }

    // MARK: - FR-006: undo and redo

    @Test func undoAndRedoRestoreExactStates() throws {
        for fixture in Self.pool.prefix(100) {
            var play: HueCompassPlay = try Self.playing(fixture.level)
            try play.apply(.probe, expecting: play.fingerprint)
            var random: HueCompassRandom = HueCompassRandom(seed: fixture.level.seed)
            var fingerprints: [String] = [play.fingerprint]
            var bearings: [Int] = [play.bearing]
            let spent: Int = play.spent
            let clues: [HueCompassClue] = play.clues
            for _ in 0..<8 {
                var steps: Int = random.int(-48...47)
                if steps >= 0 { steps += 1 }
                try play.apply(.turn(steps), expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                bearings.append(play.bearing)
            }
            for index in stride(from: 7, through: 0, by: -1) {
                try play.undo()
                #expect(play.fingerprint == fingerprints[index] && play.bearing == bearings[index])
                #expect(play.spent == spent && play.clues == clues)
            }
            #expect(!play.canUndo && play.canRedo)
            for index in 1...8 {
                try play.redo()
                #expect(play.fingerprint == fingerprints[index] && play.bearing == bearings[index])
                #expect(play.spent == spent && play.clues == clues)
            }
            #expect(play.canUndo && !play.canRedo)
            // A new turn after an undo clears redo.
            try play.undo()
            try play.undo()
            #expect(play.canRedo)
            try play.apply(.turn(1), expecting: play.fingerprint)
            #expect(!play.canRedo && play.canUndo)
            #expect(Self.error { () throws(HueCompassError) in try play.redo() } == .action("nothing-to-redo"))
            // A probe clears both stacks (when it does not spend the last unit).
            if play.remaining > 1 {
                try play.undo()
                #expect(play.canUndo && play.canRedo)
                try play.apply(.probe, expecting: play.fingerprint)
                #expect(play.stage == .playing && !play.canUndo && !play.canRedo)
                #expect(Self.error { () throws(HueCompassError) in try play.undo() } == .action("nothing-to-undo"))
                #expect(Self.error { () throws(HueCompassError) in try play.redo() } == .action("nothing-to-redo"))
            }
        }
        // A selection clears both stacks (and leaves playing).
        var play: HueCompassPlay = try Self.playing(try Self.level())
        try play.apply(.turn(4), expecting: play.fingerprint)
        try play.apply(.turn(4), expecting: play.fingerprint)
        try play.undo()
        #expect(play.canUndo && play.canRedo)
        try play.apply(.select(bearing: 30, band: 0), expecting: play.fingerprint)
        #expect(!play.canUndo && !play.canRedo)
        // Undo and redo records carry the reverse and the re-applied turn.
        var turns: HueCompassPlay = try Self.playing(try Self.level())
        try turns.apply(.turn(-7), expecting: turns.fingerprint)
        try turns.undo()
        try turns.redo()
        #expect(turns.records[1].kind == .undo && turns.records[1].action == .turn(7))
        #expect(turns.records[2].kind == .redo && turns.records[2].action == .turn(-7))
        #expect(turns.bearing == 43 && turns.spent == 0)
    }

    // MARK: - SC-002: seeded traces and replay

    /// A seeded trace of at most 30 attempted actions on `fixture`; refused actions are skipped (and leave no change).
    static func trace(_ fixture: HueCompassFixture, seed: UInt64) throws -> HueCompassPlay {
        var random: HueCompassRandom = HueCompassRandom(seed: seed)
        var play: HueCompassPlay = try Self.playing(fixture.level)
        for _ in 0..<30 where play.stage == .playing {
            let copy: HueCompassPlay = play
            let pick: Int = random.int(0...99)
            let refusal: HueCompassError?
            if pick < 50 {
                let steps: Int = random.int(-50...50)
                refusal = Self.error { () throws(HueCompassError) in
                    try play.apply(.turn(steps), expecting: play.fingerprint)
                }
            } else if pick < 65 {
                refusal = Self.error { () throws(HueCompassError) in try play.undo() }
            } else if pick < 80 {
                refusal = Self.error { () throws(HueCompassError) in try play.redo() }
            } else if pick < 94 {
                refusal = Self.error { () throws(HueCompassError) in
                    try play.apply(.probe, expecting: play.fingerprint)
                }
            } else {
                let bearing: Int = random.int(0...95)
                let band: Int = random.int(0...23)
                refusal = Self.error { () throws(HueCompassError) in
                    try play.apply(.select(bearing: bearing, band: band), expecting: play.fingerprint)
                }
            }
            if refusal != nil {
                #expect(play == copy)
            } else {
                #expect(play.records.count == copy.records.count + 1)
            }
        }
        return play
    }

    @Test func seededTracesReplayAndTamperedTracesAreRefused() throws {
        var outcomes: Set<HueCompassStage> = []
        var kinds: Set<HueCompassRecordKind> = []
        for index in Self.pool.indices {
            let fixture: HueCompassFixture = Self.pool[index]
            let level: HueCompassLevel = fixture.level
            let play: HueCompassPlay = try Self.trace(fixture, seed: 2_331 + UInt64(index))
            let records: [HueCompassRecord] = play.records
            outcomes.insert(play.stage)
            for record in records { kinds.insert(record.kind) }
            for i in records.indices {
                #expect(records[i].tick == i && records[i].seed == level.seed && records[i].schema == 1)
                if i + 1 < records.count { #expect(records[i].next == records[i + 1].previous) }
            }
            if let last = records.last { #expect(last.next == play.fingerprint) }
            let replayed: HueCompassPlay = try HueCompassPlay.replay(level: level, records: records)
            #expect(replayed == play, "trace \(index)")
            #expect(replayed.fingerprint == play.fingerprint)
            guard !records.isEmpty else { continue }
            let k: Int = Int(level.seed % UInt64(records.count))
            let r: HueCompassRecord = records[k]
            // A changed previous fingerprint.
            var changedPrevious: [HueCompassRecord] = records
            changedPrevious[k] = HueCompassRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                                  action: r.action, previous: String(repeating: "0", count: 64),
                                                  next: r.next)
            let previousError: HueCompassError? = Self.error { () throws(HueCompassError) in
                _ = try HueCompassPlay.replay(level: level, records: changedPrevious)
            }
            #expect(previousError == .stale || previousError == .malformed("record \(k)"), "trace \(index)")
            // A changed action: another turn, a turn for a probe, another selection (the fingerprint pins the selected
            // bearing and band, so even a selection with the same verdict is caught).
            let changed: HueCompassAction
            switch r.action {
            case .turn(let steps): changed = .turn(steps == 1 ? -1 : 1)
            case .probe: changed = .turn(1)
            case .select(let bearing, let band): changed = .select(bearing: bearing, band: (band + 1) % 24)
            }
            var changedAction: [HueCompassRecord] = records
            changedAction[k] = HueCompassRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind,
                                                action: changed, previous: r.previous, next: r.next)
            let actionError: HueCompassError? = Self.error { () throws(HueCompassError) in
                _ = try HueCompassPlay.replay(level: level, records: changedAction)
            }
            #expect(actionError == .malformed("record \(k)"), "trace \(index)")
            // A dropped record whose successor names its previous fingerprint.
            var dropAt: Int? = nil
            for i in 0..<(records.count - 1) where dropAt == nil {
                switch records[i + 1].kind {
                case .turn, .probe, .select: dropAt = i
                case .undo, .redo: break
                }
            }
            if let dropAt {
                var dropped: [HueCompassRecord] = records
                dropped.remove(at: dropAt)
                let droppedError: HueCompassError? = Self.error { () throws(HueCompassError) in
                    _ = try HueCompassPlay.replay(level: level, records: dropped)
                }
                #expect(droppedError == .stale || droppedError == .malformed("record \(dropAt)"), "trace \(index)")
            }
        }
        #expect(outcomes.contains(.won) && outcomes.contains(.failed) && outcomes.contains(.playing))
        #expect(kinds.count == 5)
    }

    // MARK: - FR-007: the stage machine

    @Test func theFullStageTable() throws {
        let expected: [HueCompassStage: [HueCompassEvent: HueCompassStage]] = [
            .loading: [.begin: .tutorial],
            .tutorial: [.dismissTutorial: .playing],
            .playing: [.pause: .paused],
            .paused: [.resume: .playing],
            .won: [.showResult: .result],
            .failed: [.showResult: .result],
            .result: [:],
        ]
        for stage in HueCompassStage.allCases {
            for event in Self.events {
                var play: HueCompassPlay = try Self.play(in: stage)
                let copy: HueCompassPlay = play
                if let next = expected[stage]?[event] {
                    try play.handle(event)
                    #expect(play.stage == next, "\(stage) \(event)")
                    #expect(play.records == copy.records && play.bearing == copy.bearing && play.spent == copy.spent)
                } else {
                    #expect(Self.error { () throws(HueCompassError) in try play.handle(event) } == .stage,
                            "\(stage) \(event)")
                    #expect(play == copy)
                }
            }
        }
        // A level without a tutorial goes straight from loading to playing.
        var plain: HueCompassPlay = HueCompassPlay(level: try Self.level())
        #expect(plain.stage == .loading && plain.bearing == 50 && plain.spent == 0 && plain.records.isEmpty)
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
        // Pause and resume keep the undo stack.
        var paused: HueCompassPlay = try Self.play(in: .playing)
        try paused.handle(.pause)
        #expect(!paused.canUndo)
        try paused.handle(.resume)
        #expect(paused.canUndo)
    }

    // MARK: - The fingerprint

    @Test func theFingerprintFollowsEveryPart() throws {
        let level: HueCompassLevel = try Self.level()
        let fresh: HueCompassPlay = try Self.playing(level)
        #expect(fresh.fingerprint == Self.oracle(fresh, failure: nil))
        #expect(fresh.fingerprint == (try Self.playing(level)).fingerprint)
        var seen: Set<String> = [fresh.fingerprint]
        // Bearing.
        var turned: HueCompassPlay = fresh
        try turned.apply(.turn(1), expecting: turned.fingerprint)
        #expect(seen.insert(turned.fingerprint).inserted && turned.fingerprint == Self.oracle(turned, failure: nil))
        // Spent and clues.
        var probed: HueCompassPlay = turned
        try probed.apply(.probe, expecting: probed.fingerprint)
        #expect(seen.insert(probed.fingerprint).inserted && probed.fingerprint == Self.oracle(probed, failure: nil))
        var probedTwice: HueCompassPlay = probed
        try probedTwice.apply(.probe, expecting: probedTwice.fingerprint)
        #expect(seen.insert(probedTwice.fingerprint).inserted)
        // Clues alone: the same bearing and spent, different clue bearings.
        var a: HueCompassPlay = fresh
        try a.apply(.probe, expecting: a.fingerprint)
        try a.apply(.turn(1), expecting: a.fingerprint)
        var b: HueCompassPlay = fresh
        try b.apply(.turn(1), expecting: b.fingerprint)
        try b.apply(.probe, expecting: b.fingerprint)
        #expect(a.bearing == b.bearing && a.spent == b.spent && a.stage == b.stage && a.clues != b.clues)
        #expect(a.fingerprint != b.fingerprint)
        // Stage.
        var paused: HueCompassPlay = turned
        try paused.handle(.pause)
        #expect(seen.insert(paused.fingerprint).inserted && paused.fingerprint == Self.oracle(paused, failure: nil))
        // Failure: the failed play's fingerprint includes its reason.
        var failed: HueCompassPlay = fresh
        try failed.apply(.select(bearing: 30, band: 0), expecting: failed.fingerprint)
        #expect(failed.fingerprint == Self.oracle(failed, failure: .selection))
        #expect(failed.fingerprint != Self.oracle(failed, failure: nil))
        #expect(failed.fingerprint != Self.oracle(failed, failure: .probes))
        var won: HueCompassPlay = fresh
        try won.apply(.select(bearing: 10, band: level.targetBand), expecting: won.fingerprint)
        #expect(won.fingerprint == Self.oracle(won, failure: nil) && won.fingerprint != failed.fingerprint)
        var lastProbe: HueCompassPlay = try Self.playing(try Self.level(allowance: 2))
        try lastProbe.apply(.probe, expecting: lastProbe.fingerprint)
        try lastProbe.apply(.probe, expecting: lastProbe.fingerprint)
        #expect(lastProbe.fingerprint == Self.oracle(lastProbe, failure: .probes))
        // Equal plays, equal fingerprints; a different level, a different fingerprint.
        var again: HueCompassPlay = fresh
        try again.apply(.turn(1), expecting: again.fingerprint)
        #expect(again == turned && again.fingerprint == turned.fingerprint)
        let other: HueCompassPlay = try Self.playing(try Self.level(allowance: 7))
        #expect(other.fingerprint != fresh.fingerprint)
        #expect(fresh.fingerprint.count == 64)
    }
}
