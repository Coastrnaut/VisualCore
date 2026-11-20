// WaveKnotKeeperPlayTests — feature 321 (R02-G03-01) T-R02G0301-004 (FR-R02G0301-002 … 006; SC-R02G0301-001, 002, 004;
// clarifications Q2, Q4, Q5). Host checks of the play: for 500 seeded fixtures the known solution wins, and every single
// move from every state along the solution is refused exactly when `refusal(of:points:level:)` names a reason, with that
// reason, leaving the play unchanged, and agrees with an independent rule oracle (range, bounds, coincident, crossing
// outside a gate, tension, in that order); every reason is reachable. 500 seeded action traces (moves, undo, redo,
// pause and resume refusals) replay to identical records, points and stage; undo restores the exact earlier state, redo
// the later; a new move clears redo; a stale fingerprint and tampered records are refused. Spending the allowance
// without a win fails with the final summary; the tension bound refuses; the full stage machine table. Synthetic data,
// explicit types, plain loops, short runs. Fixture seed 2_321.
import Testing
@testable import WaveKnotKeeperCore

@Suite struct WaveKnotKeeperPlayTests {
    typealias Point = WaveKnotKeeperPoint
    typealias Move = WaveKnotKeeperMove

    /// The five events in a fixed order.
    static let events: [WaveKnotKeeperEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    /// The 500 seeded fixtures (every 4th with a gate), drawn once.
    static let pool: [WaveKnotKeeperFixture] = {
        var fixtures: [WaveKnotKeeperFixture] = []
        for index in 0..<500 {
            fixtures.append(WaveKnotKeeperFixtures.fixture(index, gates: index % 4 == 0))
        }
        return fixtures
    }()

    /// A simple hexagon (no projected crossing) used by the constructed levels.
    static let hexagon: [Point] = [Point(x: 4, y: 0, z: 0), Point(x: 2, y: 4, z: 1), Point(x: -2, y: 4, z: 0),
                                   Point(x: -4, y: 0, z: 1), Point(x: -2, y: -4, z: 0), Point(x: 2, y: -4, z: 1)]

    /// A constructed level (target two crossings, never reached by the hexagon family in one step).
    static func constructed(points: [Point], bound: Int = 10_000, allowance: Int = 10,
                            tutorial: Bool = false) throws -> WaveKnotKeeperLevel {
        try WaveKnotKeeperLevel(id: "constructed", seed: 2_321, band: 1, points: points, gates: [],
                                target: try WaveKnotKeeperTarget(crossings: 2, writhe: 0), tensionBound: bound,
                                allowance: allowance, tutorial: tutorial)
    }

    /// `level` with a different allowance or tutorial flag.
    static func variant(_ level: WaveKnotKeeperLevel, allowance: Int? = nil,
                        tutorial: Bool? = nil) throws -> WaveKnotKeeperLevel {
        try WaveKnotKeeperLevel(id: level.id, seed: level.seed, band: level.band, points: level.points,
                                gates: level.gates, target: level.target, tensionBound: level.tensionBound,
                                allowance: allowance ?? level.allowance, tutorial: tutorial ?? level.tutorial)
    }

    /// The error `body` throws, or nil.
    static func error(_ body: () throws(WaveKnotKeeperError) -> Void) -> WaveKnotKeeperError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// An independent statement of the move rules, in order: range, bounds, coincident, crossing (sweep blocked and
    /// no gate holds both ends), tension.
    static func oracle(_ move: Move, _ points: [Point], _ level: WaveKnotKeeperLevel) -> String? {
        if move.point < 0 || move.point >= points.count { return "range" }
        let from: Point = points[move.point]
        let offset: (x: Int, y: Int, z: Int) = move.direction.offset
        let to: Point = Point(x: from.x + offset.x, y: from.y + offset.y, z: from.z + offset.z)
        if to.x < -16 || to.x > 16 || to.y < -16 || to.y > 16 || to.z < -16 || to.z > 16 { return "bounds" }
        for p in points where p == to { return "coincident" }
        var gated: Bool = false
        for gate in level.gates where gate.contains(from) && gate.contains(to) { gated = true }
        if !gated && !WaveKnotKeeperGeometry.sweepIsClear(points, moving: move.point, to: to) { return "crossing" }
        var moved: [Point] = points
        moved[move.point] = to
        var tension: Int = 0
        for i in 0..<moved.count {
            let a: Point = moved[i]
            let b: Point = moved[(i + 1) % moved.count]
            tension += (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) + (a.z - b.z) * (a.z - b.z)
        }
        if tension > level.tensionBound { return "tension" }
        return nil
    }

    /// Tries `move` on a copy of `play` and checks it against ``WaveKnotKeeperPlay/refusal(of:points:level:)`` and
    /// the oracle; returns the reason named (or "legal").
    static func probe(_ play: WaveKnotKeeperPlay, _ move: Move, _ note: String) -> String {
        let refusal: WaveKnotKeeperError? = WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level)
        let expected: String? = oracle(move, play.points, play.level)
        if let expected {
            #expect(refusal == .move(expected), "\(note) move \(move)")
        } else {
            #expect(refusal == nil, "\(note) move \(move)")
        }
        var copy: WaveKnotKeeperPlay = play
        let before: String = play.fingerprint
        let thrown: WaveKnotKeeperError? = error { () throws(WaveKnotKeeperError) in
            try copy.apply(move, expecting: before)
        }
        if let refusal {
            #expect(thrown == refusal, "\(note) move \(move)")
            #expect(copy == play && copy.fingerprint == before && copy.points == play.points
                    && copy.records == play.records, "\(note) move \(move)")
            if refusal == .move("crossing") {
                let from: Point = play.points[move.point]
                let to: Point = from.moved(move.direction)
                #expect(!WaveKnotKeeperGeometry.sweepIsClear(play.points, moving: move.point, to: to))
                var bothInGate: Bool = false
                for gate in play.level.gates where gate.contains(from) && gate.contains(to) { bothInGate = true }
                #expect(!bothInGate, "\(note) move \(move)")
            }
        } else {
            #expect(thrown == nil, "\(note) move \(move)")
            #expect(copy.records.count == play.records.count + 1 && copy.spent == play.spent + 1)
        }
        if case .move(let name)? = refusal { return name }
        return "legal"
    }

    /// SC-001 over `range`: the solution wins; every single move from every state on the way is checked. Returns the
    /// count of each named reason.
    static func enumerate(_ range: Range<Int>) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for index in range {
            let fixture: WaveKnotKeeperFixture = pool[index]
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            for step in 0...fixture.solution.count {
                if play.stage != .playing { break }
                let note: String = "fixture \(index) step \(step)"
                for point in -1...play.points.count {
                    for direction in WaveKnotKeeperDirection.allCases {
                        let name: String = probe(play, Move(point: point, direction: direction), note)
                        counts[name, default: 0] += 1
                    }
                }
                if step < fixture.solution.count {
                    try play.apply(fixture.solution[step], expecting: play.fingerprint)
                }
            }
            #expect(play.stage == .won, "fixture \(index)")
            #expect(play.spent <= fixture.level.allowance && play.failure == nil)
        }
        return counts
    }

    // MARK: SC-R02G0301-001

    @Test func solutionsWinAndRefusalsMatchFixtures0To50() throws {
        let counts: [String: Int] = try Self.enumerate(0..<50)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures50To100() throws {
        let counts: [String: Int] = try Self.enumerate(50..<100)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures100To150() throws {
        let counts: [String: Int] = try Self.enumerate(100..<150)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures150To200() throws {
        let counts: [String: Int] = try Self.enumerate(150..<200)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures200To250() throws {
        let counts: [String: Int] = try Self.enumerate(200..<250)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures250To300() throws {
        let counts: [String: Int] = try Self.enumerate(250..<300)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures300To350() throws {
        let counts: [String: Int] = try Self.enumerate(300..<350)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures350To400() throws {
        let counts: [String: Int] = try Self.enumerate(350..<400)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures400To450() throws {
        let counts: [String: Int] = try Self.enumerate(400..<450)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func solutionsWinAndRefusalsMatchFixtures450To500() throws {
        let counts: [String: Int] = try Self.enumerate(450..<500)
        #expect(counts["range", default: 0] > 0 && counts["crossing", default: 0] > 0 && counts["legal", default: 0] > 0)
    }

    @Test func everyNamedReasonIsReachable() throws {
        var counts: [String: Int] = try Self.enumerate(0..<30)
        // Bounds: a point on the edge of the lattice (x = 16 and, on another rope, z = −16).
        var edge: [Point] = Self.hexagon
        edge[0] = Point(x: 16, y: 0, z: 0)
        let edgePlay: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(try Self.constructed(points: edge))
        #expect(Self.probe(edgePlay, Move(point: 0, direction: .plusX), "edge") == "bounds")
        var floor: [Point] = Self.hexagon
        floor[3] = Point(x: -4, y: 0, z: -16)
        let floorPlay: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(try Self.constructed(points: floor))
        #expect(Self.probe(floorPlay, Move(point: 3, direction: .minusZ), "floor") == "bounds")
        // Coincident: two control points one step apart.
        var close: [Point] = Self.hexagon
        close[1] = Point(x: 4, y: 1, z: 0)
        let closePlay: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(try Self.constructed(points: close))
        #expect(Self.probe(closePlay, Move(point: 0, direction: .plusY), "close") == "coincident")
        // Tension: a bound equal to the start tension refuses a stretching step.
        let tight: WaveKnotKeeperLevel = try Self.constructed(points: Self.hexagon,
                                                              bound: WaveKnotKeeperGeometry.tension(Self.hexagon))
        let tightPlay: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(tight)
        #expect(Self.probe(tightPlay, Move(point: 0, direction: .plusX), "tight") == "tension")
        // Range on both sides.
        #expect(Self.probe(tightPlay, Move(point: -1, direction: .plusX), "tight") == "range")
        #expect(Self.probe(tightPlay, Move(point: 6, direction: .plusX), "tight") == "range")
        counts["bounds", default: 0] += 2
        counts["coincident", default: 0] += 1
        counts["tension", default: 0] += 1
        let names: [String] = ["range", "bounds", "coincident", "crossing", "tension", "legal"]
        for name in names { #expect(counts[name, default: 0] > 0, "\(name) is never reached") }
        // The fixtures alone reach crossing and, with their tight bounds, tension.
        #expect(counts["tension", default: 0] > 1, "no fixture reaches the tension bound")
    }

    // MARK: SC-R02G0301-002

    /// One seeded trace on a pool fixture: random legal moves, undo, redo and pause/resume refusals; checks undo,
    /// redo, redo clearing, stale and replay.
    static func trace(_ seed: UInt64) throws {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 9_321 &+ seed &* 104_729)
        let fixture: WaveKnotKeeperFixture = pool[random.int(0...499)]
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
        // Model stacks of (fingerprint, points) before each undoable move and after each redoable one.
        var undoModel: [(String, [Point])] = []
        var redoModel: [(String, [Point])] = []
        let actions: Int = random.int(4...30)
        for _ in 0..<actions where play.stage == .playing {
            let kind: Int = random.int(0...9)
            let before: WaveKnotKeeperPlay = play
            if kind <= 5 {
                // A move: try random moves until one is legal (at most 30 attempts).
                for _ in 0..<30 {
                    let move: Move = Move(point: random.int(0...(play.points.count - 1)), direction: random.direction())
                    if WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) != nil { continue }
                    let hadRedo: Bool = !redoModel.isEmpty
                    try play.apply(move, expecting: play.fingerprint)
                    undoModel.append((before.fingerprint, before.points))
                    redoModel.removeAll()
                    #expect(play.records.last?.previous == before.fingerprint)
                    #expect(play.records.last?.next == play.fingerprint)
                    if hadRedo && play.stage == .playing {
                        let after: WaveKnotKeeperPlay = play
                        #expect(Self.error { () throws(WaveKnotKeeperError) in try play.redo() }
                                == .move("nothing-to-redo"))
                        #expect(play == after)
                    }
                    break
                }
            } else if kind == 6 {
                if let top = undoModel.last {
                    try play.undo()
                    #expect(play.fingerprint == top.0 && play.points == top.1 && play.stage == .playing)
                    redoModel.append((before.fingerprint, before.points))
                    undoModel.removeLast()
                } else {
                    #expect(Self.error { () throws(WaveKnotKeeperError) in try play.undo() } == .move("nothing-to-undo"))
                    #expect(play == before)
                }
            } else if kind == 7 {
                if let top = redoModel.last {
                    try play.redo()
                    #expect(play.fingerprint == top.0 && play.points == top.1)
                    undoModel.append((before.fingerprint, before.points))
                    redoModel.removeLast()
                } else {
                    #expect(Self.error { () throws(WaveKnotKeeperError) in try play.redo() } == .move("nothing-to-redo"))
                    #expect(play == before)
                }
            } else if kind == 8 {
                // Paused: every action is refused with `.stage`, unchanged; resume restores the fingerprint's stage.
                try play.handle(.pause)
                let paused: WaveKnotKeeperPlay = play
                let fingerprint: String = play.fingerprint
                #expect(Self.error { () throws(WaveKnotKeeperError) in
                    try play.apply(Move(point: 0, direction: .plusX), expecting: fingerprint)
                } == .stage)
                #expect(Self.error { () throws(WaveKnotKeeperError) in try play.undo() } == .stage)
                #expect(Self.error { () throws(WaveKnotKeeperError) in try play.redo() } == .stage)
                #expect(Self.error { () throws(WaveKnotKeeperError) in try play.handle(.pause) } == .stage)
                #expect(play == paused && !play.canUndo && !play.canRedo)
                try play.handle(.resume)
                #expect(play == before)
            } else {
                // A stale previous fingerprint is refused, unchanged.
                #expect(Self.error { () throws(WaveKnotKeeperError) in
                    try play.apply(Move(point: 0, direction: .plusX), expecting: fixture.level.fingerprint)
                } == .stale)
                #expect(play == before)
            }
            #expect(play.canUndo == (play.stage == .playing && !undoModel.isEmpty))
        }
        // Replay reproduces every record, the points and the stage.
        let replayed: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: fixture.level, records: play.records)
        #expect(replayed.records == play.records && replayed.points == play.points && replayed.stage == play.stage)
        #expect(replayed.fingerprint == play.fingerprint && replayed.spent == play.spent && replayed == play)
        for index in play.records.indices {
            #expect(play.records[index].tick == index && play.records[index].seed == fixture.level.seed)
            if index > 0 { #expect(play.records[index].previous == play.records[index - 1].next) }
        }
        // Tampering with a record makes replay throw.
        if let first = play.records.first {
            var tampered: [WaveKnotKeeperRecord] = play.records
            tampered[0] = WaveKnotKeeperRecord(schema: first.schema, seed: first.seed, tick: first.tick, kind: first.kind,
                                               point: first.point, direction: first.direction.opposite,
                                               previous: first.previous, next: first.next)
            #expect(Self.error { () throws(WaveKnotKeeperError) in
                _ = try WaveKnotKeeperPlay.replay(level: fixture.level, records: tampered)
            } != nil)
            tampered[0] = WaveKnotKeeperRecord(schema: first.schema, seed: first.seed, tick: first.tick, kind: first.kind,
                                               point: first.point, direction: first.direction,
                                               previous: first.next, next: first.next)
            #expect(Self.error { () throws(WaveKnotKeeperError) in
                _ = try WaveKnotKeeperPlay.replay(level: fixture.level, records: tampered)
            } == .stale)
            let last: WaveKnotKeeperRecord = play.records[play.records.count - 1]
            tampered = play.records
            tampered[tampered.count - 1] = WaveKnotKeeperRecord(schema: last.schema, seed: last.seed, tick: last.tick,
                                                                kind: last.kind, point: last.point,
                                                                direction: last.direction, previous: last.previous,
                                                                next: String(repeating: "0", count: 64))
            #expect(Self.error { () throws(WaveKnotKeeperError) in
                _ = try WaveKnotKeeperPlay.replay(level: fixture.level, records: tampered)
            } == .malformed("record \(tampered.count - 1)"))
        }
    }

    @Test func tracesReplayAndUndoRestoresSeeds0To250() throws {
        for seed in 0..<250 { try Self.trace(UInt64(seed)) }
    }

    @Test func tracesReplayAndUndoRestoresSeeds250To500() throws {
        for seed in 250..<500 { try Self.trace(UInt64(seed)) }
    }

    @Test func undoOfEveryMoveOfASolutionRestoresEachEarlierState() throws {
        for index in 0..<100 {
            let fixture: WaveKnotKeeperFixture = Self.pool[index]
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            var states: [(String, [Point])] = []
            // Apply all but the winning move, then undo back to the start and redo forward.
            for move in fixture.solution {
                var probe: WaveKnotKeeperPlay = play
                try probe.apply(move, expecting: probe.fingerprint)
                if probe.stage != .playing { break }
                states.append((play.fingerprint, play.points))
                play = probe
            }
            let top: (String, [Point]) = (play.fingerprint, play.points)
            var later: [(String, [Point])] = []
            for k in stride(from: states.count - 1, through: 0, by: -1) {
                later.append((play.fingerprint, play.points))
                try play.undo()
                #expect(play.fingerprint == states[k].0 && play.points == states[k].1 && play.stage == .playing)
            }
            #expect(play.spent == 0 && play.points == fixture.level.points)
            for k in stride(from: later.count - 1, through: 0, by: -1) {
                try play.redo()
                #expect(play.fingerprint == later[k].0 && play.points == later[k].1)
            }
            #expect(play.fingerprint == top.0 && play.points == top.1)
            let replayed: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: fixture.level, records: play.records)
            #expect(replayed == play)
        }
    }

    // MARK: SC-R02G0301-004

    @Test func spendingTheAllowanceWithoutAWinFailsWithTheFinalSummary() throws {
        var failures: Int = 0
        for index in 0..<200 {
            let level: WaveKnotKeeperLevel = try Self.variant(Self.pool[index].level, allowance: 2 + index % 3)
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
            var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 7_321 &+ UInt64(index))
            var attempts: Int = 0
            while play.stage == .playing && attempts < 400 {
                attempts += 1
                let move: Move = Move(point: random.int(0...(play.points.count - 1)), direction: random.direction())
                if WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: level) != nil { continue }
                var moved: [Point] = play.points
                moved[move.point] = moved[move.point].moved(move.direction)
                if level.wins(moved) { continue }
                // Undo never fails a play: an undo just before the last move leaves it playing.
                if play.spent == level.allowance - 1 && play.spent > 0 {
                    var undone: WaveKnotKeeperPlay = play
                    try undone.undo()
                    #expect(undone.stage == .playing && undone.failure == nil)
                }
                try play.apply(move, expecting: play.fingerprint)
            }
            guard play.stage == .failed else { continue }
            failures += 1
            #expect(play.spent == level.allowance)
            #expect(play.failure == WaveKnotKeeperGeometry.summary(play.points) && play.failure == play.summary)
            #expect(play.records.last?.next == play.fingerprint)
            // After the failure every action is refused with `.stage`, unchanged.
            let failed: WaveKnotKeeperPlay = play
            let fingerprint: String = play.fingerprint
            for point in 0..<play.points.count {
                #expect(Self.error { () throws(WaveKnotKeeperError) in
                    try play.apply(Move(point: point, direction: .plusZ), expecting: fingerprint)
                } == .stage)
            }
            #expect(Self.error { () throws(WaveKnotKeeperError) in try play.undo() } == .stage)
            #expect(Self.error { () throws(WaveKnotKeeperError) in try play.redo() } == .stage)
            #expect(play == failed && !play.canUndo && !play.canRedo)
            // The failed play replays to the same outcome.
            let replayed: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: level, records: play.records)
            #expect(replayed == play && replayed.failure == play.failure)
        }
        #expect(failures >= 100, "only \(failures) plays spent their allowance")
    }

    @Test func aMoveBeyondTheTensionBoundIsRefusedUnchanged() throws {
        let tension: Int = WaveKnotKeeperGeometry.tension(Self.hexagon)
        let level: WaveKnotKeeperLevel = try Self.constructed(points: Self.hexagon, bound: tension, allowance: 1)
        let play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
        var stretched: [Point] = Self.hexagon
        stretched[0] = Point(x: 5, y: 0, z: 0)
        #expect(WaveKnotKeeperGeometry.tension(stretched) > level.tensionBound)
        var copy: WaveKnotKeeperPlay = play
        let fingerprint: String = play.fingerprint
        #expect(Self.error { () throws(WaveKnotKeeperError) in
            try copy.apply(Move(point: 0, direction: .plusX), expecting: fingerprint)
        } == .move("tension"))
        #expect(copy == play && copy.fingerprint == fingerprint && copy.spent == 0 && copy.records.isEmpty)
        // A move that shortens the rope is accepted, and with an allowance of 1 and no win the play fails.
        var shortened: [Point] = Self.hexagon
        shortened[0] = Point(x: 3, y: 0, z: 0)
        #expect(WaveKnotKeeperGeometry.tension(shortened) <= level.tensionBound && !level.wins(shortened))
        try copy.apply(Move(point: 0, direction: .minusX), expecting: fingerprint)
        #expect(copy.stage == .failed && copy.failure == WaveKnotKeeperGeometry.summary(shortened))
        // Across the fixtures, every tension refusal really exceeds the bound and leaves the play unchanged.
        var refused: Int = 0
        for index in 0..<100 {
            let fixturePlay: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(Self.pool[index].level)
            for point in 0..<fixturePlay.points.count {
                for direction in WaveKnotKeeperDirection.allCases {
                    let move: Move = Move(point: point, direction: direction)
                    guard WaveKnotKeeperPlay.refusal(of: move, points: fixturePlay.points,
                                                     level: fixturePlay.level) == .move("tension") else { continue }
                    refused += 1
                    var moved: [Point] = fixturePlay.points
                    moved[point] = moved[point].moved(direction)
                    #expect(WaveKnotKeeperGeometry.tension(moved) > fixturePlay.level.tensionBound)
                    var attempt: WaveKnotKeeperPlay = fixturePlay
                    let before: String = fixturePlay.fingerprint
                    #expect(Self.error { () throws(WaveKnotKeeperError) in
                        try attempt.apply(move, expecting: before)
                    } == .move("tension"))
                    #expect(attempt == fixturePlay)
                }
            }
        }
        #expect(refused > 0)
    }

    @Test func redoAndMovesNeverExceedTheAllowance() throws {
        // In `playing` the moves spent stay below the allowance (spending the last one wins or fails), so `.allowance`
        // is a guard that a reachable play never trips; redo at the limit is impossible for the same reason.
        for index in 0..<100 {
            let level: WaveKnotKeeperLevel = try Self.variant(Self.pool[index].level, allowance: 1 + index % 4)
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(level)
            var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 5_321 &+ UInt64(index))
            for _ in 0..<60 where play.stage == .playing {
                #expect(play.spent < level.allowance)
                let kind: Int = random.int(0...3)
                if kind == 0 && play.canUndo {
                    try play.undo()
                } else if kind == 1 && play.canRedo {
                    try play.redo()
                } else {
                    let move: Move = Move(point: random.int(0...(play.points.count - 1)),
                                          direction: random.direction())
                    if WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: level) == nil {
                        try play.apply(move, expecting: play.fingerprint)
                    }
                }
            }
            #expect(play.spent <= level.allowance)
            if play.stage == .failed { #expect(play.spent == level.allowance && play.failure != nil) }
            if play.stage == .won { #expect(play.failure == nil) }
        }
    }

    // MARK: Stage machine

    /// A play of `fixture` in every stage, keyed by stage.
    static func plays(_ fixture: WaveKnotKeeperFixture) throws -> [WaveKnotKeeperStage: WaveKnotKeeperPlay] {
        var plays: [WaveKnotKeeperStage: WaveKnotKeeperPlay] = [:]
        plays[.loading] = WaveKnotKeeperPlay(level: fixture.level)
        var tutorial: WaveKnotKeeperPlay = WaveKnotKeeperPlay(level: try variant(fixture.level, tutorial: true))
        try tutorial.handle(.begin)
        plays[.tutorial] = tutorial
        let playing: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
        plays[.playing] = playing
        var paused: WaveKnotKeeperPlay = playing
        try paused.handle(.pause)
        plays[.paused] = paused
        var won: WaveKnotKeeperPlay = playing
        for move in fixture.solution where won.stage == .playing { try won.apply(move, expecting: won.fingerprint) }
        plays[.won] = won
        var result: WaveKnotKeeperPlay = won
        try result.handle(.showResult)
        plays[.result] = result
        // Failed: an allowance of 1 and the first legal move that does not win.
        let one: WaveKnotKeeperLevel = try variant(fixture.level, allowance: 1)
        var failed: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(one)
        search: for point in 0..<one.points.count {
            for direction in WaveKnotKeeperDirection.allCases {
                let move: Move = Move(point: point, direction: direction)
                guard WaveKnotKeeperPlay.refusal(of: move, points: failed.points, level: one) == nil else { continue }
                var moved: [Point] = failed.points
                moved[point] = moved[point].moved(direction)
                if one.wins(moved) { continue }
                try failed.apply(move, expecting: failed.fingerprint)
                break search
            }
        }
        if failed.stage == .failed { plays[.failed] = failed }
        return plays
    }

    @Test func theStageMachineTableIsComplete() throws {
        var checkedFailed: Bool = false
        for index in 0..<20 {
            let plays: [WaveKnotKeeperStage: WaveKnotKeeperPlay] = try Self.plays(Self.pool[index])
            for stage in WaveKnotKeeperStage.allCases {
                guard let play = plays[stage] else { continue }
                if stage == .failed { checkedFailed = true }
                #expect(play.stage == stage)
                for event in Self.events {
                    var copy: WaveKnotKeeperPlay = play
                    let thrown: WaveKnotKeeperError? = Self.error { () throws(WaveKnotKeeperError) in
                        try copy.handle(event)
                    }
                    let expected: WaveKnotKeeperStage?
                    switch (stage, event) {
                    case (.loading, .begin): expected = play.level.tutorial ? .tutorial : .playing
                    case (.tutorial, .dismissTutorial): expected = .playing
                    case (.playing, .pause): expected = .paused
                    case (.paused, .resume): expected = .playing
                    case (.won, .showResult), (.failed, .showResult): expected = .result
                    default: expected = nil
                    }
                    if let expected {
                        #expect(thrown == nil && copy.stage == expected, "\(stage) \(event)")
                        #expect(copy.points == play.points && copy.records == play.records && copy.spent == play.spent)
                    } else {
                        #expect(thrown == .stage, "\(stage) \(event)")
                        #expect(copy == play && copy.fingerprint == play.fingerprint, "\(stage) \(event)")
                    }
                }
                // Outside `playing`, moves, undo and redo are refused with `.stage`, unchanged.
                if stage != .playing {
                    var copy: WaveKnotKeeperPlay = play
                    let fingerprint: String = play.fingerprint
                    #expect(Self.error { () throws(WaveKnotKeeperError) in
                        try copy.apply(Move(point: 0, direction: .plusX), expecting: fingerprint)
                    } == .stage)
                    #expect(Self.error { () throws(WaveKnotKeeperError) in try copy.undo() } == .stage)
                    #expect(Self.error { () throws(WaveKnotKeeperError) in try copy.redo() } == .stage)
                    #expect(copy == play)
                }
            }
        }
        #expect(checkedFailed)
    }

    @Test func aTutorialLevelPassesThroughTheTutorialAndReplays() throws {
        for index in 0..<20 {
            let fixture: WaveKnotKeeperFixture = Self.pool[index]
            let level: WaveKnotKeeperLevel = try Self.variant(fixture.level, tutorial: true)
            #expect(level.tutorial && level.fingerprint != fixture.level.fingerprint)
            var play: WaveKnotKeeperPlay = WaveKnotKeeperPlay(level: level)
            #expect(play.stage == .loading && play.spent == 0 && play.records.isEmpty && play.points == level.points)
            try play.handle(.begin)
            #expect(play.stage == .tutorial)
            let tutorial: WaveKnotKeeperPlay = play
            let fingerprint: String = play.fingerprint
            #expect(Self.error { () throws(WaveKnotKeeperError) in
                try play.apply(fixture.solution[0], expecting: fingerprint)
            } == .stage)
            #expect(play == tutorial)
            try play.handle(.dismissTutorial)
            #expect(play.stage == .playing)
            for move in fixture.solution where play.stage == .playing {
                try play.apply(move, expecting: play.fingerprint)
            }
            #expect(play.stage == .won)
            let replayed: WaveKnotKeeperPlay = try WaveKnotKeeperPlay.replay(level: level, records: play.records)
            #expect(replayed == play)
            // A level without a tutorial begins straight in `playing`.
            var direct: WaveKnotKeeperPlay = WaveKnotKeeperPlay(level: fixture.level)
            try direct.handle(.begin)
            #expect(direct.stage == .playing)
        }
    }

    // T-R02G0301-013 (edge case "a move through a crossing gate", FR-R02G0301-002): a bow tie whose strand P0–P1 passes
    // over P4–P5 at (2, 2). Pushing P1 down one step makes the swept triangle touch P4–P5 at (2, 2, 0): refused as a
    // crossing without a gate; inside a gate holding both ends the move is accepted (the projection is degenerate while
    // the strands meet at equal z), and the next step passes the strand under, flipping the crossing's sign — the count
    // stays 1, as passing one strand through another can only swap over and under — which wins the level whose target is
    // the opposite writhe.
    @Test func aCrossingGateLetsAStrandPassThroughAndFlipTheCrossing() throws {
        typealias Point = WaveKnotKeeperPoint
        let rope: [Point] = [Point(x: 0, y: 0, z: 0), Point(x: 4, y: 4, z: 1), Point(x: 6, y: 4, z: 2),
                             Point(x: 6, y: 0, z: 0), Point(x: 4, y: 0, z: 0), Point(x: 0, y: 4, z: 0)]
        let start: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(rope)
        #expect(start.crossings == 1 && !start.degenerate && abs(start.writhe) == 1)
        let target: WaveKnotKeeperTarget = try WaveKnotKeeperTarget(crossings: 1, writhe: -start.writhe)
        let gate: WaveKnotKeeperGate = try WaveKnotKeeperGate(min: Point(x: 4, y: 4, z: -1), max: Point(x: 4, y: 4, z: 1))
        let down: WaveKnotKeeperMove = WaveKnotKeeperMove(point: 1, direction: .minusZ)
        // Without the gate the step is refused and nothing changes.
        let open: WaveKnotKeeperLevel = try WaveKnotKeeperLevel(id: "no-gate", seed: 2_321, band: 1, points: rope,
                                                                gates: [], target: target, tensionBound: 1_000,
                                                                allowance: 4)
        var blocked: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(open)
        let before: WaveKnotKeeperPlay = blocked
        #expect(!WaveKnotKeeperGeometry.sweepIsClear(rope, moving: 1, to: Point(x: 4, y: 4, z: 0)))
        #expect(throws: WaveKnotKeeperError.move("crossing")) { try blocked.apply(down, expecting: blocked.fingerprint) }
        #expect(blocked == before)
        // With the gate the strand passes through.
        let gated: WaveKnotKeeperLevel = try WaveKnotKeeperLevel(id: "gate", seed: 2_321, band: 1, points: rope,
                                                                 gates: [gate], target: target, tensionBound: 1_000,
                                                                 allowance: 4)
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(gated)
        try play.apply(down, expecting: play.fingerprint)
        #expect(play.stage == .playing && play.summary.degenerate)
        try play.apply(down, expecting: play.fingerprint)
        let after: WaveKnotKeeperSummary = play.summary
        #expect(after.crossings == 1 && !after.degenerate && after.writhe == -start.writhe)
        #expect(play.stage == .won && play.spent == 2)
        // A step leaving the gate is checked again: from z = −1 down to z = −2 nothing is in the way, so it is clear.
        #expect(WaveKnotKeeperPlay.refusal(of: down, points: play.points, level: gated) == nil)
    }
}
