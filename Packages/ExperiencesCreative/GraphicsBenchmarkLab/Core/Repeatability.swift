// Repeatability — feature 177 (A24-P05) T-A24-503 (FR-A24-503; clarification Q3; data-model.md
// "RepeatabilitySummary"; contracts/review.md). Compares the run the person opened with the other saved runs (the
// opened run included, each with its save order). A trial is comparable when its case fingerprint equals the opened
// run's (else `different-case`), its report's device model, OS version, app build and quality tier equal the opened
// run's (else the first that differs, in that order; a missing report on either side is `different-device`) and it
// is not invalid (``RunQualification``; else `invalid`). The summary lists the comparable trials by save order with
// their interval p50 and p95 and GPU p50, the trials that are not comparable with their reason, and the spread
// (largest minus smallest) of the interval p50 and p95 when at least two comparable trials have the value; the GPU
// p50 spread only when every comparable trial has a GPU p50 and there are at least two. Pure Swift; no UI, GPU,
// file or clock.

/// Why a trial cannot be compared with the opened run. The raw values are the codes of clarification Q3.
public enum NotComparableReason: String, Sendable {
    /// The trial ran another case (or another version of it): its case fingerprint differs.
    case differentCase = "different-case"
    /// The trial ran on another device model, or one of the two runs has no report.
    case differentDevice = "different-device"
    /// The trial ran on another OS version.
    case differentOS = "different-os"
    /// The trial ran another app build.
    case differentBuild = "different-build"
    /// The trial ran at another quality tier.
    case differentTier = "different-tier"
    /// The trial is invalid (``QualificationClass/invalid``).
    case invalid
}

/// A saved run with its save order (the order the person saved it in).
public struct OrderedRun: Equatable, Sendable {
    /// The save order: a lower order was saved earlier.
    public var order: Int
    /// The run.
    public var run: BenchmarkRun

    /// The run `run` saved at `order`.
    public init(order: Int, run: BenchmarkRun) {
        self.order = order
        self.run = run
    }
}

/// One comparable trial: its save order and the numbers that are compared.
public struct Trial: Equatable, Sendable {
    /// The save order of the trial.
    public var order: Int
    /// The frame interval p50 in milliseconds, or nil when absent.
    public var intervalP50: Double?
    /// The frame interval p95 in milliseconds, or nil when absent (fewer than 20 intervals).
    public var intervalP95: Double?
    /// The GPU time p50 in milliseconds, or nil when the trial has no GPU distribution.
    public var gpuP50: Double?

    /// A trial at `order` with the given values.
    public init(order: Int, intervalP50: Double?, intervalP95: Double?, gpuP50: Double?) {
        self.order = order
        self.intervalP50 = intervalP50
        self.intervalP95 = intervalP95
        self.gpuP50 = gpuP50
    }
}

/// A trial that cannot be compared with the opened run, and why.
public struct NotComparableTrial: Equatable, Sendable {
    /// The save order of the trial.
    public var order: Int
    /// Why it cannot be compared.
    public var reason: NotComparableReason

    /// The trial at `order`, not comparable for `reason`.
    public init(order: Int, reason: NotComparableReason) {
        self.order = order
        self.reason = reason
    }
}

/// The repeatability of the opened run among the saved runs.
public struct RepeatabilitySummary: Equatable, Sendable {
    /// The comparable trials, by save order (the opened run included when it is not invalid).
    public var comparable: [Trial]
    /// The trials that are not comparable, by save order, with their reason.
    public var notComparable: [NotComparableTrial]
    /// The largest minus the smallest interval p50, in milliseconds; nil with fewer than two values.
    public var spreadP50Ms: Double?
    /// The largest minus the smallest interval p95, in milliseconds; nil with fewer than two values.
    public var spreadP95Ms: Double?
    /// The largest minus the smallest GPU p50, in milliseconds; nil unless every comparable trial has a GPU p50 and
    /// there are at least two.
    public var spreadGPUP50Ms: Double?

    /// A summary with the given values (not checked).
    public init(comparable: [Trial], notComparable: [NotComparableTrial], spreadP50Ms: Double?, spreadP95Ms: Double?,
                spreadGPUP50Ms: Double?) {
        self.comparable = comparable
        self.notComparable = notComparable
        self.spreadP50Ms = spreadP50Ms
        self.spreadP95Ms = spreadP95Ms
        self.spreadGPUP50Ms = spreadGPUP50Ms
    }
}

/// Compares saved trials of a case (clarification Q3).
public enum Repeatability {
    /// The repeatability of `opened` among `among`. `opened` is included even when `among` does not list it; an
    /// entry of `among` with the same order as `opened` is taken to be the opened run and not counted twice.
    public static func summarise(opened: OrderedRun, among: [OrderedRun]) -> RepeatabilitySummary {
        var all: [OrderedRun] = [opened]
        for entry in among where entry.order != opened.order { all.append(entry) }
        all.sort { $0.order < $1.order }
        var comparable: [Trial] = []
        var notComparable: [NotComparableTrial] = []
        for entry in all {
            if let reason = reason(entry.run, against: opened.run) {
                notComparable.append(NotComparableTrial(order: entry.order, reason: reason))
            } else {
                let summary = entry.run.summary
                comparable.append(Trial(order: entry.order, intervalP50: summary.interval.p50,
                                        intervalP95: summary.interval.p95, gpuP50: summary.gpu?.p50))
            }
        }
        var p50s: [Double] = []
        var p95s: [Double] = []
        var gpus: [Double] = []
        var everyGPU = true
        for trial in comparable {
            if let value = trial.intervalP50 { p50s.append(value) }
            if let value = trial.intervalP95 { p95s.append(value) }
            if let value = trial.gpuP50 { gpus.append(value) } else { everyGPU = false }
        }
        return RepeatabilitySummary(comparable: comparable, notComparable: notComparable, spreadP50Ms: spread(p50s),
                                    spreadP95Ms: spread(p95s), spreadGPUP50Ms: everyGPU ? spread(gpus) : nil)
    }

    /// Why `run` cannot be compared with `opened`, or nil when it can (see the file header for the order).
    public static func reason(_ run: BenchmarkRun, against opened: BenchmarkRun) -> NotComparableReason? {
        if run.caseFingerprint != opened.caseFingerprint { return .differentCase }
        guard let report = run.report, let reference = opened.report else { return .differentDevice }
        if report.deviceModel != reference.deviceModel { return .differentDevice }
        if report.osVersion != reference.osVersion { return .differentOS }
        if report.appBuild != reference.appBuild { return .differentBuild }
        if report.qualityTier != reference.qualityTier { return .differentTier }
        if RunQualification.qualify(run).class == .invalid { return .invalid }
        return nil
    }

    /// The largest minus the smallest of `values`, or nil with fewer than two.
    private static func spread(_ values: [Double]) -> Double? {
        guard values.count >= 2, var low = values.first, var high = values.first else { return nil }
        for value in values {
            if value < low { low = value }
            if value > high { high = value }
        }
        return high - low
    }
}
