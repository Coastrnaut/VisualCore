// ThermalStopTests — feature 177 (A24-P05) T-A24-513 (visualcore-contract risk 3; FR-A24-501): a running run never
// continues while the device is hot. Through the one app's session host, with the presenter's `conditionsSource` seam:
//   - a run measuring at a nominal thermal state ends as interrupted at the first frame read as serious (and, in a
//     second run, critical): the status reads "Interrupted: the device is hot", the report's end state is the hot one,
//     the qualification is Invalid, and no frame is recorded after the stop;
//   - a fair thermal state does not stop the run, and a new run after a hot stop starts with the plain status words.
// Short presenter runs with synthetic frame times only: no clock, no sleep.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

@Suite(.serialized) struct ThermalStopTests {
    /// Starts a run at a nominal state, measures, then turns the state to `hot` and draws one more frame; returns the
    /// recorded sample counts before and after the hot frame.
    @MainActor
    static func runIntoHeat(_ hot: FramePacing.Thermal, session: ExperienceSession,
                            shell: ExperienceShell<BenchPresenter>, from start: Double) throws -> (Int, Int) {
        let presenter = shell.presenter
        presenter.conditionsSource = { DeviceConditions(thermal: .nominal, lowPower: false) }
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: start, step: 0.5, count: 9))
        #expect(presenter.mirror.status == "Measuring")
        let before = presenter.recorder.samples.count
        presenter.conditionsSource = { DeviceConditions(thermal: hot, lowPower: false) }
        try BenchTest.draw(session, shell, at: start + 4.5)
        try BenchTest.draw(session, shell, at: start + 5.0)
        return (before, presenter.recorder.samples.count)
    }

    @MainActor
    @Test func aSeriousOrCriticalThermalStateStopsTheRun() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        var start = 10.0
        for (hot, name) in [(FramePacing.Thermal.serious, "serious"), (.critical, "critical")] {
            let (before, after) = try Self.runIntoHeat(hot, session: session, shell: shell, from: start)
            #expect(presenter.recorder.state == .interrupted, "\(name): the run is interrupted")
            #expect(presenter.stoppedForHeat, "\(name): the stop is for heat")
            #expect(presenter.mirror.status == BenchPresenter.hotWord, "\(name): \(presenter.mirror.status)")
            #expect(after == before, "\(name): no frame is recorded once the device is hot")
            let report = try #require(presenter.recorder.report, "\(name): the stopped run has its report")
            #expect(report.thermalStart == "nominal" && report.thermalEnd == name)
            let qualification = try #require(presenter.mirror.runQualification)
            #expect(qualification.class == .invalid && qualification.reasons == [.interrupted], "\(name)")
            start += 20
        }
    }

    @MainActor
    @Test func aFairStateRunsOnAndANewRunStartsClean() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        let (before, after) = try Self.runIntoHeat(.fair, session: session, shell: shell, from: 10)
        #expect(presenter.recorder.state == .running && !presenter.stoppedForHeat, "a fair state does not stop a run")
        #expect(after == before + 2)
        BenchTest.accept(shell, "run.stop")
        try BenchTest.draw(session, shell, at: 15.5)
        #expect(presenter.mirror.status == "Stopped")

        _ = try Self.runIntoHeat(.serious, session: session, shell: shell, from: 30)
        #expect(presenter.mirror.status == BenchPresenter.hotWord)
        presenter.conditionsSource = { DeviceConditions(thermal: .nominal, lowPower: false) }
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, at: 40)
        #expect(!presenter.stoppedForHeat && presenter.mirror.status == "Warm-up", "the new run starts clean")
    }
}
