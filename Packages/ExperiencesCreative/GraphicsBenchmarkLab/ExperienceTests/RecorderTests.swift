// RecorderTests — feature 174 (A24-P02) T-A24-208 and the run-interrupted half of T-A24-209 (SC-A24-202, SC-A24-203,
// SC-A24-204, SC-A24-206; clarifications Q2, Q4). The run recorder and the presenter's run handling, always with
// synthetic frame times (direct recorder calls, or the presenter's `feedTime` while the session host draws), never a
// plan in real time:
//   - a run passes warm-up, measurement and cool-down and finishes with a summary counting only measured frames;
//   - every sample has no GPU time, the encoded run file holds no GPU value, the summary has no GPU distribution and
//     carries the flag `gpu-time-not-available`, and the summary text says "GPU time not available";
//   - the CPU time of every frame drawn by the presenter is measured, never a placeholder zero;
//   - stopping mid-run gives "Stopped"; choosing another case mid-run ends the run as "Stopped" before the new case is
//     drawn; closing the session mid-run and a context rebuild mid-run give "Interrupted" with the samples kept;
//   - a restored snapshot with start requests never resumes a run.
// Feature 175 (A24-P03) T-A24-310 (SC-A24-301; clarification Q4): every interval above 25 ms is flagged dropped and
// counted while its interval still counts; a 30 ms interval in the measurement is the one dropped frame of a run fed
// at 1/64 s; warm-up and cool-down frames are excluded and counted. The checks that no sample has a GPU time hold for
// the recorder alone (no timer results applied) and for the presenter with the probe forced to unsupported.
import CoreGraphics
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

@MainActor
@Suite(.serialized) struct RecorderTests {
    /// The built-in plan's frame times, 0.25 s apart from 0 to 18 s inclusive (73 frames; exact in binary).
    static let quarterTimes = BenchTest.times(from: 0, step: 0.25, count: 73)

    // MARK: The recorder alone

    @Test func aRunPassesItsPhasesAndFinishesWithASummaryOfTheMeasuredFrames() throws {
        let recorder = RunRecorder()
        #expect(recorder.state == .idle && BenchPresenter.statusWord(recorder) == "Ready")
        recorder.start(case: .quads, at: 0)
        #expect(recorder.state == .running && BenchPresenter.statusWord(recorder) == "Warm-up")
        var words: [String] = []
        for time in Self.quarterTimes {
            recorder.record(frameTime: time, cpuMs: 1.5)
            let word = BenchPresenter.statusWord(recorder)
            if words.last != word { words.append(word) }
        }
        #expect(words == ["Warm-up", "Measuring", "Cool-down", "Finished"])
        #expect(recorder.state == .finished)
        let samples = recorder.samples
        #expect(samples.count == 72, "the frame at 18 s finishes the run and is not recorded")
        let phases = samples.map(\.phase)
        #expect(phases.filter { $0 == .warmUp }.count == 12)
        #expect(phases.filter { $0 == .measure }.count == 40)
        #expect(phases.filter { $0 == .coolDown }.count == 20)
        let indices = samples.map(\.frameIndex)
        #expect(indices == Array(0..<72))
        #expect(samples.first?.intervalMs == nil, "the run's first frame has no interval")
        let intervals = samples.dropFirst().compactMap(\.intervalMs)
        #expect(intervals.count == 71 && intervals.allSatisfy { $0 == 250 })
        for sample in samples {
            let dropped = sample.intervalMs != nil
            #expect(sample.cpuMs == 1.5 && sample.dropped == dropped, "every 250 ms interval is dropped")
        }

        let summary = try #require(recorder.summary)
        #expect(summary.measured == 40)
        #expect(summary.warmUpExcluded == 12)
        #expect(summary.coolDownExcluded == 20)
        #expect(summary.interval.count == 40 && summary.interval.p50 == 250)
        #expect(summary.cpu.count == 40)
        let droppedCount = summary.dropped
        #expect(droppedCount == 40, "every measured frame has a 250 ms interval")
        let flags = summary.flags
        #expect(flags.contains(.tooFewForP99) && !flags.contains(.tooFewForP95) && flags.contains(.droppedFrames))
    }

    @Test func noSampleHasAGPUTimeAndTheRunFileHoldsNone() throws {
        let recorder = RunRecorder()
        recorder.start(case: .alu, at: 50)
        for time in Self.quarterTimes { recorder.record(frameTime: 50 + time, cpuMs: 0.75) }
        #expect(recorder.state == .finished)
        let samples = recorder.samples
        #expect(!samples.isEmpty && samples.allSatisfy { $0.gpuMs == nil })
        let summary = try #require(recorder.summary)
        #expect(summary.gpu == nil)
        #expect(summary.flags.contains(.gpuTimeNotAvailable))
        let run = try #require(recorder.runRecord())
        #expect(run.state == .completed && run.caseID == "alu" && run.caseVersion == 1)
        let fingerprint = try BenchmarkCase.alu.fingerprint().hex
        #expect(run.caseFingerprint == fingerprint)
        let text = String(decoding: try RunDocument.encode(run), as: UTF8.self)
        #expect(!text.contains("gpuMs"), "no sample stores a GPU time")
        let reopened = try RunDocument.decode(RunDocument.encode(run)).get()
        var withGPU = 0
        for sample in reopened.samples where sample.gpuMs != nil { withGPU += 1 }
        #expect(withGPU == 0, "no stored sample has a GPU time")
        let storedGPU = reopened.summary.gpu
        #expect(storedGPU == nil, "the stored summary has no GPU distribution")
        let lines = BenchPresenter.summaryLines(summary)
        #expect(lines.contains("GPU time not available on this device."))
        #expect(lines.joined(separator: " ").contains("GPU time not available"))
    }

    @Test func theSummaryTextGivesPercentilesInMillisecondsWithTwoDecimals() {
        let summary = Summary(interval: Distribution(p50: 16.666_7, p95: nil, p99: nil, count: 12),
                              cpu: Distribution(p50: 1, p95: nil, p99: nil, count: 12), gpu: nil, measured: 12,
                              warmUpExcluded: 3, coolDownExcluded: 4, dropped: 0,
                              flags: [.gpuTimeNotAvailable, .tooFewForP95, .tooFewForP99])
        let lines = BenchPresenter.summaryLines(summary)
        #expect(lines.first == "Frame interval p50 16.67 ms")
        #expect(lines.contains("Frame interval p95 not enough frames"))
        #expect(lines.contains("Frame interval p99 not enough frames"))
        #expect(lines.contains("Measured frames 12, warm-up excluded 3, cool-down excluded 4, dropped 0"))
        #expect(lines.contains("Too few frames for p95.") && lines.contains("Too few frames for p99."))
        #expect(lines.contains("GPU time not available on this device."))
        #expect(!lines.joined().lowercased().contains("fps"), "no frame rate is shown")
    }

    @Test func stoppingAndInterruptingKeepTheSamples() {
        let recorder = RunRecorder()
        recorder.start(case: .particles, at: 0)
        for time in BenchTest.times(from: 0, step: 0.5, count: 10) { recorder.record(frameTime: time, cpuMs: 2) }
        recorder.stop()
        #expect(recorder.state == .stopped && BenchPresenter.statusWord(recorder) == "Stopped")
        #expect(recorder.samples.count == 10)
        #expect(recorder.runRecord()?.state == .stopped)
        recorder.record(frameTime: 6, cpuMs: 2)
        #expect(recorder.samples.count == 10, "nothing is recorded after a stop")

        recorder.start(case: .particles, at: 100)
        for time in BenchTest.times(from: 100, step: 0.5, count: 8) { recorder.record(frameTime: time, cpuMs: 2) }
        recorder.interrupt()
        #expect(recorder.state == .interrupted && BenchPresenter.statusWord(recorder) == "Interrupted")
        #expect(recorder.samples.count == 8)
        #expect(recorder.runRecord()?.state == .interrupted)
        recorder.stop()
        #expect(recorder.state == .interrupted, "a stop outside a run does nothing")
    }

    @Test func framesOutOfOrderAreSkippedAndAStallInterruptsWithoutAClampedValue() {
        let recorder = RunRecorder()
        recorder.start(case: .quads, at: 0)
        recorder.record(frameTime: 0, cpuMs: 1)
        recorder.record(frameTime: 0.5, cpuMs: 1)
        recorder.record(frameTime: 0.25, cpuMs: 1)
        recorder.record(frameTime: .nan, cpuMs: 1)
        #expect(recorder.samples.count == 2, "a frame earlier than the last one and a non-finite time are skipped")
        // A 1.2 s gap: the run ends as interrupted, the two earlier samples kept, nothing clamped; the 500 ms interval is
        // dropped by the A24-P03 rule.
        recorder.record(frameTime: 1.7, cpuMs: 1)
        let state = recorder.state
        #expect(state == .interrupted)
        let samples = recorder.samples
        #expect(samples.count == 2)
        for sample in samples {
            let interval = sample.intervalMs ?? 0
            let dropped = sample.intervalMs != nil
            #expect(interval <= 500 && sample.dropped == dropped && sample.cpuMs == 1)
        }
    }

    @Test func aCPUTimeOutsideItsRangeInterruptsTheRun() {
        let recorder = RunRecorder()
        recorder.start(case: .alu, at: 0)
        recorder.record(frameTime: 0, cpuMs: 1)
        recorder.record(frameTime: 0.02, cpuMs: 5_000)
        let state = recorder.state
        #expect(state == .interrupted)
        let count = recorder.samples.count
        #expect(count == 1)
        let negative = RunRecorder()
        negative.start(case: .alu, at: 0)
        negative.record(frameTime: 0, cpuMs: -1)
        let negativeState = negative.state
        #expect(negativeState == .interrupted)
    }

    @Test func aThirtyMillisecondIntervalIsDroppedAndCountedAndTheExcludedPhasesAreCounted() throws {
        let plan = RunPlan(warmUpSeconds: 1, measureSeconds: 1, coolDownSeconds: 1)
        let benchmarkCase = BenchmarkCase(id: "quads", version: 1, workload: .quads,
                                          config: BenchmarkCase.quads.config, plan: plan)
        let step = 1.0 / 64.0
        var times: [Double] = []
        var time = 0.0
        while time < 1.5 {
            times.append(time)
            time += step
        }
        let lateTime = (times.last ?? 0) + 0.030
        time = lateTime
        while time < 3.0 {
            times.append(time)
            time += step
        }
        times.append(3.0)
        var expectedWarmUp = 0
        var expectedMeasured = 0
        var expectedCoolDown = 0
        for value in times {
            if value < 1 { expectedWarmUp += 1 } else if value < 2 { expectedMeasured += 1 }
            else if value < 3 { expectedCoolDown += 1 }
        }
        let recorder = RunRecorder()
        recorder.start(case: benchmarkCase, at: 0)
        for value in times { recorder.record(frameTime: value, cpuMs: 1) }
        let state = recorder.state
        #expect(state == .finished)
        let samples = recorder.samples
        var droppedSamples: [FrameSample] = []
        for sample in samples where sample.dropped { droppedSamples.append(sample) }
        #expect(droppedSamples.count == 1, "only the 30 ms interval is above 25 ms")
        let late = try #require(droppedSamples.first)
        let lateInterval = try #require(late.intervalMs)
        #expect(late.phase == .measure && abs(lateInterval - 30) < 1e-6)
        let summary = try #require(recorder.summary)
        #expect(summary.dropped == 1 && summary.flags.contains(.droppedFrames))
        #expect(summary.measured == expectedMeasured)
        #expect(summary.warmUpExcluded == expectedWarmUp && summary.coolDownExcluded == expectedCoolDown)
        let intervalCount = summary.interval.count
        #expect(intervalCount == expectedMeasured, "the dropped frame's interval still counts")
        let largest = try #require(summary.interval.p99 ?? summary.interval.p95)
        #expect(largest <= lateInterval + 1e-6)
    }

    // MARK: Through the presenter

    @Test func aRunThroughThePresenterMeasuresTheCPUTimeAndSaysGPUTimeIsNotAvailable() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        presenter.forceTimerUnsupported = true
        #expect(presenter.status == "Ready" && presenter.mirror.status == "Ready")
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, at: 100)
        #expect(presenter.recorder.state == .running && presenter.status == "Warm-up")
        #expect(presenter.workloadFrame == 1, "the run's first frame is workload frame 0")
        var words = [presenter.mirror.status]
        for time in BenchTest.times(from: 100.5, step: 0.5, count: 36) {
            try BenchTest.draw(session, shell, at: time)
            let word = presenter.mirror.status
            if words.last != word { words.append(word) }
        }
        #expect(words == ["Warm-up", "Measuring", "Cool-down", "Finished"])
        let samples = presenter.recorder.samples
        #expect(samples.count == 36)
        #expect(samples.allSatisfy { $0.cpuMs > 0 }, "the CPU submit time is measured, never a placeholder zero")
        var withGPU = 0
        for sample in samples where sample.gpuMs != nil { withGPU += 1 }
        #expect(withGPU == 0, "the probe is forced to unsupported, so no sample has a GPU time")
        #expect(presenter.timer == nil)
        let summary = try #require(presenter.recorder.summary)
        #expect(summary.measured == 20 && summary.warmUpExcluded == 6 && summary.coolDownExcluded == 10)
        #expect(summary.gpu == nil && summary.flags.contains(.gpuTimeNotAvailable))
        let lines = presenter.mirror.summaryLines
        #expect(lines.contains("GPU time not available on this device."))
        #expect(lines.first == "Frame interval p50 500.00 ms")
        let core = try BenchTest.core(shell)
        let spoken = presenter.describe(core)
        #expect(spoken.contains("Finished") && spoken.contains("GPU time not available"))
    }

    @Test func stoppingMidRunGivesStopped() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: 10, step: 0.5, count: 9))
        #expect(presenter.status == "Measuring")
        BenchTest.accept(shell, "run.stop")
        try BenchTest.draw(session, shell, at: 15)
        #expect(presenter.recorder.state == .stopped)
        #expect(presenter.mirror.status == "Stopped" && presenter.mirror.summaryLines.isEmpty)
        #expect(presenter.recorder.samples.count == 9)
    }

    @Test func choosingAnotherCaseMidRunStopsTheRunBeforeTheNewCaseIsDrawn() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: 0, step: 0.5, count: 4))
        #expect(presenter.recorder.state == .running)
        BenchTest.accept(shell, "case.select", [1])
        try BenchTest.draw(session, shell, at: 2)
        #expect(presenter.recorder.state == .stopped && presenter.mirror.status == "Stopped")
        #expect(presenter.recorder.benchmarkCase?.id == "quads", "the stopped run is the quads run")
        #expect(presenter.recorder.samples.count == 4, "the new case's frame is not in the run")
        #expect(presenter.workloadCase.id == "alu" && presenter.workloadFrame == 1)
        #expect(presenter.mirror.selectedCase == 1)
    }

    @Test func closingTheSessionMidRunGivesInterrupted() async throws {
        let session = ExperienceSession()
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: 0, step: 0.5, count: 5))
        #expect(presenter.recorder.state == .running)
        session.close()
        #expect(presenter.recorder.state == .interrupted && presenter.mirror.status == "Interrupted")
        #expect(presenter.recorder.samples.count == 5, "the samples are kept")
        #expect(!presenter.hasWorkload, "the workload was released")
    }

    @Test func aContextRebuildMidRunGivesInterruptedWithTheSamplesKept() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: 0, step: 0.5, count: 6))
        #expect(presenter.recorder.state == .running)
        let host = try #require(session.renderHost)
        host.recreateContext()
        try BenchTest.draw(session, shell, at: 3)
        #expect(presenter.recorder.state == .interrupted && presenter.mirror.status == "Interrupted")
        #expect(presenter.recorder.samples.count == 6, "the samples are kept")
        #expect(presenter.hasWorkload, "the workload is rebuilt from the case")
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func aRestoredSnapshotNeverResumesARun() async throws {
        let first = try await BenchTest.shell()
        BenchTest.accept(first, "case.select", [2])
        BenchTest.accept(first, "run.start")
        let snapshot = try first.snapshot()

        let session = ExperienceSession()
        defer { session.close() }
        session.qualityPin = 0
        let id = BenchTest.id
        var made: ExperienceShell<BenchPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: snapshot, refusedSnapshotFails: true) {
            let shell = GraphicsBenchmarkLabExperience.make(id: id)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let shell = try #require(made)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 64, height: 48)
        view.layoutIfNeeded()
        try BenchTest.draw(session, shell, times: [0, 0.5])
        let core = try BenchTest.core(shell)
        #expect(core.startRequests == 1 && core.selectedCase == 2)
        #expect(shell.presenter.recorder.state == .idle && shell.presenter.status == "Ready")
        #expect(shell.presenter.workloadCase.id == "particles")
    }
}
