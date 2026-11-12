// SessionPerformanceTests — feature 192 T-U06-021, T-U06-025 (UA-F06; US3, US4; FR-U06-020 to FR-U06-043;
// SC-U06-004, SC-U06-005). The stage times of an open (prepare, set-up, first presented frame, programs compiled
// at the end of the set-up), the late shader compilations and rebuilds, and the performance record of a session:
// its fields while an experience is open, the frozen record after a close and after a failed open, its text form,
// and the proof that measuring changes nothing in the experience. Also: a suspension between presented frames, a
// context loss the render host detects itself (injected with the host's internal test hook, hence the testable
// import of VisualCoreRendering), a close under memory pressure, the steps of the quality level and the
// first-present time of an open that waited for its activation.
// The helpers (`sampleRequest`, `SampleProbe`, `layOut`, `drawFrame`, `openInBackground`, …) are in
// SessionOpenCloseTests.swift and SamplePresenter.swift. Test-only.
import SwiftUI
import UIKit
import XCTest
import VisualCoreDiagnostics
import VisualCoreExperience
@testable import VisualCoreExperienceHost
@testable import VisualCoreRendering
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

/// The time a test scripts; the session's `timeSource` reads it at every quality decision.
@MainActor
private final class ScriptedTime {
    var now: Double
    init(_ now: Double) { self.now = now }
}

/// The device conditions a test scripts; the session's `conditions` closure reads them.
@MainActor
private final class ScriptedDevice {
    var value: DeviceConditions
    init(_ value: DeviceConditions) { self.value = value }
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

    /// Presents one frame on `host`: first the laid-out host as it is (off screen); when that does not present,
    /// with the host's view in a window, which is returned so that the test can hide it at its end. `presented`
    /// is false when no frame can reach a display here (the caller skips then).
    private func presentFirstFrame(_ host: RenderHost) -> (presented: Bool, window: UIWindow?) {
        let before = host.presentedFrameCount
        if host.renderOneFrame(present: true), host.presentedFrameCount > before {
            return (true, nil)
        }
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
        let drawn = host.renderOneFrame(present: true)
        return (drawn && host.presentedFrameCount > before, shown)
    }

    /// Presents `count` more frames on `host`; returns how many were presented.
    private func presentFrames(_ host: RenderHost, _ count: Int) -> Int {
        var presented = 0
        for _ in 0..<count where host.renderOneFrame(present: true) { presented += 1 }
        return presented
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
        let frameCap = try XCTUnwrap(record.frameCapFPS, "a render host exists, so the cap is in the record")
        let renderScale = try XCTUnwrap(record.renderScale, "a render host exists, so the scale is in the record")
        XCTAssertEqual(frameCap, host.framePacing.maxFPS)
        XCTAssertEqual(renderScale, host.framePacing.renderScale)
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

    func testASuspensionBetweenPresentedFramesAddsNoSampleAndNoLongInterval() async throws {
        let (session, _) = await runningSession()
        var window: UIWindow?
        defer {
            window?.isHidden = true
            session.close()
        }
        let host = try XCTUnwrap(session.renderHost)
        let first = presentFirstFrame(host)
        window = first.window
        guard first.presented else {
            throw XCTSkip("no frame could be presented here, neither off screen nor in a window")
        }

        // N = 4 presented frames before the suspension: N − 1 = 3 intervals.
        let moreBefore = presentFrames(host, 3)
        XCTAssertEqual(moreBefore, 3, "three more frames were presented")
        let framesBefore = host.presentedFrameCount
        XCTAssertEqual(framesBefore, 4)
        let before = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(before.pacing.samples, framesBefore - 1, "one interval between two presented frames")

        // Away for 0.3 s: an interval that spanned it would be far longer than 1.5 refresh periods and would
        // fall in the last bin of the meter (250 ms and more).
        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        let away = try XCTUnwrap(session.performanceRecord, "a suspended experience has a record")
        XCTAssertEqual(away.pacing, before.pacing)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(host.presentedFrameCount, framesBefore, "a paused host presents nothing")

        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        let resumed = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(resumed.pacing, before.pacing, "the resume itself is no sample")

        // M = 3 presented frames after the resume: the first one starts a new chain, so M − 1 = 2 intervals.
        let moreAfter = presentFrames(host, 3)
        XCTAssertEqual(moreAfter, 3, "three frames were presented after the resume")
        let framesAfter = host.presentedFrameCount - framesBefore
        XCTAssertEqual(framesAfter, 3)
        let after = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(after.pacing.samples, (framesBefore - 1) + (framesAfter - 1),
                       "the interval across the suspension is no sample")
        XCTAssertEqual(after.pacing.invalid, before.pacing.invalid)
        let slowest = try XCTUnwrap(after.pacing.p99Ms, "there are samples")
        XCTAssertLessThan(slowest, 250, "no interval of the time away was recorded")
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

    // MARK: Record without a render host, lost context, memory pressure, steps, deferred open

    func testAFailedOpenWithoutARenderHostRecordsNoFrameCapAndNoRenderScale() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (failing, _) = sampleRequest(FailingPreparation.self)
        let result = await session.open(failing)
        guard case .failed(let failure) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(failure.stage, .prepare)
        XCTAssertNil(session.renderHost, "a failed preparation never had a render host")
        XCTAssertNil(session.performanceRecord)

        // `fail` freezes a record whenever the session holds an experience, and it does from the factory call on.
        let record = try XCTUnwrap(session.lastPerformanceRecord, "the failed preparation leaves a record")
        XCTAssertEqual(record.experience, SampleExperience.id.rawValue)
        XCTAssertNil(record.frameCapFPS, "no render host, no frame cap")
        XCTAssertNil(record.renderScale, "no render host, no render scale")
        XCTAssertNotNil(record.prepareMs, "the preparation that failed has a duration")
        XCTAssertNil(record.setupMs)
        XCTAssertNil(record.firstPresentMs)
        XCTAssertNil(record.programsCompiled)
        XCTAssertFalse(record.presented)
        XCTAssertEqual(record.gpuBytes, 0)
        XCTAssertEqual(record.gpuPeakBytes, 0)

        let data = try record.encoded()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("frame_cap_fps"), text)
        XCTAssertFalse(text.contains("render_scale"), text)
        XCTAssertTrue(text.contains("prepare_ms"), text)
        let back = try PerformanceRecord(data: data)
        XCTAssertEqual(back, record)

        // A running experience has a render host, and its record has both values.
        let (request, _) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        let host = try XCTUnwrap(session.renderHost)
        let running = try XCTUnwrap(session.performanceRecord)
        let frameCap = try XCTUnwrap(running.frameCapFPS)
        let renderScale = try XCTUnwrap(running.renderScale)
        XCTAssertEqual(frameCap, host.framePacing.maxFPS)
        XCTAssertEqual(renderScale, host.framePacing.renderScale)
        let runningData = try running.encoded()
        let runningText = String(decoding: runningData, as: UTF8.self)
        XCTAssertTrue(runningText.contains("frame_cap_fps"), runningText)
        XCTAssertTrue(runningText.contains("render_scale"), runningText)
    }

    func testAContextLossTheHostDetectsItselfIsARebuildAndNoLateCompilation() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = compilingRequest(compilesInSetup: true, lateFrame: nil)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        let drawnBefore = drawFrames(session, 3)
        XCTAssertEqual(drawnBefore, 3)
        let host = try XCTUnwrap(session.renderHost)
        let compiledBefore = host.resources.compileCount
        XCTAssertEqual(compiledBefore, 1, "the set-up compiled one program")
        let timingsBefore = session.diagnostics.timings
        XCTAssertEqual(timingsBefore.programsCompiled, 1)
        let generationBefore = host.generation

        // The host's test hook: the next frame ends as if the swap had failed with EGL_CONTEXT_LOST. The host
        // reports the loss to its observers (the session counts the rebuild) and recreates its context in the
        // same call, so nothing has to be awaited.
        host.simulateContextLossOnNextFrame()
        let lostFrame = host.renderOneFrame(present: false)
        XCTAssertFalse(lostFrame, "the frame with the lost context is dropped")
        XCTAssertGreaterThan(host.generation, generationBefore, "the host recreated its context")
        XCTAssertEqual(host.state, .active)
        XCTAssertEqual(session.state, .running, "a context the host rebuilt is no failure")
        XCTAssertTrue(session.renderHost === host)
        XCTAssertEqual(probe.presenter?.inner.setupCalls, 2, "the scene was set up again")
        let compiledAfter = host.resources.compileCount
        XCTAssertEqual(compiledAfter, compiledBefore + 1, "the program of the set-up was compiled again")
        let atRebuild = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(atRebuild.rebuilds, 1)
        XCTAssertEqual(atRebuild.lateCompilations, 0, "also before the next drawn frame")

        let drawnAfter = drawFrames(session, 20)
        XCTAssertEqual(drawnAfter, 20)
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(record.rebuilds, 1)
        XCTAssertEqual(record.lateCompilations, 0, "a rebuild after a lost context is not a late compilation")
        XCTAssertTrue(record.passes)
        XCTAssertEqual(host.resources.compileCount, compiledAfter, "nothing was compiled in the frames after")
        let timingsAfter = session.diagnostics.timings
        XCTAssertEqual(timingsAfter.programsCompiled, timingsBefore.programsCompiled,
                       "the count of the open's set-up stays")
        XCTAssertEqual(timingsAfter.setup, timingsBefore.setup, "the time of the first set-up stays")
        XCTAssertEqual(record.programsCompiled, 1)
        XCTAssertEqual(session.diagnostics.contextRecreations, 1)
        XCTAssertEqual(session.diagnostics.failures, 0)
    }

    func testTheFrozenRecordOfACloseUnderMemoryPressureKeepsThePeakAndTheEvent() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        // A limit of 0 bytes is raised to the rule's minimum of 1 byte; the sample's 1 × 1 texture has 4.
        let (request, _) = sampleRequest(memoryPressureLimit: 0)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        let drawn = drawFrames(session, 3)
        XCTAssertEqual(drawn, 3)
        let host = try XCTUnwrap(session.renderHost)
        let liveBefore = host.resources.stats.totalBytes
        XCTAssertGreaterThan(liveBefore, 1, "the session is above its limit")
        XCTAssertNil(session.lastPerformanceRecord, "nothing was closed yet")

        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .message)
        XCTAssertNil(session.performanceRecord, "no experience is open after the close")
        let frozen = try XCTUnwrap(session.lastPerformanceRecord, "the close under memory pressure leaves a record")
        XCTAssertEqual(frozen.experience, SampleExperience.id.rawValue)
        XCTAssertEqual(frozen.memoryEvents, 1, "the warning that closed the experience is counted")
        XCTAssertGreaterThanOrEqual(frozen.gpuPeakBytes, liveBefore, "the peak is read before the host is destroyed")
        XCTAssertGreaterThanOrEqual(frozen.gpuBytes, liveBefore, "and so are the live bytes")
        XCTAssertNotNil(frozen.frameCapFPS, "the render host still existed")
        XCTAssertNotNil(frozen.renderScale)
        XCTAssertEqual(session.diagnostics.memoryClosures, 1)
    }

    func testStepsDownAndUpOfTheSessionAreInItsRecord() async throws {
        let time = ScriptedTime(100)
        let device = ScriptedDevice(DeviceConditions(thermal: .serious, lowPower: false))
        let session = ExperienceSession()
        defer { session.close() }
        session.timeSource = { time.now }
        session.conditions = { device.value }
        // The host is never laid out: without a surface no frame is drawn, so only the open and the calls of
        // `refreshQuality()` below take decisions. The sample has three levels.
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)

        // t = 100 (open): hot, no change yet, so one step down: 0 → 1; last change = 100.
        XCTAssertEqual(session.qualityLevel, 1)

        // t = 102: hot; 102 − 100 ≥ 1 s (governor) and ≥ 2 s (decision interval): 1 → 2; last change = 102.
        time.now = 102
        session.refreshQuality()
        XCTAssertEqual(session.qualityLevel, 2)

        // t = 103: nominal; the calm period starts at 103; no step (and 103 − 102 < 2 s anyway).
        device.value = .nominal
        time.now = 103
        session.refreshQuality()
        XCTAssertEqual(session.qualityLevel, 2)

        // t = 113: 10 s of calm (calm period) and 113 − 102 ≥ 2 s since the last change: one step up, 2 → 1.
        time.now = 113
        session.refreshQuality()
        XCTAssertEqual(session.qualityLevel, 1)

        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertEqual(record.stepsDown, 2)
        XCTAssertEqual(record.stepsUp, 1)
        XCTAssertEqual(record.qualityLevel, 1)
        XCTAssertEqual(record.qualityLevels, 3)
        XCTAssertFalse(record.qualityPinned)
        XCTAssertEqual(record.thermal, .nominal)
        XCTAssertFalse(record.lowPower)

        // The frozen record keeps the steps (the governor is dropped only after the record was taken).
        session.close()
        let frozen = try XCTUnwrap(session.lastPerformanceRecord)
        XCTAssertEqual(frozen.stepsDown, 2)
        XCTAssertEqual(frozen.stepsUp, 1)
        XCTAssertEqual(frozen.qualityLevel, 1)
    }

    func testTheFirstPresentTimeOfADeferredOpenDoesNotIncludeTheWait() async throws {
        let session = ExperienceSession()
        var window: UIWindow?
        defer {
            window?.isHidden = true
            session.close()
        }
        let clock = ContinuousClock()
        session.setScenePhase(.background)
        let openStart = clock.now
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .suspended)
        XCTAssertEqual(session.state, .suspended)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)

        // The experience waits half a second for the app to become active.
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertNil(session.diagnostics.timings.firstPresent)

        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        let first = presentFirstFrame(host)
        window = first.window
        let total = clock.now - openStart
        guard first.presented else {
            XCTAssertNil(session.diagnostics.timings.firstPresent)
            throw XCTSkip("no frame could be presented here, neither off screen nor in a window")
        }

        let firstPresent = try XCTUnwrap(session.diagnostics.timings.firstPresent, "set by the presented frame")
        let parts = total.components
        let totalSeconds = Double(parts.seconds) + Double(parts.attoseconds) * 1e-18
        XCTAssertGreaterThanOrEqual(totalSeconds, 0.5, "the test really waited")
        XCTAssertGreaterThanOrEqual(firstPresent, 0)
        // The wait (at least the 0.5 s slept) is taken out: what is left is at most the rest of the real time.
        XCTAssertLessThanOrEqual(firstPresent, totalSeconds - 0.5 + 0.001, "the wait is not in the time")
        XCTAssertLessThan(firstPresent, 0.4, "the 0.5 s of waiting are not part of the first-present time")
        let record = try XCTUnwrap(session.performanceRecord)
        XCTAssertTrue(record.presented)
        XCTAssertEqual(record.firstPresentMs, firstPresent * 1_000)
    }
}
