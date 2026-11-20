// LissajousLabyrinthPlayTests — feature 311 (R02-G02-01) T-R02G0201-004 (FR-R02G0201-003, 004, 005, 006;
// SC-R02G0201-002, 003; clarifications Q3, Q4). 500 seeded traces replay to identical records, fingerprints and outcome;
// undo of every action restores the exact earlier state; 1,000 seeded refused attempts leave the play unchanged; the safe
// dials win; spending the allowance without a win fails with the lap verdict; the full stage machine table; no action
// after the end; tutorial levels pass through the tutorial stage. The seeded fixtures are drawn once into a pool (their
// generation samples the safe lap and is the expensive part). Test data uses explicit types and plain loops (CI
// type-check rule).
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreMath
import VisualCoreSimulation

@Suite struct LissajousLabyrinthPlayTests {
    /// The five events in a fixed order.
    static let events: [LissajousLabyrinthEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    /// 48 seeded fixtures with small allowances 3 … 10 (so traces reach both outcomes in few actions).
    static let pool: [LissajousLabyrinthFixture] = {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        var fixtures: [LissajousLabyrinthFixture] = []
        for index in 0..<48 {
            fixtures.append(LissajousLabyrinthFixture.next(&random, allowance: 3 + index % 8))
        }
        return fixtures
    }()

    /// A copy of the pool whose levels own fresh storage (decoded from their stored form), so parallel test cases do not
    /// contend on the reference counts of shared arrays.
    static func freshPool() -> [LissajousLabyrinthFixture] {
        var fixtures: [LissajousLabyrinthFixture] = []
        for fixture in pool {
            let level: LissajousLabyrinthLevel = try! LissajousLabyrinthLevel.decode(fixture.level.encoded())
            fixtures.append(LissajousLabyrinthFixture(level: level, safe: fixture.safe))
        }
        return fixtures
    }

    /// A seeded fixture from `pool`.
    static func fixture(_ random: inout SeededRandom,
                        _ pool: [LissajousLabyrinthFixture] = Self.pool) -> LissajousLabyrinthFixture {
        pool[random.int(0...(pool.count - 1))]
    }

    /// A seeded fixture from the pool whose safe dials can be reached by ``winPlan(_:)``.
    static func winnable(_ random: inout SeededRandom,
                         _ pool: [LissajousLabyrinthFixture] = Self.pool) -> LissajousLabyrinthFixture {
        let offset: Int = random.int(0...(pool.count - 1))
        for k in 0..<pool.count {
            let fixture: LissajousLabyrinthFixture = pool[(offset + k) % pool.count]
            if winPlan(fixture) != nil { return fixture }
        }
        fatalError("no winnable fixture in the pool")
    }

    /// The fixture's level with a tutorial.
    static func tutorial(_ level: LissajousLabyrinthLevel) -> LissajousLabyrinthLevel {
        try! LissajousLabyrinthLevel(id: level.id, seed: level.seed, band: level.band, amplitudes: level.amplitudes,
                                     frequencyC: level.frequencyC, start: level.start, checkpoints: level.checkpoints,
                                     obstacles: level.obstacles, allowance: level.allowance, tutorial: true)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func started(_ level: LissajousLabyrinthLevel) -> LissajousLabyrinthPlay {
        var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: level)
        try! play.handle(.begin)
        if level.tutorial { try! play.handle(.dismissTutorial) }
        return play
    }

    /// The actions that turn the start dials into the safe dials, one per differing dial: the phases first, then the
    /// frequencies in an order whose intermediate setting is coprime; nil when no such order exists or the actions
    /// exceed the allowance.
    static func winPlan(_ fixture: LissajousLabyrinthFixture) -> [LissajousLabyrinthAction]? {
        let start: LissajousLabyrinthDials = fixture.level.start
        let safe: LissajousLabyrinthDials = fixture.safe
        var actions: [LissajousLabyrinthAction] = []
        let phases: [LissajousLabyrinthDial] = [.phaseA, .phaseC]
        for dial in phases where start[dial] != safe[dial] {
            actions.append(LissajousLabyrinthAction(dial: dial, value: safe[dial]))
        }
        let orders: [[LissajousLabyrinthDial]] = [[.frequencyA, .frequencyB], [.frequencyB, .frequencyA]]
        var chosen: [LissajousLabyrinthDial]? = nil
        for order in orders {
            var dials: LissajousLabyrinthDials = start
            var fine: Bool = true
            for dial in order where dials[dial] != safe[dial] {
                dials[dial] = safe[dial]
                if !dials.isValid { fine = false }
            }
            if fine {
                chosen = order
                break
            }
        }
        guard let order = chosen else { return nil }
        for dial in order where start[dial] != safe[dial] {
            actions.append(LissajousLabyrinthAction(dial: dial, value: safe[dial]))
        }
        return actions.count <= fixture.level.allowance ? actions : nil
    }

    /// Applies the win plan while the play is playing.
    static func win(_ play: inout LissajousLabyrinthPlay, _ fixture: LissajousLabyrinthFixture) {
        guard let plan = winPlan(fixture) else {
            Issue.record("no win plan")
            return
        }
        for action in plan {
            guard play.stage == .playing else { return }
            try! play.apply(action, expecting: play.fingerprint)
        }
    }

    /// Every action that changes one dial to another in-range value with coprime frequencies, in a fixed order.
    static func validActions(_ dials: LissajousLabyrinthDials) -> [LissajousLabyrinthAction] {
        var actions: [LissajousLabyrinthAction] = []
        for dial in LissajousLabyrinthDial.allCases {
            for value in dial.range where value != dials[dial] {
                var changed: LissajousLabyrinthDials = dials
                changed[dial] = value
                if changed.isValid { actions.append(LissajousLabyrinthAction(dial: dial, value: value)) }
            }
        }
        return actions
    }

    /// A seeded valid action whose lap does not win, or nil when every valid action wins.
    static func losingAction(_ play: LissajousLabyrinthPlay,
                             _ random: inout SeededRandom) -> LissajousLabyrinthAction? {
        let actions: [LissajousLabyrinthAction] = validActions(play.dials)
        let offset: Int = random.int(0...(actions.count - 1))
        for k in 0..<actions.count {
            let action: LissajousLabyrinthAction = actions[(offset + k) % actions.count]
            var changed: LissajousLabyrinthDials = play.dials
            changed[action.dial] = action.value
            if LissajousLabyrinthLap.verdict(changed, level: play.level) != .won { return action }
        }
        return nil
    }

    /// Spends the allowance with actions that do not win.
    static func spend(_ play: inout LissajousLabyrinthPlay, _ random: inout SeededRandom) {
        while play.stage == .playing {
            guard let action = losingAction(play, &random) else {
                Issue.record("no losing action")
                return
            }
            try! play.apply(action, expecting: play.fingerprint)
        }
    }

    /// A play of `level` (whose fixture is `fixture`) in `stage`; the tutorial stage needs a tutorial level and the won
    /// and result stages a winnable fixture.
    static func play(in stage: LissajousLabyrinthStage, _ level: LissajousLabyrinthLevel,
                     _ fixture: LissajousLabyrinthFixture, _ random: inout SeededRandom) -> LissajousLabyrinthPlay {
        var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: level)
        switch stage {
        case .loading:
            break
        case .tutorial:
            try! play.handle(.begin)
        case .playing:
            play = started(level)
        case .paused:
            play = started(level)
            try! play.handle(.pause)
        case .won:
            play = started(level)
            win(&play, fixture)
        case .failed:
            play = started(level)
            spend(&play, &random)
        case .result:
            play = started(level)
            win(&play, fixture)
            try! play.handle(.showResult)
        }
        #expect(play.stage == stage)
        return play
    }

    /// The seeded random of one chunk of a split test (chunks run in parallel; each stays well under 10 s in debug).
    static func chunkRandom(_ chunk: Int) -> SeededRandom {
        SeededRandom(seed: 2_314 + UInt64(chunk) * 1_000)
    }

    /// The error an action throws on a copy of `play`, and the copy after it.
    static func attempt(_ play: LissajousLabyrinthPlay,
                        _ action: (inout LissajousLabyrinthPlay) throws(LissajousLabyrinthError) -> Void)
        -> (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay) {
        var copy: LissajousLabyrinthPlay = play
        do {
            try action(&copy)
            return (nil, copy)
        } catch {
            return (error, copy)
        }
    }

    @Test func startingPlay() {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        let fixture: LissajousLabyrinthFixture = Self.fixture(&random)
        let play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: fixture.level)
        #expect(LissajousLabyrinthPlay.schema == 1)
        #expect(play.stage == .loading)
        #expect(play.dials == fixture.level.start)
        #expect(play.spent == 0)
        #expect(play.records.isEmpty)
        #expect(play.failure == nil)
        #expect(!play.canUndo)
        #expect(!play.canRedo)
        #expect(play.fingerprint.count == 64)
    }

    @Test func fingerprintLayout() {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        let fixture: LissajousLabyrinthFixture = Self.fixture(&random)
        let play: LissajousLabyrinthPlay = Self.started(fixture.level)
        var bytes: [UInt8] = [UInt8(LissajousLabyrinthPlay.schema)]
        bytes.append(contentsOf: Array(fixture.level.fingerprint.utf8))
        bytes.append(UInt8(play.dials.frequencyA))
        bytes.append(UInt8(play.dials.frequencyB))
        bytes.append(UInt8(play.dials.phaseA))
        bytes.append(UInt8(play.dials.phaseC))
        bytes.append(0)
        bytes.append(contentsOf: Array("playing".utf8))
        #expect(play.fingerprint == StableHash.sha256Hex(bytes))
        let loading: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: fixture.level)
        #expect(loading.fingerprint != play.fingerprint)
    }

    /// 500 traces in ten chunks of 50.
    @Test(arguments: 0..<10) func tracesReplay(chunk: Int) throws {
        var random: SeededRandom = Self.chunkRandom(chunk)
        let pool: [LissajousLabyrinthFixture] = Self.freshPool()
        var won: Int = 0
        var failed: Int = 0
        var undos: Int = 0
        var redos: Int = 0
        var pauses: Int = 0
        for _ in 0..<50 {
            let fixture: LissajousLabyrinthFixture = Self.fixture(&random, pool)
            var play: LissajousLabyrinthPlay = Self.started(fixture.level)
            let length: Int = random.int(1...16)
            var steps: Int = 0
            while play.stage == .playing && steps < length {
                steps += 1
                let choice: Int = random.int(0...10)
                if choice == 8 && play.canUndo {
                    try play.undo()
                    undos += 1
                } else if choice == 9 && play.canRedo {
                    try play.redo()
                    redos += 1
                } else if choice == 10 {
                    try play.handle(.pause)
                    try play.handle(.resume)
                    pauses += 1
                } else {
                    let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[random.int(0...3)]
                    let preferred: Int = choice < 3 ? fixture.safe[dial] : random.int(dial.range)
                    // The first valid value from the preferred one onwards (a frequency of 1 is always valid).
                    let count: Int = dial.range.count
                    var value: Int = -1
                    for k in 0..<count {
                        let candidate: Int = dial.range.lowerBound
                            + (preferred - dial.range.lowerBound + k) % count
                        var changed: LissajousLabyrinthDials = play.dials
                        changed[dial] = candidate
                        if candidate != play.dials[dial] && changed.isValid {
                            value = candidate
                            break
                        }
                    }
                    let action: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: dial, value: value)
                    try play.apply(action, expecting: play.fingerprint)
                }
            }
            if play.stage == .won { won += 1 }
            if play.stage == .failed {
                failed += 1
                #expect(play.failure == LissajousLabyrinthLap.verdict(play.dials, level: fixture.level))
            }
            // The chain of records links every fingerprint.
            var previous: String = Self.started(fixture.level).fingerprint
            for index in play.records.indices {
                let record: LissajousLabyrinthRecord = play.records[index]
                #expect(record.tick == index)
                #expect(record.previous == previous)
                #expect(record.seed == fixture.level.seed)
                #expect(record.schema == LissajousLabyrinthPlay.schema)
                previous = record.next
            }
            #expect(previous == play.fingerprint)
            let replayed: LissajousLabyrinthPlay = try LissajousLabyrinthPlay.replay(level: fixture.level,
                                                                                     records: play.records)
            #expect(replayed == play)
            #expect(replayed.fingerprint == play.fingerprint)
            #expect(replayed.records == play.records)
            #expect(replayed.stage == play.stage)
            #expect(replayed.failure == play.failure)
        }
        #expect(won > 0)
        #expect(failed > 0)
        #expect(undos > 0)
        #expect(redos > 0)
        #expect(pauses > 0)
    }

    @Test func damagedTraceIsRefused() throws {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        let fixture: LissajousLabyrinthFixture = Self.fixture(&random)
        var play: LissajousLabyrinthPlay = Self.started(fixture.level)
        let action: LissajousLabyrinthAction = try #require(Self.losingAction(play, &random))
        try play.apply(action, expecting: play.fingerprint)
        try play.undo()
        let first: LissajousLabyrinthRecord = play.records[1]
        let edited: LissajousLabyrinthRecord = LissajousLabyrinthRecord(
            schema: first.schema, seed: first.seed, tick: first.tick, kind: first.kind, dial: first.dial,
            value: first.value, previous: first.previous, next: "0")
        var records: [LissajousLabyrinthRecord] = play.records
        records[1] = edited
        #expect(throws: LissajousLabyrinthError.malformed("record 1")) {
            _ = try LissajousLabyrinthPlay.replay(level: fixture.level, records: records)
        }
    }

    /// 200 plays in five chunks of 40.
    @Test(arguments: 0..<5) func undoRestoresEveryEarlierState(chunk: Int) throws {
        var random: SeededRandom = Self.chunkRandom(chunk)
        let pool: [LissajousLabyrinthFixture] = Self.freshPool()
        for _ in 0..<40 {
            let fixture: LissajousLabyrinthFixture = Self.fixture(&random, pool)
            var play: LissajousLabyrinthPlay = Self.started(fixture.level)
            var dials: [LissajousLabyrinthDials] = []
            var spent: [Int] = []
            var prints: [String] = []
            let count: Int = random.int(1...(fixture.level.allowance - 1))
            for _ in 0..<count {
                guard let action = Self.losingAction(play, &random) else { break }
                dials.append(play.dials)
                spent.append(play.spent)
                prints.append(play.fingerprint)
                try play.apply(action, expecting: play.fingerprint)
                #expect(play.stage == .playing)
                // An immediate undo restores the state before this action.
                let check: (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay) = Self.attempt(play) {
                    p throws(LissajousLabyrinthError) in try p.undo()
                }
                #expect(check.error == nil)
                #expect(check.play.dials == dials[dials.count - 1])
                #expect(check.play.spent == spent[spent.count - 1])
                #expect(check.play.fingerprint == prints[prints.count - 1])
            }
            // Undo every action in turn, then redo every one.
            let end: LissajousLabyrinthDials = play.dials
            let endPrint: String = play.fingerprint
            var index: Int = dials.count - 1
            while index >= 0 {
                try play.undo()
                #expect(play.dials == dials[index])
                #expect(play.spent == spent[index])
                #expect(play.fingerprint == prints[index])
                index -= 1
            }
            #expect(!play.canUndo)
            #expect(play.spent == 0)
            #expect(play.dials == fixture.level.start)
            while play.canRedo { try play.redo() }
            #expect(play.dials == end)
            #expect(play.fingerprint == endPrint)
            // A new action clears the redo stack.
            if play.canUndo {
                try play.undo()
                #expect(play.canRedo)
                if let action = Self.losingAction(play, &random) {
                    try play.apply(action, expecting: play.fingerprint)
                    #expect(!play.canRedo)
                }
            }
        }
    }

    /// 1,000 refused attempts in ten chunks of 100; the eleven kinds take turns.
    @Test(arguments: 0..<10) func refusedAttemptsChangeNothing(chunk: Int) {
        var random: SeededRandom = Self.chunkRandom(chunk)
        let pool: [LissajousLabyrinthFixture] = Self.freshPool()
        for attempt in 0..<100 {
            let kind: Int = (chunk * 100 + attempt) % 11
            var fixture: LissajousLabyrinthFixture = Self.fixture(&random, pool)
            var play: LissajousLabyrinthPlay = Self.started(fixture.level)
            // A few accepted actions first, so refusals happen in varied states.
            let warm: Int = random.int(0...min(3, fixture.level.allowance - 2))
            for _ in 0..<warm {
                if let action = Self.losingAction(play, &random) {
                    try! play.apply(action, expecting: play.fingerprint)
                }
            }
            let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[random.int(0...3)]
            let current: Int = play.dials[dial]
            var expected: LissajousLabyrinthError = .stage
            var result: (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay)
            switch kind {
            case 0: // out of range
                let values: [Int] = [dial.range.lowerBound - 1, dial.range.upperBound + 1, -100, 100]
                let action: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: dial,
                                                                                value: values[random.int(0...3)])
                expected = .move("range")
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in
                    try p.apply(action, expecting: p.fingerprint)
                }
            case 1: // no change
                let action: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: dial, value: current)
                expected = .move("no-change")
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in
                    try p.apply(action, expecting: p.fingerprint)
                }
            case 2: // frequencies not coprime
                var candidates: [LissajousLabyrinthAction] = []
                let frequencies: [LissajousLabyrinthDial] = [.frequencyA, .frequencyB]
                for frequency in frequencies {
                    for value in frequency.range where value != play.dials[frequency] {
                        var changed: LissajousLabyrinthDials = play.dials
                        changed[frequency] = value
                        if !changed.isValid {
                            candidates.append(LissajousLabyrinthAction(dial: frequency, value: value))
                        }
                    }
                }
                if candidates.isEmpty {
                    // Both frequencies are 1: set one to 2 first, then 4 … 8 even values clash with it.
                    let two: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: .frequencyA, value: 2)
                    if play.spent + 1 < play.level.allowance {
                        try! play.apply(two, expecting: play.fingerprint)
                    }
                    if play.stage == .playing && play.dials.frequencyA == 2 {
                        candidates.append(LissajousLabyrinthAction(dial: .frequencyB, value: 4))
                    }
                }
                if candidates.isEmpty {
                    expected = .stage
                    play = Self.play(in: .paused, fixture.level, fixture, &random)
                    let other: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: .phaseA,
                                                                                   value: (play.dials.phaseA + 1) % 16)
                    result = Self.attempt(play) { p throws(LissajousLabyrinthError) in
                        try p.apply(other, expecting: p.fingerprint)
                    }
                } else {
                    let action: LissajousLabyrinthAction = candidates[random.int(0...(candidates.count - 1))]
                    expected = .move("not-coprime")
                    result = Self.attempt(play) { p throws(LissajousLabyrinthError) in
                        try p.apply(action, expecting: p.fingerprint)
                    }
                }
            case 3: // over the allowance: the allowance is spent, so the play has failed and refuses every action
                Self.spend(&play, &random)
                #expect(play.stage == .failed)
                #expect(play.spent == play.level.allowance)
                let actions: [LissajousLabyrinthAction] = Self.validActions(play.dials)
                let action: LissajousLabyrinthAction = actions[random.int(0...(actions.count - 1))]
                expected = .stage
                if random.int(0...1) == 0 {
                    result = Self.attempt(play) { p throws(LissajousLabyrinthError) in
                        try p.apply(action, expecting: p.fingerprint)
                    }
                } else {
                    result = Self.attempt(play) { p throws(LissajousLabyrinthError) in try p.redo() }
                }
            case 4: // wrong stage: loading, tutorial, paused, won, failed or result
                let stages: [LissajousLabyrinthStage] = [.loading, .tutorial, .paused, .won, .failed, .result]
                let stage: LissajousLabyrinthStage = stages[random.int(0...5)]
                if stage == .won || stage == .result { fixture = Self.winnable(&random, pool) }
                let level: LissajousLabyrinthLevel = stage == .tutorial ? Self.tutorial(fixture.level) : fixture.level
                play = Self.play(in: stage, level, fixture, &random)
                let actions: [LissajousLabyrinthAction] = Self.validActions(play.dials)
                let action: LissajousLabyrinthAction = actions[random.int(0...(actions.count - 1))]
                expected = .stage
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in
                    try p.apply(action, expecting: p.fingerprint)
                }
            case 5: // undo in a wrong stage
                let stages: [LissajousLabyrinthStage] = [.loading, .paused, .failed]
                play = Self.play(in: stages[random.int(0...2)], fixture.level, fixture, &random)
                expected = .stage
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in try p.undo() }
            case 6: // redo in a wrong stage
                let stages: [LissajousLabyrinthStage] = [.loading, .paused, .failed]
                play = Self.play(in: stages[random.int(0...2)], fixture.level, fixture, &random)
                expected = .stage
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in try p.redo() }
            case 7: // stale fingerprint
                let actions: [LissajousLabyrinthAction] = Self.validActions(play.dials)
                let action: LissajousLabyrinthAction = actions[random.int(0...(actions.count - 1))]
                let stale: String = random.int(0...1) == 0 ? LissajousLabyrinthPlay(level: fixture.level).fingerprint
                    : String(repeating: "0", count: 64)
                expected = .stale
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in try p.apply(action, expecting: stale) }
            case 8: // nothing to undo
                play = Self.started(fixture.level)
                expected = .move("nothing-to-undo")
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in try p.undo() }
            case 9: // nothing to redo
                expected = .move("nothing-to-redo")
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in try p.redo() }
            default: // an event the stage does not allow
                play = Self.play(in: .paused, fixture.level, fixture, &random)
                let events: [LissajousLabyrinthEvent] = [.begin, .dismissTutorial, .pause, .showResult]
                let event: LissajousLabyrinthEvent = events[random.int(0...3)]
                expected = .stage
                result = Self.attempt(play) { p throws(LissajousLabyrinthError) in try p.handle(event) }
            }
            #expect(result.error == expected)
            #expect(result.play == play)
            #expect(result.play.fingerprint == play.fingerprint)
        }
    }

    @Test func safeDialsWin() {
        var winners: Int = 0
        for fixture in Self.pool {
            guard Self.winPlan(fixture) != nil else { continue }
            winners += 1
            var play: LissajousLabyrinthPlay = Self.started(fixture.level)
            Self.win(&play, fixture)
            #expect(play.stage == .won)
            #expect(play.spent <= 4)
            #expect(play.spent <= fixture.level.allowance)
            #expect(play.failure == nil)
            #expect(LissajousLabyrinthLap.verdict(play.dials, level: fixture.level) == .won)
            #expect(play.records.last?.next == play.fingerprint)
        }
        #expect(winners >= Self.pool.count / 3)
    }

    /// 100 plays in two chunks of 50.
    @Test(arguments: 0..<2) func spendingTheAllowanceFails(chunk: Int) {
        var random: SeededRandom = Self.chunkRandom(chunk)
        let pool: [LissajousLabyrinthFixture] = Self.freshPool()
        for _ in 0..<50 {
            let fixture: LissajousLabyrinthFixture = Self.fixture(&random, pool)
            var play: LissajousLabyrinthPlay = Self.started(fixture.level)
            Self.spend(&play, &random)
            #expect(play.stage == .failed)
            #expect(play.spent == fixture.level.allowance)
            let verdict: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(play.dials, level: fixture.level)
            #expect(play.failure == verdict)
            #expect(verdict != .won)
            #expect(!play.canUndo)
            #expect(!play.canRedo)
        }
    }

    @Test func stageMachineTable() {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        let fixture: LissajousLabyrinthFixture = Self.winnable(&random)
        let levels: [LissajousLabyrinthLevel] = [Self.tutorial(fixture.level), fixture.level]
        for level in levels {
            for stage in LissajousLabyrinthStage.allCases {
                if stage == .tutorial && !level.tutorial { continue }
                for event in Self.events {
                    let play: LissajousLabyrinthPlay = Self.play(in: stage, level, fixture, &random)
                    var allowed: LissajousLabyrinthStage? = nil
                    switch (stage, event) {
                    case (.loading, .begin): allowed = level.tutorial ? .tutorial : .playing
                    case (.tutorial, .dismissTutorial): allowed = .playing
                    case (.playing, .pause): allowed = .paused
                    case (.paused, .resume): allowed = .playing
                    case (.won, .showResult), (.failed, .showResult): allowed = .result
                    default: allowed = nil
                    }
                    let result: (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay) = Self.attempt(play) {
                        p throws(LissajousLabyrinthError) in try p.handle(event)
                    }
                    if let next = allowed {
                        #expect(result.error == nil, "\(stage) \(event)")
                        #expect(result.play.stage == next, "\(stage) \(event)")
                        #expect(result.play.dials == play.dials)
                        #expect(result.play.spent == play.spent)
                        #expect(result.play.records == play.records)
                    } else {
                        #expect(result.error == .stage, "\(stage) \(event)")
                        #expect(result.play == play, "\(stage) \(event)")
                    }
                }
            }
        }
    }

    @Test func noActionAfterTheEnd() {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        let ends: [LissajousLabyrinthStage] = [.won, .failed, .result]
        for _ in 0..<20 {
            let fixture: LissajousLabyrinthFixture = Self.winnable(&random)
            for stage in ends {
                let play: LissajousLabyrinthPlay = Self.play(in: stage, fixture.level, fixture, &random)
                let actions: [LissajousLabyrinthAction] = Self.validActions(play.dials)
                for action in actions {
                    let result: (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay) = Self.attempt(play) {
                        p throws(LissajousLabyrinthError) in try p.apply(action, expecting: p.fingerprint)
                    }
                    #expect(result.error == .stage)
                    #expect(result.play == play)
                }
                let undo: (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay) = Self.attempt(play) {
                    p throws(LissajousLabyrinthError) in try p.undo()
                }
                #expect(undo.error == .stage)
                #expect(undo.play == play)
                let redo: (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay) = Self.attempt(play) {
                    p throws(LissajousLabyrinthError) in try p.redo()
                }
                #expect(redo.error == .stage)
                #expect(redo.play == play)
                #expect(!play.canUndo)
                #expect(!play.canRedo)
            }
        }
    }

    @Test func tutorialLevelsPassThroughTheTutorial() throws {
        var random: SeededRandom = SeededRandom(seed: 2_314)
        for _ in 0..<20 {
            let fixture: LissajousLabyrinthFixture = Self.fixture(&random)
            let level: LissajousLabyrinthLevel = Self.tutorial(fixture.level)
            var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: level)
            try play.handle(.begin)
            #expect(play.stage == .tutorial)
            let action: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: .phaseA,
                                                                            value: (play.dials.phaseA + 1) % 16)
            let refused: (error: LissajousLabyrinthError?, play: LissajousLabyrinthPlay) = Self.attempt(play) {
                p throws(LissajousLabyrinthError) in try p.apply(action, expecting: p.fingerprint)
            }
            #expect(refused.error == .stage)
            #expect(refused.play == play)
            try play.handle(.dismissTutorial)
            #expect(play.stage == .playing)
            // A level without a tutorial goes straight to playing.
            var plain: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: fixture.level)
            try plain.handle(.begin)
            #expect(plain.stage == .playing)
        }
    }
}
