// QualificationDisplayTests — feature 177 (A24-P05) T-A24-506 (FR-A24-502, FR-A24-503; SC-A24-501, SC-A24-502;
// clarifications Q1–Q3; User Stories 1, 2). How the qualification and the repeatability are shown:
//   - the results list row ends with the class word ("Valid", "Qualified", "Invalid"); the opened result's lines are
//     the class word and the reason sentences;
//   - the controls show the qualification of the ended run: a run interrupted by a gap over 1,000 ms after its start
//     (driven by `feedTime`) is "Invalid" with "Interrupted (for example by leaving the app)"; a stopped run is
//     "Invalid" with "Stopped before the end"; a finished run under ordinary conditions is "Valid"; nothing is shown
//     while a run is running;
//   - an opened result's repeatability block lists the comparable trials with their spread, the others with their
//     reason, and the one-trial sentence for a single trial.
// Synthetic runs and short presenter runs only: no clock, no sleep.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

/// Fixtures of the qualification tests.
@MainActor
enum QualificationFixture {
    /// A report of `benchmarkCase` (fingerprint `fingerprint`) under ordinary conditions: thermal state nominal at the
    /// start and the end, Low Power Mode off, on OS `os`.
    static func ordinaryReport(_ benchmarkCase: BenchmarkCase, fingerprint: String, os: String = "27.2.0") -> RunReport {
        RunReport(deviceModel: "iPhone17,1", osVersion: os, appVersion: "1.0", appBuild: "7",
                  renderer: "Synthetic GPU", glVersion: "OpenGL ES 3.0 Synthetic", qualityTier: "level-0",
                  thermalStart: "nominal", thermalEnd: "nominal", lowPowerStart: false, lowPowerEnd: false,
                  timingSources: .standard(gpuMeasured: false), caseID: benchmarkCase.id,
                  caseVersion: benchmarkCase.version, caseFingerprint: fingerprint)
    }

    /// A completed quads run of 120 measured frames under ordinary conditions (valid), on OS `os`, as `state`.
    static func ordinaryRun(state: RunState = .completed, offset: Int = 0, os: String = "27.2.0") throws
        -> BenchmarkRun {
        let benchmarkCase = BenchmarkCase.quads
        let samples = ResultTest.samples(measured: 120, offset: offset)
        let summary = try Summary.make(samples)
        let fingerprint = try benchmarkCase.fingerprint().hex
        return BenchmarkRun(benchmarkCase: benchmarkCase, caseFingerprint: fingerprint, samples: samples,
                            summary: summary, state: state,
                            report: ordinaryReport(benchmarkCase, fingerprint: fingerprint, os: os))
    }

    /// A case of the quads workload with a plan of 1 + 1 + 0 seconds (a short finished run).
    static var shortQuads: BenchmarkCase {
        BenchmarkCase(id: "quads", version: 1, workload: .quads, config: BenchmarkCase.quads.config,
                      plan: RunPlan(warmUpSeconds: 1, measureSeconds: 1, coolDownSeconds: 0))
    }
}

@Suite(.serialized) struct QualificationDisplayTests {
    @MainActor
    @Test func theListAndTheOpenedResultShowTheClassAndTheSentences() throws {
        let place = try BenchStoragePlace("qualification-list")
        defer { place.remove() }
        let exporter = ResultTest.exporter("qualification-list")
        defer { exporter.clear() }
        let presenter = BenchPresenter(storage: place.storage, exporter: exporter)
        let library = try #require(presenter.library)
        let valid = try QualificationFixture.ordinaryRun()
        let qualified = try ResultTest.run(.alu)
        let invalid = try ResultTest.run(.particles, state: .interrupted)
        for run in [valid, qualified, invalid] { _ = ResultTest.value(library.save(run)) }
        presenter.showResults()
        let entries = presenter.mirror.resultEntries
        #expect(entries.count == 3)
        var words: [String: String] = [:]
        for entry in entries {
            let label = ResultsView.rowLabel(entry)
            let word = label.components(separatedBy: ", ").last ?? ""
            words[entry.file] = word
        }
        #expect(words == ["result-1.json": "Valid", "result-2.json": "Qualified", "result-3.json": "Invalid"])

        let opened = try #require(ResultTest.value(presenter.openResult(file: "result-2.json")))
        let qualification = RunQualification.qualify(opened.run)
        let lines = QualificationText.lines(qualification)
        #expect(lines == ["Qualified", "The thermal state changed during the run", "Low Power Mode was on",
                          "Too few frames for p99"])
        let label = QualificationText.label(qualification)
        #expect(label.hasPrefix("Qualification, Qualified, The thermal state changed during the run"))

        let interrupted = try #require(ResultTest.value(presenter.openResult(file: "result-3.json")))
        let invalidLines = QualificationText.lines(RunQualification.qualify(interrupted.run))
        #expect(invalidLines == ["Invalid", "Interrupted (for example by leaving the app)"])
        let validLines = QualificationText.lines(RunQualification.qualify(valid))
        #expect(validLines == ["Valid"])
    }

    @MainActor
    @Test func aRunInterruptedByAGapOverASecondIsInvalidInTheControls() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: 10, step: 0.5, count: 9))
        let measuring = presenter.mirror.status
        let whileRunning = presenter.mirror.runQualification
        #expect(measuring == "Measuring" && whileRunning == nil, "nothing is shown while the run is running")
        // A gap of 1.5 s, over the 1,000 ms sample cap, as after a return from the background.
        try BenchTest.draw(session, shell, at: 15.5)
        let status = presenter.mirror.status
        #expect(status == "Interrupted")
        let qualification = try #require(presenter.mirror.runQualification)
        let lines = QualificationText.lines(qualification)
        #expect(lines.first == "Invalid")
        #expect(lines.contains("Interrupted (for example by leaving the app)"))
        let label = QualificationText.label(qualification)
        #expect(label.contains("Invalid"))
    }

    @MainActor
    @Test func aStoppedRunIsInvalidInTheControls() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session)
        let presenter = shell.presenter
        BenchTest.accept(shell, "run.start")
        try BenchTest.draw(session, shell, times: BenchTest.times(from: 10, step: 0.5, count: 9))
        BenchTest.accept(shell, "run.stop")
        try BenchTest.draw(session, shell, at: 15)
        let qualification = try #require(presenter.mirror.runQualification)
        let lines = QualificationText.lines(qualification)
        #expect(lines == ["Invalid", "Stopped before the end"])
        let canSave = presenter.mirror.canSave
        #expect(canSave, "a stopped run can still be saved")
    }

    @MainActor
    @Test func aFinishedRunUnderOrdinaryConditionsIsValidInTheControls() async throws {
        let shell = try await BenchTest.shell()
        let presenter = shell.presenter
        let core = try BenchTest.core(shell)
        let benchmarkCase = QualificationFixture.shortQuads
        presenter.recorder.start(case: benchmarkCase, at: 0)
        let step = 1.0 / 120.0
        var time = 0.0
        while time < 2.0 {
            presenter.recorder.record(frameTime: time, cpuMs: 1.5)
            time += step
        }
        presenter.recorder.record(frameTime: 2.0, cpuMs: 1.5)
        let state = presenter.recorder.state
        #expect(state == .finished)
        let fingerprint = try benchmarkCase.fingerprint().hex
        presenter.recorder.attachReport(QualificationFixture.ordinaryReport(benchmarkCase, fingerprint: fingerprint))
        presenter.follow(core)
        let qualification = try #require(presenter.mirror.runQualification)
        let lines = QualificationText.lines(qualification)
        #expect(lines == ["Valid"], "\(lines)")
        let status = presenter.mirror.status
        #expect(status == "Finished")
    }

    @MainActor
    @Test func theRepeatabilityBlockComparesTrialsAndNamesTheOthers() throws {
        let place = try BenchStoragePlace("qualification-repeat")
        defer { place.remove() }
        let exporter = ResultTest.exporter("qualification-repeat")
        defer { exporter.clear() }
        let presenter = BenchPresenter(storage: place.storage, exporter: exporter)
        let library = try #require(presenter.library)
        let runs = [try QualificationFixture.ordinaryRun(offset: 0), try QualificationFixture.ordinaryRun(offset: 2),
                    try QualificationFixture.ordinaryRun(offset: 0, os: "26.5.0"),
                    try QualificationFixture.ordinaryRun(state: .stopped), try ResultTest.run(.alu)]
        for run in runs { _ = ResultTest.value(library.save(run)) }
        presenter.showResults()
        _ = try #require(ResultTest.value(presenter.openResult(file: "result-1.json")))
        let summary = try #require(presenter.mirror.repeatability)
        var orders: [Int] = []
        for trial in summary.comparable { orders.append(trial.order) }
        #expect(orders == [1, 2])
        let lines = RepeatabilityView.lines(summary)
        #expect(lines.first == "2 comparable trials.")
        let p50 = try #require(summary.spreadP50Ms)
        #expect(lines.contains("Spread of p50: " + BenchPresenter.milliseconds(text: p50)))
        #expect(lines.contains("Trial 3: not comparable, Another OS version"))
        #expect(lines.contains("Trial 4: not comparable, Not valid"))
        #expect(lines.contains("Trial 5: not comparable, Another case or case version"))
        #expect(!lines.contains(RepeatabilityView.oneTrial))

        let alone = Repeatability.summarise(opened: OrderedRun(order: 1, run: runs[0]), among: [])
        let aloneLines = RepeatabilityView.lines(alone)
        #expect(aloneLines.contains(RepeatabilityView.oneTrial))
        var spreads = 0
        for line in aloneLines where line.hasPrefix("Spread") { spreads += 1 }
        #expect(spreads == 0, "no spread with one trial")
        let sentences = [RepeatabilityView.sentence(.differentDevice), RepeatabilityView.sentence(.differentBuild),
                         RepeatabilityView.sentence(.differentTier)]
        #expect(sentences == ["Another device", "Another app build", "Another quality tier"])

        presenter.hideResults()
        let closed = presenter.mirror.repeatability
        #expect(closed == nil)
    }
}
