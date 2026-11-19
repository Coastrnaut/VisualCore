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
//     one is skipped (it would break the sample set's order); an interval or a CPU time above the sample cap
//     (`SampleLimits.maxDurationMs`, 1 s) is stored as the cap, and such an interval marks the frame `dropped` (a
//     frame that late was dropped, and the summary then says so instead of refusing the set); a negative CPU time is
//     stored as 0; no sample is appended past `SampleLimits.maxSamples`.
//   - `stop()` ends a running run as `stopped`, `interrupt()` as `interrupted` (a context rebuild or the session
//     closing); both keep the samples and summarise them when the set allows it. Outside a run they do nothing.
//   - `runRecord()` is the finished, stopped or interrupted run as A24-P01's `BenchmarkRun` (nil without a summary).
import Foundation
import GraphicsBenchmarkLabCore
import VisualCoreExperience

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

    /// A recorder with no run.
    init() {}

    /// Begins a run of `benchmarkCase` at the frame time `time` (seconds), dropping any earlier run.
    func start(case benchmarkCase: BenchmarkCase, at time: Double) {
        self.benchmarkCase = benchmarkCase
        timeline = RunTimeline(plan: benchmarkCase.plan, start: time)
        samples = []
        summary = nil
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
        let cap = SampleLimits.maxDurationMs
        var interval: Double?
        var dropped = false
        if let previousTime {
            let raw = (frameTime - previousTime) * 1_000
            if raw > cap { dropped = true }
            interval = min(max(raw, 0), cap)
        }
        let cpu = cpuMs.isFinite ? min(max(cpuMs, 0), cap) : cap
        samples.append(FrameSample(frameIndex: samples.count, phase: framePhase, intervalMs: interval, cpuMs: cpu,
                                   gpuMs: nil, dropped: dropped))
        previousTime = frameTime
        phase = framePhase
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

    /// The ended run as a `BenchmarkRun` (finished → completed); nil while idle or running, or without a summary or
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
        return BenchmarkRun(caseID: benchmarkCase.id, caseVersion: benchmarkCase.version,
                            caseFingerprint: fingerprint.hex, samples: samples, summary: summary, state: runState)
    }
}
