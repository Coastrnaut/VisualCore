// AcousticConstellatorPlayTests — feature 421 (R02-G13-01) T-R02G1301-004 (FR-R02G1301-003 … 008, 011, 014;
// SC-R02G1301-002, 003, 004; clarifications Q3, Q4, Q5). The play of an Acoustic Constellator level: the full stage
// table of `handle(_:)`; the fixtures' known actions keep the play going and win exactly on the closing listen, with the
// report and the label after every action equal to the level's listen and the label of the play's links; each failure
// named on constructed levels (`missing` with the lowest pair, `disconnected` with its tick and the lowest snapped link,
// `incoherent` with the longest run); budget failure on the exact action with budgets one action either side, and a
// listen on the last action wins; the validation order stage, stale, action (star, self, exists, degree, limit,
// missing, fixed, step) with every refusal reachable, spending nothing and leaving the play unchanged; the fingerprint
// is the SHA-256 of its canonical text; undo of every action restores the exact fingerprint, undo from failed returns
// to playing, a won play is final and a new action clears redo; 500 seeded traces (seed 2_421 onwards) replay to the
// same records, fingerprints and outcome, and tampered traces are refused. Explicit types, plain loops, short traces;
// each test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import AcousticConstellatorCore

struct AcousticConstellatorPlayTests {
    typealias Play = AcousticConstellatorPlay
    typealias Link = AcousticConstellatorLink

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(AcousticConstellatorAction)
        case stale(AcousticConstellatorAction)
        case undo
        case redo
        case event(AcousticConstellatorEvent)
    }

    static let events: [AcousticConstellatorEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(AcousticConstellatorError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: AcousticConstellatorAction) throws(AcousticConstellatorError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> AcousticConstellatorError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused \(op) changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.actionsSpent == play.actionsSpent, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: AcousticConstellatorLevel) throws(AcousticConstellatorError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A constructed level: stars at `phases` with `rates`, drawn on the grid's diagonal.
    static func level(rates: [Int], phases: [Int], fixed: [Link], symbol: [Link], coupling: Int = 2,
                      degreeLimit: Int = 2, linkLimit: Int = 3, snapLimit: Int = 2, threshold: Int = 9,
                      hold: Int = 3, window: Int = 6, budget: Int = 5,
                      tutorial: Bool = false) throws(AcousticConstellatorError) -> AcousticConstellatorLevel {
        var stars: [AcousticConstellatorStar] = []
        for index in 0..<rates.count {
            stars.append(AcousticConstellatorStar(x: index, y: index, z: index, rate: rates[index],
                                                  phase: phases[index]))
        }
        return try AcousticConstellatorLevel(id: "play-case", seed: 77, difficulty: 1, stars: stars, fixedLinks: fixed,
                                             symbol: symbol, coupling: coupling, degreeLimit: degreeLimit,
                                             linkLimit: linkLimit, snapLimit: snapLimit, threshold: threshold,
                                             hold: hold, window: window, budget: budget, tutorial: tutorial)
    }

    /// The hand level (three stars of rate 1 at phases 0, 0, 1; fixed 0–1; symbol 0–1, 1–2) with another budget or
    /// tutorial flag.
    static func hand(budget: Int = 5, tutorial: Bool = false, threshold: Int = 9, hold: Int = 3,
                     window: Int = 6) throws(AcousticConstellatorError) -> AcousticConstellatorLevel {
        try level(rates: [1, 1, 1], phases: [0, 0, 1], fixed: [Link(a: 0, b: 1)],
                  symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], threshold: threshold, hold: hold, window: window,
                  budget: budget, tutorial: tutorial)
    }

    /// The play action of a fixture tuple.
    static func action(_ tuple: (kind: String, a: Int, b: Int)) -> AcousticConstellatorAction {
        switch tuple.kind {
        case "link": .link(tuple.a, tuple.b)
        case "unlink": .unlink(tuple.a, tuple.b)
        case "nudge": .nudge(tuple.a, tuple.b)
        default: .listen
        }
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: AcousticConstellatorLevel = try Self.hand(tutorial: true)
        let without: AcousticConstellatorLevel = try Self.hand()
        let nudge: AcousticConstellatorAction = .nudge(0, 1)

        // loading: only begin.
        var play = Play(level: withTutorial)
        #expect(play.stage == .loading)
        #expect(play.links == [Link(a: 0, b: 1)])
        #expect(play.phases == [0, 0, 1])
        #expect(play.actionsSpent == 0)
        #expect(play.actionsLeft == 5)
        #expect(play.failure == nil)
        #expect(play.report == withTutorial.listen(links: [Link(a: 0, b: 1)], phases: [0, 0, 1]))
        #expect(play.label == AcousticConstellatorLabel.label(stars: 3, links: [Link(a: 0, b: 1)]))
        #expect(!play.matchesSymbol)
        #expect(!play.canUndo && !play.canRedo)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(nudge)) == .stage)
        #expect(Self.refusal(play, .act(.listen)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(nudge)) == .stage)
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

        // paused: resume only; actions refused by stage, even stale or invalid ones.
        for event in Self.events where event != .resume {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(nudge)) == .stage)
        #expect(Self.refusal(play, .act(.listen)) == .stage)
        #expect(Self.refusal(play, .stale(.link(99, 99))) == .stage)
        try play.handle(.resume)
        #expect(play.stage == .playing)

        // won: showResult only; undo refused (final).
        var won: Play = try Self.playing(without)
        try Self.act(&won, .link(2, 1))
        try Self.act(&won, .listen)
        #expect(won.stage == .won)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(nudge)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
        #expect(!won.canUndo && !won.canRedo)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(.listen)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)

        // failed: showResult, undo; actions and redo refused.
        var failed: Play = try Self.playing(without)
        try Self.act(&failed, .listen)
        #expect(failed.stage == .failed)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(nudge)) == .stage)
        #expect(Self.refusal(failed, .act(.listen)) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        #expect(failed.canUndo)
        var shown: Play = failed
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        #expect(Self.refusal(shown, .undo) == .stage)
        #expect(!shown.canUndo)
    }

    // MARK: - Known actions

    /// The fixtures: the known links and nudges keep the play going (the report always the level's listen of the play's
    /// links and phases, the label that of its links), and the listen after them wins on the exact tick of the level's
    /// listen of the winning state.
    @Test func fixturesWinOnTheExactListen() throws {
        let fixtures: [AcousticConstellatorFixture] = AcousticConstellatorFixtures.fixtures(200)
        for fixture in fixtures {
            let level: AcousticConstellatorLevel = fixture.level
            var play: Play = try Self.playing(level)
            let count: Int = fixture.winningActions.count
            for number in 0..<(count - 1) {
                let action: AcousticConstellatorAction = Self.action(fixture.winningActions[number])
                #expect(action != .listen)
                try Self.act(&play, action)
                #expect(play.stage == .playing)
                #expect(play.failure == nil)
                #expect(play.actionsSpent == number + 1)
                #expect(play.links == play.links.sorted())
                #expect(play.report == level.listen(links: play.links, phases: play.phases))
                #expect(play.records.last?.kind == action.kind)
            }
            #expect(Set(play.links) == Set(fixture.winningLinks))
            #expect(play.phases == fixture.winningPhases)
            #expect(Self.action(fixture.winningActions[count - 1]) == .listen)
            try Self.act(&play, .listen)
            #expect(play.stage == .won, "fixture \(level.seed) did not win")
            #expect(play.failure == nil)
            #expect(play.actionsSpent == count)
            let expected: AcousticConstellatorListen = level.listen(links: fixture.winningLinks,
                                                                    phases: fixture.winningPhases)
            #expect(play.report.outcome == expected.outcome)
            #expect(play.report.won)
            #expect(play.records.last?.kind == .listen)
            #expect(play.records.count == count)
            // The label reports the winning graph (checked on constellations of up to 6 stars to keep the run short;
            // the 8-star label search visits 8! orderings).
            if level.stars.count <= 6 {
                #expect(play.label == AcousticConstellatorLabel.label(stars: level.stars.count,
                                                                      links: fixture.winningLinks))
                #expect(play.matchesSymbol == (play.label == level.symbolLabel))
                if Set(fixture.winningLinks) == Set(level.symbol) { #expect(play.matchesSymbol) }
            }

            // A bare listen of the level as loaded fails, never wins.
            var early: Play = try Self.playing(level)
            try Self.act(&early, .listen)
            #expect(early.stage == .failed)
            #expect(early.failure != nil)
        }
    }

    // MARK: - Failures

    /// Each failure kind named on constructed levels; the failure follows the listen's outcome exactly.
    @Test func failuresAreNamed() throws {
        // missing: the hand level as loaded lacks 1–2.
        var missing: Play = try Self.playing(try Self.hand())
        try Self.act(&missing, .listen)
        #expect(missing.failure == .missing(Link(a: 1, b: 2)))
        #expect(missing.failure?.code == "missing")
        #expect(missing.actionsSpent == 1)

        // missing names the lowest pair: symbol 2–3, 0–3, 1–3 with nothing linked names 0–3.
        let star: AcousticConstellatorLevel = try Self.level(
            rates: [1, 1, 1, 1], phases: [0, 0, 0, 0], fixed: [],
            symbol: [Link(a: 2, b: 3), Link(a: 0, b: 3), Link(a: 1, b: 3)], degreeLimit: 3)
        var lowest: Play = try Self.playing(star)
        try Self.act(&lowest, .listen)
        #expect(lowest.failure == .missing(Link(a: 0, b: 3)))

        // disconnected: rates 0, 0, 4 with K 1 and σ 2 snap 1–2 on tick 1 (gap 4).
        let drift: AcousticConstellatorLevel = try Self.level(
            rates: [0, 0, 4], phases: [0, 0, 0], fixed: [], symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)],
            coupling: 1)
        var apart: Play = try Self.playing(drift)
        try Self.act(&apart, .link(0, 1))
        try Self.act(&apart, .link(2, 1))
        try Self.act(&apart, .listen)
        #expect(apart.failure == .disconnected(tick: 1, link: Link(a: 1, b: 2)))
        #expect(apart.failure?.code == "disconnected")
        #expect(apart.report.snapped[1] == [1])

        // disconnected names the lowest snapped link: rates 0, 5, 0 snap both links on tick 1.
        let both: AcousticConstellatorLevel = try Self.level(
            rates: [0, 5, 0], phases: [0, 0, 0], fixed: [], symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)],
            coupling: 1)
        var split: Play = try Self.playing(both)
        try Self.act(&split, .link(1, 2))
        try Self.act(&split, .link(0, 1))
        try Self.act(&split, .listen)
        #expect(split.links == [Link(a: 0, b: 1), Link(a: 1, b: 2)])
        #expect(split.failure == .disconnected(tick: 1, link: Link(a: 0, b: 1)))

        // incoherent: phase 3 on star 2 syncs on tick 4 (0, 0, 3 → 1, 2, 3 → 2, 3, 3 → 3, 3, 4 → 4, 4, 4); window 5
        // leaves a run of 2 below the hold 3.
        var late: Play = try Self.playing(try Self.hand(window: 5))
        try Self.act(&late, .link(1, 2))
        try Self.act(&late, .nudge(2, 1))
        try Self.act(&late, .nudge(2, 1))
        #expect(late.phases == [0, 0, 3])
        try Self.act(&late, .listen)
        #expect(late.report.phases == [[0, 0, 3], [1, 2, 3], [2, 3, 3], [3, 3, 4], [4, 4, 4], [5, 5, 5]])
        #expect(late.failure == .incoherent(2))
        #expect(late.failure?.code == "incoherent")
        #expect(late.report.longestRun == 2)

        // A window of 6 holds on tick 6 instead.
        var held: Play = try Self.playing(try Self.hand(window: 6))
        try Self.act(&held, .link(1, 2))
        try Self.act(&held, .nudge(2, 1))
        try Self.act(&held, .nudge(2, 1))
        try Self.act(&held, .listen)
        #expect(held.stage == .won)
        #expect(held.report.outcome == .won(tick: 6))

        // The hand level wins on tick 3 once 1–2 is linked; the label then matches the symbol's.
        var hand: Play = try Self.playing(try Self.hand())
        try Self.act(&hand, .link(1, 2))
        #expect(hand.matchesSymbol)
        try Self.act(&hand, .listen)
        #expect(hand.report.outcome == .won(tick: 3))
    }

    // MARK: - Budget

    /// Budget failure on the exact action, with budgets one action either side; a listen on the last action decides by
    /// itself (wins or fails by its outcome), never `budget`.
    @Test func budgetFailsOnTheExactAction() throws {
        // Budget 2: the second nudge spends the last action and fails budget(1).
        var two: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&two, .nudge(0, 1))
        #expect(two.stage == .playing)
        #expect(two.actionsLeft == 1)
        try Self.act(&two, .nudge(0, 1))
        #expect(two.stage == .failed)
        #expect(two.failure == .budget(1))
        #expect(two.failure?.code == "budget")
        #expect(two.actionsLeft == 0)
        #expect(two.phases == [2, 0, 1])
        #expect(two.report == two.level.listen(links: [Link(a: 0, b: 1)], phases: [2, 0, 1]))

        // Budget 3 (one more): the same two nudges leave play going.
        var three: Play = try Self.playing(try Self.hand(budget: 3))
        try Self.act(&three, .nudge(0, 1))
        try Self.act(&three, .nudge(0, 1))
        #expect(three.stage == .playing)
        #expect(three.failure == nil)
        #expect(three.actionsLeft == 1)

        // Budget 1 (one fewer): the first nudge fails budget(0); so does a link or an unlink.
        var one: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&one, .nudge(0, 1))
        #expect(one.failure == .budget(0))
        var oneLink: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&oneLink, .link(1, 2))
        #expect(oneLink.failure == .budget(0))
        var unlinkLast: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&unlinkLast, .link(1, 2))
        try Self.act(&unlinkLast, .unlink(2, 1))
        #expect(unlinkLast.failure == .budget(1))
        #expect(unlinkLast.links == [Link(a: 0, b: 1)])

        // A listen on the last action wins.
        var last: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&last, .link(1, 2))
        try Self.act(&last, .listen)
        #expect(last.stage == .won)
        #expect(last.failure == nil)
        #expect(last.actionsLeft == 0)

        // A failing listen on the last action names its outcome, not the budget.
        var lastMissing: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&lastMissing, .listen)
        #expect(lastMissing.failure == .missing(Link(a: 1, b: 2)))
    }

    // MARK: - Refusals

    /// The validation order stage, stale, action (star, self, exists, degree, limit, missing, fixed, step), with every
    /// refusal reachable; a refused action spends nothing and leaves the play unchanged.
    @Test func everyRefusalIsReachableInOrder() throws {
        // Five stars, D 2, E 3, fixed 0–1.
        let level: AcousticConstellatorLevel = try Self.level(
            rates: [1, 1, 1, 1, 1], phases: [0, 0, 0, 0, 0], fixed: [Link(a: 0, b: 1)],
            symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], budget: 20)
        var play: Play = try Self.playing(level)

        // Nothing to undo or redo.
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))

        // Stale before action: an invalid action with a stale fingerprint is stale.
        #expect(Self.refusal(play, .stale(.link(99, 99))) == .stale)
        #expect(Self.refusal(play, .stale(.listen)) == .stale)

        // Unknown star first.
        #expect(Self.refusal(play, .act(.link(5, 0))) == .action("star"))
        #expect(Self.refusal(play, .act(.link(0, -1))) == .action("star"))
        #expect(Self.refusal(play, .act(.link(9, 9))) == .action("star"))
        #expect(Self.refusal(play, .act(.unlink(5, 1))) == .action("star"))
        #expect(Self.refusal(play, .act(.nudge(5, 1))) == .action("star"))
        #expect(Self.refusal(play, .act(.nudge(-1, 7))) == .action("star"))
        // Self, then exists.
        #expect(Self.refusal(play, .act(.link(2, 2))) == .action("self"))
        #expect(Self.refusal(play, .act(.unlink(1, 1))) == .action("self"))
        #expect(Self.refusal(play, .act(.link(0, 1))) == .action("exists"))
        #expect(Self.refusal(play, .act(.link(1, 0))) == .action("exists"))
        // Removing a fixed or missing link.
        #expect(Self.refusal(play, .act(.unlink(1, 0))) == .action("fixed"))
        #expect(Self.refusal(play, .act(.unlink(2, 3))) == .action("missing"))
        // A nudge step other than ±1.
        #expect(Self.refusal(play, .act(.nudge(0, 0))) == .action("step"))
        #expect(Self.refusal(play, .act(.nudge(0, 2))) == .action("step"))
        #expect(Self.refusal(play, .act(.nudge(4, -2))) == .action("step"))
        #expect(Self.refusal(play, .act(.nudge(4, -1))) == nil)
        #expect(Self.refusal(play, .act(.nudge(4, 1))) == nil)

        // Degree: 1–2 takes star 1 to D = 2; any further link at star 1 is refused by degree.
        try Self.act(&play, .link(1, 2))
        #expect(Self.refusal(play, .act(.link(3, 1))) == .action("degree"))
        #expect(Self.refusal(play, .act(.link(1, 2))) == .action("exists"))
        // Limit: 3–4 makes three links = E; a fourth is refused by limit, but degree comes first.
        try Self.act(&play, .link(4, 3))
        #expect(play.links == [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 3, b: 4)])
        #expect(Self.refusal(play, .act(.link(0, 2))) == .action("limit"))
        #expect(Self.refusal(play, .act(.link(1, 4))) == .action("degree"))
        // A placed link may be removed; then the limit has room again.
        #expect(Self.refusal(play, .act(.unlink(4, 3))) == nil)
        #expect(Self.refusal(play, .act(.unlink(3, 2))) == .action("missing"))

        // Stage first: paused refuses even a stale invalid action by stage.
        try play.handle(.pause)
        #expect(Self.refusal(play, .stale(.link(99, 99))) == .stage)
        try play.handle(.resume)

        // Reason codes.
        let codes: [String] = [AcousticConstellatorError.stage.reasonCode, AcousticConstellatorError.stale.reasonCode,
                               AcousticConstellatorError.action("star").reasonCode]
        #expect(codes == ["r02-g13.stage", "r02-g13.stale", "r02-g13.action"])

        // Only the two accepted links were spent and recorded.
        #expect(play.actionsSpent == 2)
        #expect(play.records.count == 2)

        // A redo after a new action is refused.
        try play.undo()
        #expect(play.canRedo)
        try Self.act(&play, .nudge(2, -1))
        #expect(!play.canRedo)
        #expect(Self.refusal(play, .redo) == .action("redo"))
    }

    // MARK: - Fingerprint

    /// The fingerprint is the SHA-256 of its canonical text and covers links, phases, actions, stage and failure.
    @Test func fingerprintIsCanonical() throws {
        let level: AcousticConstellatorLevel = try Self.hand()
        var play: Play = try Self.playing(level)
        let text0: String = "{\"actions\":0,\"failure\":\"none\",\"level\":\"" + level.fingerprint
            + "\",\"links\":[[0,1]],\"phases\":[0,0,1],\"schema\":1,\"stage\":\"playing\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text0.utf8)))
        #expect(play.fingerprint.count == 64)
        try Self.act(&play, .listen)
        let text1: String = "{\"actions\":1,\"failure\":\"missing 1 2\",\"level\":\"" + level.fingerprint
            + "\",\"links\":[[0,1]],\"phases\":[0,0,1],\"schema\":1,\"stage\":\"failed\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text1.utf8)))

        let drift: AcousticConstellatorLevel = try Self.level(
            rates: [0, 0, 4], phases: [0, 0, 0], fixed: [], symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)],
            coupling: 1)
        var apart: Play = try Self.playing(drift)
        try Self.act(&apart, .link(2, 1))
        try Self.act(&apart, .link(0, 1))
        try Self.act(&apart, .listen)
        let text2: String = "{\"actions\":3,\"failure\":\"disconnected 1 1 2\",\"level\":\"" + drift.fingerprint
            + "\",\"links\":[[0,1],[1,2]],\"phases\":[0,0,0],\"schema\":1,\"stage\":\"failed\"}"
        #expect(apart.fingerprint == StableHash.sha256Hex(Array(text2.utf8)))

        var late: Play = try Self.playing(try Self.hand(window: 5))
        try Self.act(&late, .link(1, 2))
        try Self.act(&late, .nudge(2, 1))
        try Self.act(&late, .nudge(2, 1))
        try Self.act(&late, .listen)
        let text3: String = "{\"actions\":4,\"failure\":\"incoherent 2\",\"level\":\"" + late.level.fingerprint
            + "\",\"links\":[[0,1],[1,2]],\"phases\":[0,0,3],\"schema\":1,\"stage\":\"failed\"}"
        #expect(late.fingerprint == StableHash.sha256Hex(Array(text3.utf8)))

        var budget: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&budget, .nudge(1, -1))
        let text4: String = "{\"actions\":1,\"failure\":\"budget 0\",\"level\":\"" + budget.level.fingerprint
            + "\",\"links\":[[0,1]],\"phases\":[0,11,1],\"schema\":1,\"stage\":\"failed\"}"
        #expect(budget.fingerprint == StableHash.sha256Hex(Array(text4.utf8)))

        // Stage is covered.
        var paused: Play = try Self.playing(level)
        let playingPrint: String = paused.fingerprint
        try paused.handle(.pause)
        #expect(paused.fingerprint != playingPrint)
    }

    // MARK: - Undo and redo

    /// Undo of every action restores the exact earlier fingerprint, links, phases, report and label; redo restores the
    /// later ones; undo while paused stays paused; undo from failed returns to playing (recorded) and redo restores the
    /// failure.
    @Test func undoRestoresExactStates() throws {
        let level: AcousticConstellatorLevel = try Self.level(
            rates: [1, 1, 1, 1, 1], phases: [0, 0, 0, 0, 0], fixed: [Link(a: 0, b: 1)],
            symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], budget: 20)
        var play: Play = try Self.playing(level)
        let actions: [AcousticConstellatorAction] = [.link(1, 2), .nudge(3, 1), .link(3, 4), .unlink(1, 2),
                                                     .nudge(0, -1), .link(2, 0)]
        var states: [Play] = [play]
        for action in actions {
            try Self.act(&play, action)
            states.append(play)
        }
        var undone: Int = 0
        for earlier in stride(from: states.count - 2, through: 0, by: -1) {
            let previous: String = play.fingerprint
            try play.undo()
            undone += 1
            #expect(play.fingerprint == states[earlier].fingerprint)
            #expect(play.links == states[earlier].links)
            #expect(play.phases == states[earlier].phases)
            #expect(play.actionsSpent == states[earlier].actionsSpent)
            #expect(play.report == states[earlier].report)
            #expect(play.label == states[earlier].label)
            #expect(play.matchesSymbol == states[earlier].matchesSymbol)
            #expect(play.records.last?.kind == .undo)
            #expect(play.records.last?.previous == previous)
            #expect(play.records.last?.next == play.fingerprint)
        }
        #expect(!play.canUndo)
        #expect(play.canRedo)
        for later in 1..<states.count {
            try play.redo()
            #expect(play.fingerprint == states[later].fingerprint)
            #expect(play.links == states[later].links)
            #expect(play.phases == states[later].phases)
            #expect(play.report == states[later].report)
            #expect(play.records.last?.kind == .redo)
        }
        #expect(play.records.count == actions.count + 2 * undone)

        // Undo while paused stays paused; redo too.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        #expect(play.links == states[states.count - 2].links)
        try play.redo()
        #expect(play.stage == .paused)
        try play.handle(.resume)
        #expect(play.fingerprint == states[states.count - 1].fingerprint)

        // Undo from a budget failure returns to playing and is recorded; redo restores the failure.
        var failed: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&failed, .nudge(0, 1))
        let beforeFail: Play = failed
        try Self.act(&failed, .nudge(0, 1))
        #expect(failed.failure == .budget(1))
        let failedPrint: String = failed.fingerprint
        try failed.undo()
        #expect(failed.stage == .playing)
        #expect(failed.failure == nil)
        #expect(failed.actionsSpent == 1)
        #expect(failed.fingerprint == beforeFail.fingerprint)
        #expect(failed.records.last?.kind == .undo)
        #expect(failed.records.last?.previous == failedPrint)
        try failed.redo()
        #expect(failed.stage == .failed)
        #expect(failed.failure == .budget(1))
        #expect(failed.fingerprint == failedPrint)

        // Undo from a failed listen returns to playing at the earlier state; then the play can still win.
        var retry: Play = try Self.playing(try Self.hand())
        let start: String = retry.fingerprint
        try Self.act(&retry, .listen)
        try retry.undo()
        #expect(retry.stage == .playing)
        #expect(retry.fingerprint == start)
        #expect(retry.actionsSpent == 0)
        try Self.act(&retry, .link(1, 2))
        try Self.act(&retry, .listen)
        #expect(retry.stage == .won)
    }

    // MARK: - Replay

    /// 500 seeded traces (seed 2_421 onwards) of random valid and invalid links, unlinks, nudges, listens, undo, redo,
    /// pause and resume replay to the same records, fingerprints and outcome; tampered traces are refused. The fixtures'
    /// symbol stars share one rate and rarely drift apart, so 20 further traces run on drifting three-star levels
    /// (symbol 0–1, 1–2, seeded rates) where links snap.
    @Test func seededTracesReplayExactly() throws {
        var random = SeededRandom(seed: 2_421)
        var cases: [(level: AcousticConstellatorLevel, actions: [(kind: String, a: Int, b: Int)])] = []
        for fixture in AcousticConstellatorFixtures.fixtures(500, from: 2_421) {
            cases.append((fixture.level, fixture.winningActions))
        }
        for _ in 0..<20 {
            let drift: AcousticConstellatorLevel = try Self.level(
                rates: [random.int(0...11), random.int(0...11), random.int(0...11)],
                phases: [random.int(0...11), random.int(0...11), random.int(0...11)], fixed: [],
                symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], coupling: random.int(1...8), budget: 12)
            cases.append((drift, [("link", 0, 1), ("link", 1, 2), ("listen", 0, 0)]))
        }
        var reached: Set<String> = []
        for fixture in cases {
            let level: AcousticConstellatorLevel = fixture.level
            var play: Play = try Self.playing(level)
            let n: Int = level.stars.count
            let steps: Int = random.int(6...40)
            for _ in 0..<steps {
                let choice: Int = random.int(0...16)
                let op: Op
                switch choice {
                case 0...1: op = .act(.link(random.int(-1...n), random.int(-1...n)))
                case 2...3: op = .act(.link(random.int(0...(n - 1)), random.int(0...(n - 1))))
                case 4:
                    if play.links.isEmpty {
                        op = .act(.unlink(random.int(0...(n - 1)), random.int(0...(n - 1))))
                    } else {
                        let link: Link = play.links[random.int(0...(play.links.count - 1))]
                        op = .act(.unlink(link.b, link.a))
                    }
                case 5: op = .act(.unlink(random.int(-1...n), random.int(0...(n - 1))))
                case 6: op = .act(.nudge(random.int(-1...n), random.int(-2...2)))
                case 15: op = .act(.nudge(random.int(0...(n - 1)), random.int(0...1) == 0 ? -1 : 1))
                case 7:
                    let tuple: (kind: String, a: Int, b: Int) =
                        fixture.actions[random.int(0...(fixture.actions.count - 1))]
                    op = .act(Self.action(tuple))
                case 8: op = .act(.listen)
                case 9...10: op = .undo
                case 11: op = .redo
                case 12: op = .event(.pause)
                case 13: op = .event(.resume)
                default: op = .stale(.listen)
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
                #expect(play.report == level.listen(links: play.links, phases: play.phases))
                if play.stage == .won { reached.insert("won") }
                if let failure = play.failure { reached.insert("failed-" + failure.code) }
            }
            let replayed: Play = try Play.replay(level: level, records: play.records)
            #expect(replayed.records == play.records)
            #expect(replayed.links == play.links)
            #expect(replayed.phases == play.phases)
            #expect(replayed.actionsSpent == play.actionsSpent)
            #expect(replayed.report == play.report)
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
                var tampered: [AcousticConstellatorRecord] = play.records
                let r: AcousticConstellatorRecord = tampered[0]
                tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                         action: r.action, previous: r.previous, next: "0000")
                #expect(throws: AcousticConstellatorError.malformed("record 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed &+ 1, index: r.index,
                                                         kind: r.kind, action: r.action, previous: r.previous,
                                                         next: r.next)
                #expect(throws: AcousticConstellatorError.malformed("seed 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = AcousticConstellatorRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                                         action: r.action, previous: r.previous, next: r.next)
                #expect(throws: AcousticConstellatorError.malformed("schema 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                         action: r.action, previous: "0000", next: r.next)
                #expect(throws: AcousticConstellatorError.malformed("replay")) {
                    try Play.replay(level: level, records: tampered)
                }
            }
        }
        let expected: [String] = ["accepted", "action-star", "action-self", "action-exists", "action-degree",
                                  "action-limit", "action-missing", "action-fixed", "action-step", "action-undo",
                                  "action-redo", "r02-g13.stage", "r02-g13.stale", "won", "failed-missing",
                                  "failed-disconnected", "failed-incoherent", "failed-budget"]
        for name in expected {
            #expect(reached.contains(name), "trace never reached \(name)")
        }
    }

    /// A record whose kind and action disagree, or whose index is changed, is refused; records round-trip through
    /// JSON.
    @Test func replayRefusesMismatchedRecords() throws {
        let level: AcousticConstellatorLevel = try Self.hand()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .link(1, 2))
        try Self.act(&play, .listen)
        let replayed: Play = try Play.replay(level: level, records: play.records)
        #expect(replayed == play)
        let r: AcousticConstellatorRecord = play.records[0]
        var tampered: [AcousticConstellatorRecord] = play.records
        tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .nudge,
                                                 action: r.action, previous: r.previous, next: r.next)
        #expect(throws: AcousticConstellatorError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .link,
                                                 action: nil, previous: r.previous, next: r.next)
        #expect(throws: AcousticConstellatorError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                                 action: r.action, previous: r.previous, next: r.next)
        #expect(throws: AcousticConstellatorError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .link,
                                                 action: .link(0, 2), previous: r.previous, next: r.next)
        #expect(throws: AcousticConstellatorError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        // A replayed action that is refused surfaces its refusal.
        tampered[0] = AcousticConstellatorRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .link,
                                                 action: .link(9, 1), previous: r.previous, next: r.next)
        #expect(throws: AcousticConstellatorError.action("star")) {
            try Play.replay(level: level, records: tampered)
        }
        // Records round-trip through JSON.
        let data: Data = try JSONEncoder().encode(play.records)
        let decoded: [AcousticConstellatorRecord] = try JSONDecoder().decode([AcousticConstellatorRecord].self,
                                                                            from: data)
        #expect(decoded == play.records)
    }
}
