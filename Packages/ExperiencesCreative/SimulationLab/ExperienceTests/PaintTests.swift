// PaintTests — feature 120 (A16-P04) T-A16-403/404 (FR-A16-401; SC-A16-401; clarification Q1). Painting through the
// action and through touches: `sim.paint` changes only the brush's cells and keeps the step count; a value that is not
// a whole cell is refused; `sim.spec` with each bundled preset's values gives its spec and a refused spec changes
// nothing; in a session a tap at a cell's centre paints that cell, a drag across three cells paints three, the Seed
// row's action equals the tap's, and a touch outside the grid square sends nothing.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class PaintTests: XCTestCase {
    /// `core` after `control` with `values`.
    private func applied(_ core: SimulationCore, _ control: String, _ values: [Double]) -> (SimulationCore, ActionResult) {
        simulationApplied(core, control, values)
    }

    func testPaintChangesOnlyTheBrushCellsAndKeepsTheStep() {
        for family in 0..<3 {
            var core = SimulationCore(seed: 3)
            if family > 0 { core = applied(core, "sim.family", [Double(family)]).0 }
            let before = core
            let (painted, result) = applied(core, "sim.paint", [20, 30, 0])
            XCTAssertTrue(result.isAccepted, "family \(family)")
            XCTAssertEqual(painted.stepCount, before.stepCount)
            let expected = SimulationBrush.painted(before.model.field, kind: before.kind, x: 20, y: 30, mode: .tap,
                                                   precision: before.model.precision)
            XCTAssertEqual(painted.model.field, expected, "family \(family): exactly the brush")
            XCTAssertNotEqual(painted.model.field, before.model.field, "family \(family) changed")
        }
        let core = SimulationCore(seed: 3)
        XCTAssertFalse(applied(core, "sim.paint", [2.5, 3, 0]).1.isAccepted)
        XCTAssertEqual(applied(core, "sim.paint", [2.5, 3, 0]).0, core)
    }

    func testSpecGivesEachBundledPresetAndRefusesBadOnes() {
        let core = SimulationCore(seed: 1)
        for preset in ExperimentPreset.bundled {
            let (made, result) = applied(core, "sim.spec", SimulationCore.specValues(preset.spec))
            XCTAssertTrue(result.isAccepted, preset.name)
            XCTAssertEqual(made.model.spec.kind, preset.spec.kind, preset.name)
            XCTAssertEqual(made.model.spec.parameters, preset.spec.parameters, preset.name)
            XCTAssertEqual(made.model.spec.timeStep, preset.spec.timeStep, preset.name)
            XCTAssertEqual(made.stepCount, 0)
        }
        let (unchanged, refused) = applied(core, "sim.spec", [1, 0.035, 0.065, 1.9])
        XCTAssertEqual(refused, .rejected(.rule(code: SimulationRule.unstable)))
        XCTAssertEqual(unchanged, core)
    }

    /// The centre of cell (x, y) in points on a `size` canvas.
    private func centre(_ x: Int, _ y: Int, size: CGSize) -> Vec2 {
        let n = SimulationCore.gridSize
        let square = SimulationPresenter.square(width: Int(size.width), height: Int(size.height), grid: n)
        let cell = square.side / Double(n)
        let top = Double(size.height) - square.y - square.side
        return Vec2(square.x + (Double(x) + 0.5) * cell, top + (Double(n - 1 - y) + 0.5) * cell)
    }

    func testTouchesPaintCellsLikeTheSeedRow() async throws {
        let size = CGSize(width: 240, height: 240)
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session, size: size)
        try SimulationTest.pause(shell)
        let view = Vec2(Double(size.width), Double(size.height))
        let start = try SimulationTest.core(shell)
        func touch(_ id: Int, _ phase: PointerPhase, _ at: Vec2) {
            shell.presenter.pointer(PointerEvent(id: id, phase: phase, location: at, timestamp: 0), viewSize: view,
                                    port: shell.port)
        }
        touch(1, .began, centre(10, 12, size: size))
        touch(1, .ended, centre(10, 12, size: size))
        let tapped = try SimulationTest.core(shell)
        let expected = simulationApplied(start, "sim.paint", [10, 12, 0]).0
        XCTAssertEqual(tapped.model.field, expected.model.field, "a tap equals the Seed row's sim.paint [10, 12, 0]")
        XCTAssertEqual(tapped.stepCount, start.stepCount)

        touch(2, .began, centre(30, 30, size: size))
        touch(2, .moved, centre(31, 30, size: size))
        touch(2, .moved, centre(32, 30, size: size))
        touch(2, .ended, centre(32, 30, size: size))
        let dragged = try SimulationTest.core(shell)
        for x in 30...32 { XCTAssertEqual(dragged.model.field.current[x, 30, 0], 1, "cell \(x) painted alive") }

        let before = try SimulationTest.core(shell)
        touch(3, .began, Vec2(1, 1))
        touch(3, .ended, Vec2(1, 1))
        XCTAssertEqual(try SimulationTest.core(shell), before, "outside the square nothing changes")
        XCTAssertEqual(shell.presenter.gestureActions, ["sim.paint"])
        session.close()
    }
}
