// FacetedForgePlayTests — feature 371 (R02-G08-01) T-R02G0801-004 (FR-R02G0801-004 … 008, 010, 011; SC-R02G0801-002,
// 004; clarifications Q2, Q4, Q5). The play of a Faceted Forge level: the full stage table of `handle(_:)`; the 500
// fixtures' known cuts win exactly on their last cut, each accepted cut spending one cut, and on a budget of exactly
// that many cuts; a sliver exactly at the limit is allowed and one strictly below fails on the exact cut, naming the
// piece and the cut; the budget fails on the exact cut, with budgets one cut either side; the validation order stage,
// stale, range, miss, with every refusal reachable, spending nothing and leaving the play unchanged; undo from failed
// returns to playing and a won play is final; undo and redo restore exact fingerprints and a new cut clears redo; 500
// seeded traces (seed 2_371) replay to the same records, fingerprint and outcome, and a tampered record is refused.
// Explicit types, plain loops; each test well under 10 s.
import Foundation
import Testing
@testable import FacetedForgeCore

@Suite struct FacetedForgePlayTests {
    typealias Play = FacetedForgePlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(FacetedForgeAction)
        case stale(FacetedForgeAction)
        case undo
        case redo
        case event(FacetedForgeEvent)
    }

    static let events: [FacetedForgeEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(FacetedForgeError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: FacetedForgeAction) throws(FacetedForgeError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> FacetedForgeError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused \(op) changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.cuts == play.cuts, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: FacetedForgeLevel) throws(FacetedForgeError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// `base` with another budget.
    static func level(_ base: FacetedForgeLevel, budget: Int) throws(FacetedForgeError) -> FacetedForgeLevel {
        try FacetedForgeLevel(id: base.id, seed: base.seed, difficulty: base.difficulty, planes: base.planes,
                              budget: budget, sliver: base.sliver, target: base.target, tutorial: base.tutorial)
    }

    /// The cube −a … a.
    static func cube(_ a: Int) -> [FacetedForgeHalfSpace] {
        let slabs: [[FacetedForgeHalfSpace]] = [0, 1, 2].map { FacetedForgeFixtures.slab($0, -a, a) }
        return slabs.flatMap { $0 }.sorted()
    }

    /// The cube −a … a with the target "two halves of 6 faces", the given budget and sliver limit.
    static func cubeLevel(_ a: Int, budget: Int, sliver: FacetedForgeFraction,
                          tutorial: Bool = false) throws(FacetedForgeError) -> FacetedForgeLevel {
        let half: FacetedForgeFraction = try FacetedForgeFraction(1, 2)
        let target: [FacetedForgeTargetPiece] = [FacetedForgeTargetPiece(share: half, faces: 6),
                                                 FacetedForgeTargetPiece(share: half, faces: 6)]
        return try FacetedForgeLevel(id: "cube-\(a)", seed: UInt64(a), difficulty: 1, planes: cube(a), budget: budget,
                                     sliver: sliver, target: target, tutorial: tutorial)
    }

    /// A random cut that crosses one of `pieces`: random operands (depths −12 … 12) until the plane crosses the piece.
    static func randomCut(_ pieces: [FacetedForgePiece], _ random: inout FacetedForgeRandom) -> FacetedForgeAction {
        while true {
            let index: Int = random.int(0...(pieces.count - 1))
            let direction: Int = random.int(0...12)
            let depth: Int = random.int(-12...12)
            if pieces[index].isCrossed(direction: direction, depth: depth) { return .cut(index, direction, depth) }
        }
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: FacetedForgeLevel = try Self.cubeLevel(2, budget: 2, sliver: FacetedForgeFraction(1, 16),
                                                                 tutorial: true)
        let without: FacetedForgeLevel = try Self.cubeLevel(2, budget: 2, sliver: FacetedForgeFraction(1, 16))
        let halve: FacetedForgeAction = .cut(0, 0, 0)

        // loading: only begin.
        var loading = Play(level: withTutorial)
        #expect(loading.stage == .loading)
        #expect(loading.cuts == 0)
        #expect(loading.remaining == 2)
        #expect(loading.pieces == [withTutorial.crystal])
        #expect(loading.shares == [.one])
        for event in Self.events where event != .begin {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(halve)) == .stage)
        #expect(Self.refusal(loading, .undo) == .stage)
        #expect(Self.refusal(loading, .redo) == .stage)
        try loading.handle(.begin)
        #expect(loading.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(halve)) == .stage)
        #expect(Self.refusal(loading, .undo) == .stage)
        #expect(Self.refusal(loading, .redo) == .stage)
        try loading.handle(.dismissTutorial)
        #expect(loading.stage == .playing)

        // No tutorial: begin goes straight to playing.
        var direct = Play(level: without)
        try direct.handle(.begin)
        #expect(direct.stage == .playing)

        // playing: only pause.
        for event in Self.events where event != .pause {
            #expect(Self.refusal(direct, .event(event)) == .stage)
        }
        try direct.handle(.pause)
        #expect(direct.stage == .paused)

        // paused: only resume; cuts refused; undo and redo judged (nothing to undo here).
        for event in Self.events where event != .resume {
            #expect(Self.refusal(direct, .event(event)) == .stage)
        }
        #expect(Self.refusal(direct, .act(halve)) == .stage)
        #expect(Self.refusal(direct, .undo) == .action("nothing-to-undo"))
        #expect(Self.refusal(direct, .redo) == .action("nothing-to-redo"))
        try direct.handle(.resume)
        #expect(direct.stage == .playing)

        // won: only showResult; then result refuses everything.
        var won: Play = direct
        try Self.act(&won, halve)
        #expect(won.stage == .won)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(.cut(0, 0, 1))) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(halve)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)

        // failed: only showResult; cuts and redo refused, undo accepted.
        var failed: Play = try Self.playing(try Self.cubeLevel(2, budget: 1, sliver: FacetedForgeFraction(1, 16)))
        try Self.act(&failed, .cut(0, 0, 1))
        #expect(failed.stage == .failed)
        #expect(failed.failure == .budget)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(.cut(0, 0, 0))) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        #expect(failed.canUndo)
        #expect(!failed.canRedo)
        try failed.handle(.showResult)
        #expect(failed.stage == .result)
        #expect(Self.refusal(failed, .undo) == .stage)
    }

    // MARK: - Known solutions

    @Test func fixtureCutsWinOnTheirLastCut() throws {
        for fixture in FacetedForgeFixtures.fixtures(500) {
            var play: Play = try Self.playing(fixture.level)
            for (step, action) in fixture.actions.enumerated() {
                #expect(play.stage == .playing, "\(fixture.level.id) ended before cut \(step)")
                let before: String = play.fingerprint
                try Self.act(&play, action)
                #expect(play.cuts == step + 1)
                #expect(play.remaining == fixture.level.budget - step - 1)
                #expect(play.pieces.count == step + 2)
                #expect(play.pieces == FacetedForgePiece.canonical(play.pieces))
                #expect(play.records.count == step + 1)
                #expect(play.records[step].previous == before)
                #expect(play.records[step].next == play.fingerprint)
                #expect(play.records[step].cut == step)
                #expect(play.records[step].kind == .cut)
                #expect(play.records[step].action == action)
                #expect(play.records[step].seed == fixture.level.seed)
                #expect(play.records[step].schema == Play.schema)
            }
            #expect(play.stage == .won, "\(fixture.level.id)")
            #expect(play.failure == nil)
            // The truth metric: the shares sum to one.
            var total: FacetedForgeFraction = .zero
            for share in play.shares { total = try total.adding(share) }
            #expect(total == .one)
            var made: [FacetedForgeTargetPiece] = []
            for (index, piece) in play.pieces.enumerated() {
                made.append(FacetedForgeTargetPiece(share: play.shares[index], faces: piece.faceCount))
            }
            #expect(made.sorted() == fixture.level.target)
        }
    }

    /// A budget of exactly the solution length wins on the last cut; one more leaves a cut unspent.
    @Test func aWinOnTheLastCutOfTheBudgetWins() throws {
        for fixture in FacetedForgeFixtures.fixtures(100) {
            let n: Int = fixture.actions.count
            for budget in [n, n + 1] where budget <= FacetedForgeLevel.budgets.upperBound {
                var play: Play = try Self.playing(try Self.level(fixture.level, budget: budget))
                for action in fixture.actions { try Self.act(&play, action) }
                #expect(play.stage == .won, "\(fixture.level.id) budget \(budget)")
                #expect(play.failure == nil)
                #expect(play.remaining == budget - n)
            }
        }
    }

    // MARK: - Sliver

    /// Cutting the 2-cube at x = 1 leaves a quarter: a limit of 1/4 allows it, 3/10 fails on that cut naming piece 2.
    @Test func aSliverAtTheLimitIsAllowedAndBelowItFails() throws {
        let quarter: FacetedForgeFraction = try FacetedForgeFraction(1, 4)
        var atLimit: Play = try Self.playing(try Self.cubeLevel(2, budget: 3, sliver: quarter))
        try Self.act(&atLimit, .cut(0, 0, 1))
        #expect(atLimit.stage == .playing)
        #expect(atLimit.failure == nil)
        #expect(atLimit.shares == [try FacetedForgeFraction(3, 4), quarter])

        var below: Play = try Self.playing(try Self.cubeLevel(2, budget: 3, sliver: FacetedForgeFraction(3, 10)))
        try Self.act(&below, .cut(0, 0, 1))
        #expect(below.stage == .failed)
        #expect(below.failure == .sliver(1, 0))
        #expect(below.failure?.code == "sliver")
        #expect(below.cuts == 1)
        #expect(below.records.count == 1)
        #expect(below.records[0].next == below.fingerprint)
    }

    /// The second cut of the 2-cube (x = 1, then the larger piece at y = 1) leaves 3/16: at a limit of 3/16 it is
    /// allowed, at 1/4 it fails on cut index 1, naming the new piece at index 2 of the canonical order.
    @Test func aSliverOnALaterCutNamesThePieceAndTheCut() throws {
        let small: FacetedForgeFraction = try FacetedForgeFraction(3, 16)
        let quarter: FacetedForgeFraction = try FacetedForgeFraction(1, 4)
        let limits: [(FacetedForgeFraction, FacetedForgeFailure?)] = [(small, nil), (quarter, .sliver(2, 1))]
        for (limit, failure) in limits {
            var play: Play = try Self.playing(try Self.cubeLevel(2, budget: 4, sliver: limit))
            try Self.act(&play, .cut(0, 0, 1))
            #expect(play.stage == .playing)
            try Self.act(&play, .cut(0, 1, 1))
            #expect(play.failure == failure, "limit \(limit.text)")
            #expect(play.stage == (failure == nil ? .playing : .failed))
            #expect(play.shares == [try FacetedForgeFraction(9, 16), quarter, small])
        }
    }

    /// A sliver is judged before the win and the budget: a sliver on the last cut of the budget is named a sliver.
    @Test func aSliverIsJudgedBeforeTheBudget() throws {
        var play: Play = try Self.playing(try Self.cubeLevel(2, budget: 1, sliver: FacetedForgeFraction(3, 10)))
        try Self.act(&play, .cut(0, 0, 1))
        #expect(play.failure == .sliver(1, 0))
        #expect(play.remaining == 0)
    }

    // MARK: - Budget

    /// Slices of the 6-cube at x = 5, 4, 3, … never win and never make a sliver; budget b stays playing after b − 1
    /// cuts and fails on cut b, for b = 1 … 6 (each one cut either side of its neighbours).
    @Test func theBudgetFailsOnTheExactCut() throws {
        for budget in 1...6 {
            let level: FacetedForgeLevel = try Self.cubeLevel(6, budget: budget, sliver: FacetedForgeFraction(1, 16))
            var play: Play = try Self.playing(level)
            for step in 0..<budget {
                #expect(play.stage == .playing, "budget \(budget) cut \(step)")
                #expect(play.remaining == budget - step)
                try Self.act(&play, .cut(0, 0, 5 - step))
            }
            #expect(play.stage == .failed, "budget \(budget)")
            #expect(play.failure == .budget)
            #expect(play.failure?.code == "budget")
            #expect(play.cuts == budget)
            #expect(play.remaining == 0)
            #expect(play.records.last?.cut == budget - 1)
            // Undo from failed returns to playing with the cut given back.
            try play.undo()
            #expect(play.stage == .playing)
            #expect(play.failure == nil)
            #expect(play.cuts == budget - 1)
            #expect(play.records.last?.kind == .undo)
        }
    }

    // MARK: - Refusals

    @Test func everyRefusalIsReachableInOrder() throws {
        let level: FacetedForgeLevel = try Self.cubeLevel(2, budget: 3, sliver: FacetedForgeFraction(1, 16))
        var play: Play = try Self.playing(level)
        // range: piece index, direction and depth.
        for action in [FacetedForgeAction.cut(1, 0, 0), .cut(-1, 0, 0), .cut(0, 13, 0), .cut(0, -1, 0),
                       .cut(0, 0, 25), .cut(0, 0, -25)] {
            #expect(Self.refusal(play, .act(action)) == .action("range"))
            // stale comes before range.
            #expect(Self.refusal(play, .stale(action)) == .stale)
        }
        // miss: a plane on the boundary or outside the piece; a body diagonal through a corner only.
        for action in [FacetedForgeAction.cut(0, 0, 2), .cut(0, 0, -2), .cut(0, 1, 24), .cut(0, 9, 6), .cut(0, 9, -6)] {
            #expect(Self.refusal(play, .act(action)) == .miss)
            #expect(Self.refusal(play, .stale(action)) == .stale)
        }
        // nothing to undo or redo.
        #expect(Self.refusal(play, .undo) == .action("nothing-to-undo"))
        #expect(Self.refusal(play, .redo) == .action("nothing-to-redo"))
        // stage comes before stale and range.
        try play.handle(.pause)
        #expect(Self.refusal(play, .stale(.cut(9, 99, 99))) == .stage)
        #expect(Self.refusal(play, .act(.cut(0, 0, 0))) == .stage)
        try play.handle(.resume)
        // A refused cut leaves the play able to cut: accepted after the refusals.
        try Self.act(&play, .cut(0, 0, 1))
        #expect(play.cuts == 1)
        #expect(play.records.count == 1)
        #expect(Self.refusal(play, .act(.cut(2, 0, 0))) == .action("range"))
        #expect(Self.refusal(play, .act(.cut(1, 0, 0))) == .miss)
        #expect(FacetedForgeError.action("range").reasonCode == "r02-g08.action")
        #expect(FacetedForgeError.miss.reasonCode == "r02-g08.miss")
    }

    // MARK: - Undo and redo

    @Test func undoAndRedoRestoreExactFingerprints() throws {
        for fixture in FacetedForgeFixtures.fixtures(100) {
            var play: Play = try Self.playing(fixture.level)
            var prints: [String] = [play.fingerprint]
            var states: [Play] = [play]
            for action in fixture.actions {
                try Self.act(&play, action)
                prints.append(play.fingerprint)
                states.append(play)
            }
            #expect(play.stage == .won)
            #expect(Self.refusal(play, .undo) == .stage)
            // Rebuild to one cut before the win and walk back and forth.
            var walk: Play = try Self.playing(fixture.level)
            let n: Int = fixture.actions.count
            for action in fixture.actions.dropLast() { try Self.act(&walk, action) }
            for step in stride(from: n - 1, to: 0, by: -1) {
                let cutsBefore: Int = walk.cuts
                try walk.undo()
                #expect(walk.fingerprint == prints[step - 1])
                #expect(walk.pieces == states[step - 1].pieces)
                #expect(walk.shares == states[step - 1].shares)
                #expect(walk.cuts == step - 1)
                #expect(walk.records.last?.kind == .undo)
                #expect(walk.records.last?.cut == cutsBefore)
                #expect(walk.records.last?.action == nil)
            }
            #expect(!walk.canUndo)
            for step in 1..<n {
                try walk.redo()
                #expect(walk.fingerprint == prints[step])
                #expect(walk.records.last?.kind == .redo)
            }
            #expect(!walk.canRedo)
            // Undo while paused stays paused; a new cut clears redo.
            try walk.handle(.pause)
            if walk.canUndo {
                try walk.undo()
                #expect(walk.stage == .paused)
                #expect(walk.canRedo)
                try walk.handle(.resume)
                try Self.act(&walk, fixture.actions[n - 2])
                #expect(!walk.canRedo)
                #expect(Self.refusal(walk, .redo) == .action("nothing-to-redo"))
            } else {
                try walk.handle(.resume)
            }
            try Self.act(&walk, fixture.actions[n - 1])
            #expect(walk.stage == .won)
            #expect(walk.fingerprint == prints[n])
        }
    }

    /// Redo of a failing cut fails again with the same fingerprint.
    @Test func redoOfAFailingCutFailsAgain() throws {
        var play: Play = try Self.playing(try Self.cubeLevel(2, budget: 3, sliver: FacetedForgeFraction(3, 10)))
        try Self.act(&play, .cut(0, 0, 1))
        let failed: String = play.fingerprint
        try play.undo()
        #expect(play.stage == .playing)
        #expect(play.cuts == 0)
        try play.redo()
        #expect(play.stage == .failed)
        #expect(play.failure == .sliver(1, 0))
        #expect(play.fingerprint == failed)
        #expect(play.records.map(\.kind) == [.cut, .undo, .redo])
    }

    // MARK: - Replay

    @Test func seededTracesReplayToIdenticalFingerprints() throws {
        var random = FacetedForgeRandom(seed: FacetedForgeFixtures.seed)
        var outcomes: Set<FacetedForgeStage> = []
        for fixture in FacetedForgeFixtures.fixtures(500) {
            var play: Play = try Self.playing(fixture.level)
            for _ in 0..<12 {
                if play.stage == .won { break }
                if play.stage == .failed {
                    try play.undo()
                    continue
                }
                switch random.int(0...9) {
                case 0: try? play.undo()
                case 1: try? play.redo()
                case 2:
                    try play.handle(.pause)
                    try? play.undo()
                    try play.handle(.resume)
                case 3, 4:
                    let index: Int = play.cuts < fixture.actions.count ? play.cuts : 0
                    try? Self.act(&play, fixture.actions[index])
                default:
                    try Self.act(&play, Self.randomCut(play.pieces, &random))
                }
            }
            outcomes.insert(play.stage)
            var replayed: Play = try Play.replay(level: fixture.level, records: play.records)
            #expect(replayed.records == play.records, "\(fixture.level.id)")
            if let last = play.records.last { #expect(replayed.fingerprint == last.next) }
            // A resume after the last (paused) undo is not a record: resume the replay to match.
            if replayed.stage == .paused && play.stage == .playing { try replayed.handle(.resume) }
            #expect(replayed.stage == play.stage)
            #expect(replayed.fingerprint == play.fingerprint)
            #expect(replayed.pieces == play.pieces)
            #expect(replayed.shares == play.shares)
            #expect(replayed.cuts == play.cuts)
            #expect(replayed.failure == play.failure)
        }
        #expect(outcomes.contains(.playing))
        #expect(outcomes.contains(.won))
    }

    @Test func aTamperedTraceIsRefused() throws {
        let fixture: FacetedForgeFixture = FacetedForgeFixtures.fixture(FacetedForgeFixtures.seed + 1)
        var play: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&play, action) }
        let records: [FacetedForgeRecord] = play.records
        // A changed next fingerprint.
        var changed: [FacetedForgeRecord] = records
        let first: FacetedForgeRecord = records[0]
        changed[0] = FacetedForgeRecord(schema: first.schema, seed: first.seed, cut: first.cut, kind: first.kind,
                                        action: first.action, previous: first.previous, next: "0000")
        #expect(throws: FacetedForgeError.malformed("record 0")) {
            _ = try Play.replay(level: fixture.level, records: changed)
        }
        // A changed previous fingerprint.
        changed[0] = FacetedForgeRecord(schema: first.schema, seed: first.seed, cut: first.cut, kind: first.kind,
                                        action: first.action, previous: "0000", next: first.next)
        #expect(throws: FacetedForgeError.malformed("replay")) {
            _ = try Play.replay(level: fixture.level, records: changed)
        }
        // A cut record without its action.
        changed[0] = FacetedForgeRecord(schema: first.schema, seed: first.seed, cut: first.cut, kind: .cut,
                                        action: nil, previous: first.previous, next: first.next)
        #expect(throws: FacetedForgeError.malformed("record 0")) {
            _ = try Play.replay(level: fixture.level, records: changed)
        }
        // The records round-trip through JSON and still replay.
        let data: Data = try JSONEncoder().encode(records)
        let decoded: [FacetedForgeRecord] = try JSONDecoder().decode([FacetedForgeRecord].self, from: data)
        #expect(decoded == records)
        #expect(try Play.replay(level: fixture.level, records: decoded).fingerprint == play.fingerprint)
    }
}
