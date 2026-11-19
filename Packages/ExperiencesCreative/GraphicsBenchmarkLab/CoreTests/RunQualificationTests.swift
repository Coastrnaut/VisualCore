// RunQualificationTests — feature 177 (A24-P05) T-A24-502 (FR-A24-501; SC-A24-501; clarification Q1; User Story 1).
// One fixture per class and per reason: a clean completed run is valid with no reason; a stopped, an interrupted and
// an unmeasured run are invalid with exactly their reasons (and none of the qualified ones); each qualified condition
// alone gives exactly its reason; every condition together gives every qualified reason in the fixed order; the
// codes and sentences are those of clarification Q1. Synthetic values only.
import Testing
@testable import GraphicsBenchmarkLabCore

/// Synthetic runs for the qualification and repeatability tests, built directly from a summary (the samples are
/// not needed: qualification and repeatability read the summary, the state and the report only).
enum QualificationFixture {
    /// A valid report: nominal thermal state throughout, Low Power Mode off, the given identity fields.
    static func report(deviceModel: String = "iPhone99,1", osVersion: String = "27.2", appBuild: String = "1",
                       qualityTier: String = "level-0", thermalStart: String = "nominal",
                       thermalEnd: String = "nominal", lowPowerStart: Bool = false,
                       lowPowerEnd: Bool = false) -> RunReport {
        RunReport(deviceModel: deviceModel, osVersion: osVersion, appVersion: "1.0", appBuild: appBuild,
                  renderer: "Synthetic Renderer", glVersion: "OpenGL ES 3.0 (synthetic)", qualityTier: qualityTier,
                  thermalStart: thermalStart, thermalEnd: thermalEnd, lowPowerStart: lowPowerStart,
                  lowPowerEnd: lowPowerEnd, timingSources: .standard(gpuMeasured: true), caseID: "quads",
                  caseVersion: 1, caseFingerprint: SyntheticReport.fingerprint)
    }

    /// A summary of `measured` frames with the given interval p50 and p95, GPU p50 (no GPU distribution when nil)
    /// and flags.
    static func summary(measured: Int = 120, p50: Double? = 16.5, p95: Double? = 17.0, gpuP50: Double? = 4.5,
                        flags: [QualityFlag] = []) -> Summary {
        let interval = Distribution(p50: p50, p95: p95, p99: nil, count: measured)
        let cpu = Distribution(p50: 2.0, p95: 2.5, p99: nil, count: measured)
        var gpu: Distribution?
        if let gpuP50 { gpu = Distribution(p50: gpuP50, p95: gpuP50 + 0.5, p99: nil, count: measured) }
        return Summary(interval: interval, cpu: cpu, gpu: gpu, measured: measured, warmUpExcluded: 0,
                       coolDownExcluded: 0, dropped: 0, flags: flags)
    }

    /// A run of the quads case (or of `benchmarkCase`) with the given state, summary and report.
    static func run(state: RunState = .completed, summary: Summary = summary(),
                    report: RunReport? = report(), benchmarkCase: BenchmarkCase = .quads) throws -> BenchmarkRun {
        try BenchmarkRun(benchmarkCase: benchmarkCase, samples: [], summary: summary, state: state, report: report)
    }
}

@Suite struct RunQualificationTests {
    @Test func aCleanCompletedRunIsValid() throws {
        let qualification = RunQualification.qualify(try QualificationFixture.run())
        #expect(qualification == Qualification(class: .valid, reasons: []))
        let codes = qualification.reasonCodes
        #expect(codes == "")
    }

    @Test func eachInvalidReasonAlone() throws {
        let stopped = RunQualification.qualify(try QualificationFixture.run(state: .stopped))
        let interrupted = RunQualification.qualify(try QualificationFixture.run(state: .interrupted))
        let empty = QualificationFixture.summary(measured: 0, p50: nil, p95: nil, gpuP50: nil, flags: [.noSamples])
        let unmeasured = RunQualification.qualify(try QualificationFixture.run(summary: empty))
        #expect(stopped == Qualification(class: .invalid, reasons: [.stopped]))
        #expect(interrupted == Qualification(class: .invalid, reasons: [.interrupted]))
        #expect(unmeasured == Qualification(class: .invalid, reasons: [.noSamples]))
    }

    @Test func invalidReasonsCombineAndHideQualifiedOnes() throws {
        let empty = QualificationFixture.summary(measured: 0, p50: nil, p95: nil, gpuP50: nil, flags: [.noSamples])
        let hot = QualificationFixture.report(thermalStart: "fair", thermalEnd: "critical", lowPowerEnd: true)
        let run = try QualificationFixture.run(state: .interrupted, summary: empty, report: hot)
        let qualification = RunQualification.qualify(run)
        #expect(qualification == Qualification(class: .invalid, reasons: [.interrupted, .noSamples]))
        let withoutReport = try QualificationFixture.run(state: .stopped, report: nil)
        let stopped = RunQualification.qualify(withoutReport)
        #expect(stopped == Qualification(class: .invalid, reasons: [.stopped]))
    }

    @Test func eachQualifiedReasonAlone() throws {
        let cases: [(BenchmarkRun, QualificationReason)] = [
            (try QualificationFixture.run(report: QualificationFixture.report(thermalEnd: "fair")), .thermalChanged),
            (try QualificationFixture.run(report: QualificationFixture.report(thermalStart: "serious",
                                                                              thermalEnd: "serious")),
             .thermalSerious),
            (try QualificationFixture.run(report: QualificationFixture.report(thermalStart: "critical",
                                                                              thermalEnd: "critical")),
             .thermalCritical),
            (try QualificationFixture.run(report: QualificationFixture.report(lowPowerStart: true)), .lowPower),
            (try QualificationFixture.run(report: QualificationFixture.report(lowPowerEnd: true)), .lowPower),
            (try QualificationFixture.run(summary: QualificationFixture.summary(flags: [.droppedFrames])),
             .droppedFrames),
            (try QualificationFixture.run(summary: QualificationFixture.summary(flags: [.tooFewForP99])),
             .tooFewForP99),
            (try QualificationFixture.run(report: nil), .noReport),
        ]
        for (run, reason) in cases {
            let qualification = RunQualification.qualify(run)
            #expect(qualification == Qualification(class: .qualified, reasons: [reason]), "\(reason.rawValue)")
        }
    }

    @Test func flagsThatAreNotReasonsKeepARunValid() throws {
        let summary = QualificationFixture.summary(p95: nil, gpuP50: nil, flags: [.tooFewForP95, .gpuTimeNotAvailable])
        let qualification = RunQualification.qualify(try QualificationFixture.run(summary: summary))
        #expect(qualification.class == .valid)
    }

    @Test func everyQualifiedReasonInTheFixedOrder() throws {
        let hotEnd = QualificationFixture.report(thermalStart: "serious", thermalEnd: "critical", lowPowerEnd: true)
        let summary = QualificationFixture.summary(flags: [.tooFewForP99, .droppedFrames])
        let withReport = RunQualification.qualify(try QualificationFixture.run(summary: summary, report: hotEnd))
        #expect(withReport == Qualification(class: .qualified, reasons: [
            .thermalChanged, .thermalSerious, .thermalCritical, .lowPower, .droppedFrames, .tooFewForP99,
        ]))
        let codes = withReport.reasonCodes
        #expect(codes == "thermal-changed;thermal-serious;thermal-critical;low-power;dropped-frames;too-few-for-p99")
        let withoutReport = RunQualification.qualify(try QualificationFixture.run(summary: summary, report: nil))
        #expect(withoutReport.reasons == [.droppedFrames, .tooFewForP99, .noReport])
    }

    @Test func theCodesAndTheirOrderAreFixed() {
        var codes: [String] = []
        for reason in QualificationReason.allCases { codes.append(reason.rawValue) }
        #expect(codes == [
            "stopped", "interrupted", "no-samples", "thermal-changed", "thermal-serious", "thermal-critical",
            "low-power", "dropped-frames", "too-few-for-p99", "no-report",
        ])
        var classes: [String] = []
        for value in [QualificationClass.valid, .qualified, .invalid] { classes.append(value.rawValue) }
        #expect(classes == ["valid", "qualified", "invalid"])
    }

    @Test func everySentence() {
        let expected: [QualificationReason: String] = [
            .stopped: "Stopped before the end",
            .interrupted: "Interrupted (for example by leaving the app)",
            .noSamples: "No frame was measured",
            .thermalChanged: "The thermal state changed during the run",
            .thermalSerious: "The device was hot (serious)",
            .thermalCritical: "The device was hot (critical)",
            .lowPower: "Low Power Mode was on",
            .droppedFrames: "Some frames were dropped",
            .tooFewForP99: "Too few frames for p99",
            .noReport: "No device report",
        ]
        for reason in QualificationReason.allCases {
            let sentence = reason.sentence
            #expect(sentence == expected[reason], "\(reason.rawValue)")
        }
        let count = expected.count
        #expect(count == QualificationReason.allCases.count)
    }
}
