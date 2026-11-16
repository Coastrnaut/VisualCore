// FloatMirrorTests — feature 119 (A16-P03) T-A16-304 (FR-A16-303; SC-A16-301; clarification Q3). The presenter's float
// mirrors inside the one app's session host, short runs only: running reaction-diffusion and the wave step their GPU
// field by the engine's iterations and stay within 0.01 of the CPU field; a mirror is loaded again once 64 GPU steps
// ran since its last load; a context recreation, a resize, a preset, a reset and a time step load it from the CPU
// field; the drawn cells equal the CPU palette within ±1 per channel; no pass samples its own output.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class FloatMirrorTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated { FieldPass.runObserver = nil }
        super.tearDown()
    }

    /// The presenter's GPU field of the current family, read right after a frame.
    private func gpuField(_ session: ExperienceSession, _ shell: ExperienceShell<SimulationPresenter>) throws
        -> FieldGrid {
        try SimulationTest.frames(session, 1)
        let core = try SimulationTest.core(shell)
        if core.kind == .wave { return try XCTUnwrap(shell.presenter.wave).readBack().current }
        return try XCTUnwrap(shell.presenter.grayScott).readBack()
    }

    /// Opens the experience in `family` (1 or 2).
    private func open(_ session: ExperienceSession, family: Double) async throws -> ExperienceShell<SimulationPresenter> {
        let shell = try await SimulationTest.open(session)
        XCTAssertTrue(shell.handle(control: "sim.family", values: [family]).isAccepted)
        try SimulationTest.frames(session, 1)
        XCTAssertEqual(shell.presenter.floatSupported, true, "Floating-point render targets are not available")
        return shell
    }

    func testRunningMirrorsStayWithinToleranceAndReloadAfter64Steps() async throws {
        for family in [1.0, 2.0] {
            let session = ExperienceSession()
            let shell = try await open(session, family: family)
            let presenter = shell.presenter
            XCTAssertTrue(shell.handle(control: "sim.speed", values: [4]).isAccepted)
            let loads = presenter.floatLoadCount
            var reloaded = false
            for frame in 0..<60 {
                let gpu = try gpuField(session, shell)
                let cpu = try SimulationTest.core(shell).model.field.current
                let difference = try XCTUnwrap(gpu.maxAbsDifference(cpu))
                XCTAssertLessThanOrEqual(difference, 0.01, "family \(family) frame \(frame)")
                XCTAssertLessThanOrEqual(presenter.stepsSinceLoad, SimulationPresenter.reloadInterval)
                if presenter.floatLoadCount > loads { reloaded = true }
            }
            XCTAssertGreaterThan(presenter.floatStepCount, 0, "family \(family) stepped on the GPU")
            XCTAssertGreaterThan(try SimulationTest.core(shell).stepCount, SimulationPresenter.reloadInterval)
            XCTAssertTrue(reloaded, "family \(family) reloaded after 64 steps")
            session.close()
            XCTAssertNil(presenter.grayScott)
            XCTAssertNil(presenter.wave)
        }
    }

    func testNonStepChangesLoadTheMirror() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, family: 1)
        let presenter = shell.presenter
        try SimulationTest.pause(shell)
        try SimulationTest.frames(session, 1)
        var loads = presenter.floatLoadCount
        func expectLoad(_ name: String) throws {
            let gpu = try gpuField(session, shell)
            XCTAssertEqual(presenter.floatLoadCount, loads + 1, "\(name) loads the mirror")
            XCTAssertEqual(gpu, try SimulationTest.core(shell).model.field.current, "\(name): exact after a load")
            loads = presenter.floatLoadCount
        }
        session.recreateContext()
        try expectLoad("a context recreation")
        session.renderHost?.view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        session.renderHost?.view.layoutIfNeeded()
        try expectLoad("a resize")
        XCTAssertTrue(shell.handle(control: "sim.preset", values: [1]).isAccepted)
        try expectLoad("a preset")
        XCTAssertTrue(shell.handle(control: "sim.step").isAccepted)
        try SimulationTest.frames(session, 1)
        loads = presenter.floatLoadCount
        XCTAssertTrue(shell.handle(control: "sim.reset").isAccepted)
        try expectLoad("a reset")
        XCTAssertTrue(shell.handle(control: "sim.timestep", values: [0.5]).isAccepted)
        try expectLoad("a time step")
        session.close()
    }

    func testTheDrawnCellsAreThePalettesWithinOne() async throws {
        for family in [1.0, 2.0] {
            let session = ExperienceSession()
            let shell = try await open(session, family: family)
            try SimulationTest.pause(shell)
            for _ in 0..<3 { XCTAssertTrue(shell.handle(control: "sim.step").isAccepted) }
            let frame = try SimulationTest.picture(session)
            let core = try SimulationTest.core(shell)
            let expected = SimulationPalette.rgba(core.model.field, kind: core.kind)
            let n = SimulationCore.gridSize
            let square = SimulationPresenter.square(width: frame.width, height: frame.height, grid: n)
            let cell = square.side / Double(n)
            var worst = 0
            for y in stride(from: 0, to: n, by: 3) {
                for x in stride(from: 0, to: n, by: 3) {
                    let px = Int(square.x + (Double(x) + 0.5) * cell), py = Int(square.y + (Double(y) + 0.5) * cell)
                    let at = (py * frame.width + px) * 4, want = (y * n + x) * 4
                    for c in 0..<3 { worst = max(worst, abs(Int(frame.rgba[at + c]) - Int(expected[want + c]))) }
                }
            }
            XCTAssertLessThanOrEqual(worst, 1, "family \(family): the GPU display is the CPU palette within ±1")
            session.close()
        }
    }

    func testNoFloatPassSamplesItsOutput() async throws {
        let session = ExperienceSession()
        let shell = try await open(session, family: 2)
        XCTAssertTrue(shell.handle(control: "sim.speed", values: [4]).isAccepted)
        var runs: [FieldPass.Run] = []
        FieldPass.runObserver = { runs.append($0) }
        try SimulationTest.frames(session, 10)
        FieldPass.runObserver = nil
        let violations = runs.filter { !$0.outputIsFramebuffer && $0.inputs.values.contains($0.output) }
        XCTAssertEqual(violations.count, 0, "no run samples its output: \(violations)")
        XCTAssertEqual(runs.filter { $0.label == "a16.wave.display" }.count, 10, "one wave display per frame")
        XCTAssertGreaterThan(runs.filter { !$0.outputIsFramebuffer }.count, 0, "the wave stepped")
        session.close()
    }
}
