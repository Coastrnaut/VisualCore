// MazeBeamFixtureTests — feature 100 (A13-P05) T-A13-504 (FR-A13-520; SC-A13-504; clarification Q5). For each of the
// 20 levels, three boards are drawn: the level at its start, the level after its recorded solution
// (`MazeCore.fixtureEntries(level:)` played by `MazeCore.played(seed:entries:)`) and the level after `Solver.solve`'s
// answer (each turnable tile whose solved orientation differs from the start selected and turned once). For each of
// the 60 boards, the core beam lines of `MazePresenter.scene(_:)` (children of the root with ids `beam<i>`, not the
// `beam<i>.halo` glow) equal `core.beam.segments` one to one: as many lines as segments, and line `beam<i>` runs from
// segment i's start to its end within 1e-9. The line end points are in cells: the root carries the scale
// `MazePresenter.unit`, so they are compared with the tracer's board coordinates directly.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreUI

@MainActor
final class MazeBeamFixtureTests: XCTestCase {
    /// The tolerance of an end point comparison, in cells.
    private let tolerance: Double = 1e-9

    /// A core prepared with seed 1 on level `level` in its starting orientations.
    private func startCore(level: Int) -> MazeCore {
        var core: MazeCore = MazeCore(seed: 1)
        let selected: Bool = core.apply(ExperienceAction(control: "level.select", values: [Double(level)],
                                                         step: 0)).isAccepted
        XCTAssertTrue(selected, "level \(level + 1) selected")
        return core
    }

    /// A core of level `level` turned to `Solver.solve`'s answer from its start; nil (after a failure) when the solver
    /// does not solve the level.
    private func solverCore(level: Int) -> MazeCore? {
        var core: MazeCore = startCore(level: level)
        let result: SolverResult = Solver.solve(core.board)
        guard case .solved(let orientations, _, _) = result else {
            XCTFail("level \(level + 1): the solver solves the level (got \(result))")
            return nil
        }
        let start: [Orientation] = core.state.orientations
        XCTAssertEqual(orientations.count, start.count, "level \(level + 1): one orientation per turnable tile")
        let count: Int = min(orientations.count, start.count)
        for index in 0..<count where orientations[index] != start[index] {
            let select: ExperienceAction = ExperienceAction(control: "tile.select", values: [Double(index)], step: 0)
            XCTAssertTrue(core.apply(select).isAccepted, "level \(level + 1): tile \(index) selected")
            let turn: ExperienceAction = ExperienceAction(control: "tile.turn", values: [], step: 0)
            XCTAssertTrue(core.apply(turn).isAccepted, "level \(level + 1): tile \(index) turned")
        }
        return core
    }

    /// Checks that the core beam lines of `MazePresenter.scene(core)` equal `core.beam.segments` one to one (count,
    /// then line `beam<i>`'s end points against segment i's start and end within ``tolerance``, in cells).
    private func checkBeamLines(_ core: MazeCore, _ name: String) throws {
        let root: SceneNode = MazePresenter.scene(core)
        let segments: [BeamSegment] = core.beam.segments
        var lines: [SceneNode] = []
        for child in root.children where child.id.hasPrefix("beam") && !child.id.hasSuffix(".halo") {
            lines.append(child)
        }
        XCTAssertEqual(lines.count, segments.count, "\(name): one core beam line per segment")
        for index in 0..<segments.count {
            let segment: BeamSegment = segments[index]
            let id: String = "beam\(index)"
            let found: SceneNode? = root.children.first { (node: SceneNode) -> Bool in node.id == id }
            let line: SceneNode = try XCTUnwrap(found, "\(name): line \(id)")
            guard case .line(let a, let b, _) = line.primitive else {
                XCTFail("\(name): \(id) is a line")
                continue
            }
            XCTAssertEqual(a.x, segment.start.x, accuracy: tolerance, "\(name): \(id) start x")
            XCTAssertEqual(a.y, segment.start.y, accuracy: tolerance, "\(name): \(id) start y")
            XCTAssertEqual(b.x, segment.end.x, accuracy: tolerance, "\(name): \(id) end x")
            XCTAssertEqual(b.y, segment.end.y, accuracy: tolerance, "\(name): \(id) end y")
        }
    }

    func testCoreBeamLinesEqualTheTracerSegmentsOnSixtyBoards() throws {
        XCTAssertEqual(MazeCore.levelCount, 20)
        var checked: Int = 0
        for level in 0..<20 {
            let start: MazeCore = startCore(level: level)
            XCTAssertEqual(start.state.levelIndex, level)
            try checkBeamLines(start, "level \(level + 1) start")
            checked += 1

            let recorded: MazeCore = MazeCore.played(seed: 1, entries: MazeCore.fixtureEntries(level: level))
            XCTAssertEqual(recorded.state.levelIndex, level)
            XCTAssertTrue(recorded.isSolved, "level \(level + 1): the recorded solution solves the level")
            try checkBeamLines(recorded, "level \(level + 1) recorded solution")
            checked += 1

            guard let solved: MazeCore = solverCore(level: level) else { continue }
            XCTAssertEqual(solved.state.levelIndex, level)
            XCTAssertTrue(solved.isSolved, "level \(level + 1): the solver's answer solves the level")
            try checkBeamLines(solved, "level \(level + 1) solver answer")
            checked += 1
        }
        XCTAssertEqual(checked, 60, "20 levels × (start, recorded solution, solver answer)")
    }
}
