// BoundaryRuleTests — feature 121 (A16-P05) T-A16-505 (FR-A16-505; the phase MVP: the GPU ping-pong path with explicit
// boundary rules). The boundary rules of the three families on the GPU inside the one app's session host, short runs
// only (each test well under 10 s, no wall-clock assertion):
// - the automaton wraps: the seeded field is cleared through `sim.paint` taps, a glider painted at the right edge is
//   stepped 4 × 64 generations one `sim.step` at a time; after every step the GPU field equals the CPU field and the
//   CPU reference (`AutomatonRule.life` with its wrap boundary), the glider crosses to the left edge, and after the
//   full lap it is back where it started;
// - reaction-diffusion wraps: a disc painted at cell (0, 0) covers cells on the opposite edges, and after one GPU step
//   the field is within 0.01 of the CPU field there and everywhere;
// - the wave keeps a fixed zero border: after 30 running frames every edge cell reads exactly 0 on the GPU and the
//   CPU (the 100-step GPU check is `WaveBorderTests`).
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class BoundaryRuleTests: XCTestCase {
    /// The grid side (64).
    private let n = SimulationCore.gridSize

    /// Opens the experience, switches it to `family` through the presenter and draws one frame.
    private func open(_ session: ExperienceSession, family: Int) async throws -> ExperienceShell<SimulationPresenter> {
        let shell = try await SimulationTest.open(session)
        XCTAssertTrue(shell.presenter.send("sim.family", [Double(family)], through: shell.port).isAccepted)
        try SimulationTest.frames(session, 1)
        if family > 0 {
            XCTAssertEqual(shell.presenter.floatSupported, true, "Floating-point render targets are not available")
        }
        return shell
    }

    /// Sends `sim.paint` at (x, y) with `mode` through the presenter and checks that it was accepted.
    private func paint(_ shell: ExperienceShell<SimulationPresenter>, _ x: Int, _ y: Int, mode: Int,
                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(shell.presenter.send("sim.paint", [Double(x), Double(y), Double(mode)], through: shell.port)
            .isAccepted, "paint (\(x), \(y))", file: file, line: line)
    }

    /// Whether any cell of `grid` in column `x` is alive.
    private func columnAlive(_ grid: FieldGrid, _ x: Int) -> Bool {
        (0..<grid.height).contains { grid[x, $0, 0] >= 0.5 }
    }

    func testTheAutomatonGliderWrapsOnTheGPULikeTheCPU() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, family: 0)
        try SimulationTest.pause(shell)
        // Clear the seeded field: a tap toggles a live cell dead.
        let seeded = try SimulationTest.core(shell).model.field.current
        for y in 0..<n { for x in 0..<n where seeded[x, y, 0] >= 0.5 { paint(shell, x, y, mode: 0) } }
        // A glider moving +x, +y, its left column at x = 60, its right column at x = 62.
        for (x, y) in [(61, 10), (62, 11), (60, 12), (61, 12), (62, 12)] { paint(shell, x, y, mode: 1) }
        let start = try SimulationTest.core(shell).model.field.current
        var alive = 0
        for y in 0..<n { for x in 0..<n where start[x, y, 0] >= 0.5 { alive += 1 } }
        XCTAssertEqual(alive, 5, "only the glider is alive")
        try SimulationTest.frames(session, 1)
        XCTAssertEqual(try XCTUnwrap(shell.presenter.automaton).readBack(), start, "the painted field is loaded")

        var reference = start
        var crossed = false
        let generations = 4 * n
        for generation in 1...generations {
            XCTAssertTrue(shell.handle(control: "sim.step").isAccepted)
            try SimulationTest.frames(session, 1)
            let gpu = try XCTUnwrap(shell.presenter.automaton).readBack()
            let cpu = try SimulationTest.core(shell).model.field.current
            reference = AutomatonRule.life.step(reference)
            XCTAssertEqual(cpu, reference, "generation \(generation): the CPU is the wrapped Life rule")
            XCTAssertEqual(gpu, cpu, "generation \(generation): the GPU equals the CPU on wrapped neighbourhoods")
            if gpu != cpu { break }
            if columnAlive(gpu, 0) && columnAlive(gpu, n - 1) { crossed = true }
        }
        XCTAssertTrue(crossed, "the glider crossed from x = 63 to x = 0")
        XCTAssertEqual(try XCTUnwrap(shell.presenter.automaton).readBack(), start,
                       "after 4 × 64 generations the glider is back where it started")
        session.close()
    }

    func testAReactionDiffusionDiscAtTheCornerWrapsToTheOppositeEdges() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, family: 1)
        try SimulationTest.pause(shell)
        let cells = SimulationBrush.cells(kind: .reactionDiffusion, x: 0, y: 0, size: n)
        for corner in [(63, 63), (62, 0), (0, 62), (63, 0)] {
            XCTAssertTrue(cells.contains { $0 == corner }, "the disc covers \(corner)")
        }
        paint(shell, 0, 0, mode: 0)
        let painted = try SimulationTest.core(shell).model.field.current
        for (x, y) in [(63, 63), (62, 0), (0, 62)] {
            XCTAssertEqual(painted[x, y, 1], SimulationBrush.reactionV, "v at (\(x), \(y)) before the step")
            XCTAssertEqual(painted[x, y, 0], SimulationBrush.reactionU, "u at (\(x), \(y)) before the step")
        }

        XCTAssertTrue(shell.handle(control: "sim.step").isAccepted)
        try SimulationTest.frames(session, 1)
        let gpu = try XCTUnwrap(shell.presenter.grayScott).readBack()
        let cpu = try SimulationTest.core(shell).model.field.current
        let difference = try XCTUnwrap(gpu.maxAbsDifference(cpu))
        XCTAssertLessThanOrEqual(difference, 0.01, "one GPU step is within 0.01 of the CPU")
        for (x, y) in [(63, 63), (62, 0), (0, 62), (0, 0)] {
            XCTAssertLessThanOrEqual(abs(gpu[x, y, 1] - cpu[x, y, 1]), 0.01, "v at (\(x), \(y))")
            XCTAssertGreaterThan(gpu[x, y, 1], 0.1, "the disc shows at (\(x), \(y)) on the GPU")
        }
        session.close()
    }

    func testTheWaveEdgesStayZeroOnTheGPUAndTheCPU() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, family: 2)
        try SimulationTest.frames(session, 30)
        try SimulationTest.pause(shell)
        try SimulationTest.frames(session, 1)
        let gpu = try XCTUnwrap(shell.presenter.wave).readBack().current
        let core = try SimulationTest.core(shell)
        XCTAssertGreaterThan(core.stepCount, 0, "the wave ran")
        let cpu = core.model.field.current
        var edges = 0, nonZeroGPU = 0, nonZeroCPU = 0
        for y in 0..<n {
            for x in 0..<n where x == 0 || y == 0 || x == n - 1 || y == n - 1 {
                edges += 1
                if gpu[x, y, 0] != 0 { nonZeroGPU += 1 }
                if cpu[x, y, 0] != 0 { nonZeroCPU += 1 }
            }
        }
        XCTAssertEqual(edges, 4 * n - 4)
        XCTAssertEqual(nonZeroGPU, 0, "every GPU edge cell is exactly 0")
        XCTAssertEqual(nonZeroCPU, 0, "every CPU edge cell is exactly 0")
        session.close()
    }
}
