// AuroraLoomLights — feature 306 (R02-G01-06) T-R02G0106-004 (FR-R02G0106-004; clarification Q3; research R3). The
// presenter's eased light levels: one per gate crossing (ribbon × 4 + gate, 12 in all) and the win glow. Each level
// moves linearly toward its target (1 when the snapshot shows the crossing lit or the play won, else 0) in presentation
// time, over 0.15 s normally and 0.45 s under Reduce Flashing, so no light ever switches in one frame. Under Reduce
// Flashing a level that has started a fade also finishes it before it may turn back (it commits to the end it is
// heading for), so a target that flickers faster than the fade cannot make a level hover and blink around half its
// range: two crossings of half the range are then at least one full fade (0.45 s) apart, at most 3 per second. The
// state and the digest never see these levels; they are presentation only and pure.

/// The eased light levels of Aurora Loom's 12 gate crossings and its win glow (presentation only).
public struct AuroraLoomLights: Sendable, Equatable {
    /// The time a level takes to move across its whole range normally, in seconds.
    public static let normalDuration = 0.15
    /// The time a level takes to move across its whole range under Reduce Flashing, in seconds.
    public static let reducedFlashDuration = 0.45
    /// The number of crossing levels: 3 ribbons × 4 gates.
    public static let crossingCount = 12

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The crossing levels 0 … 1, index `ribbon * 4 + gate`.
    public private(set) var crossings: [Double]
    /// The win glow 0 … 1 (target 1 while the snapshot's stage is `won`).
    public private(set) var glow: Double
    /// The end (0 or 1) each level is heading for: the 12 crossings, then the glow. Under Reduce Flashing it changes
    /// only when the level has reached it.
    private var headings: [Double]

    /// Dark lights (every level 0) with the fade speed for `reducedFlash`.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        crossings = Array(repeating: 0, count: Self.crossingCount)
        glow = 0
        headings = Array(repeating: 0, count: Self.crossingCount + 1)
    }

    /// The time a level takes to cross its whole range with the current setting, in seconds.
    public var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// The crossing levels followed by the glow (13 values), as a sample for the measures below.
    public var levels: [Double] { crossings + [glow] }

    /// The targets `snapshot` asks for: the 12 crossings (1 lit, 0 dark), then the glow (1 when won, else 0).
    public static func targets(of snapshot: AuroraLoomSceneSnapshot) -> [Double] {
        var result: [Double] = []
        result.reserveCapacity(crossingCount + 1)
        for ribbon in 0..<3 {
            for gate in 0..<4 {
                result.append(snapshot.lit(ribbon: ribbon, gate: gate) ? 1 : 0)
            }
        }
        result.append(snapshot.stage == .won ? 1 : 0)
        return result
    }

    /// Moves every level toward its target by `elapsed / duration` (at most to the target); a negative or non-finite
    /// `elapsed` counts as 0. Under Reduce Flashing a level mid-fade keeps heading for the end it started toward.
    public mutating func step(toward snapshot: AuroraLoomSceneSnapshot, elapsed: Double) {
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let delta: Double = time / duration
        let targets: [Double] = Self.targets(of: snapshot)
        var current: [Double] = levels
        for index in 0..<current.count {
            let level: Double = current[index]
            if !reducedFlash || level == headings[index] {
                headings[index] = targets[index]
            }
            let heading: Double = headings[index]
            if abs(heading - level) <= delta {
                current[index] = heading
            } else {
                current[index] = min(max(level + (heading > level ? delta : -delta), 0), 1)
            }
        }
        store(current)
    }

    /// Jumps every level to its target (used for the first frame only, so the scene does not fade in from dark).
    public mutating func settle(to snapshot: AuroraLoomSceneSnapshot) {
        let targets: [Double] = Self.targets(of: snapshot)
        headings = targets
        store(targets)
    }

    private mutating func store(_ values: [Double]) {
        crossings = Array(values[0..<Self.crossingCount])
        glow = values[Self.crossingCount]
    }

    /// The largest number of times any one element crosses half its range (0.5) within a one-second window.
    ///
    /// `samples` holds one vector of levels per frame, taken every `1 / frameRate` seconds. A crossing is a step from
    /// one frame to the next where the level goes from below 0.5 to 0.5 or above, or back. For each element the
    /// crossings are counted in every window of `frameRate` (rounded, at least 1) consecutive steps — the whole run when
    /// it is shorter — and the largest count over elements and windows is returned. Empty input gives 0.
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double {
        guard samples.count >= 2 else { return 0 }
        let window: Int = frameRate.isFinite ? max(Int(frameRate.rounded()), 1) : 1
        let width: Int = samples.map(\.count).min() ?? 0
        var best: Int = 0
        for element in 0..<width {
            var flags: [Int] = []
            flags.reserveCapacity(samples.count - 1)
            for frame in 1..<samples.count {
                let before: Bool = samples[frame - 1][element] >= 0.5
                let after: Bool = samples[frame][element] >= 0.5
                flags.append(before != after ? 1 : 0)
            }
            var count: Int = 0
            for index in 0..<flags.count {
                count += flags[index]
                if index >= window { count -= flags[index - window] }
                best = max(best, count)
            }
        }
        return Double(best)
    }

    /// The shortest time, in seconds, that any element takes for a change of more than half its range.
    ///
    /// Each element's samples are split into fades: maximal runs of consecutive frame steps that all move the level the
    /// same way (a step of no change ends a run). A fade whose total change exceeds 0.5 counts, and its time is its
    /// number of steps divided by `frameRate`. A fade still moving at the last sample is unfinished and is skipped.
    /// Returns `.infinity` when no element makes such a change (or the frame rate is not positive and finite).
    public static func shortestHalfRangeChange(_ samples: [[Double]], frameRate: Double) -> Double {
        guard samples.count >= 2, frameRate.isFinite, frameRate > 0 else { return .infinity }
        let width: Int = samples.map(\.count).min() ?? 0
        var shortest: Double = .infinity
        for element in 0..<width {
            var direction: Int = 0
            var start: Double = samples[0][element]
            var steps: Int = 0
            for frame in 1..<samples.count {
                let before: Double = samples[frame - 1][element]
                let after: Double = samples[frame][element]
                let sign: Int = after > before ? 1 : (after < before ? -1 : 0)
                if sign != direction {
                    if direction != 0 && abs(before - start) > 0.5 {
                        shortest = min(shortest, Double(steps) / frameRate)
                    }
                    direction = sign
                    start = before
                    steps = 0
                }
                if sign != 0 { steps += 1 }
            }
        }
        return shortest
    }
}
