// OnsetDetector — feature 048 (A06-P02) T-A06-203; FR-A06-203, SC-A06-203.
// Research D4; contract specs/048-ml-p02-feature-analysis/contracts/api.md.

/// An adaptive-threshold onset detector over a stream of spectral-flux values.
///
/// For each ``update(flux:time:)`` the threshold is ``multiple`` times the mean of the previous fluxes in the
/// history (at most ``historyCount`` of them; the mean is 0 while the history is empty) plus ``minimum``. An onset is
/// reported when the flux exceeds the threshold and either no onset was reported yet or at least
/// ``minimumInterval`` seconds passed since the last one. The current flux joins the history after the decision.
///
/// The history is a fixed ring allocated in `init`; ``update(flux:time:)`` never allocates. Non-finite fluxes are
/// treated as 0.
public struct OnsetDetector: Sendable {
    /// Number of previous fluxes the adaptive mean covers (at least 1).
    public let historyCount: Int
    /// Factor applied to the mean of the history.
    public let multiple: Float
    /// Constant added to the threshold so that silence never triggers.
    public let minimum: Float
    /// Shortest time in seconds between two reported onsets.
    public let minimumInterval: Double

    private var history: [Float]
    private var head = 0
    private var filled = 0
    private var sum: Double = 0
    private var lastOnset: Double?

    /// Creates a detector with an empty history and no previous onset.
    ///
    /// - Parameters:
    ///   - historyCount: number of previous fluxes averaged; clamped to at least 1. Default 43.
    ///   - multiple: factor on the mean flux. Default 1.5.
    ///   - minimum: constant added to the threshold. Default 1e-4.
    ///   - minimumInterval: seconds between onsets; negative or non-finite values become 0. Default 0.1.
    public init(historyCount: Int = 43, multiple: Float = 1.5, minimum: Float = 1e-4, minimumInterval: Double = 0.1) {
        let count = max(historyCount, 1)
        self.historyCount = count
        self.multiple = multiple
        self.minimum = minimum
        self.minimumInterval = minimumInterval.isFinite ? max(minimumInterval, 0) : 0
        self.history = [Float](repeating: 0, count: count)
    }

    /// Feeds one flux value and reports whether it is an onset.
    ///
    /// - Parameters:
    ///   - flux: the spectral flux of the current window; non-finite values are treated as 0.
    ///   - time: the timestamp of the window in seconds, used for the minimum interval.
    /// - Returns: `true` when the flux exceeds the adaptive threshold outside the minimum interval.
    public mutating func update(flux: Float, time: Double) -> Bool {
        let current: Float = flux.isFinite ? flux : 0
        let mean: Float = filled > 0 ? Float(sum / Double(filled)) : 0
        let threshold = multiple * mean + minimum
        var onset = current > threshold
        if onset, let last = lastOnset, time - last < minimumInterval {
            onset = false
        }
        if onset { lastOnset = time }

        if filled == historyCount {
            sum -= Double(history[head])
        } else {
            filled += 1
        }
        history[head] = current
        sum += Double(current)
        head = (head + 1) % historyCount
        if filled == historyCount && head == 0 {
            // Recompute once per lap to keep rounding drift of the running sum bounded.
            sum = history.reduce(0) { $0 + Double($1) }
        }
        return onset
    }

    /// Clears the history and forgets the last onset.
    public mutating func reset() {
        for index in history.indices { history[index] = 0 }
        head = 0
        filled = 0
        sum = 0
        lastOnset = nil
    }
}
