// SizeChangeTests — feature 121 (A16-P05) T-A16-504 (FR-A16-504; SC-A16-504; the phase's regression fixture). A canvas
// size change and a context recreation mid-run, for each of the three families inside the one app's session host on
// the simulator, short runs only (each test well under 10 s, no wall-clock assertion): a resize keeps
// `resourceBuildCount`, loads the family's mirror again, leaves its GPU field within the family's tolerance of the CPU
// field (exact for the automaton, 0.01 for the float families) and draws the grid square inside the new canvas; a
// `recreateContext` makes the resources once more, loads the mirror and leaves the field within tolerance with the
// session running. The field targets are grid-sized (64 × 64), not canvas-sized, so a resize only reloads them from
// the CPU state, while a recreation remakes them with the passes.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class SizeChangeTests: XCTestCase {
    /// The presenter's GPU field of `shell`'s current family, read right after the frame the caller drew.
    private func gpuField(_ shell: ExperienceShell<SimulationPresenter>) throws -> FieldGrid {
        let presenter = shell.presenter
        switch try SimulationTest.core(shell).kind {
        case .automaton: return try XCTUnwrap(presenter.automaton, "the automaton pair exists").readBack()
        case .reactionDiffusion: return try XCTUnwrap(presenter.grayScott, "the Gray-Scott pair exists").readBack()
        case .wave: return try XCTUnwrap(presenter.wave, "the wave pair exists").readBack().current
        }
    }

    /// The number of mirror loads of `shell`'s current family (the automaton's own counter, or the float one).
    private func loads(_ shell: ExperienceShell<SimulationPresenter>) throws -> Int {
        try SimulationTest.core(shell).kind == .automaton ? shell.presenter.gpuLoadCount
            : shell.presenter.floatLoadCount
    }

    /// Draws one frame and checks that the GPU field is within the family's tolerance of the CPU field: equal for
    /// the automaton, at most 0.01 apart for reaction-diffusion and the wave.
    private func assertWithinTolerance(_ session: ExperienceSession, _ shell: ExperienceShell<SimulationPresenter>,
                                       _ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        try SimulationTest.frames(session, 1)
        let gpu = try gpuField(shell)
        let core = try SimulationTest.core(shell)
        let cpu = core.model.field.current
        if core.kind == .automaton {
            XCTAssertEqual(gpu, cpu, "\(name): the GPU field equals the CPU field", file: file, line: line)
        } else {
            let difference = try XCTUnwrap(gpu.maxAbsDifference(cpu), "\(name): same shape", file: file, line: line)
            XCTAssertLessThanOrEqual(difference, 0.01, "\(name): within 0.01 of the CPU field", file: file, line: line)
        }
    }

    func testAResizeAndARecreationKeepEachFamilysFieldWithinTolerance() async throws {
        for family in 0..<3 {
            let name = "family \(family)"
            let session = ExperienceSession()
            let shell = try await SimulationTest.open(session)
            let presenter = shell.presenter
            XCTAssertTrue(presenter.send("sim.family", [Double(family)], through: shell.port).isAccepted, name)
            try SimulationTest.frames(session, 1)
            if family > 0 {
                XCTAssertEqual(presenter.floatSupported, true, "Floating-point render targets are not available")
            }
            try SimulationTest.frames(session, 6)
            try SimulationTest.pause(shell)
            try assertWithinTolerance(session, shell, "\(name) before")
            let builds = presenter.resourceBuildCount
            var mirrorLoads = try loads(shell)
            let squareBefore = try XCTUnwrap(presenter.lastSquare, "\(name): a square was drawn")

            // (a) A resize: the grid-sized targets are only loaded again.
            let view = try XCTUnwrap(session.renderHost?.view)
            view.frame = CGRect(origin: .zero, size: CGSize(width: 200, height: 300))
            view.layoutIfNeeded()
            try assertWithinTolerance(session, shell, "\(name) after the resize")
            XCTAssertEqual(presenter.resourceBuildCount, builds, "\(name): a resize builds nothing")
            XCTAssertEqual(try loads(shell), mirrorLoads + 1, "\(name): a resize loads the mirror from the CPU state")
            let pixels = try XCTUnwrap(session.renderHost).pixelSize
            let square = try XCTUnwrap(presenter.lastSquare, "\(name): a square was drawn after the resize")
            XCTAssertLessThanOrEqual(square.side, Double(min(pixels.width, pixels.height)),
                                     "\(name): the square fits the new canvas")
            XCTAssertGreaterThanOrEqual(square.x, 0, name)
            XCTAssertGreaterThanOrEqual(square.y, 0, name)
            XCTAssertLessThanOrEqual(square.x + square.side, Double(pixels.width), name)
            XCTAssertLessThanOrEqual(square.y + square.side, Double(pixels.height), name)
            let expected = SimulationPresenter.square(width: pixels.width, height: pixels.height,
                                                      grid: SimulationCore.gridSize)
            XCTAssertEqual(square.side, expected.side, "\(name): the square of the new canvas")
            XCTAssertTrue(square.x != squareBefore.x || square.y != squareBefore.y || square.side != squareBefore.side,
                          "\(name): the square follows the new canvas")
            mirrorLoads = try loads(shell)

            // (b) A context recreation: the targets are made again with the passes.
            session.recreateContext()
            XCTAssertEqual(session.state, .running, name)
            try assertWithinTolerance(session, shell, "\(name) after the context recreation")
            XCTAssertEqual(presenter.resourceBuildCount, builds + 1, "\(name): one rebuild")
            XCTAssertEqual(try loads(shell), mirrorLoads + 1, "\(name): a recreation loads the mirror")
            XCTAssertEqual(session.state, .running, name)
            session.close()
        }
    }

    /// T-A16-509 (FR-A16-504/505): a paint and a step with no frame between reach the GPU in every family — the mirror
    /// is loaded from the painted, stepped CPU field (the core's paint count changed) instead of being stepped from the
    /// unpainted one.
    func testAPaintThenAStepInOneFrameReachesTheGPU() async throws {
        for family in 0..<3 {
            let name = "family \(family)"
            let session = ExperienceSession()
            let shell = try await SimulationTest.open(session)
            let presenter = shell.presenter
            XCTAssertTrue(presenter.send("sim.family", [Double(family)], through: shell.port).isAccepted, name)
            try SimulationTest.frames(session, 2)
            try SimulationTest.pause(shell)
            try SimulationTest.frames(session, 1)
            let before = try loads(shell)
            XCTAssertTrue(presenter.send("sim.paint", [20, 20, 0], through: shell.port).isAccepted, name)
            XCTAssertTrue(presenter.send("sim.step", through: shell.port).isAccepted, name)
            try assertWithinTolerance(session, shell, name + ": paint then step")
            XCTAssertEqual(try loads(shell), before + 1, name + ": the mirror was loaded")
            session.close()
        }
    }
}
