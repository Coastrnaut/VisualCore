// ArcadeFlowTests — feature 077 (A10-P03) T-A10-303 (FR-A10-310; clarification 2; research D3; SC-A10-301). The
// screen rules, host-free and short: a new experience opens on title; every allowed move (title + start, over + start
// with a new run, playing ↔ paused through pause 1/0, paused or over + restart with a new run) and every other
// combination of the three actions and four screens refused; only playing advances; the screen derived from a saved
// run (over, paused, otherwise playing); the screen's raw values round-trip through JSON.
import Foundation
import Testing
import NeonArcadeCore

@Suite struct ArcadeFlowTests {
    private let actions: [ArcadeFlowAction] = [.start, .pause(true), .pause(false), .restart]

    @Test func aNewExperienceOpensOnTitle() {
        #expect(ArcadeFlow.initialScreen == .title)
    }

    @Test func everyAllowedMove() {
        #expect(ArcadeFlow.apply(.start, to: .title) == ArcadeTransition(screen: .playing, newRun: false))
        #expect(ArcadeFlow.apply(.start, to: .over) == ArcadeTransition(screen: .playing, newRun: true))
        #expect(ArcadeFlow.apply(.pause(true), to: .playing) == ArcadeTransition(screen: .paused, newRun: false))
        #expect(ArcadeFlow.apply(.pause(false), to: .paused) == ArcadeTransition(screen: .playing, newRun: false))
        #expect(ArcadeFlow.apply(.restart, to: .paused) == ArcadeTransition(screen: .playing, newRun: true))
        #expect(ArcadeFlow.apply(.restart, to: .over) == ArcadeTransition(screen: .playing, newRun: true))
    }

    @Test func everyOtherMoveIsRefused() {
        let allowed: [(ArcadeFlowAction, ArcadeScreen)] = [(.start, .title), (.start, .over), (.pause(true), .playing),
                                                           (.pause(false), .paused), (.restart, .paused),
                                                           (.restart, .over)]
        var refused = 0
        for action in actions {
            for screen in ArcadeScreen.allCases where !allowed.contains(where: { $0.0 == action && $0.1 == screen }) {
                #expect(ArcadeFlow.apply(action, to: screen) == nil, "\(action) on \(screen)")
                refused += 1
            }
        }
        #expect(refused == actions.count * ArcadeScreen.allCases.count - allowed.count)
        #expect(refused == 10)
    }

    @Test func aWholeGameFollowsTheFlow() throws {
        var screen = ArcadeFlow.initialScreen
        for (action, expected) in [(ArcadeFlowAction.start, ArcadeScreen.playing), (.pause(true), .paused),
                                   (.pause(false), .playing), (.pause(true), .paused), (.restart, .playing)] {
            screen = try #require(ArcadeFlow.apply(action, to: screen)).screen
            #expect(screen == expected)
        }
        #expect(ArcadeFlow.apply(.restart, to: screen) == nil)
    }

    @Test func onlyPlayingAdvances() {
        #expect(ArcadeScreen.allCases.filter(\.advancesRun) == [.playing])
    }

    @Test func theScreenDerivedFromASavedRun() {
        var run = GameRun.new()
        #expect(ArcadeScreen.derived(from: run) == .playing)
        run.paused = true
        #expect(ArcadeScreen.derived(from: run) == .paused)
        run.paused = false
        run.lives = 0
        run.over = true
        #expect(ArcadeScreen.derived(from: run) == .over)
    }

    @Test func theScreenRoundTripsThroughJSON() throws {
        #expect(ArcadeScreen.allCases.map(\.rawValue) == ["title", "playing", "paused", "over"])
        let data = try JSONEncoder().encode(ArcadeScreen.allCases)
        #expect(try JSONDecoder().decode([ArcadeScreen].self, from: data) == ArcadeScreen.allCases)
    }
}
