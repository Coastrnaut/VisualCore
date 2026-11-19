// RunRecorder — feature 174 (A24-P02) T-A24-207 (FR-A24-204; clarification Q2; data-model.md "RunRecorder"). Turns
// the frames the presenter draws during a run into A24-P01's `FrameSample`s and, when the run finishes, into its
// `Summary`. It never reads a clock: the presenter passes each frame's time and its own measured CPU submit time.
//
//   - `start(case:at:)` begins a run of the case at the frame time `time` (seconds): the samples are cleared and the
//     run's `RunTimeline` is laid out from `time`.
//   - `record(frameTime:cpuMs:)` places the frame on the timeline. While the run is not finished it appends one
//     sample: `frameIndex` counting from 0, the phase, `intervalMs` = (t − previous t) × 1,000 (absent for the run's
//     first frame), `cpuMs` as given, `gpuMs` always absent (no timer: A24-P00 gap U-GPUTIMER) and `dropped` false. A
//     frame at or after the timeline's end appends nothing and finishes the run: the summary is `Summary.make` of the
//     samples and the state `finished`.
//     Choices recorded here (lead's agent, T-A24-207): a frame whose time is not finite or earlier than the previous
//     one is skipped (it would break the sample set's order); no sample is appended past `SampleLimits.maxSamples`.
//     Convergence (T-A24-216): no value is ever clamped. An interval or a CPU time that is not finite or leaves
//     0…`SampleLimits.maxDurationMs` (1 s) ends the run as `interrupted` with the earlier samples kept, and `dropped`
//     stays false until the A24-P03 rule decides it.
//   - `stop()` ends a running run as `stopped`, `interrupt()` as `interrupted` (a context rebuild or the session
//     closing); both keep the samples and summarise them when the set allows it. Outside a run they do nothing.
//   - `runRecord()` is the finished, stopped or interrupted run as A24-P01's `BenchmarkRun` (nil without a summary).
// Feature 175 (A24-P03) T-A24-308 (FR-A24-301, 302, 306; clarifications Q3, Q4):
//   - `dropped` is `DroppedFrameRule.isDropped(intervalMs:)` of each recorded interval (more than 25 ms); the interval
//     still counts in the summary. The A24-P02 rule that a value outside its range ends the run as interrupted stays.
//   - `applyGPUTimes(_:)` fills `gpuMs` of the samples whose `frameIndex` equals a result's frame, only for
//     measurement-phase samples, only while the run is running and only for a finite value within
//     0…`SampleLimits.maxDurationMs`; any other result is ignored and the sample keeps no GPU time. The presenter
//     applies the timer's results before the frame that ends the run is recorded, so the summary is computed after
//     the final apply.
//   - `attachReport(_:)` stores the ended run's `RunReport` (the presenter builds it); `runRecord()` carries it. A new
//     run clears it.
import Foundation
import GraphicsBenchmarkLabCore
import VisualCoreExperience
import VisualCoreRendering

/// Records the frames of one benchmark run (see the file header).
@MainActor
final class RunRecorder {
    /// Where the recorder is.
    enum State: String, Equatable, Sendable {
        /// No run since the recorder was made.
        case idle
        /// A run is being recorded.
        case running
        /// The last run reached the end of its plan.
        case finished
        /// The last run was stopped by the person (or by choosing another case).
        case stopped
        /// The last run was ended by a context rebuild or by the session closing.
        case interrupted
    }

    /// Where the recorder is.
    private(set) var state = State.idle
    /// The case of the current or last run; nil before the first run.
    private(set) var benchmarkCase: BenchmarkCase?
    /// The timeline of the current or last run; nil before the first run.
    private(set) var timeline: RunTimeline?
    /// The samples of the current or last run, in frame order.
    private(set) var samples: [FrameSample] = []
    /// The summary of the last run once it ended (nil while running, before a run, or when the set could not be
    /// summarised).
    private(set) var summary: Summary?
    /// The phase of the last recorded frame while running (warm-up before the first frame); nil outside a run.
    private(set) var phase: RunPhase?
    /// The time of the last recorded frame, seconds.
    private var previousTime: Double?
    /// The report of the ended run, attached by the presenter; nil while running, before a run, or before it is
    /// attached.
    private(set) var report: RunReport?

    /// A recorder with no run.
    init() {}

    /// Begins a run of `benchmarkCase` at the frame time `time` (seconds), dropping any earlier run.
    func start(case benchmarkCase: BenchmarkCase, at time: Double) {
        self.benchmarkCase = benchmarkCase
        timeline = RunTimeline(plan: benchmarkCase.plan, start: time)
        samples = []
        summary = nil
        report = nil
        previousTime = nil
        phase = .warmUp
        state = .running
    }

    /// Records the frame drawn at `frameTime` (seconds) whose CPU submit took `cpuMs` milliseconds (see the file
    /// header). Does nothing outside a run.
    func record(frameTime: Double, cpuMs: Double) {
        guard state == .running, let timeline, frameTime.isFinite else { return }
        if let previousTime, frameTime < previousTime { return }
        guard let framePhase = timeline.phase(at: frameTime) else {
            finish(as: .finished)
            return
        }
        guard samples.count < SampleLimits.maxSamples else { return }
        // Feature 174 T-A24-216: no value is clamped. A frame whose interval or CPU time is not finite or leaves
        // 0…`SampleLimits.maxDurationMs` (a stall, a background gap) ends the run as interrupted, the earlier samples
        // kept. Feature 175 T-A24-308: `dropped` is the A24-P03 rule's verdict on the interval.
        let cap = SampleLimits.maxDurationMs
        var interval: Double?
        if let previousTime {
            let raw = (frameTime - previousTime) * 1_000
            guard raw.isFinite, raw >= 0, raw <= cap else {
                finish(as: .interrupted)
                return
            }
            interval = raw
        }
        guard cpuMs.isFinite, cpuMs >= 0, cpuMs <= cap else {
            finish(as: .interrupted)
            return
        }
        samples.append(FrameSample(frameIndex: samples.count, phase: framePhase, intervalMs: interval, cpuMs: cpuMs,
                                   gpuMs: nil, dropped: DroppedFrameRule.isDropped(intervalMs: interval)))
        previousTime = frameTime
        phase = framePhase
    }

    /// The index of the sample the next recorded frame gets (the count of samples so far).
    var nextFrameIndex: Int { samples.count }

    /// Fills the GPU time of the measured samples named by `times` (see the file header): a result whose frame is
    /// the `frameIndex` of a measurement-phase sample and whose value is finite and within
    /// 0…``SampleLimits/maxDurationMs`` sets that sample's `gpuMs`; every other result is ignored. Does nothing
    /// outside a run.
    func applyGPUTimes(_ times: [GPUFrameTime]) {
        guard state == .running else { return }
        for time in times {
            let index = time.frame
            guard samples.indices.contains(index), samples[index].frameIndex == index,
                  samples[index].phase == .measure else { continue }
            let value = time.milliseconds
            guard value.isFinite, value >= 0, value <= SampleLimits.maxDurationMs else { continue }
            samples[index].gpuMs = value
        }
    }

    /// Stores `report` as the ended run's report. Does nothing while idle or running.
    func attachReport(_ report: RunReport) {
        guard state != .idle, state != .running else { return }
        self.report = report
    }

    /// Ends a running run as stopped, keeping its samples.
    func stop() {
        guard state == .running else { return }
        finish(as: .stopped)
    }

    /// Ends a running run as interrupted, keeping its samples.
    func interrupt() {
        guard state == .running else { return }
        finish(as: .interrupted)
    }

    /// Ends the run in `end`: the summary of the samples (nil when the set is refused) and no current phase.
    private func finish(as end: State) {
        do {
            summary = try Summary.make(samples)
        } catch {
            summary = nil
        }
        phase = nil
        state = end
    }

    /// The ended run as a `BenchmarkRun` (finished → completed) with its attached report; nil while idle or running, or without a summary or
    /// a case fingerprint.
    func runRecord() -> BenchmarkRun? {
        let runState: RunState
        switch state {
        case .idle, .running: return nil
        case .finished: runState = .completed
        case .stopped: runState = .stopped
        case .interrupted: runState = .interrupted
        }
        guard let benchmarkCase, let summary, let fingerprint = try? benchmarkCase.fingerprint() else { return nil }
        return BenchmarkRun(benchmarkCase: benchmarkCase, caseFingerprint: fingerprint.hex, samples: samples,
                            summary: summary, state: runState, report: report)
    }
}
