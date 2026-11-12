// SessionPerformanceTests — feature 192 T-U06-021, T-U06-025 (UA-F06; US3, US4; FR-U06-020 to FR-U06-043;
// SC-U06-004, SC-U06-005). The stage times of an open (prepare, set-up, first presented frame, programs compiled
// at the end of the set-up), the late shader compilations and rebuilds, and the performance record of a session:
// its fields while an experience is open, the frozen record after a close and after a failed open, its text form,
// and the proof that measuring changes nothing in the experience.
// The helpers (`sampleRequest`, `SampleProbe`, `layOut`, `drawFrame`, `openInBackground`, …) are in
// SessionOpenCloseTests.swift and SamplePresenter.swift. Test-only.
import SwiftUI
import UIKit
import XCTest
import VisualCoreDiagnostics
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

// MARK: - A presenter that compiles shader programs

/// The sample presenter with shader programs: it behaves like `SamplePresenter<NoFault>` (which it wraps) and, on
/// request, compiles one program in its set-up and one more in a later drawn frame (a late compilation).
@MainActor
private final class CompilingPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>

    /// The sample presenter that does the drawing.
    let inner = SamplePresenter<NoFault>()
    /// Whether `setup` compiles a program (as a real experience does).
    let compilesInSetup: Bool
    /// The drawn frame (1 is the first) in which one more program is compiled; nil for never.
    let lateFrame: Int?
    /// Frames drawn since the presenter was created.
    private(set) var drawnFrames = 0
    private var setupProgram: ShaderProgram?
    private var lateProgram: ShaderProgram?

    init(compilesInSetup: Bool, lateFrame: Int?) {
        self.compilesInSetup = compilesInSetup
        self.lateFrame = lateFrame
    }

    /// A full-screen triangle (GLSL ES 3.00; the registry's shader library supplies the version line).
    private static let vertexSource = """
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """
    /// The fragment source of the program of the set-up; it differs from every other program of the package.
    private static let setupFragmentSource = """
    precision mediump float;
    out vec4 sessionPerformanceSetupColor;
    void main() { sessionPerformanceSetupColor = vec4(0.125, 0.25, 0.375, 1.0); }
    """
    /// The fragment source of the late program; it differs from the set-up's, so it is no cache hit.
    private static let lateFragmentSource = """
    precision mediump float;
    out vec4 sessionPerformanceLateColor;
    void main() { sessionPerformanceLateColor = vec4(0.625, 0.75, 0.875, 1.0); }
    """

    func setup(_ context: RenderContext) throws {
        try inner.setup(context)
        if compilesInSetup {
            setupProgram = try context.resources.program(vertex: Self.vertexSource,
                                                         fragment: Self.setupFragmentSource)
        }
    }

    func resize(_ context: RenderContext) {
        inner.resize(context)
    }

    func draw(_ core: SampleExperienceCore<NoFault>, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        drawnFrames += 1
        if drawnFrames == lateFrame {
            lateProgram = try context.resources.program(vertex: Self.vertexSource,
                                                        fragment: Self.lateFragmentSource)
        }
        try inner.draw(core, tier: tier, context: context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        if let setupProgram { context.resources.release(setupProgram) }
        if let lateProgram { context.resources.release(lateProgram) }
        setupProgram = nil
        lateProgram = nil
        inner.teardown(context)
    }

    func shedCaches() {
        inner.shedCaches()
    }

    func describe(_ core: SampleExperienceCore<NoFault>) -> String {
        inner.describe(core)
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        inner.makeControls(port)
    }
}

/// What a test keeps of the compiling experience a request's factory built.
@MainActor
private final class CompilingProbe {
    /// The shell of the last factory call.
    var shell: ExperienceShell<CompilingPresenter>?
    /// The presenter of the last factory call.
    var presenter: CompilingPresenter? { shell?.presenter }
}

/// An open request for the sample drawn by a `CompilingPresenter`, and the probe that sees what its factory builds.
@MainActor
private func compilingRequest(compilesInSetup: Bool, lateFrame: Int?,
                              seed: UInt64 = 42) -> (request: ExperienceOpenRequest, probe: CompilingProbe) {
    let probe = CompilingProbe()
    let request = ExperienceOpenRequest(id: SampleExperience.id, seed: seed) {
        let presenter = CompilingPresenter(compilesInSetup: compilesInSetup, lateFrame: lateFrame)
        let shell = ExperienceShell(id: SampleExperience.id, presenter: presenter)
        probe.shell = shell
        return shell
    }
    return (request, probe)
}

// MARK: - Tests

@MainActor
final class SessionPerformanceTests: XCTestCase {
    // MARK: Helpers

    /// A session with the healthy sample running and laid out, after `frames` frames drawn without presenting.
    /// `prepare` sees the session before the open (to inject conditions or the launch time).
    private func runningSession(
        seed: UInt64 = 42, frames: Int = 0, prepare: ((ExperienceSession) -> Void)? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) async -> (session: ExperienceSession, probe: SampleProbe<NoFault>) {
        let session = ExperienceSession()
        prepare?(session)
        let (request, probe) = sampleRequest(seed: seed)
        let result = await session.open(request)
        XCTAssertEqual(result, .running, file: file, line: line)
        layOut(session)
        XCTAssertEqual(drawFrames(session, frames), frames, "every frame was drawn", file: file, line: line)
        return (session, probe)
    }

    /// Draws `count` frames without presenting them; returns how many were drawn.
    @discardableResult
    private func drawFrames(_ session: ExperienceSession, _ count: Int) -> Int {
        var drawn = 0
        for _ in 0..<count where drawFrame(session) { drawn += 1 }
        return drawn
    }

    /// Checks that no stage of `timings` has a value.
    private func assertNoStage(_ timings: SessionStageTimings, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(timings.prepare, file: file, line: line)
        XCTAssertNil(timings.createHost, file: file, line: line)
        XCTAssertNil(timings.activate, file: file, line: line)
        XCTAssertNil(timings.firstFrame, file: file, line: line)
        XCTAssertNil(timings.setup, file: file, line: line)
        XCTAssertNil(timings.firstPresent, file: file, line: line)
        XCTAssertNil(timings.programsCompiled, file: file, line: line)
    }

    // MARK: Stages (US3; FR-U06-020 to FR-U06-023)

    func testAfterAnOpenPrepareSetupAndTheProgramsCompiledAreSet() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        let host = try XCTUnwrap(session.renderHost)
        let compiled = host.resources.compileCount
        let timings = session.diagnostics.timings

        XCTAssertNotNil(timings.prepare, "the preparation has a duration")
        XCTAssertGreaterThanOrEqual(timings.prepare ?? -1, 0)
        XCTAssertNotNil(timings.setup, "the set-up has a duration")
        XCTAssertGreaterThanOrEqual(timings.setup ?? -1, 0)
        XCTAssertNotNil(timings.programsCompiled, "the programs compiled in the set-up are counted")
        XCTAssertGreaterThanOrEqual(timings.programsCompiled ?? -1, 0)
        XCTAssertEqual(timings.programsCompiled, compiled, "the count is the registry's at the end of the set-up")
    }

    func testAPresenterThatCompilesInItsSetupHasThatProgramInTheCount() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = compilingRequest(compilesInSetup: true, lateFrame: nil)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        let host = try XCTUnwrap(session.renderHost)
        let compiled = host.resources.compileCount
        XCTAssertEqual(compiled, 1, "the set-up compiled one program")
        XCTAssertEqual(session.diagnostics.timings.programsCompiled, 1)
        XCTAssertEqual(probe.presenter?.inner.setupCalls, 1)
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(record.programsCompiled, 1)
        XCTAssertEqual(record.lateCompilations, 0, "a program of the set-up is not a late compilation")
        XCTAssertTrue(record.passes)
    }

    func testWithoutAPresentedFrameTheFirstPresentIsNilAndTheRecordSaysNotPresented() async throws {
        let (session, _) = await runningSession(frames: 5)
        defer { session.close() }
        XCTAssertNotNil(session.diagnostics.timings.firstFrame, "frames were drawn")
        XCTAssertNil(session.diagnostics.timings.firstPresent, "a drawn frame that was not presented does not count")
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertFalse(record.presented)
        XCTAssertNil(record.firstPresentMs)
        XCTAssertEqual(record.pacing.samples, 0, "no presented frame, no pacing sample")
        XCTAssertEqual(session.renderHost?.presentedFrameCount, 0)
    }

    func testWithPresentedFramesTheFirstPresentIsSetOnceAndThePacingHasOneSampleLessThanFrames() async throws {
        let (session, _) = await runningSession()
        var window: UIWindow?
        defer {
            window?.isHidden = true
            session.close()
        }
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertNil(session.diagnostics.timings.firstPresent)

        // First the laid-out host as it is (off screen); when that does not present, the host's view in a window.
        var presented = host.renderOneFrame(present: true)
        if !presented || host.presentedFrameCount == 0 {
            let frame = CGRect(x: 0, y: 0, width: 64, height: 64)
            let shown = UIWindow(frame: frame)
            let controller = UIViewController()
            shown.rootViewController = controller
            shown.isHidden = false
            controller.view.frame = frame
            controller.view.addSubview(host.view)
            host.view.frame = frame
            shown.layoutIfNeeded()
            host.view.layoutIfNeeded()
            window = shown
            presented = host.renderOneFrame(present: true)
        }
        guard presented, host.presentedFrameCount > 0 else {
            // No display path in this environment: only the behaviour without a display can be checked.
            XCTAssertNil(session.diagnostics.timings.firstPresent)
            let record = try XCTUnwrap(session.performanceRecord)
            XCTAssertFalse(record.presented)
            XCTAssertNil(record.firstPresentMs)
            throw XCTSkip("no frame could be presented here, neither off screen nor in a window")
        }

        let first = try XCTUnwrap(session.diagnostics.timings.firstPresent, "set by the first presented frame")
        let prepare = try XCTUnwrap(session.diagnostics.timings.prepare)
        XCTAssertGreaterThanOrEqual(first, prepare, "the time to the first present contains the preparation")

        var more = 0
        for _ in 0..<5 where host.renderOneFrame(present: true) { more += 1 }
        XCTAssertEqual(more, 5, "five more frames were presented")
        XCTAssertEqual(session.diagnostics.timings.firstPresent, first, "the first present is set once")

        let record = try XCTUnwrap(session.performanceRecord)
        let frames = host.presentedFrameCount
        XCTAssertTrue(record.presented)
        XCTAssertEqual(record.firstPresentMs, first * 1_000)
        XCTAssertGreaterThanOrEqual(frames, 6)
        XCTAssertEqual(record.pacing.samples, frames - 1, "one interval between two presented frames")
        XCTAssertEqual(record.pacing.invalid, 0)
        XCTAssertNotNil(record.pacing.medianMs)
    }

    func testAFailedSetupKeepsPrepareAndLeavesSetupAndFirstPresentNil() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        XCTAssertNil(session.lastPerformanceRecord)
        let (request, _) = sampleRequest(configure: { $0.failsInSetup = true })
        let result = await session.open(request)
        guard case .failed(let failure) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(failure.stage, .setup)

        let timings = session.diagnostics.timings
        XCTAssertNotNil(timings.prepare)
        XCTAssertNil(timings.setup, "a set-up that threw has no duration")
        XCTAssertNil(timings.firstPresent)
        XCTAssertNil(timings.programsCompiled)

        XCTAssertNil(session.performanceRecord, "no experience is open after a failed open")
        let record = try XCTUnwrap(session.lastPerformanceRecord, "the failed open leaves a record")
        XCTAssertEqual(record.experience, SampleExperience.id.rawValue)
        XCTAssertNotNil(record.prepareMs)
        XCTAssertNil(record.setupMs)
        XCTAssertNil(record.firstPresentMs)
        XCTAssertFalse(record.presented)
    }

    func testACancelledPreparationLeavesEveryStageNilAndNoRecord() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, _) = sampleRequest(SlowPreparation.self)
        let pending = openInBackground(session, request)
        let preparing = await waitUntil { session.state == .preparing }
        XCTAssertTrue(preparing, "the slow sample is preparing")
        XCTAssertNil(session.performanceRecord, "no record while preparing")

        session.close()
        let result = await pending.value
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(session.state, .idle)
        assertNoStage(session.diagnostics.timings)
        XCTAssertNil(session.performanceRecord)
        XCTAssertNil(session.lastPerformanceRecord, "a cancelled preparation leaves the last record as it was")
    }

    func test600InteractiveFramesOfTheSampleGiveNoLateCompilation() async throws {
        let (session, _) = await runningSession()
        defer { session.close() }
        XCTAssertEqual(drawFrames(session, 600), 600)
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(record.lateCompilations, 0)
        XCTAssertTrue(record.passes)
        XCTAssertEqual(record.rebuilds, 0)
    }

    func testAProgramCompiledInTheTenthFrameIsExactlyOneLateCompilation() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = compilingRequest(compilesInSetup: false, lateFrame: 10)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        let compiledInSetup = session.diagnostics.timings.programsCompiled
        XCTAssertEqual(compiledInSetup, 0, "this presenter compiles nothing in its set-up")
        layOut(session)

        XCTAssertEqual(drawFrames(session, 9), 9)
        let early = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(early.lateCompilations, 0, "nothing was compiled in the first nine frames")
        XCTAssertTrue(early.passes)

        XCTAssertEqual(drawFrames(session, 11), 11)
        XCTAssertEqual(probe.presenter?.drawnFrames, 20)
        XCTAssertEqual(session.state, .running, "the late compilation is no failure")
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(record.lateCompilations, 1)
        XCTAssertFalse(record.passes)
        XCTAssertEqual(record.rebuilds, 0)
        XCTAssertEqual(session.diagnostics.timings.programsCompiled, compiledInSetup,
                       "the count of the set-up does not follow later compilations")
        XCTAssertEqual(record.programsCompiled, compiledInSetup)
        XCTAssertEqual(session.renderHost?.resources.compileCount, 1)
    }

    func testAContextRecreationOfTheSampleCountsOneRebuildAndNoLateCompilation() async throws {
        let (session, _) = await runningSession(frames: 3)
        defer { session.close() }
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        let after = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(after.rebuilds, 1)
        XCTAssertEqual(after.lateCompilations, 0)

        XCTAssertEqual(drawFrames(session, 20), 20)
        let later = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(later.rebuilds, 1)
        XCTAssertEqual(later.lateCompilations, 0)
        XCTAssertTrue(later.passes)
    }

    func testTheProgramsRebuiltAfterAContextRecreationAreNotLateCompilations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = compilingRequest(compilesInSetup: true, lateFrame: nil)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        XCTAssertEqual(drawFrames(session, 3), 3)
        let host = try XCTUnwrap(session.renderHost)
        let compiledBefore = host.resources.compileCount
        XCTAssertEqual(compiledBefore, 1)

        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.presenter?.inner.setupCalls, 2, "the scene was set up again")
        let compiledAfter = host.resources.compileCount
        XCTAssertEqual(compiledAfter, 2, "the program of the set-up was compiled again in the new context")

        XCTAssertEqual(drawFrames(session, 20), 20)
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(record.rebuilds, 1)
        XCTAssertEqual(record.lateCompilations, 0, "a rebuild after a lost context is not a late compilation")
        XCTAssertTrue(record.passes)
        XCTAssertEqual(session.diagnostics.timings.programsCompiled, 1, "the count of the open's set-up stays")
    }

    func testOldEncodedStageTimingsDecodeWithTheNewFieldsNil() throws {
        let old = Data(#"{"prepare":0.1}"#.utf8)
        let timings = try JSONDecoder().decode(SessionStageTimings.self, from: old)
        XCTAssertEqual(timings.prepare, 0.1)
        XCTAssertNil(timings.setup)
        XCTAssertNil(timings.firstPresent)
        XCTAssertNil(timings.programsCompiled)
    }

    // MARK: Record (US4; FR-U06-030 to FR-U06-043)

    func testTheRecordIsNilWhenIdleAndHoldsTheMeasurementsWhileRunning() async throws {
        let idle = ExperienceSession()
        XCTAssertNil(idle.performanceRecord, "no record without an experience")
        XCTAssertNil(idle.lastPerformanceRecord)

        let (session, _) = await runningSession(frames: 3) { session in
            session.conditions = { DeviceConditions(thermal: .fair, lowPower: true) }
        }
        defer { session.close() }
        let host = try XCTUnwrap(session.renderHost)
        let record = try XCTUnwrap(session.performanceRecord)
        let stats = host.resources.stats
        let timings = session.diagnostics.timings

        XCTAssertEqual(record.experience, SampleExperience.id.rawValue)
        XCTAssertEqual(record.qualityLevels, 3, "the sample declares three levels")
        XCTAssertEqual(record.qualityLevel, session.qualityLevel)
        XCTAssertLessThan(record.qualityLevel, record.qualityLevels)
        XCTAssertFalse(record.qualityPinned, "no pin was set")
        XCTAssertEqual(record.gpuBytes, stats.totalBytes)
        XCTAssertEqual(record.gpuPeakBytes, stats.peakBytes)
        XCTAssertGreaterThan(record.gpuBytes, 0, "the sample's texture is live")
        XCTAssertNotNil(record.memoryFootprintBytes, "the simulator reports the footprint")
        XCTAssertGreaterThan(record.memoryFootprintBytes ?? 0, 0)
        XCTAssertEqual(record.thermal, .fair, "from the injected conditions")
        XCTAssertTrue(record.lowPower, "from the injected conditions")
        XCTAssertNotNil(record.prepareMs)
        XCTAssertNotNil(record.setupMs)
        XCTAssertEqual(record.prepareMs, timings.prepare.map { $0 * 1_000 }, "milliseconds")
        XCTAssertEqual(record.setupMs, timings.setup.map { $0 * 1_000 }, "milliseconds")
        XCTAssertEqual(record.programsCompiled, timings.programsCompiled)
        XCTAssertEqual(record.frameCapFPS, host.framePacing.maxFPS)
        XCTAssertEqual(record.renderScale, host.framePacing.renderScale)
        XCTAssertEqual(record.memoryEvents, 0)
        XCTAssertEqual(record.rebuilds, 0)
        XCTAssertNil(record.launchMs, "no launch time was given")
        XCTAssertNil(record.firstLaunch)
    }

    func testTheLaunchTimeGivenToTheSessionIsInTheRecord() async throws {
        let (session, _) = await runningSession(frames: 1) { session in
            session.launch = LaunchTiming(milliseconds: 123.5, firstLaunch: true)
        }
        defer { session.close() }
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(record.launchMs, 123.5)
        XCTAssertEqual(record.firstLaunch, true)
    }

    func testAMemoryWarningCountsOneMemoryEventAndKeepsTheQualityLevel() async throws {
        let (session, _) = await runningSession(frames: 3)
        defer { session.close() }
        let levelBefore = session.qualityLevel
        let before = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(before.memoryEvents, 0)

        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .running, "the sample is far below the memory-pressure limit")
        let after = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(after.memoryEvents, 1)
        XCTAssertEqual(session.qualityLevel, levelBefore, "a memory warning does not change the quality")
        XCTAssertEqual(after.qualityLevel, before.qualityLevel)
    }

    func testASuspensionAndAResumeAddNoMissedRefreshAndNoSample() async throws {
        let (session, _) = await runningSession(frames: 3)
        defer { session.close() }
        let before = try XCTUnwrap(session.performanceRecord)

        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        let away = try XCTUnwrap(session.performanceRecord, "a suspended experience has a record")
        XCTAssertEqual(away.pacing, before.pacing)

        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(drawFrames(session, 3), 3)
        let after = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(after.pacing, before.pacing, "no frame was presented in between")
        XCTAssertEqual(after.pacing.missed, before.pacing.missed)
        XCTAssertEqual(after.pacing.samples, before.pacing.samples)
    }

    func testAfterACloseTheLastRecordIsTheFrozenOneAndTheLiveRecordIsNil() async throws {
        let (session, _) = await runningSession(frames: 10)
        defer { session.close() }
        XCTAssertNil(session.lastPerformanceRecord, "nothing was closed yet")
        let before = try XCTUnwrap(session.performanceRecord)

        session.close()
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.performanceRecord)
        let frozen = try XCTUnwrap(session.lastPerformanceRecord)
        XCTAssertEqual(frozen.experience, before.experience)
        XCTAssertEqual(frozen.prepareMs, before.prepareMs)
        XCTAssertEqual(frozen.setupMs, before.setupMs)
        XCTAssertEqual(frozen.lateCompilations, before.lateCompilations)
        XCTAssertEqual(frozen.programsCompiled, before.programsCompiled)
        XCTAssertEqual(frozen.gpuPeakBytes, before.gpuPeakBytes)
    }

    func testTheTextOfTheRecordReadsBackEqual() async throws {
        let (session, _) = await runningSession(frames: 5) { session in
            session.launch = LaunchTiming(milliseconds: 123.5, firstLaunch: false)
        }
        defer { session.close() }
        let record = try XCTUnwrap(session.performanceRecord)
        let data = try record.encoded()
        XCTAssertLessThanOrEqual(data.count, PerformanceRecord.maxBytes)
        let back = try PerformanceRecord(data: data)
        XCTAssertEqual(back, record)

        session.close()
        let frozen = try XCTUnwrap(session.lastPerformanceRecord)
        let frozenData = try frozen.encoded()
        let frozenBack = try PerformanceRecord(data: frozenData)
        XCTAssertEqual(frozenBack, frozen)
    }

    func testMeasuringChangesNothingInTheExperience() async throws {
        // The same run twice (same seed, same request, 120 frames and one action): once the record is read in
        // every frame, once it is never read.
        func run(measured: Bool) async throws -> (digest: String, steps: Int) {
            let (session, probe) = await runningSession(seed: 7)
            defer { session.close() }
            for frame in 0..<120 {
                if frame == 60 {
                    let action = session.experience?.handle(control: "tone", values: [0.5])
                    XCTAssertEqual(action, .accepted)
                }
                XCTAssertTrue(drawFrame(session))
                if measured {
                    let record = session.performanceRecord
                    XCTAssertNotNil(record)
                }
            }
            let digest = try probe.digest()
            return (digest.hex, probe.stepIndex)
        }
        let measured = try await run(measured: true)
        let unmeasured = try await run(measured: false)
        XCTAssertEqual(measured.digest, unmeasured.digest, "reading the record does not change the state")
        XCTAssertEqual(measured.steps, unmeasured.steps)
        XCTAssertGreaterThan(unmeasured.steps, 0, "the run advanced the state")
    }
}
