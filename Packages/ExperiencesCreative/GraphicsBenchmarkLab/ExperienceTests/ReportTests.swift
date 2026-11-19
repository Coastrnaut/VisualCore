// ReportTests — feature 175 (A24-P03) T-A24-310 (SC-A24-303; FR-A24-307; clarification Q5; US3). The report of a run
// through the presenter in the one app's session host (synthetic frame times 0.5 s apart, each frame presented so
// that GPU timer results arrive):
//   - a finished run's record carries a report that validates, every string field non-empty, the renderer and GL
//     version equal to the context's capabilities (cut to 128 characters), tier "level-0", the case reference equal
//     to the run's, and the GPU timer named as a source exactly when a sample has a GPU time;
//   - with the probe forced off the GPU timer is never named;
//   - a stopped run carries a report too, and the run file with the report reopens to the same run;
//   - `ReportSource` gives "unknown" for empty strings and cuts long ones.
import CoreGraphics
import Foundation
import Testing
import UIKit
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

@MainActor
@Suite(.serialized) struct ReportTests {
    /// Opens the experience, applies `forced`, starts a run at 100 s and draws `count` more frames 0.5 s apart.
    private func run(_ session: ExperienceSession, forced: Bool, count: Int) async throws
        -> ExperienceShell<BenchPresenter> {
        let shell = try await BenchTest.open(session)
        shell.presenter.forceTimerUnsupported = forced
        BenchTest.accept(shell, "run.start")
        try BenchTest.drawPresented(session, shell, at: 100)
        for time in BenchTest.times(from: 100.5, step: 0.5, count: count) {
            try BenchTest.drawPresented(session, shell, at: time)
        }
        return shell
    }

    /// Checks `report` against the run and the capabilities of `session`'s host.
    private func check(_ report: RunReport, of run: BenchmarkRun, session: ExperienceSession,
                       sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(throws: Never.self, sourceLocation: sourceLocation) { try report.validate() }
        let strings = [report.deviceModel, report.osVersion, report.appVersion, report.appBuild, report.renderer,
                       report.glVersion, report.qualityTier, report.thermalStart, report.thermalEnd, report.caseID,
                       report.caseFingerprint]
        for value in strings {
            #expect(!value.isEmpty && value.count <= RunReport.maxFieldLength, sourceLocation: sourceLocation)
        }
        let host = try #require(session.renderHost, sourceLocation: sourceLocation)
        let capabilities = host.resources.renderCapabilities
        let renderer = ReportSource.bounded(capabilities.renderer)
        let glVersion = ReportSource.bounded(capabilities.glVersion)
        #expect(report.renderer == renderer && report.glVersion == glVersion, sourceLocation: sourceLocation)
        #expect(report.qualityTier == "level-0", sourceLocation: sourceLocation)
        let sameCase = report.caseID == run.caseID && report.caseVersion == run.caseVersion
            && report.caseFingerprint == run.caseFingerprint
        #expect(sameCase, sourceLocation: sourceLocation)
        let sources = report.timingSources
        #expect(sources.interval == "frame time" && sources.cpu == "presenter CPU time", sourceLocation: sourceLocation)
        var timed = false
        for sample in run.samples where sample.gpuMs != nil { timed = true }
        let expectedGPU: String? = timed ? "GPU timer" : nil
        #expect(sources.gpu == expectedGPU, sourceLocation: sourceLocation)
        let model = ReportSource.deviceModel()
        #expect(report.deviceModel == model, sourceLocation: sourceLocation)
        let os = ReportSource.osVersion()
        #expect(report.osVersion == os && os.split(separator: ".").count == 3, sourceLocation: sourceLocation)
    }

    @Test func aFinishedRunCarriesAValidReportWithEveryFieldFilled() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await run(session, forced: false, count: 36)
        let recorder = shell.presenter.recorder
        let state = recorder.state
        #expect(state == .finished)
        let run = try #require(recorder.runRecord())
        let report = try #require(run.report)
        try check(report, of: run, session: session)
        let support = shell.presenter.timerSupport
        let expectedGPU: String? = support == .supported ? TimingSources.gpuTimer : nil
        #expect(report.timingSources.gpu == expectedGPU, "a supported timer times the presented measured frames")
        let reopened = try RunDocument.decode(RunDocument.encode(run)).get()
        #expect(reopened == run, "the run file with its report reopens to the same run")
        print("A24 report (simulator context only): \(report.deviceModel), \(report.osVersion), "
              + "\(report.renderer), gpu source \(report.timingSources.gpu ?? "none")")
    }

    @Test func withTheProbeForcedOffTheGPUTimerIsNeverNamed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await run(session, forced: true, count: 36)
        let run = try #require(shell.presenter.recorder.runRecord())
        let report = try #require(run.report)
        try check(report, of: run, session: session)
        let gpu = report.timingSources.gpu
        #expect(gpu == nil)
    }

    @Test func aStoppedRunCarriesAReportToo() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await run(session, forced: false, count: 8)
        BenchTest.accept(shell, "run.stop")
        try BenchTest.drawPresented(session, shell, at: 105)
        let run = try #require(shell.presenter.recorder.runRecord())
        #expect(run.state == .stopped)
        let report = try #require(run.report)
        try check(report, of: run, session: session)
    }

    @Test func theSourceFillsEmptyStringsAndCutsLongOnes() throws {
        let empty = ReportSource.bounded("")
        #expect(empty == "unknown")
        let long = ReportSource.bounded(String(repeating: "r", count: 300))
        #expect(long.count == RunReport.maxFieldLength)
        var capabilities = RenderCapabilities()
        capabilities.renderer = ""
        capabilities.glVersion = String(repeating: "g", count: 200)
        let report = ReportSource.report(case: .particles, capabilities: capabilities, tier: 0,
                                         start: DeviceConditions(thermal: .nominal, lowPower: false),
                                         end: DeviceConditions(thermal: .serious, lowPower: true), gpuMeasured: true)
        #expect(throws: Never.self) { try report.validate() }
        #expect(report.renderer == "unknown" && report.glVersion.count == RunReport.maxFieldLength)
        #expect(report.thermalStart == "nominal" && report.thermalEnd == "serious")
        #expect(!report.lowPowerStart && report.lowPowerEnd)
        #expect(report.flags == [RunReport.thermalChangedFlag])
        #expect(report.timingSources.gpu == TimingSources.gpuTimer)
        let version = ReportSource.appVersion()
        let build = ReportSource.appBuild()
        #expect(!version.isEmpty && !build.isEmpty)
    }
}
