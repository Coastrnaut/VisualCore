// ParticleFieldTests — feature 174 (A24-P02) T-A24-204 (SC-A24-202; clarification Q1). The particle field is identical
// for the same index and frame, stays inside the view for frames 0…600 for 1,000 particles, moves particles between
// frames, keeps its sizes and colours in range, respects its count in `states`, and gives position 0 for an empty view.
// Plain loops with locals bound before each expectation keep the type-checker and the run fast.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabCore

@Suite struct ParticleFieldTests {
    private static let width = 390.0
    private static let height = 844.0

    @Test func sameIndexAndFrameGiveTheSameState() {
        let field = ParticleField(count: 100)
        let other = ParticleField(count: 100)
        for index in 0..<100 {
            let first = field.state(index: index, frame: 42, width: Self.width, height: Self.height)
            let second = other.state(index: index, frame: 42, width: Self.width, height: Self.height)
            #expect(first == second, "index \(index)")
        }
    }

    @Test func staysInsideTheViewForSixHundredFrames() {
        let field = ParticleField(count: 1_000)
        var outside = 0
        var badAppearance = 0
        for frame in stride(from: 0, through: 600, by: 1) {
            let states = field.states(frame: frame, width: Self.width, height: Self.height)
            for state in states {
                if !(state.x >= 0 && state.x < Self.width && state.y >= 0 && state.y < Self.height) { outside += 1 }
                if !(state.size >= 2 && state.size <= 6) { badAppearance += 1 }
                if !(state.red >= 0 && state.red <= 1 && state.green >= 0 && state.green <= 1
                    && state.blue >= 0 && state.blue <= 1 && state.alpha > 0 && state.alpha <= 1) { badAppearance += 1 }
            }
        }
        #expect(outside == 0)
        #expect(badAppearance == 0)
    }

    @Test func differentFramesMoveParticles() {
        let field = ParticleField(count: 100)
        var moved = 0
        for index in 0..<100 {
            let before = field.state(index: index, frame: 0, width: Self.width, height: Self.height)
            let after = field.state(index: index, frame: 10, width: Self.width, height: Self.height)
            if before.x != after.x || before.y != after.y { moved += 1 }
        }
        #expect(moved > 90)
        let first = field.states(frame: 0, width: Self.width, height: Self.height)
        let later = field.states(frame: 1, width: Self.width, height: Self.height)
        #expect(first != later)
    }

    @Test func speedIsAtMostTwoPointsPerFrame() {
        let field = ParticleField(count: 200)
        var tooFast = 0
        for index in 0..<200 {
            let before = field.state(index: index, frame: 0, width: 10_000, height: 10_000)
            let after = field.state(index: index, frame: 1, width: 10_000, height: 10_000)
            var dx = abs(after.x - before.x)
            var dy = abs(after.y - before.y)
            if dx > 5_000 { dx = 10_000 - dx }
            if dy > 5_000 { dy = 10_000 - dy }
            if dx > 2 + 1e-9 || dy > 2 + 1e-9 { tooFast += 1 }
        }
        #expect(tooFast == 0)
    }

    @Test func statesRespectCount() {
        let zero = ParticleField(count: 0).states(frame: 3, width: Self.width, height: Self.height).count
        let some = ParticleField(count: 37).states(frame: 3, width: Self.width, height: Self.height).count
        let negative = ParticleField(count: -5).states(frame: 3, width: Self.width, height: Self.height).count
        #expect(zero == 0)
        #expect(some == 37)
        #expect(negative == 0)
        let field = ParticleField(count: 37)
        let all = field.states(frame: 3, width: Self.width, height: Self.height)
        let last = field.state(index: 36, frame: 3, width: Self.width, height: Self.height)
        #expect(all.last == last)
    }

    @Test func emptyViewGivesZeroPosition() {
        let field = ParticleField(count: 10)
        for index in 0..<10 {
            let state = field.state(index: index, frame: 7, width: 0, height: -3)
            let x = state.x
            let y = state.y
            #expect(x == 0)
            #expect(y == 0)
        }
    }
}
