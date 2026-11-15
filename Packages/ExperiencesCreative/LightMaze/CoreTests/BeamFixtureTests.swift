// BeamFixtureTests — feature 096 (A13-P01) T-A13-103 (FR-A13-113; clarification Q4; research D4; SC-A13-103). The
// committed beam fixtures: the solved beams of levels 1, 10 and 20 (`lm-01`, `lm-10`, `lm-20`), every segment's end
// points as exact Double values with its bounce and branch, and the end reasons. They were generated once from the
// tracer and are compared bit for bit (`==` on Double), so any change to the ray cast or the tracer that moves a beam
// shows up here.
import Foundation
import LightMazeCore
import Testing
import VisualCoreMath

@Suite struct BeamFixtureTests {
    /// One fixture segment: start x, start y, end x, end y, bounce, branch.
    struct Fixture {
        var x0: Double, y0: Double, x1: Double, y1: Double, bounce: Int, branch: Int
    }

    /// Compares the solved beam of level `index` with `fixtures` and `ends`.
    private func check(_ index: Int, _ fixtures: [Fixture], _ ends: [BeamEnd]) throws {
        let level = LevelCatalog.bundled.levels[index]
        let beam = BeamTracer.trace(try #require(level.solvedBoard))
        #expect(beam.isSolved, "\(level.id)")
        #expect(beam.endReasons == ends, "\(level.id)")
        #expect(beam.segments.count == fixtures.count, "\(level.id)")
        for position in 0..<min(beam.segments.count, fixtures.count) {
            let segment = beam.segments[position]
            let fixture = fixtures[position]
            #expect(segment.start == Vec2(fixture.x0, fixture.y0), "\(level.id) segment \(position) start")
            #expect(segment.end == Vec2(fixture.x1, fixture.y1), "\(level.id) segment \(position) end")
            #expect(segment.bounce == fixture.bounce && segment.branch == fixture.branch, "\(level.id) \(position)")
        }
    }

    @Test func levelOne() throws {
        let fixtures: [Fixture] = [
            Fixture(x0: 0.5, y0: 2.5, x1: 2.5, y1: 2.5, bounce: 0, branch: 0),
            Fixture(x0: 2.5, y0: 2.5, x1: 2.5, y1: 4.2, bounce: 1, branch: 0),
        ]
        try check(0, fixtures, [.target])
    }

    @Test func levelTen() throws {
        let fixtures: [Fixture] = [
            Fixture(x0: 1.5, y0: 5.5, x1: 4.5, y1: 5.5, bounce: 0, branch: 0),
            Fixture(x0: 4.5, y0: 5.5, x1: 4.5, y1: 4.5, bounce: 1, branch: 0),
            Fixture(x0: 4.5, y0: 4.5, x1: 0.5, y1: 4.5, bounce: 2, branch: 0),
            Fixture(x0: 0.5, y0: 4.5, x1: 0.5, y1: 6.5, bounce: 3, branch: 0),
            Fixture(x0: 0.5, y0: 6.5, x1: 2.5, y1: 6.5, bounce: 4, branch: 0),
            Fixture(x0: 2.5, y0: 6.5, x1: 2.5, y1: 0.7999999999999998, bounce: 5, branch: 0),
        ]
        try check(9, fixtures, [.target])
    }

    @Test func levelTwenty() throws {
        let fixtures: [Fixture] = [
            Fixture(x0: 0.5, y0: 7.5, x1: 3.5, y1: 7.5, bounce: 0, branch: 0),
            Fixture(x0: 3.5, y0: 7.5, x1: 3.5, y1: 2.5, bounce: 1, branch: 0),
            Fixture(x0: 3.5, y0: 2.5, x1: 1.5, y1: 2.5, bounce: 2, branch: 0),
            Fixture(x0: 1.5, y0: 2.5, x1: 1.5, y1: 0.5, bounce: 3, branch: 0),
            Fixture(x0: 1.5, y0: 0.5, x1: 5.200000000000001, y1: 0.5, bounce: 4, branch: 0),
            Fixture(x0: 3.5, y0: 7.5, x1: 6.5, y1: 7.5, bounce: 0, branch: 1),
            Fixture(x0: 6.5, y0: 7.5, x1: 6.5, y1: 4.5, bounce: 1, branch: 1),
            Fixture(x0: 6.5, y0: 4.5, x1: 0.7999999999999998, y1: 4.5, bounce: 2, branch: 1),
        ]
        try check(19, fixtures, [.target, .target])
    }
}
