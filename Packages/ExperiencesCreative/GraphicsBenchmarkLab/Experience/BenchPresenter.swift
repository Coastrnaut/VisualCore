// BenchPresenter — feature 174 (A24-P02) T-A24-207 (FR-A24-204, FR-A24-205, FR-A24-206; clarifications Q1, Q2, Q4;
// contracts/experience.md "Presenter"; data-model.md "RunRecorder", "Workload"). Draws Graphics Benchmark Lab through
// the host only and owns the run:
//
//   - Workload: one `WorkloadRenderer` of the selected case, built in `setup` (again after a context loss), rebuilt when the
//     core's case changes, resized in `resize` and released in `teardown`. The workload frame number n
//     (``workloadFrame``) counts the frames drawn since the case was chosen or the run started; the picture is a
//     function of the case and n only.
//   - Run: the core counts `run.start` and `run.stop` requests; the presenter acts on a rise. At each `draw`, in this
//     order: a case change ends a running run as stopped and rebuilds the workload (n back to 0) before the new case
//     is drawn; a rise of `stopRequests` stops a running run; a rise of `startRequests` starts a run of the selected
//     case at this frame's time (n back to 0; a start while a run is running is ignored). The first state drawn is
//     adopted without acting on its counters, so a restored snapshot never resumes a run; a counter that falls (a
//     reset) is adopted too. Then the workload draws frame n, timed with `ContinuousClock` around the workload's draw
//     calls (the CPU submit time, never a placeholder), and the frame is recorded (``RunRecorder``) with the frame's
//     time. A context rebuild (`teardown`, then `setup`) and the session closing (`teardown`) end a running run as
//     interrupted, keeping its samples; a draw on a context of another generation than the last one does too.
//   - Words: the status line is one of "Ready", "Warm-up", "Measuring", "Cool-down", "Finished", "Stopped",
//     "Interrupted" (or "Interrupted: the device is hot", T-A24-513); after a finished run the summary block gives the
//     frame interval p50, p95 and p99 in milliseconds with two decimals (or "not enough frames"), the frame counts
//     and the flags as sentences ("GPU time not available on this device."). No frame rate is shown.
//   - Mirror: ``BenchMirror`` is what the controls show; it is updated at each draw, a field only when it changed.
//   - Test seams: ``recorder``, ``workloadFrame``, ``drawnFrames``, ``workloadCase`` and ``feedTime`` (a synthetic
//     frame time used instead of `FrameInfo.time` while set).
//   - Probe: the opening case (quads) ends each frame with its last layer, the code-made texture turned by
//     (layers − 1 + n) / 64 of a turn about the centre, repeated 1.5 times per view height. ``probes(_:)`` follows
//     that turn: for the frame last drawn it names the view point whose texel is the centre of the orange checker
//     cell next to the texture's middle (cell (1, 2) of 4 × 4); an orange texel mixed with the noise at 0.35 keeps
//     red at least 51 of 255 above green and blue, so the class is `red` at every n and every noise value. The other
//     cases declare no probe (the runner reads the frame of the opening state only).
//
// Feature 175 (A24-P03) T-A24-308, T-A24-309 (FR-A24-301, 302, 304, 306, 307; clarifications Q3–Q5):
//   - Probe and timer: in `setup`, and at a draw on a context of another generation than the timer's, the presenter
//     decides ``timerSupport`` with `TimerProbe.decide(extensions:)` over `context.resources.renderCapabilities` and,
//     when supported and the seam ``forceTimerUnsupported`` is off, creates a `GPUFrameTimer`; a timer that cannot be
//     created makes the support `unsupported`. Turning the seam on releases the timer at the next draw. `teardown`
//     releases it.
//   - Timing: while a run is running (any phase) the workload draw is bracketed with `begin(frame:)`/`end()`, keyed by
//     the presenter's own drawn-frame count; a frame the recorder recorded maps that key to its sample index. Each
//     draw first polls the timer and passes the results of the current run's frames to
//     ``RunRecorder/applyGPUTimes(_:)`` (which keeps measured frames only), so results arrive within the ring's four
//     frames and the frame that ends a run is recorded after the last apply. A new run clears the key map, so a late
//     result of an earlier run is never applied.
//   - Report: a run's start records `DeviceConditions.current()`, the context's `RenderCapabilities` and the tier;
//     when the run ends (finished, stopped or interrupted, in `draw`, `resize` or `teardown`) the report is built by
//     ``ReportSource`` with the end conditions and the GPU timer named only when a sample has a GPU time, and attached
//     to the recorder.
//   - Summary: a "GPU time" line with p50, p95 and p99 only when the summary has a GPU distribution; otherwise the
//     flag's sentence "GPU time not available on this device."
//
// Feature 176 (A24-P04) T-A24-406 (FR-A24-402, 404, 405; clarifications Q2–Q5; contracts/results.md):
//   - Library: the presenter holds a ``ResultLibrary`` over the experience's storage (nil without storage) and an
//     ``ResultExporter`` over `TemporaryFolder(name: "GraphicsBenchmarkLab-Export")`; the result actions are the
//     extension in ResultsView.swift. After a run ends (finished, stopped or interrupted) the mirror's ``BenchMirror/canSave``
//     is on and `result-save` saves that ended run once: the presenter remembers the run it saved last and refuses an
//     equal run with "This result is already saved.". Saving and exporting touch no graphics.
//   - Exports are written only by the person's tap; `teardown` (the session closing, or a context rebuild) empties the
//     export folder and drops the share item, and `init` empties what a killed session left behind.
//
// Feature 177 (A24-P05) T-A24-513 (visualcore-contract risk 3; FR-A24-501): every frame of a running run reads the
//   device conditions through ``conditionsSource`` (a test seam, `DeviceConditions.current()` by default); a serious or
//   critical thermal state ends the run as interrupted before the frame is drawn, its report carries the hot end
//   state, its qualification is Invalid (interrupted) and the status reads
//   "Interrupted: the device is hot". The run start and the report's end conditions use the same source.
//
// Feature 177 (A24-P05) T-A24-505 (FR-A24-502, 503, 504; clarifications Q1–Q5; contracts/review.md):
//   - Qualification: after any run ends (finished, stopped or interrupted) the mirror's ``BenchMirror/runQualification``
//     is `RunQualification.qualify` of the ended run (computed again only when the state, the sample count or the
//     report's presence changes); an ended run without a summary is invalid with `stopped`, `interrupted` or
//     `no-samples`. It is nil while idle or running.
//   - Opening a result computes ``BenchMirror/repeatability`` (``repeatability(of:)``); `explain` sets
//     ``BenchMirror/explanationSource`` (RepeatabilityView.swift).
//
// Feature 178 (A24-P06) T-A24-604 (FR-A24-603; SC-A24-602): the test-only seam ``BenchPresenter/failNextDraw`` makes
//   the next `draw` throw ``BenchDrawError/injected`` once, before it acts on the core, records or draws anything; the
//   seam clears itself and nothing in the experience or its interface sets it. The session then fails with the error's
//   message, and the saved results are not touched (only an explicit save or removal writes them).
//
// Maximum 60 frames per second; one quality tier, `level-0`. No GL call: everything is drawn by the workload and the
// VisualCore GPU timer.
import Foundation
import GraphicsBenchmarkLabCore
import Observation
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// A drawing failure of Graphics Benchmark Lab (feature 178, A24-P06, T-A24-604).
enum BenchDrawError: Error, Equatable, CustomStringConvertible, LocalizedError {
    /// The test-only seam ``BenchPresenter/failNextDraw`` made this draw fail.
    case injected

    /// The message the failed session shows: "The drawing failed (injected by a test)."
    var description: String {
        switch self {
        case .injected:
            return "The drawing failed (injected by a test)."
        }
    }

    /// The same message as ``description``.
    var errorDescription: String? { description }
}

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class BenchMirror {
    /// The index of the selected case in `BenchmarkCase.builtIn`.
    var selectedCase = 0
    /// The status word ("Ready", "Warm-up", …).
    var status = BenchPresenter.readyWord
    /// Whether a run is being recorded.
    var running = false
    /// The summary block's lines after a finished run; empty otherwise.
    var summaryLines: [String] = []
    /// Whether an ended run (finished, stopped or interrupted) can be saved: `result-save` is shown.
    var canSave = false
    /// Whether the inline results list is shown.
    var showingResults = false
    /// The saved results, newest first, as the list shows them.
    var resultEntries: [ResultLibraryEntry] = []
    /// Whether the library is read only (its index was written by a newer version).
    var resultsReadOnly = false
    /// The opened saved result; nil when none is open.
    var openedResult: OpenedResult?
    /// The outcome of the last result action, or its refusal's sentence; empty before any.
    var resultMessage = ""
    /// The share item of the last export of the opened result; nil before an export.
    var exportItem: ResultExportFile?
    /// The qualification of the ended run (finished, stopped or interrupted) shown in the controls; nil while idle or
    /// running (feature 177).
    var runQualification: Qualification?
    /// The repeatability of the opened result among the saved results; nil when none is open (feature 177).
    var repeatability: RepeatabilitySummary?
    /// Where "About these numbers" was opened from; nil while it is hidden (feature 177).
    var explanationSource: ExplanationSource?
}

/// Draws Graphics Benchmark Lab and records its runs (see the file header).
@MainActor
final class BenchPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = BenchCore

    /// The status word before any run.
    nonisolated static let readyWord = "Ready"
    /// The text of a percentile that has too few frames.
    nonisolated static let notEnoughFrames = "not enough frames"

    /// What the controls show.
    let mirror = BenchMirror()
    /// The recorder of the current or last run (a test seam).
    let recorder = RunRecorder()
    /// The workload of the drawn case; nil before `setup` and after `teardown`.
    private var workload: WorkloadRenderer?
    /// The index of the case the workload draws (and `setup` builds).
    private var drawnCaseIndex = 0
    /// The frames drawn since the case was chosen or the run started: the next frame's n (a test seam).
    private(set) var workloadFrame = 0
    /// The n of the frame last drawn; nil before the first frame.
    private(set) var lastDrawnWorkloadFrame: Int?
    /// How many frames were drawn (a test seam).
    private(set) var drawnFrames = 0
    /// A frame time, seconds, used instead of `FrameInfo.time` while set (a test seam for synthetic runs).
    var feedTime: Double?
    /// Test-only seam: when true, the next `draw` throws ``BenchDrawError/injected`` once, before it acts on the
    /// core, records or draws anything; the seam clears itself and nothing in the experience or its interface sets it
    /// (feature 178, A24-P06, T-A24-604).
    var failNextDraw = false
    /// The request counters last acted on; nil until the first state is drawn.
    private var seenRequests: (start: Int, stop: Int)?
    /// The generation and pixel size of the last context drawn into; nil before the first frame.
    private var lastContext: (generation: Int, width: Int, height: Int)?
    /// Forces the probe to `unsupported` so that no GPU timer is created (a test seam); takes effect at `setup` or the
    /// next draw.
    var forceTimerUnsupported = false
    /// The GPU frame timer of the current context generation; nil when unsupported, forced off or torn down (a test
    /// seam, read-only).
    private(set) var timer: GPUFrameTimer?
    /// The probe's decision for the current context (a test seam, read-only); unsupported before `setup`.
    private(set) var timerSupport = TimerSupport.unsupported(reason: BenchPresenter.notProbedReason)
    /// The context generation the timer and ``timerSupport`` belong to; nil before `setup` and after `teardown`.
    private var timerGeneration: Int?
    /// The current run's timed frames: the drawn-frame key passed to the timer → the index of the recorded sample.
    private var timedFrames: [Int: Int] = [:]
    /// What ``BenchMirror/runQualification`` was computed from: the state, the sample count and whether a report is
    /// attached; nil while idle or running.
    private var qualifiedKey: String?
    /// The conditions at the current run's start, waiting for its report; nil when no report is pending.
    private var runStart: (conditions: DeviceConditions, capabilities: RenderCapabilities, tier: Int)?
    /// The device conditions now (a test seam; `DeviceConditions.current()` by default), read at a run's start, at
    /// its end and on every frame while it runs.
    var conditionsSource: () -> DeviceConditions = { DeviceConditions.current() }
    /// Whether the last run was ended by a serious or critical thermal state; reset when a run starts.
    private(set) var stoppedForHeat = false
    /// The status of a run ended by heat.
    nonisolated static let hotWord = "Interrupted: the device is hot"

    /// The reason of ``timerSupport`` before a context was probed.
    nonisolated static let notProbedReason = "no render context has been probed"
    /// The reason of ``timerSupport`` while ``forceTimerUnsupported`` is on.
    nonisolated static let forcedReason = "the GPU timer is turned off for this test"
    /// The reason of ``timerSupport`` when the extension is listed but the timer could not be created.
    nonisolated static let notCreatedReason = "the GPU timer could not be created on this context"

    /// The saved results over the experience's storage; nil when the experience was made without storage.
    let library: ResultLibrary?
    /// The writer of exports (a test seam: tests give their own folder).
    let exporter: ResultExporter
    /// The ended run saved last by this presenter; an equal run is refused as already saved.
    var savedRun: BenchmarkRun?

    /// A presenter with no workload until `setup`, its library over `storage` (none without storage) and its exports
    /// written through `exporter`, whose folder is emptied now (what a killed session left behind).
    init(storage: ExperienceStorage? = nil, exporter: ResultExporter = ResultExporter()) {
        library = storage.map { ResultLibrary(storage: $0) }
        self.exporter = exporter
        exporter.clear()
    }

    /// The frame cap: 60 frames per second.
    var maxFramesPerSecond: Int { 60 }

    /// The case the workload draws (a test seam).
    var workloadCase: BenchmarkCase { BenchCore.cases[drawnCaseIndex] }

    /// Whether a workload is built (a test seam).
    var hasWorkload: Bool { workload != nil }

    // MARK: Render scene

    /// Builds the workload of the drawn case (again after a context loss).
    func setup(_ context: RenderContext) throws {
        workload?.release()
        workload = nil
        prepareTimer(context)
        workload = try WorkloadRenderer(benchmarkCase: workloadCase, context: context)
    }

    /// Releases any timer, probes `context` and creates a GPU timer when supported and not forced off (see the file
    /// header).
    private func prepareTimer(_ context: RenderContext) {
        timer?.release()
        timer = nil
        timedFrames = [:]
        timerGeneration = context.generation
        if forceTimerUnsupported {
            timerSupport = .unsupported(reason: Self.forcedReason)
            return
        }
        let decided = TimerProbe.decide(extensions: context.resources.renderCapabilities.extensions)
        guard decided == .supported else {
            timerSupport = decided
            return
        }
        timer = GPUFrameTimer(context: context)
        timerSupport = timer == nil ? .unsupported(reason: Self.notCreatedReason) : .supported
    }

    /// Polls the timer and applies the current run's results to the recorder.
    private func applyTimerResults() {
        guard let timer else { return }
        let results = timer.poll()
        var mapped: [GPUFrameTime] = []
        for result in results {
            guard let index = timedFrames.removeValue(forKey: result.frame) else { continue }
            mapped.append(GPUFrameTime(frame: index, milliseconds: result.milliseconds))
        }
        if !mapped.isEmpty { recorder.applyGPUTimes(mapped) }
    }

    /// Builds and attaches the report of a run that has ended since its start (see the file header), with the end
    /// conditions read now.
    private func attachReportIfEnded() {
        guard let start = runStart, recorder.state != .running, recorder.state != .idle,
              let benchmarkCase = recorder.benchmarkCase else { return }
        var gpuMeasured = false
        for sample in recorder.samples where sample.gpuMs != nil {
            gpuMeasured = true
            break
        }
        let report = ReportSource.report(case: benchmarkCase, capabilities: start.capabilities, tier: start.tier,
                                         start: start.conditions, end: conditionsSource(),
                                         gpuMeasured: gpuMeasured)
        recorder.attachReport(report)
        runStart = nil
    }

    /// Passes the new drawable size to the workload.
    func resize(_ context: RenderContext) {
        // FR-A24-206: a size change during a run ends it as interrupted (its samples are kept).
        if let lastContext, lastContext.1 != context.pixelWidth || lastContext.2 != context.pixelHeight {
            recorder.interrupt()
            attachReportIfEnded()
        }
        workload?.resize(context)
    }

    /// Acts on the core's case and requests, draws workload frame n timed by `ContinuousClock`, records the frame and
    /// brings the mirror up to date (see the file header). Throws ``BenchDrawError/injected`` once while
    /// ``failNextDraw`` is set (it is cleared first).
    func draw(_ core: BenchCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw BenchDrawError.injected
        }
        let time = feedTime ?? frame.time
        if let lastContext, lastContext.generation != context.generation { recorder.interrupt() }
        if timerGeneration != context.generation || (forceTimerUnsupported && timer != nil) {
            prepareTimer(context)
        }
        lastContext = (context.generation, context.pixelWidth, context.pixelHeight)
        applyTimerResults()
        if core.selectedCase != drawnCaseIndex, BenchCore.cases.indices.contains(core.selectedCase) {
            recorder.stop()
            workload?.release()
            workload = nil
            drawnCaseIndex = core.selectedCase
            workloadFrame = 0
            workload = try WorkloadRenderer(benchmarkCase: workloadCase, context: context)
        }
        actOnRequests(core, at: time, tier: tier, context: context)
        stopIfHot()
        let timing = recorder.state == .running ? timer : nil
        let key = drawnFrames
        let index = recorder.nextFrameIndex
        timing?.begin(frame: key)
        let clock = ContinuousClock()
        let begin = clock.now
        try workload?.draw(frame: workloadFrame, context: context)
        let cpuMs = Self.milliseconds(clock.now - begin)
        timing?.end()
        recorder.record(frameTime: time, cpuMs: cpuMs)
        if timing != nil, recorder.samples.count == index + 1 { timedFrames[key] = index }
        attachReportIfEnded()
        lastDrawnWorkloadFrame = workloadFrame
        workloadFrame += 1
        drawnFrames += 1
        follow(core)
    }

    /// Starts or stops the run on a rise of the core's request counters; adopts the first counters seen and any that
    /// fall. A start records the conditions of the run's report (the device conditions now, `context`'s capabilities
    /// and `tier`).
    private func actOnRequests(_ core: BenchCore, at time: Double, tier: Int, context: RenderContext) {
        guard let seen = seenRequests else {
            seenRequests = (core.startRequests, core.stopRequests)
            return
        }
        if core.stopRequests > seen.stop { recorder.stop() }
        if core.startRequests > seen.start, recorder.state != .running {
            attachReportIfEnded()
            recorder.start(case: workloadCase, at: time)
            workloadFrame = 0
            timedFrames = [:]
            runStart = (conditionsSource(), context.resources.renderCapabilities, tier)
            stoppedForHeat = false
        }
        seenRequests = (core.startRequests, core.stopRequests)
    }

    /// Ends a running run as interrupted, with its report, when the device's thermal state is serious or critical
    /// (visualcore-contract risk 3: a run never continues while the device is hot).
    private func stopIfHot() {
        guard recorder.state == .running else { return }
        let thermal = conditionsSource().thermal
        guard thermal == .serious || thermal == .critical else { return }
        recorder.interrupt()
        stoppedForHeat = true
        attachReportIfEnded()
    }

    /// Ends a running run as interrupted (attaching its report), releases the GPU timer and the workload.
    func teardown(_ context: RenderContext) {
        recorder.interrupt()
        attachReportIfEnded()
        timer?.release()
        timer = nil
        timerGeneration = nil
        timedFrames = [:]
        workload?.release()
        workload = nil
        clearExports()
        followRecorder()
    }

    /// `duration` in milliseconds.
    nonisolated static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
    }

    // MARK: Words

    /// The status word of `recorder` (see the file header).
    static func statusWord(_ recorder: RunRecorder) -> String {
        switch recorder.state {
        case .idle: return readyWord
        case .running:
            switch recorder.phase ?? .warmUp {
            case .warmUp: return "Warm-up"
            case .measure: return "Measuring"
            case .coolDown: return "Cool-down"
            }
        case .finished: return "Finished"
        case .stopped: return "Stopped"
        case .interrupted: return "Interrupted"
        }
    }

    /// The status word of the current run.
    var status: String {
        recorder.state == .interrupted && stoppedForHeat ? Self.hotWord : Self.statusWord(recorder)
    }

    /// `value` in milliseconds with two decimals ("16.67 ms"), or "not enough frames".
    nonisolated static func milliseconds(text value: Double?) -> String {
        guard let value, value.isFinite else { return notEnoughFrames }
        return String(format: "%.2f ms", value)
    }

    /// The sentence of `flag`.
    nonisolated static func sentence(_ flag: QualityFlag) -> String {
        switch flag {
        case .noSamples: return "No frames were measured."
        case .tooFewForP95: return "Too few frames for p95."
        case .tooFewForP99: return "Too few frames for p99."
        case .droppedFrames: return "Some measured frames were dropped."
        case .gpuTimeNotAvailable: return "GPU time not available on this device."
        }
    }

    /// The summary block of `summary`: the interval percentiles, the GPU time percentiles when the summary has a GPU
    /// distribution, the counts, then one sentence per flag.
    nonisolated static func summaryLines(_ summary: Summary) -> [String] {
        let interval = summary.interval
        var lines = ["Frame interval p50 " + milliseconds(text: interval.p50),
                     "Frame interval p95 " + milliseconds(text: interval.p95),
                     "Frame interval p99 " + milliseconds(text: interval.p99)]
        if let gpu = summary.gpu {
            lines.append("GPU time p50 " + milliseconds(text: gpu.p50) + ", p95 " + milliseconds(text: gpu.p95)
                             + ", p99 " + milliseconds(text: gpu.p99))
        }
        lines += ["Measured frames \(summary.measured), warm-up excluded \(summary.warmUpExcluded), "
                         + "cool-down excluded \(summary.coolDownExcluded), dropped \(summary.dropped)"]
        lines += summary.flags.map(sentence)
        return lines
    }

    /// The summary block of the current run: its lines after a finished run, empty otherwise.
    var summaryLines: [String] {
        guard recorder.state == .finished, let summary = recorder.summary else { return [] }
        return Self.summaryLines(summary)
    }

    /// The summary block as one text, lines joined by new lines (empty before a finished run).
    var summaryText: String { summaryLines.joined(separator: "\n") }

    /// The spoken title of the case at `index` ("Textured quads", "Shader ALU", "Particles").
    nonisolated static func title(ofCase index: Int) -> String {
        guard BenchCore.cases.indices.contains(index) else { return "Unknown case" }
        return title(of: BenchCore.cases[index].workload)
    }

    /// The spoken title of a case of `workload` ("Textured quads", "Shader ALU", "Particles"), whatever its version.
    nonisolated static func title(of workload: Workload) -> String {
        switch workload {
        case .quads: return "Textured quads"
        case .alu: return "Shader ALU"
        case .particles: return "Particles"
        }
    }

    /// Brings the mirror's case, status, running flag and summary up to `core` and the recorder.
    func follow(_ core: BenchCore) {
        if mirror.selectedCase != core.selectedCase { mirror.selectedCase = core.selectedCase }
        followRecorder()
    }

    /// Brings the mirror's status, running flag and summary up to the recorder.
    private func followRecorder() {
        let status = self.status
        if mirror.status != status { mirror.status = status }
        let running = recorder.state == .running
        if mirror.running != running { mirror.running = running }
        let lines = summaryLines
        if mirror.summaryLines != lines { mirror.summaryLines = lines }
        let ended = recorder.state != .idle && recorder.state != .running && recorder.summary != nil
            && recorder.benchmarkCase != nil
        if mirror.canSave != ended { mirror.canSave = ended }
        let qualification = endedQualification()
        if mirror.runQualification != qualification { mirror.runQualification = qualification }
    }

    /// The qualification of the ended run, or nil while idle or running (see the file header).
    private func endedQualification() -> Qualification? {
        let state = recorder.state
        guard state != .idle, state != .running else {
            qualifiedKey = nil
            return nil
        }
        let key = state.rawValue + " \(recorder.samples.count) " + (recorder.report == nil ? "none" : "report")
        if key == qualifiedKey, let known = mirror.runQualification { return known }
        qualifiedKey = key
        if let run = recorder.runRecord() { return RunQualification.qualify(run) }
        switch state {
        case .stopped: return Qualification(class: .invalid, reasons: [.stopped])
        case .interrupted: return Qualification(class: .invalid, reasons: [.interrupted])
        default: return Qualification(class: .invalid, reasons: [.noSamples])
        }
    }

    /// The canvas label, for example "Graphics Benchmark Lab, Textured quads, Ready", with the summary after a
    /// finished run.
    func describe(_ core: BenchCore) -> String {
        var text = "Graphics Benchmark Lab, " + Self.title(ofCase: core.selectedCase) + ", " + status
        let lines = summaryLines
        if !lines.isEmpty { text += ". " + lines.joined(separator: ". ") }
        return text
    }

    // MARK: Probe

    /// The probe of the frame last drawn (see the file header): for quads, the point of the orange cell's centre at
    /// the last layer's turn, class `red`; none for the other cases or before a frame.
    func probes(_ core: BenchCore) -> [FrameProbe] {
        guard workloadCase.workload == .quads, let n = lastDrawnWorkloadFrame, let lastContext,
              let point = Self.quadsProbePoint(layers: workloadCase.config.layers ?? 1, frame: n,
                                               width: lastContext.width, height: lastContext.height) else { return [] }
        return [FrameProbe(name: "quads-orange-cell", x: point.x, y: point.y,
                           expected: FrameColorClass.red.rawValue)].compactMap { $0 }
    }

    /// The view point (x from the left, y from the top, both 0…1) whose quads texel at the last layer of frame `n` is
    /// the centre of the orange cell (1, 2) of the 4 × 4 checker; nil for an empty drawable. The inverse of the layer
    /// shader: `uv = fract(R(turn) · ((v_uv − 0.5) · (aspect, 1)) · 1.5 + 0.5)`.
    static func quadsProbePoint(layers: Int, frame n: Int, width: Int, height: Int) -> (x: Double, y: Double)? {
        guard width > 0, height > 0 else { return nil }
        let steps = WorkloadRenderer.turnSteps
        let step = ((max(layers, 1) - 1 + n) % steps + steps) % steps
        let angle = 2 * Double.pi * Double(step) / Double(steps)
        let c = cos(angle), s = sin(angle)
        // The texel (0.375, 0.625), the orange cell's centre, relative to the texture's middle, over the repeat.
        let rx = -0.125 / 1.5, ry = 0.125 / 1.5
        // Turned back by the angle.
        let px = c * rx + s * ry
        let py = -s * rx + c * ry
        let aspect = Double(width) / Double(height)
        let u = px / aspect + 0.5
        let v = py + 0.5
        return (x: u, y: 1 - v)
    }

    // MARK: Controls

    /// The actions of the native controls: all three.
    var nativeActions: Set<String> { Set(BenchCore.actionIDs) }

    /// The native controls (``GBLControls``).
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(GBLControls(port: port, mirror: mirror, presenter: self))
    }
}
