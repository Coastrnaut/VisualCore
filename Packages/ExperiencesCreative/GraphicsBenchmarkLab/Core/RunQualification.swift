// RunQualification — feature 177 (A24-P05) T-A24-502 (FR-A24-501; clarification Q1; data-model.md
// "Qualification"). Classifies a run as valid, qualified or invalid from the run alone, with every reason that
// applies in the fixed order of ``QualificationReason/allCases``:
//
// - **invalid** when the state is `stopped` (`stopped`) or `interrupted` (`interrupted`), or no frame was measured
//   (`no-samples`); the reasons are those of these three that apply.
// - otherwise **qualified** when any of `thermal-changed` (start and end differ), `thermal-serious` or
//   `thermal-critical` (either state), `low-power` (on at start or end), `dropped-frames` (the summary's flag),
//   `too-few-for-p99` (the summary's flag) or `no-report` (the run has no report) applies.
// - otherwise **valid** with no reason.
//
// The qualification is derived, never stored: the run file (version 3) is unchanged, and the CSV (version 2) writes
// it in the `qualification` and `qualification_reasons` rows. Pure Swift; no UI, GPU, file or clock.

/// The class of a run: whether its numbers can be read as they are.
public enum QualificationClass: String, Codable, Sendable {
    /// The run completed under ordinary conditions; its numbers can be read as they are.
    case valid
    /// The run completed, but at least one condition (see ``QualificationReason``) calls for care.
    case qualified
    /// The run did not complete or measured nothing; its numbers are not a measurement.
    case invalid
}

/// A reason for a run's class. The cases are declared in the fixed order a qualification lists them in; the raw
/// values are the codes of clarification Q1 that the CSV writes.
public enum QualificationReason: String, Codable, CaseIterable, Sendable {
    /// The person stopped the run before the end (invalid).
    case stopped
    /// The run was interrupted, for example by leaving the app (invalid).
    case interrupted
    /// No frame was measured (invalid).
    case noSamples = "no-samples"
    /// The thermal state at the end differs from the one at the start (qualified).
    case thermalChanged = "thermal-changed"
    /// The thermal state was serious at the start or the end (qualified).
    case thermalSerious = "thermal-serious"
    /// The thermal state was critical at the start or the end (qualified).
    case thermalCritical = "thermal-critical"
    /// Low Power Mode was on at the start or the end (qualified).
    case lowPower = "low-power"
    /// At least one measured frame was dropped (qualified).
    case droppedFrames = "dropped-frames"
    /// Fewer than 100 measured intervals, so the interval p99 is absent (qualified).
    case tooFewForP99 = "too-few-for-p99"
    /// The run has no device report (qualified).
    case noReport = "no-report"

    /// The sentence shown for the reason in the opened result (clarification Q1).
    public var sentence: String {
        switch self {
        case .stopped: "Stopped before the end"
        case .interrupted: "Interrupted (for example by leaving the app)"
        case .noSamples: "No frame was measured"
        case .thermalChanged: "The thermal state changed during the run"
        case .thermalSerious: "The device was hot (serious)"
        case .thermalCritical: "The device was hot (critical)"
        case .lowPower: "Low Power Mode was on"
        case .droppedFrames: "Some frames were dropped"
        case .tooFewForP99: "Too few frames for p99"
        case .noReport: "No device report"
        }
    }
}

/// The qualification of a run: its class and the reasons for it.
public struct Qualification: Equatable, Sendable {
    /// The run's class.
    public var `class`: QualificationClass
    /// The reasons for the class, in the order of ``QualificationReason/allCases``; empty exactly when valid.
    public var reasons: [QualificationReason]

    /// A qualification of `class` for `reasons` (not checked).
    public init(class: QualificationClass, reasons: [QualificationReason]) {
        self.class = `class`
        self.reasons = reasons
    }

    /// The reason codes joined by `;`, the empty string when there is none (the CSV's `qualification_reasons`).
    public var reasonCodes: String {
        var codes: [String] = []
        for reason in reasons { codes.append(reason.rawValue) }
        return codes.joined(separator: ";")
    }
}

/// Qualifies a run from the run alone (clarification Q1).
public enum RunQualification {
    /// The qualification of `run`: invalid for a stopped or interrupted run or one that measured no frame;
    /// otherwise qualified with every reason that applies; otherwise valid.
    public static func qualify(_ run: BenchmarkRun) -> Qualification {
        var applies: Set<QualificationReason> = []
        if run.state == .stopped { applies.insert(.stopped) }
        if run.state == .interrupted { applies.insert(.interrupted) }
        if run.summary.measured == 0 { applies.insert(.noSamples) }
        if applies.isEmpty == false {
            return Qualification(class: .invalid, reasons: ordered(applies))
        }
        if let report = run.report {
            if report.thermalStart != report.thermalEnd { applies.insert(.thermalChanged) }
            if report.thermalStart == "serious" || report.thermalEnd == "serious" { applies.insert(.thermalSerious) }
            if report.thermalStart == "critical" || report.thermalEnd == "critical" {
                applies.insert(.thermalCritical)
            }
            if report.lowPowerStart || report.lowPowerEnd { applies.insert(.lowPower) }
        } else {
            applies.insert(.noReport)
        }
        if run.summary.flags.contains(.droppedFrames) { applies.insert(.droppedFrames) }
        if run.summary.flags.contains(.tooFewForP99) { applies.insert(.tooFewForP99) }
        if applies.isEmpty { return Qualification(class: .valid, reasons: []) }
        return Qualification(class: .qualified, reasons: ordered(applies))
    }

    /// The reasons of `set` in the order of ``QualificationReason/allCases``.
    private static func ordered(_ set: Set<QualificationReason>) -> [QualificationReason] {
        var result: [QualificationReason] = []
        for reason in QualificationReason.allCases where set.contains(reason) { result.append(reason) }
        return result
    }
}
