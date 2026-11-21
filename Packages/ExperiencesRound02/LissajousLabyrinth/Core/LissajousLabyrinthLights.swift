// LissajousLabyrinthLights — feature 316 (R02-G02-06) T-R02G0206-003 (FR-R02G0206-004; clarification Q3; research R3).
// The presenter's eased light levels: one per checkpoint (target 1 visited in order, 0.5 the next one, else 0), one per
// obstacle (target 1 while it is the obstacle the lap first touches, else 0) and the win glow (target 1 while the play is
// won, else 0). Each level moves linearly toward its target in presentation time, across its whole range in 0.15 s
// normally and 0.45 s under Reduce Flashing, so no light ever switches in one frame. Under Reduce Flashing a level that
// has started moving also finishes the move to the value it is heading for before it may turn back, so a target that
// flickers faster than the fade cannot make a level hover and blink around half its range: two crossings of half the
// range are then at least one full fade (0.45 s × the distance) apart, at most 3 per second. When the level's checkpoint
// or obstacle count changes (a new level) the lights jump to the new targets. The state and the digest never see these
// levels; they are presentation only and pure.

/// The eased light levels of Lissajous Labyrinth's checkpoints, obstacles and win glow (presentation only).
public struct LissajousLabyrinthLights: Sendable, Equatable {
    /// The time a level takes to move across its whole range normally, in seconds.
    public static let normalDuration = 0.15
    /// The time a level takes to move across its whole range under Reduce Flashing, in seconds.
    public static let reducedFlashDuration = 0.45

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The checkpoint levels 0 … 1, in the level's checkpoint order.
    public private(set) var checkpoints: [Double]
    /// The obstacle levels 0 … 1, in the level's obstacle order.
    public private(set) var obstacles: [Double]
    /// The win glow 0 … 1.
    public private(set) var glow: Double
    /// The value each level is heading for: the checkpoints, the obstacles, then the glow. Under Reduce Flashing it
    /// changes only when the level has reached it.
    private var headings: [Double]

    /// Dark lights (no checkpoints or obstacles yet, glow 0) with the fade speed for `reducedFlash`; the first
    /// ``settle(to:)`` or ``step(toward:elapsed:)`` sizes them to the level.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        checkpoints = []
        obstacles = []
        glow = 0
        headings = [0]
    }

    /// The time a level takes to cross its whole range with the current setting, in seconds.
    public var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// The checkpoint levels, then the obstacle levels, then the glow, as one sample for the measures below.
    public var levels: [Double] { checkpoints + obstacles + [glow] }

    /// The targets `snapshot` asks for: per checkpoint 1 when visited in order, 0.5 for the next one, else 0; per
    /// obstacle 1 when it is the lap's contact obstacle, else 0; the glow 1 when the stage is `won`, else 0.
    public static func targets(_ snapshot: LissajousLabyrinthSceneSnapshot)
        -> (checkpoints: [Double], obstacles: [Double], glow: Double) {
        let next: Int? = snapshot.nextCheckpoint
        var checkpointTargets: [Double] = []
        checkpointTargets.reserveCapacity(snapshot.level.checkpoints.count)
        for index in 0..<snapshot.level.checkpoints.count {
            if snapshot.visited(index) {
                checkpointTargets.append(1)
            } else if index == next {
                checkpointTargets.append(0.5)
            } else {
                checkpointTargets.append(0)
            }
        }
        let contact: Int? = snapshot.contactObstacle
        var obstacleTargets: [Double] = []
        obstacleTargets.reserveCapacity(snapshot.level.obstacles.count)
        for index in 0..<snapshot.level.obstacles.count {
            obstacleTargets.append(index == contact ? 1 : 0)
        }
        return (checkpointTargets, obstacleTargets, snapshot.stage == .won ? 1 : 0)
    }

    /// Moves every level toward its target by `elapsed / duration` (at most to the target); a negative or non-finite
    /// `elapsed` counts as 0. Under Reduce Flashing a level mid-fade keeps heading for the value it started toward. When
    /// the snapshot's checkpoint or obstacle count differs from the current one, the lights settle instead.
    public mutating func step(toward snapshot: LissajousLabyrinthSceneSnapshot, elapsed: Double) {
        let wanted = Self.targets(snapshot)
        guard wanted.checkpoints.count == checkpoints.count, wanted.obstacles.count == obstacles.count else {
            settle(to: snapshot)
            return
        }
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let delta: Double = time / duration
        let targets: [Double] = wanted.checkpoints + wanted.obstacles + [wanted.glow]
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
        store(current, checkpointCount: checkpoints.count, obstacleCount: obstacles.count)
    }

    /// Jumps every level to its target and sizes the lights to the snapshot's level (used for the first frame, so the
    /// scene does not fade in from dark).
    public mutating func settle(to snapshot: LissajousLabyrinthSceneSnapshot) {
        let wanted = Self.targets(snapshot)
        let values: [Double] = wanted.checkpoints + wanted.obstacles + [wanted.glow]
        headings = values
        store(values, checkpointCount: wanted.checkpoints.count, obstacleCount: wanted.obstacles.count)
    }

    private mutating func store(_ values: [Double], checkpointCount: Int, obstacleCount: Int) {
        checkpoints = Array(values[0..<checkpointCount])
        obstacles = Array(values[checkpointCount..<(checkpointCount + obstacleCount)])
        glow = values[checkpointCount + obstacleCount]
    }

    /// The largest number of times any one element crosses half its range (0.5) within a one-second window.
    ///
    /// `samples` holds one vector of levels per frame, taken every `1 / frameRate` seconds. A crossing is a step from
    /// one frame to the next where the level goes from below 0.5 to 0.5 or above, or back. For each element the
    /// crossings are counted in every window of `frameRate` (rounded, at least 1) consecutive steps — the whole run when
    /// it is shorter — and the largest count over elements and windows is returned. Fewer than two samples give 0;
    /// only the elements present in every sample are measured.
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

    /// The shortest time, in seconds, that any element takes for a complete one-way change of more than half its range.
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
