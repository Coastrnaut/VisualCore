// WaveKnotKeeperLights — feature 326 (R02-G03-06) T-R02G0306-003 (FR-R02G0306-004; clarification Q3; research R3, R4).
// The presenter's eased light levels: one per crossing mark, keyed by its two segment indices (target 1 while the mark is
// in the snapshot, 0 once it is gone), the target match (target 1 while the summary is not degenerate and its crossings
// and writhe equal the target's, else 0) and the win glow (target 1 while the play is won, else 0). Each level moves
// linearly toward its target in presentation time, across its whole range in 0.15 s normally and 0.45 s under Reduce
// Flashing, so no light switches in one frame. Under Reduce Flashing a level that has started moving finishes the move to
// the value it is heading for before it may turn back (feature 316's rule), so a target that flickers faster than the
// fade cannot make a level hover and blink around half its range. Each crossing light remembers its mark's over-strand
// segment and the fraction along that segment (0 … 1) where the mark lies, updated from every snapshot in which the mark
// is present; a mark that disappears after a move fades out at that fraction of the same (moved) segment, and a mark
// that appears fades in at its drawn crossing point. A crossing level at 0 whose target is 0 is dropped. A new level
// (another level number or point count) settles the lights at once. The state and the digest never see these levels;
// they are presentation only and pure.

/// The eased light levels of Wave Knot Keeper's crossing marks, target match and win glow (presentation only).
public struct WaveKnotKeeperLights: Sendable, Equatable {
    /// A crossing mark's identity: its two segment indices, `first < second` as in ``WaveKnotKeeperCrossingMark``.
    public struct Key: Sendable, Hashable {
        /// The lower segment index.
        public let first: Int
        /// The higher segment index.
        public let second: Int

        /// A key of the given segment indices (not checked).
        public init(first: Int, second: Int) {
            self.first = first
            self.second = second
        }

        /// The key of `mark`.
        init(_ mark: WaveKnotKeeperCrossingMark) {
            self.init(first: mark.first, second: mark.second)
        }
    }

    /// One crossing light: its eased level and where its mark lies on the rope.
    public struct Crossing: Sendable, Equatable {
        /// The eased level 0 … 1.
        public let level: Double
        /// The over-strand segment of the mark (the last one seen while the mark was present).
        public let over: Int
        /// The fraction 0 … 1 along segment `over` where the mark lies (the last one seen while it was present).
        public let fraction: Double

        /// A crossing light of the given values (not checked).
        public init(level: Double, over: Int, fraction: Double) {
            self.level = level
            self.over = over
            self.fraction = fraction
        }
    }

    /// The time a level takes to move across its whole range normally, in seconds.
    public static let normalDuration = 0.15
    /// The time a level takes to move across its whole range under Reduce Flashing, in seconds.
    public static let reducedFlashDuration = 0.45

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The crossing lights by mark key: present marks and marks still fading out.
    public private(set) var crossings: [Key: Crossing]
    /// The target-match level 0 … 1.
    public private(set) var match: Double
    /// The win glow 0 … 1.
    public private(set) var glow: Double

    /// The value each crossing level is heading for; under Reduce Flashing it changes only when the level has reached it.
    private var crossingHeadings: [Key: Double]
    /// The value the match level is heading for.
    private var matchHeading: Double
    /// The value the glow is heading for.
    private var glowHeading: Double
    /// The marks present in the last snapshot (target 1).
    private var present: Set<Key>
    /// The match target of the last snapshot.
    private var matchTarget: Double
    /// The glow target of the last snapshot.
    private var glowTarget: Double
    /// The level number of the last snapshot; nil before the first.
    private var ropeLevel: Int?
    /// The point count of the last snapshot.
    private var ropePoints: Int

    /// Dark lights (no crossings, match and glow 0) with the fade speed for `reducedFlash`; the first ``settle(to:)``
    /// or ``step(toward:elapsed:)`` settles them to its snapshot.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        crossings = [:]
        match = 0
        glow = 0
        crossingHeadings = [:]
        matchHeading = 0
        glowHeading = 0
        present = []
        matchTarget = 0
        glowTarget = 0
        ropeLevel = nil
        ropePoints = 0
    }

    /// The time a level takes to cross its whole range with the current setting, in seconds.
    var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// Whether every level is at the target of the last snapshot (no mark fading in or out, match and glow at rest).
    public var isSettled: Bool {
        guard match == matchTarget, glow == glowTarget, matchHeading == matchTarget, glowHeading == glowTarget else {
            return false
        }
        for (key, light) in crossings {
            let target: Double = present.contains(key) ? 1 : 0
            if light.level != target || crossingHeadings[key] != target { return false }
        }
        return present.allSatisfy { crossings[$0] != nil }
    }

    /// The match target of `snapshot`: 1 while its summary is not degenerate and its crossings and writhe equal the
    /// target's, else 0.
    static func matchTarget(_ snapshot: WaveKnotKeeperSceneSnapshot) -> Double {
        snapshot.matchesTarget ? 1 : 0
    }

    /// The glow target of `snapshot`: 1 when the stage is `won`, else 0.
    static func glowTarget(_ snapshot: WaveKnotKeeperSceneSnapshot) -> Double {
        snapshot.stage == .won ? 1 : 0
    }

    /// The fraction 0 … 1 along `mark`'s over-strand segment where it lies in `snapshot`'s rope; nil when the segment is
    /// unusable (the caller then keeps the last fraction, or 0.5 for a new mark).
    static func fraction(of mark: WaveKnotKeeperCrossingMark, in snapshot: WaveKnotKeeperSceneSnapshot) -> Double? {
        WaveKnotKeeperSceneGeometry.crossingParameter(mark, points: snapshot.points)
    }

    /// Moves every level toward its target by `elapsed / duration` (at most to the target); a negative or non-finite
    /// `elapsed` counts as 0. Present marks update their over segment and fraction; absent marks keep theirs while they
    /// fade out and are dropped at 0. Under Reduce Flashing a level mid-fade keeps heading for the value it started
    /// toward. A snapshot of another level number or point count (or the first snapshot) settles instead.
    public mutating func step(toward snapshot: WaveKnotKeeperSceneSnapshot, elapsed: Double) {
        guard ropeLevel == snapshot.levelNumber, ropePoints == snapshot.points.count else {
            settle(to: snapshot)
            return
        }
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let delta: Double = time / duration
        var marks: [Key: WaveKnotKeeperCrossingMark] = [:]
        for mark in snapshot.crossings { marks[Key(mark)] = mark }
        var keys: Set<Key> = Set(crossings.keys)
        keys.formUnion(marks.keys)
        var nextCrossings: [Key: Crossing] = [:]
        var nextHeadings: [Key: Double] = [:]
        for key in keys {
            let old: Crossing? = crossings[key]
            let target: Double = marks[key] == nil ? 0 : 1
            var heading: Double = crossingHeadings[key] ?? 0
            let (level, newHeading) = advance(old?.level ?? 0, heading: heading, target: target, delta: delta)
            heading = newHeading
            if level == 0 && target == 0 && heading == 0 { continue }
            var over: Int = old?.over ?? 0
            var fraction: Double = old?.fraction ?? 0.5
            if let mark = marks[key] {
                over = mark.over
                fraction = Self.fraction(of: mark, in: snapshot) ?? fraction
            }
            nextCrossings[key] = Crossing(level: level, over: over, fraction: fraction)
            nextHeadings[key] = heading
        }
        crossings = nextCrossings
        crossingHeadings = nextHeadings
        present = Set(marks.keys)
        matchTarget = Self.matchTarget(snapshot)
        glowTarget = Self.glowTarget(snapshot)
        (match, matchHeading) = advance(match, heading: matchHeading, target: matchTarget, delta: delta)
        (glow, glowHeading) = advance(glow, heading: glowHeading, target: glowTarget, delta: delta)
    }

    /// Jumps every level to its target for `snapshot` (present marks 1, every other mark dropped; match and glow at
    /// their targets): used for the first frame and a new level, so the scene does not fade in from dark.
    public mutating func settle(to snapshot: WaveKnotKeeperSceneSnapshot) {
        var nextCrossings: [Key: Crossing] = [:]
        var nextHeadings: [Key: Double] = [:]
        for mark in snapshot.crossings {
            let key: Key = Key(mark)
            nextCrossings[key] = Crossing(level: 1, over: mark.over, fraction: Self.fraction(of: mark, in: snapshot) ?? 0.5)
            nextHeadings[key] = 1
        }
        crossings = nextCrossings
        crossingHeadings = nextHeadings
        present = Set(nextCrossings.keys)
        matchTarget = Self.matchTarget(snapshot)
        glowTarget = Self.glowTarget(snapshot)
        match = matchTarget
        matchHeading = matchTarget
        glow = glowTarget
        glowHeading = glowTarget
        ropeLevel = snapshot.levelNumber
        ropePoints = snapshot.points.count
    }

    /// One level's move toward `target`: the heading follows the target unless Reduce Flashing holds a started fade,
    /// then the level moves at most `delta` toward the heading, clamped to 0 … 1.
    private func advance(_ level: Double, heading: Double, target: Double, delta: Double) -> (Double, Double) {
        var heading: Double = heading
        if !reducedFlash || level == heading { heading = target }
        if abs(heading - level) <= delta { return (heading, heading) }
        return (min(max(level + (heading > level ? delta : -delta), 0), 1), heading)
    }

    /// The largest number of times any one element crosses half its range (0.5) within a one-second window.
    ///
    /// `samples` holds one vector of levels per frame, taken every `1 / frameRate` seconds. A crossing is a strict pass
    /// through 0.5: the level's side (below or above 0.5) changes, a level of exactly 0.5 keeping the side it came from.
    /// For each element the crossings are counted in every window of `frameRate` (rounded, at least 1) consecutive steps —
    /// the whole run when it is shorter — and the largest count over elements and windows is returned. Fewer than two
    /// samples give 0; only the elements present in every sample are measured.
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double {
        guard samples.count >= 2 else { return 0 }
        let window: Int = frameRate.isFinite ? max(Int(frameRate.rounded()), 1) : 1
        let width: Int = samples.map(\.count).min() ?? 0
        var best: Int = 0
        for element in 0..<width {
            var flags: [Int] = []
            flags.reserveCapacity(samples.count - 1)
            var side: Int = samples[0][element] > 0.5 ? 1 : (samples[0][element] < 0.5 ? -1 : 0)
            for frame in 1..<samples.count {
                let value: Double = samples[frame][element]
                let now: Int = value > 0.5 ? 1 : (value < 0.5 ? -1 : side)
                flags.append(side != 0 && now != side ? 1 : 0)
                if now != 0 { side = now }
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
    static func shortestHalfRangeChange(_ samples: [[Double]], frameRate: Double) -> Double {
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
