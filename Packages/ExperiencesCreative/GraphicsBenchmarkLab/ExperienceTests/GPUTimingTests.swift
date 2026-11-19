// GPUTimingTests — feature 175 (A24-P03) T-A24-310 (SC-A24-302; FR-A24-304, FR-A24-306; clarification Q3; US2). A run
// through the presenter in the one app's session host, with synthetic frame times 0.5 s apart (36 frames for the
// built-in 3 + 10 + 5 s plan, so the test stays short):
//   - on the simulator the probe says supported and a GPU timer exists; every GPU time is finite, non-negative and
//     within 1,000 ms; at least one measured frame has one; no warm-up or cool-down frame has one;
//   - with the seam `forceTimerUnsupported`, no timer exists, no sample has a GPU time and the summary carries
//     `gpu-time-not-available`;
//   - the recorder alone keeps only measured, finite, in-range results.
// If the renderer listed the extension but the timer could not be created (a stand-in renderer), the supported test
// records that as an issue rather than passing with nothing timed. Simulator GPU times are context only, never device
// evidence.
import CoreGraphics
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

@MainActor
@Suite(.serialized) struct GPUTimingTests {
    /// The frame times after the run's start frame at 100 s: 0.5 s apart, through the plan's end at 118 s.
    static let runTimes = BenchTest.times(from: 100.5, step: 0.5, count: 36)

    /// Opens the experience, applies `forced` to the seam, runs the opening case to its end (presenting each frame)
    /// and returns the shell.
    private func finishedRun(_ session: ExperienceSession, forced: Bool) async throws
        -> ExperienceShell<BenchPresenter> {
        let shell = try await BenchTest.open(session)
        shell.presenter.forceTimerUnsupported = forced
        BenchTest.accept(shell, "run.start")
        try BenchTest.drawPresented(session, shell, at: 100)
        for time in Self.runTimes { try BenchTest.drawPresented(session, shell, at: time) }
        let state = shell.presenter.recorder.state
        #expect(state == .finished)
        return shell
    }

    @Test func onTheSimulatorMeasuredFramesCarryAFiniteGPUTimeAndNoOtherFrameDoes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await finishedRun(session, forced: false)
        let presenter = shell.presenter
        let support = presenter.timerSupport
        #expect(support == .supported, "the simulator's renderer offers \(GPUFrameTimer.extensionName)")
        #expect(presenter.timer != nil, "a supported probe creates the timer")
        let samples = presenter.recorder.samples
        var measuredWithGPU = 0
        var otherWithGPU = 0
        var values: [Double] = []
        for sample in samples {
            guard let gpu = sample.gpuMs else { continue }
            values.append(gpu)
            if sample.phase == .measure { measuredWithGPU += 1 } else { otherWithGPU += 1 }
            #expect(gpu.isFinite && gpu >= 0 && gpu <= 1_000, "frame \(sample.frameIndex): \(gpu) ms")
        }
        #expect(measuredWithGPU >= 1, "at least one measured frame was timed")
        #expect(otherWithGPU == 0, "warm-up and cool-down frames carry no GPU time")
        let summary = try #require(presenter.recorder.summary)
        let lines = BenchPresenter.summaryLines(summary)
        var gpuLines = 0
        for line in lines where line.hasPrefix("GPU time p50") { gpuLines += 1 }
        let expectedGPULines = summary.gpu == nil ? 0 : 1
        #expect(gpuLines == expectedGPULines, "the GPU line appears only with a GPU distribution")
        let minimum = values.min() ?? -1
        let maximum = values.max() ?? -1
        print("A24 GPU timer (simulator context only): \(values.count) of \(samples.count) samples timed, "
              + "\(minimum)…\(maximum) ms, gpu distribution \(summary.gpu != nil), "
              + "disjoint reads \(presenter.timer?.disjointCount ?? -1)")
    }

    @Test func withTheProbeForcedOffNoSampleHasAGPUTimeAndTheSummarySaysSo() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await finishedRun(session, forced: true)
        let presenter = shell.presenter
        let support = presenter.timerSupport
        #expect(support == .unsupported(reason: BenchPresenter.forcedReason))
        #expect(presenter.timer == nil)
        var withGPU = 0
        for sample in presenter.recorder.samples where sample.gpuMs != nil { withGPU += 1 }
        #expect(withGPU == 0)
        let summary = try #require(presenter.recorder.summary)
        let gpu = summary.gpu
        #expect(gpu == nil && summary.flags.contains(.gpuTimeNotAvailable))
        let lines = presenter.mirror.summaryLines
        #expect(lines.contains("GPU time not available on this device."))
        var gpuLines = 0
        for line in lines where line.hasPrefix("GPU time p50") { gpuLines += 1 }
        #expect(gpuLines == 0)
    }

    @Test func theRecorderKeepsOnlyMeasuredFiniteInRangeResults() throws {
        let recorder = RunRecorder()
        let plan = RunPlan(warmUpSeconds: 1, measureSeconds: 1, coolDownSeconds: 1)
        let benchmarkCase = BenchmarkCase(id: "alu", version: 1, workload: .alu, config: BenchmarkCase.alu.config,
                                          plan: plan)
        recorder.start(case: benchmarkCase, at: 0)
        // Frames 0–1 warm-up, 2–5 measurement, 6 cool-down.
        let times = [0.0, 0.5, 1.0, 1.25, 1.5, 1.75, 2.25]
        for time in times { recorder.record(frameTime: time, cpuMs: 1) }
        recorder.applyGPUTimes([GPUFrameTime(frame: 0, milliseconds: 1), GPUFrameTime(frame: 2, milliseconds: 2),
                                GPUFrameTime(frame: 3, milliseconds: .nan), GPUFrameTime(frame: 4, milliseconds: -1),
                                GPUFrameTime(frame: 5, milliseconds: 1_000.5), GPUFrameTime(frame: 6, milliseconds: 3),
                                GPUFrameTime(frame: 40, milliseconds: 4)])
        let gpuTimes = recorder.samples.map(\.gpuMs)
        let expected: [Double?] = [nil, nil, 2, nil, nil, nil, nil]
        #expect(gpuTimes == expected)
        recorder.stop()
        recorder.applyGPUTimes([GPUFrameTime(frame: 3, milliseconds: 1)])
        let afterStop = recorder.samples[3].gpuMs
        #expect(afterStop == nil, "nothing is applied once the run has ended")
        let summary = try #require(recorder.summary)
        #expect(summary.gpu == nil && summary.flags.contains(.gpuTimeNotAvailable))
    }
}
