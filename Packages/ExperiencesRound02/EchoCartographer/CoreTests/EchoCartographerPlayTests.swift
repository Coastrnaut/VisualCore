// EchoCartographerPlayTests — feature 401 (R02-G11-01) T-R02G1101-004 (FR-R02G1101-002 … 008, 013, 014;
// SC-R02G1101-001, 002, 004; clarifications Q2, Q3, Q4, Q5). The play of an Echo Cartographer level: the full stage
// table of `handle(_:)`; the 500 fixtures' known pulses and claims win exactly on the last claim and never before; on the
// hand level a claim at the tolerance locates and one cell further misses, the localization errors are exact and a pulse
// reveals exactly its rays; energy failure on the exact action with budgets one action either side, a miss cost
// exceeding the energy clamped to 0, and a win on the last unit of energy; the validation order stage, stale, action,
// no-op, with every refusal reachable, spending nothing and leaving the play unchanged; markers toggle, stay sorted and
// cap at 8; undo from failed returns to playing, a won play is final; undo of every action restores the exact
// fingerprint, energy and knowledge and a new action clears redo; 500 seeded traces (seed 2_401 onwards) replay to the
// same records, fingerprints and outcome, and a tampered trace is refused. Explicit types, plain loops; each test well
// under 10 s.
import Foundation
import Testing
import VisualCoreSimulation
@testable import EchoCartographerCore

struct EchoCartographerPlayTests {
    typealias Play = EchoCartographerPlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(EchoCartographerAction)
        case stale(EchoCartographerAction)
        case undo
        case redo
        case event(EchoCartographerEvent)
    }

    static let events: [EchoCartographerEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func cell(_ x: Int, _ y: Int) -> EchoCartographerCell { EchoCartographerCell(x: x, y: y) }

    static func perform(_ op: Op, _ play: inout Play) throws(EchoCartographerError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: EchoCartographerAction) throws(EchoCartographerError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> EchoCartographerError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused \(op) changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.energy == play.energy, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: EchoCartographerLevel) throws(EchoCartographerError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The hand level with a tutorial.
    static func tutorialHand() throws -> EchoCartographerLevel {
        let hand: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        return try EchoCartographerLevel(id: "hand-tutorial", seed: hand.seed, difficulty: 1, chamber: hand.chamber,
                                         entry: hand.entry, beacons: hand.beacons, tolerance: hand.tolerance,
                                         energy: hand.energy, missCost: hand.missCost, tutorial: true)
    }

    /// The knowledge expected after pulses from `emitters`, computed independently from the walls.
    static func expectedKnowledge(_ level: EchoCartographerLevel,
                                  emitters: [EchoCartographerCell]) -> [EchoCartographerKnown] {
        let chamber: EchoCartographerChamber = level.chamber
        var cells: [EchoCartographerKnown] = Array(repeating: .unknown, count: chamber.width * chamber.height)
        cells[level.entry.y * chamber.width + level.entry.x] = .open
        let steps: [(Int, Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        for emitter in emitters {
            for (dx, dy) in steps {
                var x: Int = emitter.x + dx
                var y: Int = emitter.y + dy
                while x >= 0 && x < chamber.width && y >= 0 && y < chamber.height {
                    let index: Int = y * chamber.width + x
                    if chamber.walls.contains(index) {
                        cells[index] = .wall
                        break
                    }
                    cells[index] = .open
                    x += dx
                    y += dy
                }
            }
        }
        return cells
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: EchoCartographerLevel = try Self.tutorialHand()
        let without: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let pulse: EchoCartographerAction = .pulse(0, 0)

        // loading: only begin.
        var play = Play(level: withTutorial)
        #expect(play.stage == .loading)
        #expect(play.energy == 6)
        #expect(play.markers.isEmpty)
        #expect(play.located.isEmpty)
        #expect(play.lastEcho == nil)
        #expect(play.failure == nil)
        #expect(play.knowledge == withTutorial.openingKnowledge)
        #expect(!play.canUndo && !play.canRedo)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(pulse)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(pulse)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        try play.handle(.dismissTutorial)
        #expect(play.stage == .playing)

        // Without a tutorial, begin goes straight to playing.
        var direct = Play(level: without)
        try direct.handle(.begin)
        #expect(direct.stage == .playing)

        // playing: pause only.
        for event in Self.events where event != .pause {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        try play.handle(.pause)
        #expect(play.stage == .paused)

        // paused: resume only; actions refused by stage, even stale ones.
        for event in Self.events where event != .resume {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(pulse)) == .stage)
        #expect(Self.refusal(play, .stale(pulse)) == .stage)
        try play.handle(.resume)
        #expect(play.stage == .playing)

        // won: showResult only; undo refused (final).
        var won: Play = try Self.playing(without)
        try Self.act(&won, .claim(6, 0))
        try Self.act(&won, .claim(2, 2))
        #expect(won.stage == .won)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(pulse)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
        #expect(!won.canUndo)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(pulse)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)

        // failed: showResult, undo; actions and redo refused.
        var failed: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 1))
        try Self.act(&failed, pulse)
        #expect(failed.stage == .failed)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(pulse)) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        #expect(failed.canUndo)
        var shown: Play = failed
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        #expect(Self.refusal(shown, .undo) == .stage)
    }

    // MARK: - Known actions

    /// The 500 fixtures: the known pulses then claims win exactly on the last claim, never before. A fixture with an
    /// energy of 1 fails on its pulse (a pulse that spends the last energy fails); it is undone and the claims alone
    /// win.
    @Test func fixturesWinOnTheLastKnownClaim() throws {
        let fixtures: [EchoCartographerFixture] = EchoCartographerFixtures.fixtures(500)
        var pulseFailures: Int = 0
        for fixture in fixtures {
            let level: EchoCartographerLevel = fixture.level
            var play: Play = try Self.playing(level)
            var emitters: [EchoCartographerCell] = []
            for (index, emitter) in fixture.pulses.enumerated() {
                try Self.act(&play, .pulse(emitter.x, emitter.y))
                emitters.append(emitter)
                #expect(play.lastEcho == level.echo(from: emitter))
                #expect(play.energy == level.energy - index - 1)
                #expect(play.knowledge.cells == Self.expectedKnowledge(level, emitters: emitters))
                if play.energy == 0 {
                    #expect(play.stage == .failed)
                    #expect(play.failure == .energy(index))
                    try play.undo()
                    #expect(play.stage == .playing)
                    #expect(play.energy == level.energy)
                    emitters.removeLast()
                    pulseFailures += 1
                    break
                }
                #expect(play.stage == .playing)
            }
            let energyBefore: Int = play.energy
            for (index, claim) in fixture.claims.enumerated() {
                #expect(play.stage == .playing, "won before the last claim of \(level.id)")
                try Self.act(&play, .claim(claim.x, claim.y))
                #expect(play.located.count == index + 1)
                #expect(play.energy == energyBefore)
                #expect(play.knowledge[claim] == .open)
            }
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.localizationErrors == Array(repeating: 0, count: level.beacons.count))
            #expect(play.totalLocalizationError == 0)
        }
        #expect(pulseFailures > 0)
    }

    /// On the hand level (beacons (6, 0) then (2, 2), tolerance 1): a claim at the tolerance locates, one cell further
    /// misses (spending 2, revealing nothing); the localization errors are exact.
    @Test func claimAtTheToleranceLocatesAndOneFurtherMisses() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        #expect(level.beacons == [Self.cell(6, 0), Self.cell(2, 2)])
        var play: Play = try Self.playing(level)
        let opening: EchoCartographerKnowledge = play.knowledge

        // (4, 2) is 2 from both beacons: a miss that reveals nothing.
        try Self.act(&play, .claim(4, 2))
        #expect(play.energy == 4)
        #expect(play.located.isEmpty)
        #expect(play.knowledge == opening)
        #expect(play.stage == .playing)
        #expect(play.records.last?.kind == .claim)

        // (3, 2) is 1 from (2, 2): locates beacon 1 and makes (2, 2) known open.
        try Self.act(&play, .claim(3, 2))
        #expect(play.energy == 4)
        #expect(play.located == [1: Self.cell(3, 2)])
        #expect(play.knowledge[Self.cell(2, 2)] == .open)
        #expect(play.localizationErrors == [1])
        #expect(play.totalLocalizationError == 1)

        // (6, 1) is 1 from (6, 0): locates beacon 0 and wins.
        try Self.act(&play, .claim(6, 1))
        #expect(play.stage == .won)
        #expect(play.located == [0: Self.cell(6, 1), 1: Self.cell(3, 2)])
        #expect(play.localizationErrors == [1, 1])
        #expect(play.totalLocalizationError == 2)
        #expect(play.energy == 4)

        // Tolerance 0: only the beacon's own cell locates.
        var exact: Play = try Self.playing(EchoCartographerFixtures.handLevel(tolerance: 0))
        try Self.act(&exact, .claim(6, 1))
        #expect(exact.located.isEmpty)
        #expect(exact.energy == 4)
        try Self.act(&exact, .claim(6, 0))
        #expect(exact.located == [0: Self.cell(6, 0)])

        // Tolerance 2: (4, 2) is now 2 from both; the nearest-then-lowest-row rule picks (6, 0), beacon 0.
        var wide: Play = try Self.playing(EchoCartographerFixtures.handLevel(tolerance: 2))
        try Self.act(&wide, .claim(4, 2))
        #expect(wide.located == [0: Self.cell(4, 2)])
        #expect(wide.localizationErrors == [2])
        // (4, 4) is 2 from (2, 2), 4 from (6, 0): locates beacon 1 and wins.
        try Self.act(&wide, .claim(4, 4))
        #expect(wide.stage == .won)
        #expect(wide.totalLocalizationError == 4)
    }

    /// A pulse from the entry of the hand level spends 1, reveals exactly its rays and reports echoes 4 and 10.
    @Test func pulseRevealsItsRaysAndReportsEchoes() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .pulse(0, 0))
        #expect(play.energy == 5)
        let echo: EchoCartographerEcho? = play.lastEcho
        #expect(echo?.beaconDistances == [4, 10])
        #expect(echo?.beaconDelays == [96, 240])
        var distances: [Int] = []
        for ray in echo?.rays ?? [] { distances.append(ray.distance) }
        #expect(distances == [1, 3, 5, 1])
        #expect(play.knowledge.cells == Self.expectedKnowledge(level, emitters: [Self.cell(0, 0)]))
        #expect(play.knowledge[Self.cell(3, 0)] == .wall)
        #expect(play.knowledge[Self.cell(0, 4)] == .open)
        #expect(play.knowledge[Self.cell(2, 1)] == .unknown)
        #expect(play.records.count == 1)
        #expect(play.records[0].kind == .pulse)
        #expect(play.records[0].index == 0)
        #expect(play.records[0].action == .pulse(0, 0))
        #expect(play.progressDescription == "0 of 2 beacons located, 5 energy left")

        // A second pulse from a newly known open cell.
        try Self.act(&play, .pulse(2, 0))
        #expect(play.energy == 4)
        #expect(play.knowledge.cells == Self.expectedKnowledge(level, emitters: [Self.cell(0, 0), Self.cell(2, 0)]))
        #expect(play.lastEcho == level.echo(from: Self.cell(2, 0)))
        #expect(play.records[1].index == 1)
    }

    // MARK: - Energy

    /// Energy failure on the exact action, with budgets one action either side; a miss cost exceeding the energy
    /// clamps to 0; a win on the last unit of energy wins.
    @Test func energyFailsOnTheExactAction() throws {
        // Energy 2: pulse, pulse → failed on action 1.
        var two: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 2))
        try Self.act(&two, .pulse(0, 0))
        #expect(two.stage == .playing)
        #expect(two.energy == 1)
        try Self.act(&two, .pulse(0, 0))
        #expect(two.stage == .failed)
        #expect(two.energy == 0)
        #expect(two.failure == .energy(1))
        #expect(two.failure?.code == "energy")

        // Energy 3 (one more): the same two pulses leave it playing; the third fails on action 2.
        var three: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 3))
        try Self.act(&three, .pulse(0, 0))
        try Self.act(&three, .pulse(0, 0))
        #expect(three.stage == .playing)
        #expect(three.failure == nil)
        try Self.act(&three, .pulse(0, 0))
        #expect(three.failure == .energy(2))

        // Energy 1 (one fewer): the first pulse fails on action 0.
        var one: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 1))
        try Self.act(&one, .pulse(0, 0))
        #expect(one.failure == .energy(0))

        // Marks are free and count as actions: mark, mark, pulse with energy 1 fails on action 2.
        var marked: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 1))
        try Self.act(&marked, .mark(4, 4))
        try Self.act(&marked, .mark(5, 4))
        try Self.act(&marked, .pulse(0, 0))
        #expect(marked.failure == .energy(2))

        // A miss cost of 3 with 1 energy left clamps to 0 and fails.
        var clamp: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 1, missCost: 3))
        try Self.act(&clamp, .claim(4, 2))
        #expect(clamp.energy == 0)
        #expect(clamp.failure == .energy(0))

        // Energy 3, miss cost 2: miss → 1, miss → 0 (clamped) fails on action 1.
        var misses: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 3, missCost: 2))
        try Self.act(&misses, .claim(4, 2))
        #expect(misses.energy == 1)
        #expect(misses.stage == .playing)
        try Self.act(&misses, .claim(4, 2))
        #expect(misses.energy == 0)
        #expect(misses.failure == .energy(1))

        // Locating one beacon does not prevent the energy failure while another is hidden.
        var partial: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 1))
        try Self.act(&partial, .claim(6, 0))
        #expect(partial.stage == .playing)
        try Self.act(&partial, .pulse(0, 0))
        #expect(partial.failure == .energy(1))
        #expect(partial.located.count == 1)

        // A win on the last unit of energy wins: energy 3, a miss (1 left), then both hits (free).
        var last: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 3, missCost: 2))
        try Self.act(&last, .claim(4, 2))
        try Self.act(&last, .claim(6, 0))
        try Self.act(&last, .claim(2, 2))
        #expect(last.stage == .won)
        #expect(last.energy == 1)
        #expect(last.failure == nil)

        // Energy 1: two hits win with the only unit unspent.
        var minimal: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 1))
        try Self.act(&minimal, .claim(2, 2))
        try Self.act(&minimal, .claim(6, 0))
        #expect(minimal.stage == .won)
        #expect(minimal.energy == 1)
    }

    // MARK: - Refusals

    /// Every refusal reason is reachable, in the validation order stage, stale, action, no-op, and leaves the play
    /// unchanged.
    @Test func everyRefusalIsReachableInOrder() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var play: Play = try Self.playing(level)

        // Nothing to undo or redo.
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))

        // Outside the chamber, for every action kind.
        let outside: [EchoCartographerAction] = [.pulse(-1, 0), .pulse(7, 0), .claim(0, -1), .claim(0, 5),
                                                 .mark(7, 4), .mark(-1, -1)]
        for action in outside {
            #expect(Self.refusal(play, .act(action)) == .action("cell"))
            // Stale before action.
            #expect(Self.refusal(play, .stale(action)) == .stale)
        }
        // A pulse from an unknown cell, then from a known wall.
        #expect(Self.refusal(play, .act(.pulse(1, 0))) == .action("pulse"))
        try Self.act(&play, .pulse(0, 0))
        #expect(Self.refusal(play, .act(.pulse(3, 0))) == .action("pulse"))
        #expect(Self.refusal(play, .act(.pulse(2, 1))) == .action("pulse"))
        // A claim on a known wall.
        #expect(Self.refusal(play, .act(.claim(3, 0))) == .action("claim"))
        // A second pulse reveals the wall (1, 1); a claim on (2, 2) locates beacon 1.
        try Self.act(&play, .pulse(0, 1))
        #expect(play.knowledge[Self.cell(1, 1)] == .wall)
        try Self.act(&play, .claim(2, 2))
        #expect(play.located == [1: Self.cell(2, 2)])
        // No-op: within the tolerance only of the located beacon.
        #expect(Self.refusal(play, .act(.claim(2, 2))) == .noop)
        #expect(Self.refusal(play, .act(.claim(3, 3))) == .noop)
        // Action before no-op: (1, 1) is a known wall within the tolerance of the located beacon.
        #expect(Self.refusal(play, .act(.claim(1, 1))) == .action("claim"))
        // Stale before action and no-op.
        #expect(Self.refusal(play, .stale(.claim(2, 2))) == .stale)
        #expect(Self.refusal(play, .stale(.pulse(3, 0))) == .stale)
        // Stage before stale.
        try play.handle(.pause)
        #expect(Self.refusal(play, .stale(.claim(2, 2))) == .stage)
        #expect(Self.refusal(play, .act(.pulse(0, 0))) == .stage)
        try play.handle(.resume)
        // A ninth marker.
        for x in 0..<7 { try Self.act(&play, .mark(x, 4)) }
        try Self.act(&play, .mark(6, 3))
        #expect(play.markers.count == 8)
        #expect(Self.refusal(play, .act(.mark(0, 3))) == .action("marker"))
        // An unrevealed wall is not refused as a wall: (3, 3) was refused only as a no-op above.
        #expect(play.knowledge[Self.cell(3, 3)] == .unknown)
    }

    /// Markers toggle, stay in cell-index order, cap at 8, cost nothing and never decide anything.
    @Test func markersToggleAndCapAtEight() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var play: Play = try Self.playing(level)
        let opening: String = play.fingerprint
        try Self.act(&play, .mark(4, 4))
        try Self.act(&play, .mark(1, 0))
        try Self.act(&play, .mark(3, 0))
        #expect(play.markers == [Self.cell(1, 0), Self.cell(3, 0), Self.cell(4, 4)])
        #expect(play.energy == 6)
        #expect(play.fingerprint != opening)
        try Self.act(&play, .mark(3, 0))
        #expect(play.markers == [Self.cell(1, 0), Self.cell(4, 4)])
        try Self.act(&play, .mark(1, 0))
        try Self.act(&play, .mark(4, 4))
        #expect(play.markers.isEmpty)
        #expect(play.fingerprint == opening)
        #expect(play.records.count == 6)

        // Markers on beacons decide nothing.
        try Self.act(&play, .mark(6, 0))
        try Self.act(&play, .mark(2, 2))
        #expect(play.located.isEmpty)
        #expect(play.stage == .playing)

        // Fill to 8 (any cell, walls included), refuse a ninth, allow toggling one off and another on.
        let extra: [EchoCartographerCell] = [Self.cell(0, 0), Self.cell(1, 1), Self.cell(3, 3), Self.cell(5, 4),
                                             Self.cell(6, 4), Self.cell(0, 4)]
        for marker in extra { try Self.act(&play, .mark(marker.x, marker.y)) }
        #expect(play.markers.count == EchoCartographerLevel.maximumMarkers)
        var sorted: [EchoCartographerCell] = play.markers
        sorted.sort()
        #expect(play.markers == sorted)
        #expect(Self.refusal(play, .act(.mark(4, 0))) == .action("marker"))
        try Self.act(&play, .mark(1, 1))
        #expect(play.markers.count == 7)
        try Self.act(&play, .mark(4, 0))
        #expect(play.markers.count == 8)
        #expect(play.energy == 6)
    }

    // MARK: - Undo and redo

    /// Undo of every action restores the exact fingerprint, energy, knowledge, markers, located beacons and last echo;
    /// redo restores the later ones; a new action clears redo; undo from failed returns to playing (recorded).
    @Test func undoRestoresExactStates() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var play: Play = try Self.playing(level)
        let actions: [EchoCartographerAction] = [.pulse(0, 0), .mark(2, 2), .claim(4, 2), .pulse(2, 0), .claim(6, 1)]
        var states: [Play] = [play]
        for action in actions {
            try Self.act(&play, action)
            states.append(play)
        }
        #expect(play.stage == .playing)
        #expect(play.energy == 2)
        #expect(play.located == [0: Self.cell(6, 1)])
        var undone: Int = 0
        var index: Int = states.count - 1
        while index > 0 {
            try play.undo()
            undone += 1
            index -= 1
            let expected: Play = states[index]
            #expect(play.fingerprint == expected.fingerprint)
            #expect(play.energy == expected.energy)
            #expect(play.knowledge == expected.knowledge)
            #expect(play.markers == expected.markers)
            #expect(play.located == expected.located)
            #expect(play.lastEcho == expected.lastEcho)
            #expect(play.records.last?.kind == .undo)
        }
        #expect(!play.canUndo)
        #expect(play.canRedo)
        for later in 1..<states.count {
            try play.redo()
            #expect(play.fingerprint == states[later].fingerprint)
            #expect(play.energy == states[later].energy)
            #expect(play.knowledge == states[later].knowledge)
        }
        #expect(play.records.count == actions.count + 2 * undone)

        // A new action clears redo.
        try play.undo()
        #expect(play.canRedo)
        try Self.act(&play, .mark(0, 0))
        #expect(!play.canRedo)
        #expect(Self.refusal(play, .redo) == .action("redo"))

        // Undo while paused stays paused.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        try play.redo()
        #expect(play.stage == .paused)
        try play.handle(.resume)

        // Undo from failed returns to playing and is recorded; redo restores the failure.
        var failed: Play = try Self.playing(EchoCartographerFixtures.handLevel(energy: 2))
        try Self.act(&failed, .pulse(0, 0))
        let beforeFail: Play = failed
        try Self.act(&failed, .pulse(0, 0))
        #expect(failed.stage == .failed)
        let failedPrint: String = failed.fingerprint
        try failed.undo()
        #expect(failed.stage == .playing)
        #expect(failed.failure == nil)
        #expect(failed.energy == 1)
        #expect(failed.fingerprint == beforeFail.fingerprint)
        #expect(failed.records.last?.kind == .undo)
        #expect(failed.records.last?.previous == failedPrint)
        try failed.redo()
        #expect(failed.stage == .failed)
        #expect(failed.failure == .energy(1))
        #expect(failed.fingerprint == failedPrint)
    }

    /// The fingerprint is deterministic and covers every part of the state.
    @Test func fingerprintIsCanonical() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var a: Play = try Self.playing(level)
        var b: Play = try Self.playing(level)
        #expect(a.fingerprint == b.fingerprint)
        #expect(a.fingerprint.count == 64)
        // Different located beacons: different fingerprints, also after the same mark.
        try Self.act(&a, .claim(6, 0))
        try Self.act(&b, .claim(2, 2))
        #expect(a.fingerprint != b.fingerprint)
        var a2: Play = a
        var b2: Play = b
        try Self.act(&a2, .mark(0, 0))
        try Self.act(&b2, .mark(0, 0))
        #expect(a2.fingerprint != b2.fingerprint)
        // Same claims, different claim cells: different fingerprint.
        var c: Play = try Self.playing(level)
        try Self.act(&c, .claim(6, 1))
        #expect(c.fingerprint != a.fingerprint)
        // Stage is covered.
        var paused: Play = try Self.playing(level)
        let playingPrint: String = paused.fingerprint
        try paused.handle(.pause)
        #expect(paused.fingerprint != playingPrint)
        // Repeated computation is stable.
        for _ in 0..<5 { #expect(a.fingerprint == a.fingerprint) }
    }

    // MARK: - Replay

    /// 500 seeded traces (seed 2_401 onwards) of random valid and invalid actions, undo, redo, pause and resume replay
    /// to the same records, fingerprints and outcome; a tampered trace is refused.
    @Test func seededTracesReplayExactly() throws {
        var random = SeededRandom(seed: 2_401)
        let fixtures: [EchoCartographerFixture] = EchoCartographerFixtures.fixtures(500, from: 2_401)
        var reached: Set<String> = []
        for fixture in fixtures {
            let level: EchoCartographerLevel = fixture.level
            var play: Play = try Self.playing(level)
            let width: Int = level.chamber.width
            let height: Int = level.chamber.height
            let steps: Int = random.int(4...30)
            for _ in 0..<steps {
                let choice: Int = random.int(0...13)
                let x: Int = random.int(-1...width)
                let y: Int = random.int(-1...height)
                let op: Op
                switch choice {
                case 0...1: op = .act(.pulse(x, y))
                case 2...3: op = .act(.claim(x, y))
                case 4: op = .act(.mark(x, y))
                case 5:
                    var open: [Int] = []
                    for index in 0..<(width * height) where play.knowledge[index] == .open { open.append(index) }
                    let pick: EchoCartographerCell = level.chamber.cell(open[random.int(0...(open.count - 1))])
                    op = .act(.pulse(pick.x, pick.y))
                case 6:
                    let beacon: EchoCartographerCell = level.beacons[random.int(0...(level.beacons.count - 1))]
                    op = .act(.claim(beacon.x, beacon.y))
                case 7...8: op = .undo
                case 9: op = .redo
                case 10: op = .event(.pause)
                case 11: op = .event(.resume)
                case 12: op = .act(.mark(random.int(0...(width - 1)), random.int(0...(height - 1))))
                default: op = .stale(.mark(0, 0))
                }
                let before: Play = play
                do {
                    try Self.perform(op, &play)
                    if case .act = op { reached.insert("accepted") }
                } catch {
                    #expect(play == before)
                    switch error {
                    case .action(let name): reached.insert("action-" + name)
                    default: reached.insert(error.reasonCode)
                    }
                }
            }
            let replayed: Play = try Play.replay(level: level, records: play.records)
            #expect(replayed.records == play.records)
            #expect(replayed.knowledge == play.knowledge)
            #expect(replayed.markers == play.markers)
            #expect(replayed.located == play.located)
            #expect(replayed.energy == play.energy)
            #expect(replayed.lastEcho == play.lastEcho)
            #expect(replayed.failure == play.failure)
            if let last = play.records.last {
                #expect(replayed.fingerprint == last.next)
            }
            // Pauses are not records: align a trailing pause or resume, then the plays agree exactly.
            var aligned: Play = replayed
            if aligned.stage == .playing && play.stage == .paused {
                try aligned.handle(.pause)
            } else if aligned.stage == .paused && play.stage == .playing {
                try aligned.handle(.resume)
            }
            #expect(aligned == play)
            #expect(aligned.fingerprint == play.fingerprint)
            if play.records.count > 0 {
                var tampered: [EchoCartographerRecord] = play.records
                let r: EchoCartographerRecord = tampered[0]
                tampered[0] = EchoCartographerRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                     action: r.action, previous: r.previous, next: "0000")
                #expect(throws: EchoCartographerError.malformed("record 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = EchoCartographerRecord(schema: r.schema, seed: r.seed &+ 1, index: r.index,
                                                     kind: r.kind, action: r.action, previous: r.previous,
                                                     next: r.next)
                #expect(throws: EchoCartographerError.malformed("seed 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = EchoCartographerRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                                     action: r.action, previous: r.previous, next: r.next)
                #expect(throws: EchoCartographerError.malformed("schema 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = EchoCartographerRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                     action: r.action, previous: "0000", next: r.next)
                #expect(throws: EchoCartographerError.malformed("replay")) {
                    try Play.replay(level: level, records: tampered)
                }
            }
        }
        let expected: [String] = ["accepted", "action-cell", "action-pulse", "action-claim", "action-undo",
                                  "action-redo", "r02-g11.noop", "r02-g11.stage", "r02-g11.stale"]
        for name in expected {
            #expect(reached.contains(name), "trace never reached \(name)")
        }
    }

    /// A record whose action is missing or of another kind is refused; a hand trace with a pause replays.
    @Test func replayRefusesMismatchedRecords() throws {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .pulse(0, 0))
        try play.handle(.pause)
        try play.undo()
        try play.handle(.resume)
        try Self.act(&play, .claim(6, 0))
        let replayed: Play = try Play.replay(level: level, records: play.records)
        #expect(replayed == play)
        let r: EchoCartographerRecord = play.records[0]
        var tampered: [EchoCartographerRecord] = play.records
        tampered[0] = EchoCartographerRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .claim,
                                             action: r.action, previous: r.previous, next: r.next)
        #expect(throws: EchoCartographerError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = EchoCartographerRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .pulse,
                                             action: nil, previous: r.previous, next: r.next)
        #expect(throws: EchoCartographerError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = EchoCartographerRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                             action: r.action, previous: r.previous, next: r.next)
        #expect(throws: EchoCartographerError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        // A record that names an action the replay refuses surfaces that refusal.
        tampered[0] = EchoCartographerRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .pulse,
                                             action: .pulse(1, 0), previous: r.previous, next: r.next)
        #expect(throws: EchoCartographerError.action("pulse")) {
            try Play.replay(level: level, records: tampered)
        }
    }
}
