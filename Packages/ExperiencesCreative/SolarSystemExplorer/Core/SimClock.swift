// SimClock — feature 106 (A14-P04) T-A14-404 (FR-A14-401, FR-A14-402; SC-A14-401, SC-A14-402; clarification Q1;
// data-model "SimClock"). The simulated clock of Solar System Explorer: while time plays, each host step (1/120 s)
// adds rate / 120 days, where the rate is one of 1, 7, 30 or 365 simulated days per second ("1 day/s", "1 week/s",
// "1 month/s", "1 year/s"). N steps from a day offset add rate × N / 120 days (exactly up to `Double` rounding, far
// below 1e-9 days for the runs used). A step that would leave `SimulatedDate.range` clamps to the end it reached and
// reports `stopped` (the caller then pauses and records `endOfRange`, spoken `stopSentence`); a step from a day
// already at the end in the direction of motion (rates are positive, so the upper end) also stops there. An invalid
// rate index moves nothing and does not stop; a non-finite day offset moves nothing and stops. Pure and host-free:
// the clock never reads the wall clock, so replays are deterministic.
import Foundation

/// The simulated clock's rates and its one-step advance.
public enum SimClock {
    /// The rates in simulated days per simulated second, indexed by `rateIndex`.
    public static let rates: [Double] = [1, 7, 30, 365]
    /// The words of each rate, in ``rates`` order.
    public static let rateLabels: [String] = ["1 day/s", "1 week/s", "1 month/s", "1 year/s"]
    /// The duration of one host step in seconds (1/120).
    public static let stepSeconds: Double = 1.0 / 120
    /// The host steps per second (120).
    public static let stepsPerSecond: Double = 120
    /// The stop reason recorded when the clock reaches an end of the model's range.
    public static let endOfRange = "end-of-range"
    /// The sentence spoken when the clock stops at an end of the model's range.
    public static let stopSentence = "The model's range ends here"

    /// The days one host step adds at `rateIndex` (rate / 120), or nil for an index outside ``rates``.
    public static func daysPerStep(rateIndex: Int) -> Double? {
        guard rates.indices.contains(rateIndex) else { return nil }
        return rates[rateIndex] / stepsPerSecond
    }

    /// `dayOffset` advanced by one host step at `rateIndex`, clamped into ``SimulatedDate/range``; `stopped` is true
    /// when the step reached or passed an end (or started at the end in the direction of motion). An invalid rate
    /// index returns `dayOffset` unchanged and not stopped; a non-finite `dayOffset` returns it unchanged and stopped.
    public static func advance(dayOffset: Double, rateIndex: Int) -> (dayOffset: Double, stopped: Bool) {
        guard let delta = daysPerStep(rateIndex: rateIndex) else { return (dayOffset, false) }
        guard dayOffset.isFinite else { return (dayOffset, true) }
        let range = SimulatedDate.range
        let next = dayOffset + delta
        if next >= range.upperBound { return (range.upperBound, true) }
        if next <= range.lowerBound { return (range.lowerBound, true) }
        return (next, false)
    }
}
