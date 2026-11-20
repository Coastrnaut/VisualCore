// AuroraLoomPlayTests — feature 301 (R02-G01-01) T-R02G0101-004 (FR-R02G0101-004, 005, 006; SC-R02G0101-002, 003, 004;
// clarifications Q2, Q3, Q4). 500 seeded traces replay to identical records, fingerprints and outcome; undo of every move
// restores the exact earlier state; 1,000 seeded refused attempts leave the play unchanged; the winning steps win;
// spending the allowance without a win fails with the worst mismatch; the full stage machine table; no move after the end;
// tutorial levels pass through the tutorial stage.
// Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import AuroraLoomCore
import VisualCoreMath
import VisualCoreSimulation

@Suite struct AuroraLoomPlayTests {
    /// The five events in a fixed order.
    static let events: [AuroraLoomEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func started(_ level: AuroraLoomLevel) -> AuroraLoomPlay {
        var play: AuroraLoomPlay = AuroraLoomPlay(level: level)
        try! play.handle(.begin)
        if level.tutorial { try! play.handle(.dismissTutorial) }
        return play
    }

    /// The step of a control in `steps`.
    static func step(_ steps: AuroraLoomSteps, _ ribbon: Int, _ control: AuroraLoomControl) -> Int {
        control == .wave ? steps.wave[ribbon] : steps.phase[ribbon]
    }

    /// `steps` with one control set.
    static func setting(_ steps: AuroraLoomSteps, _ move: AuroraLoomMove) -> AuroraLoomSteps {
        var result: AuroraLoomSteps = steps
        if move.control == .wave { result.wave[move.ribbon] = move.step } else { result.phase[move.ribbon] = move.step }
        return result
    }

    /// Moves every control to the fixture's winning step, in ribbon then control order, while the play is playing.
    static func win(_ play: inout AuroraLoomPlay, _ fixture: AuroraLoomFixture) {
        for ribbon in 0..<3 {
            for control in AuroraLoomControl.allCases {
                guard play.stage == .playing else { return }
                let target: Int = step(fixture.winning, ribbon, control)
                if step(play.steps, ribbon, control) != target {
                    let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control, step: target)
                    try! play.apply(move, expecting: play.fingerprint)
                }
            }
        }
    }

    /// A seeded move whose result does not win, or nil when every single-control change wins.
    static func losingMove(_ play: AuroraLoomPlay, _ random: inout SeededRandom) -> AuroraLoomMove? {
        let offset: Int = random.int(0...95)
        for k in 0..<96 {
            let index: Int = (offset + k) % 96
            let ribbon: Int = index / 32
            let control: AuroraLoomControl = (index / 16) % 2 == 0 ? .wave : .phase
            let value: Int = index % 16
            if value == step(play.steps, ribbon, control) { continue }
            let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control, step: value)
            if !AuroraLoomHarmony.wins(setting(play.steps, move), level: play.level) { return move }
        }
        return nil
    }

    /// Spends the allowance with moves that do not win.
    static func spend(_ play: inout AuroraLoomPlay, _ random: inout SeededRandom) {
        while play.stage == .playing {
            guard let move = losingMove(play, &random) else {
                Issue.record("no losing move")
                return
            }
            try! play.apply(move, expecting: play.fingerprint)
        }
    }

    /// A fixture whose level has (or lacks) a tutorial.
    static func fixture(tutorial: Bool, _ random: inout SeededRandom) -> AuroraLoomFixture {
        while true {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            if fixture.level.tutorial == tutorial { return fixture }
        }
    }

    /// A play of the fixture in `stage` (the tutorial stage needs a tutorial level).
    static func play(in stage: AuroraLoomStage, _ fixture: AuroraLoomFixture,
                     _ random: inout SeededRandom) -> AuroraLoomPlay {
        var play: AuroraLoomPlay = AuroraLoomPlay(level: fixture.level)
        switch stage {
        case .loading:
            break
        case .tutorial:
            try! play.handle(.begin)
        case .playing:
            play = started(fixture.level)
        case .paused:
            play = started(fixture.level)
            try! play.handle(.pause)
        case .won:
            play = started(fixture.level)
            win(&play, fixture)
        case .failed:
            play = started(fixture.level)
            spend(&play, &random)
        case .result:
            play = started(fixture.level)
            win(&play, fixture)
            try! play.handle(.showResult)
        }
        #expect(play.stage == stage)
        return play
    }

    /// The error an action throws on a copy of `play`, and the copy after it.
    static func attempt(_ play: AuroraLoomPlay,
                        _ action: (inout AuroraLoomPlay) throws(AuroraLoomError) -> Void)
        -> (error: AuroraLoomError?, play: AuroraLoomPlay) {
        var copy: AuroraLoomPlay = play
        do {
            try action(&copy)
            return (nil, copy)
        } catch {
            return (error, copy)
        }
    }

    @Test func startingPlay() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
        let play: AuroraLoomPlay = AuroraLoomPlay(level: fixture.level)
        #expect(play.stage == .loading)
        #expect(play.steps == fixture.level.startSteps)
        #expect(play.spent == 0)
        #expect(play.records.isEmpty)
        #expect(play.failure == nil)
        #expect(!play.canUndo)
        #expect(!play.canRedo)
        #expect(play.fingerprint.count == 64)
    }

    @Test func fingerprintLayout() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
        let play: AuroraLoomPlay = Self.started(fixture.level)
        var bytes: [UInt8] = [UInt8(AuroraLoomLevel.schema)]
        bytes.append(contentsOf: Array(fixture.level.fingerprint.utf8))
        for r in 0..<3 { bytes.append(UInt8(play.steps.wave[r])) }
        for r in 0..<3 { bytes.append(UInt8(play.steps.phase[r])) }
        bytes.append(0)
        bytes.append(contentsOf: Array("playing".utf8))
        #expect(play.fingerprint == StableHash.sha256Hex(bytes))
        let loading: AuroraLoomPlay = AuroraLoomPlay(level: fixture.level)
        #expect(loading.fingerprint != play.fingerprint)
    }

    @Test func tracesReplay() throws {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        var won: Int = 0
        var failed: Int = 0
        var undos: Int = 0
        var redos: Int = 0
        for _ in 0..<500 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            var play: AuroraLoomPlay = Self.started(fixture.level)
            let length: Int = random.int(1...90)
            var actions: Int = 0
            while play.stage == .playing && actions < length {
                actions += 1
                let choice: Int = random.int(0...9)
                if choice == 8 && play.canUndo {
                    try play.undo()
                    undos += 1
                } else if choice == 9 && play.canRedo {
                    try play.redo()
                    redos += 1
                } else {
                    let ribbon: Int = random.int(0...2)
                    let control: AuroraLoomControl = random.int(0...1) == 0 ? .wave : .phase
                    let current: Int = Self.step(play.steps, ribbon, control)
                    var value: Int = choice < 3 ? Self.step(fixture.winning, ribbon, control) : random.int(0...15)
                    if value == current { value = (current + 1 + random.int(0...14)) % 16 }
                    let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control, step: value)
                    try play.apply(move, expecting: play.fingerprint)
                }
            }
            if play.stage == .won { won += 1 }
            if play.stage == .failed { failed += 1 }
            // The chain of records links every fingerprint.
            var previous: String = Self.started(fixture.level).fingerprint
            for index in play.records.indices {
                let record: AuroraLoomRecord = play.records[index]
                #expect(record.tick == index)
                #expect(record.previous == previous)
                #expect(record.seed == fixture.level.seed)
                #expect(record.schema == AuroraLoomLevel.schema)
                previous = record.next
            }
            #expect(previous == play.fingerprint)
            let replayed: AuroraLoomPlay = try AuroraLoomPlay.replay(level: fixture.level, records: play.records)
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
    }

    @Test func damagedTraceIsRefused() throws {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
        var play: AuroraLoomPlay = Self.started(fixture.level)
        let move: AuroraLoomMove = try #require(Self.losingMove(play, &random))
        try play.apply(move, expecting: play.fingerprint)
        try play.undo()
        let first: AuroraLoomRecord = play.records[1]
        let edited: AuroraLoomRecord = AuroraLoomRecord(schema: first.schema, seed: first.seed, tick: first.tick,
                                                        kind: first.kind, ribbon: first.ribbon, control: first.control,
                                                        step: first.step, previous: first.previous, next: "0")
        var records: [AuroraLoomRecord] = play.records
        records[1] = edited
        #expect(throws: AuroraLoomError.malformed("record 1")) {
            _ = try AuroraLoomPlay.replay(level: fixture.level, records: records)
        }
    }

    @Test func undoRestoresEveryEarlierState() throws {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        for _ in 0..<200 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            var play: AuroraLoomPlay = Self.started(fixture.level)
            var steps: [AuroraLoomSteps] = []
            var spent: [Int] = []
            var prints: [String] = []
            let count: Int = random.int(1...(fixture.level.allowance - 1))
            for _ in 0..<count {
                guard let move = Self.losingMove(play, &random) else { break }
                steps.append(play.steps)
                spent.append(play.spent)
                prints.append(play.fingerprint)
                try play.apply(move, expecting: play.fingerprint)
                #expect(play.stage == .playing)
                // An immediate undo restores the state before this move.
                let check: (error: AuroraLoomError?, play: AuroraLoomPlay) = Self.attempt(play) { p throws(AuroraLoomError) in
                    try p.undo()
                }
                #expect(check.error == nil)
                #expect(check.play.steps == steps[steps.count - 1])
                #expect(check.play.spent == spent[spent.count - 1])
                #expect(check.play.fingerprint == prints[prints.count - 1])
            }
            // Undo every move in turn, then redo every one.
            let end: AuroraLoomSteps = play.steps
            let endPrint: String = play.fingerprint
            var index: Int = steps.count - 1
            while index >= 0 {
                try play.undo()
                #expect(play.steps == steps[index])
                #expect(play.spent == spent[index])
                #expect(play.fingerprint == prints[index])
                index -= 1
            }
            #expect(!play.canUndo)
            #expect(play.spent == 0)
            while play.canRedo { try play.redo() }
            #expect(play.steps == end)
            #expect(play.fingerprint == endPrint)
            // A new move clears the redo stack.
            if play.canUndo {
                try play.undo()
                #expect(play.canRedo)
                if let move = Self.losingMove(play, &random) {
                    try play.apply(move, expecting: play.fingerprint)
                    #expect(!play.canRedo)
                }
            }
        }
    }

    @Test func refusedAttemptsChangeNothing() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        var kinds: [Int] = Array(repeating: 0, count: 10)
        for _ in 0..<1_000 {
            let kind: Int = random.int(0...9)
            kinds[kind] += 1
            var fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            var play: AuroraLoomPlay = Self.started(fixture.level)
            // A few accepted moves first, so refusals happen in varied states.
            let warm: Int = random.int(0...min(3, fixture.level.allowance - 2))
            for _ in 0..<warm {
                if let move = Self.losingMove(play, &random) { try! play.apply(move, expecting: play.fingerprint) }
            }
            let ribbon: Int = random.int(0...2)
            let control: AuroraLoomControl = random.int(0...1) == 0 ? .wave : .phase
            let current: Int = Self.step(play.steps, ribbon, control)
            let other: Int = (current + 1 + random.int(0...14)) % 16
            var expected: AuroraLoomError = .stage
            var result: (error: AuroraLoomError?, play: AuroraLoomPlay)
            switch kind {
            case 0: // out of range
                let ribbons: [Int] = [-1, 3, ribbon, ribbon]
                let values: [Int] = [other, other, -1, 16]
                let pick: Int = random.int(0...3)
                let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbons[pick], control: control, step: values[pick])
                expected = .move("range")
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.apply(move, expecting: p.fingerprint) }
            case 1: // no change
                let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control, step: current)
                expected = .move("no-change")
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.apply(move, expecting: p.fingerprint) }
            case 2: // over the allowance: the allowance is spent, so the play has failed and refuses every action
                Self.spend(&play, &random)
                #expect(play.stage == .failed)
                let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control, step: other)
                expected = .stage
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.apply(move, expecting: p.fingerprint) }
            case 3: // wrong stage: loading, tutorial, paused, won, failed or result
                let stages: [AuroraLoomStage] = [.loading, .tutorial, .paused, .won, .failed, .result]
                let stage: AuroraLoomStage = stages[random.int(0...5)]
                if stage == .tutorial { fixture = Self.fixture(tutorial: true, &random) }
                play = Self.play(in: stage, fixture, &random)
                let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control,
                                                          step: (Self.step(play.steps, ribbon, control) + 1) % 16)
                expected = .stage
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.apply(move, expecting: p.fingerprint) }
            case 4: // undo in a wrong stage
                let stages: [AuroraLoomStage] = [.loading, .paused, .won, .failed, .result]
                play = Self.play(in: stages[random.int(0...4)], fixture, &random)
                expected = .stage
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.undo() }
            case 5: // redo in a wrong stage
                let stages: [AuroraLoomStage] = [.loading, .paused, .won, .failed, .result]
                play = Self.play(in: stages[random.int(0...4)], fixture, &random)
                expected = .stage
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.redo() }
            case 6: // stale fingerprint
                let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control, step: other)
                let stale: String = random.int(0...1) == 0 ? AuroraLoomPlay(level: fixture.level).fingerprint
                    : String(repeating: "0", count: 64)
                expected = .stale
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.apply(move, expecting: stale) }
            case 7: // nothing to undo
                play = Self.started(fixture.level)
                expected = .move("nothing-to-undo")
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.undo() }
            case 8: // nothing to redo
                expected = .move("nothing-to-redo")
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.redo() }
            default: // an event the stage does not allow
                play = Self.play(in: .paused, fixture, &random)
                let events: [AuroraLoomEvent] = [.begin, .dismissTutorial, .pause, .showResult]
                let event: AuroraLoomEvent = events[random.int(0...3)]
                expected = .stage
                result = Self.attempt(play) { p throws(AuroraLoomError) in try p.handle(event) }
            }
            #expect(result.error == expected)
            #expect(result.play == play)
            #expect(result.play.fingerprint == play.fingerprint)
        }
        for count in kinds { #expect(count > 50) }
    }

    @Test func winningStepsWin() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        for _ in 0..<100 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            var play: AuroraLoomPlay = Self.started(fixture.level)
            Self.win(&play, fixture)
            #expect(play.stage == .won)
            #expect(play.spent <= 6)
            #expect(play.spent <= fixture.level.allowance)
            #expect(play.failure == nil)
            #expect(AuroraLoomHarmony.wins(play.steps, level: fixture.level))
            #expect(play.records.last?.next == play.fingerprint)
        }
    }

    @Test func spendingTheAllowanceFails() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        for _ in 0..<100 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            var play: AuroraLoomPlay = Self.started(fixture.level)
            Self.spend(&play, &random)
            #expect(play.stage == .failed)
            #expect(play.spent == fixture.level.allowance)
            let worst: AuroraLoomMismatch = AuroraLoomHarmony.worst(play.steps, level: fixture.level)
            #expect(play.failure == worst)
            #expect(abs(worst.residual) > fixture.level.tolerance)
            #expect(!play.canUndo)
            #expect(!play.canRedo)
        }
    }

    @Test func stageMachineTable() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let tutorialFixture: AuroraLoomFixture = Self.fixture(tutorial: true, &random)
        let plainFixture: AuroraLoomFixture = Self.fixture(tutorial: false, &random)
        let fixtures: [AuroraLoomFixture] = [tutorialFixture, plainFixture]
        for fixture in fixtures {
            for stage in AuroraLoomStage.allCases {
                if stage == .tutorial && !fixture.level.tutorial { continue }
                for event in Self.events {
                    let play: AuroraLoomPlay = Self.play(in: stage, fixture, &random)
                    var allowed: AuroraLoomStage? = nil
                    switch (stage, event) {
                    case (.loading, .begin): allowed = fixture.level.tutorial ? .tutorial : .playing
                    case (.tutorial, .dismissTutorial): allowed = .playing
                    case (.playing, .pause): allowed = .paused
                    case (.paused, .resume): allowed = .playing
                    case (.won, .showResult), (.failed, .showResult): allowed = .result
                    default: allowed = nil
                    }
                    let result: (error: AuroraLoomError?, play: AuroraLoomPlay) = Self.attempt(play) {
                        p throws(AuroraLoomError) in try p.handle(event)
                    }
                    if let next = allowed {
                        #expect(result.error == nil, "\(stage) \(event)")
                        #expect(result.play.stage == next, "\(stage) \(event)")
                        #expect(result.play.steps == play.steps)
                        #expect(result.play.records == play.records)
                    } else {
                        #expect(result.error == .stage, "\(stage) \(event)")
                        #expect(result.play == play, "\(stage) \(event)")
                    }
                }
            }
        }
    }

    @Test func noMoveAfterTheEnd() {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        let ends: [AuroraLoomStage] = [.won, .failed, .result]
        for _ in 0..<30 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            for stage in ends {
                let play: AuroraLoomPlay = Self.play(in: stage, fixture, &random)
                for ribbon in 0..<3 {
                    for control in AuroraLoomControl.allCases {
                        let move: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: control,
                                                                  step: (Self.step(play.steps, ribbon, control) + 1) % 16)
                        let result: (error: AuroraLoomError?, play: AuroraLoomPlay) = Self.attempt(play) {
                            p throws(AuroraLoomError) in try p.apply(move, expecting: p.fingerprint)
                        }
                        #expect(result.error == .stage)
                        #expect(result.play == play)
                    }
                }
                let undo: (error: AuroraLoomError?, play: AuroraLoomPlay) = Self.attempt(play) {
                    p throws(AuroraLoomError) in try p.undo()
                }
                #expect(undo.error == .stage)
                let redo: (error: AuroraLoomError?, play: AuroraLoomPlay) = Self.attempt(play) {
                    p throws(AuroraLoomError) in try p.redo()
                }
                #expect(redo.error == .stage)
                #expect(!play.canUndo)
                #expect(!play.canRedo)
            }
        }
    }

    @Test func tutorialLevelsPassThroughTheTutorial() throws {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        for _ in 0..<20 {
            let fixture: AuroraLoomFixture = AuroraLoomFixture.next(&random)
            var play: AuroraLoomPlay = AuroraLoomPlay(level: fixture.level)
            try play.handle(.begin)
            if fixture.level.tutorial {
                #expect(play.stage == .tutorial)
                let move: AuroraLoomMove = AuroraLoomMove(ribbon: 0, control: .wave,
                                                          step: (play.steps.wave[0] + 1) % 16)
                let refused: (error: AuroraLoomError?, play: AuroraLoomPlay) = Self.attempt(play) {
                    p throws(AuroraLoomError) in try p.apply(move, expecting: p.fingerprint)
                }
                #expect(refused.error == .stage)
                try play.handle(.dismissTutorial)
            }
            #expect(play.stage == .playing)
        }
    }
}

