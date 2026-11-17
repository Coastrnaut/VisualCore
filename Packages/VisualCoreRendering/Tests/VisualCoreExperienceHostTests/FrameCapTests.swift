// FrameCapTests — feature 134 (A18-P04) T-A18-402 (FR-A18-404, FR-A18-409; contract
// specs/134-ac-p04-power-visibility/contracts/power.md "Frame cap"). The optional frame cap of a presenter: a presenter
// declaring 30 opens a session whose render host paces at 30, a presenter without a declaration keeps 60, a declared 10
// is raised to the floor of 30; `FramePacing` lowers a requested 60 under Low Power Mode or serious heat and keeps a
// declared 30 at the floor. Short, no GPU readback.
//
// The host's pacing follows the simulator's thermal state and Low Power Mode; the session cases assert the contract's
// values at nominal heat with Low Power Mode off, and otherwise the value `FramePacing` defines for the conditions read.
import XCTest
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

/// A presenter that keeps every default of `ExperiencePresenter`, the frame cap among them.
@MainActor
private final class UncappedPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>
    func setup(_ context: RenderContext) throws {}
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
    func describe(_ core: Core) -> String { "uncapped" }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
}

/// A presenter that declares a frame cap.
@MainActor
private final class CappedPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>
    let maxFramesPerSecond: Int
    init(_ cap: Int) { maxFramesPerSecond = cap }
    func setup(_ context: RenderContext) throws {}
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
    func describe(_ core: Core) -> String { "capped \(maxFramesPerSecond)" }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
}

@MainActor
final class FrameCapTests: XCTestCase {
    /// The conditions the render host reads, as `FramePacing` sees them.
    private var conditions: (thermal: FramePacing.Thermal, lowPower: Bool) {
        let info = ProcessInfo.processInfo
        return (FramePacing.Thermal(rawValue: info.thermalState.rawValue) ?? .nominal, info.isLowPowerModeEnabled)
    }

    /// Opens a session of `make()` and returns its host's frame-rate cap; closes the session.
    private func openedCap(_ make: @escaping @MainActor () -> any Experience,
                           file: StaticString = #filePath, line: UInt = #line) async throws -> Int {
        let session = ExperienceSession()
        let request = ExperienceOpenRequest(id: SampleExperience.id, seed: 7, memoryPressureLimit: nil, make: make)
        let result = await session.open(request)
        XCTAssertEqual(result, .running, file: file, line: line)
        let host = try XCTUnwrap(session.renderHost, file: file, line: line)
        let cap = host.framePacing.maxFPS
        session.close()
        XCTAssertEqual(session.state, .idle, file: file, line: line)
        return cap
    }

    /// The cap `FramePacing` defines for `requested` under the conditions read now.
    private func expected(_ requested: Int) -> Int {
        let now = conditions
        return FramePacing(thermal: now.thermal, lowPower: now.lowPower, requestedMaxFPS: requested).maxFPS
    }

    private var nominal: Bool { conditions.thermal == .nominal && !conditions.lowPower }

    func testTheDefaultIsSixty() {
        let presenter = UncappedPresenter()
        XCTAssertEqual(presenter.maxFramesPerSecond, 60)
        let shell = ExperienceShell(id: SampleExperience.id, presenter: presenter)
        XCTAssertEqual(shell.maxFramesPerSecond, 60)
        let experience: any Experience = shell
        XCTAssertEqual(experience.maxFramesPerSecond, 60)
        let capped: any Experience = ExperienceShell(id: SampleExperience.id, presenter: CappedPresenter(30))
        XCTAssertEqual(capped.maxFramesPerSecond, 30, "the shell forwards the presenter's cap")
    }

    func testADeclaredThirtyReachesTheHost() async throws {
        let cap = try await openedCap { ExperienceShell(id: SampleExperience.id, presenter: CappedPresenter(30)) }
        XCTAssertEqual(cap, expected(30))
        if nominal { XCTAssertEqual(cap, 30) }
    }

    func testAPresenterWithoutADeclarationKeepsSixty() async throws {
        let cap = try await openedCap { ExperienceShell(id: SampleExperience.id, presenter: UncappedPresenter()) }
        XCTAssertEqual(cap, expected(60))
        if nominal { XCTAssertEqual(cap, 60) }
    }

    func testADeclaredTenIsRaisedToTheFloor() async throws {
        let cap = try await openedCap { ExperienceShell(id: SampleExperience.id, presenter: CappedPresenter(10)) }
        XCTAssertEqual(cap, FramePacing.minimumFPS)
        XCTAssertEqual(cap, 30)
    }

    func testPacingLowersSixtyUnderPressureAndKeepsThirty() {
        XCTAssertEqual(FramePacing(thermal: .nominal, lowPower: false, requestedMaxFPS: 60).maxFPS, 60)
        let lowPower = FramePacing(thermal: .nominal, lowPower: true, requestedMaxFPS: 60).maxFPS
        XCTAssertLessThan(lowPower, 60)
        XCTAssertEqual(lowPower, 30)
        let serious = FramePacing(thermal: .serious, lowPower: false, requestedMaxFPS: 60).maxFPS
        XCTAssertLessThan(serious, 60)
        XCTAssertEqual(serious, 30)
        XCTAssertEqual(FramePacing(thermal: .critical, lowPower: false, requestedMaxFPS: 60).maxFPS, 30)
        XCTAssertEqual(FramePacing(thermal: .fair, lowPower: false, requestedMaxFPS: 60).maxFPS, 60)
        // A declared 30 stays at the floor under every condition.
        for thermal in FramePacing.Thermal.allCases {
            for lowPower in [false, true] {
                XCTAssertEqual(FramePacing(thermal: thermal, lowPower: lowPower, requestedMaxFPS: 30).maxFPS, 30,
                               "\(thermal) lowPower \(lowPower)")
            }
        }
        XCTAssertEqual(FramePacing(thermal: .nominal, lowPower: false, requestedMaxFPS: 10).maxFPS, 30)
    }
}
