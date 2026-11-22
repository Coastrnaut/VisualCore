// ChronoConstellatorLights — feature 356 (R02-G06-06) T-R02G0606-003 (FR-R02G0606-004; SC-R02G0606-003; clarification
// Q3). The presenter's eased light levels: one target ring per star (target 1 while that star stands on its target, 0.5
// otherwise), one star node per star (target 1 on its target, 0.7 off it), the win glow (target 1 while the play is
// won, else 0) and the collision mark (target 1 while the play's failure is a collision, else 0).
//
// Each level moves linearly toward its target in presentation time, and every fade, from the level where it starts to
// the value it heads for, takes exactly the duration: 0.15 s normally and 0.45 s under Reduce Flashing (feature 346's
// rule: with a fixed fade time every fade of more than half an element's range lasts 0.45 s ≥ 0.4 s, and a level
// crosses the middle of its range at most once per fade). Normally the heading follows the target at once, starting a
// new fade from where the level is, so a target is reached within 0.15 s of its last change. Under Reduce Flashing a
// level that has started moving finishes the fade to the value it is heading for before it may turn back, so a target
// that flickers faster than the fade cannot make a level blink. A new level number or a change of the star count (or
// the first snapshot) settles the lights at once, resizing the ring and node arrays; a retry of the same level fades.
// The state and the digest never see these levels; they are presentation only and pure.

/// The eased light levels of Chrono Constellator's target rings, star nodes, win glow and collision mark (presentation
/// only).
public struct ChronoConstellatorLights: Sendable, Equatable {
    /// One linear fade: the level it started at, the value it heads for and the share of the duration done.
    struct Fade: Sendable, Equatable {
        /// The level when the fade began.
        var start: Double
        /// The value the fade heads for.
        var heading: Double
        /// The share of the duration elapsed, 0 … 1 (1: done, the level is the heading).
        var progress: Double

        /// A finished fade resting at `value`.
        static func resting(_ value: Double) -> Fade { Fade(start: value, heading: value, progress: 1) }

        /// Whether the fade has finished (within a rounding tolerance).
        var isDone: Bool { progress >= 1 - ChronoConstellatorLights.tolerance }

        /// The current level: the heading once done, else the linear mix of start and heading, clamped to 0 … 1.
        var level: Double {
            if isDone { return heading }
            return min(max(start + (heading - start) * progress, 0), 1)
        }
    }

    /// The time every fade takes normally, in seconds.
    public static let normalDuration = 0.15
    /// The time every fade takes under Reduce Flashing, in seconds.
    public static let reducedFlashDuration = 0.45
    /// A target ring's level while its star stands on it.
    public static let ringLit = 1.0
    /// A target ring's level while its star is elsewhere.
    public static let ringUnlit = 0.5
    /// A star node's level while the star stands on its target.
    public static let nodeOnTarget = 1.0
    /// A star node's level while the star is off its target.
    public static let nodeOffTarget = 0.7
    /// The rounding tolerance for a finished fade.
    static let tolerance = 1e-9

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The target ring levels, one per star in star order.
    public private(set) var rings: [Double]
    /// The star node levels, one per star in star order.
    public private(set) var nodes: [Double]
    /// The win glow 0 … 1.
    public private(set) var glow: Double
    /// The collision mark 0 … 1.
    public private(set) var collision: Double

    /// The fade of each ring.
    private var ringFades: [Fade]
    /// The fade of each node.
    private var nodeFades: [Fade]
    /// The fade of the glow.
    private var glowFade: Fade
    /// The fade of the collision mark.
    private var collisionFade: Fade
    /// The targets of the last snapshot: rings, nodes, glow and collision mark.
    private var targets: Targets
    /// The level number and star count of the last snapshot; nil before the first.
    private var shape: [Int]?

    /// The light targets of one snapshot.
    struct Targets: Sendable, Equatable {
        /// The ring targets, one per star.
        var rings: [Double]
        /// The node targets, one per star.
        var nodes: [Double]
        /// The glow target.
        var glow: Double
        /// The collision mark target.
        var collision: Double

        /// The targets of `snapshot`: a ring at ``ringLit`` and a node at ``nodeOnTarget`` for each star on its target
        /// (``ringUnlit`` and ``nodeOffTarget`` otherwise), the glow 1 when the stage is `won`, the collision mark 1
        /// when the play's failure is a collision.
        init(_ snapshot: ChronoConstellatorSceneSnapshot) {
            var rings: [Double] = []
            var nodes: [Double] = []
            rings.reserveCapacity(snapshot.stars.count)
            nodes.reserveCapacity(snapshot.stars.count)
            for star in snapshot.stars {
                rings.append(star.onTarget ? ChronoConstellatorLights.ringLit : ChronoConstellatorLights.ringUnlit)
                nodes.append(star.onTarget ? ChronoConstellatorLights.nodeOnTarget
                                           : ChronoConstellatorLights.nodeOffTarget)
            }
            self.rings = rings
            self.nodes = nodes
            glow = snapshot.stage == .won ? 1 : 0
            if case .collision = snapshot.failure {
                collision = 1
            } else {
                collision = 0
            }
        }

        /// No targets: no stars, glow and mark 0.
        init() {
            rings = []
            nodes = []
            glow = 0
            collision = 0
        }
    }

    /// Dark lights (no rings or nodes, glow and mark 0) with the fade time for `reducedFlash`; the first
    /// ``settle(to:)`` or ``step(toward:elapsed:)`` settles them to its snapshot.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        rings = []
        nodes = []
        glow = 0
        collision = 0
        ringFades = []
        nodeFades = []
        glowFade = Fade.resting(0)
        collisionFade = Fade.resting(0)
        targets = Targets()
        shape = nil
    }

    /// The time every fade takes with the current setting, in seconds.
    var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// Whether every level rests at the target of the last snapshot with no fade under way.
    public var isSettled: Bool {
        guard Self.rests(glowFade, at: targets.glow), Self.rests(collisionFade, at: targets.collision) else {
            return false
        }
        guard ringFades.count == targets.rings.count, nodeFades.count == targets.nodes.count else { return false }
        for index in ringFades.indices where !Self.rests(ringFades[index], at: targets.rings[index]) { return false }
        for index in nodeFades.indices where !Self.rests(nodeFades[index], at: targets.nodes[index]) { return false }
        return true
    }

    /// Whether `fade` has finished at `value`.
    private static func rests(_ fade: Fade, at value: Double) -> Bool { fade.isDone && fade.heading == value }

    /// The level number and star count of `snapshot`; another shape settles instead of fading.
    static func shape(_ snapshot: ChronoConstellatorSceneSnapshot) -> [Int] {
        [snapshot.levelNumber, snapshot.stars.count]
    }

    /// Moves every level toward its target by `elapsed` seconds of its fade (each fade lasts ``normalDuration`` or
    /// ``reducedFlashDuration``); a negative or non-finite `elapsed` counts as 0. Under Reduce Flashing a level
    /// mid-fade keeps heading for the value it started toward. A snapshot of another level number or star count (or the
    /// first) settles instead.
    public mutating func step(toward snapshot: ChronoConstellatorSceneSnapshot, elapsed: Double) {
        guard shape == Self.shape(snapshot) else {
            settle(to: snapshot)
            return
        }
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let share: Double = time / duration
        targets = Targets(snapshot)
        for index in ringFades.indices {
            ringFades[index] = advance(ringFades[index], target: targets.rings[index], share: share)
        }
        for index in nodeFades.indices {
            nodeFades[index] = advance(nodeFades[index], target: targets.nodes[index], share: share)
        }
        glowFade = advance(glowFade, target: targets.glow, share: share)
        collisionFade = advance(collisionFade, target: targets.collision, share: share)
        publish()
    }

    /// Jumps every level to its target for `snapshot`, resizing the rings and nodes to its star count: used for the
    /// first frame and a new level, so the scene does not fade in from dark.
    public mutating func settle(to snapshot: ChronoConstellatorSceneSnapshot) {
        targets = Targets(snapshot)
        ringFades = targets.rings.map { Fade.resting($0) }
        nodeFades = targets.nodes.map { Fade.resting($0) }
        glowFade = Fade.resting(targets.glow)
        collisionFade = Fade.resting(targets.collision)
        shape = Self.shape(snapshot)
        publish()
    }

    /// Copies the fades' current levels into the public levels.
    private mutating func publish() {
        rings = ringFades.map(\.level)
        nodes = nodeFades.map(\.level)
        glow = glowFade.level
        collision = collisionFade.level
    }

    /// One level's fade toward `target`: normally a changed target starts a new fade from the current level; under
    /// Reduce Flashing only a finished fade may take a new heading. The fade then advances by `share` of its duration.
    private func advance(_ fade: Fade, target: Double, share: Double) -> Fade {
        var next: Fade = fade
        if next.heading != target && (!reducedFlash || next.isDone) {
            let level: Double = fade.level
            next = level == target ? Fade.resting(target) : Fade(start: level, heading: target, progress: 0)
        }
        if next.isDone { return Fade.resting(next.heading) }
        next.progress = min(next.progress + share, 1)
        return next.isDone ? Fade.resting(next.heading) : next
    }

    /// The largest number of times any one element crosses half its range (0.5) within a one-second window.
    ///
    /// `samples` holds one vector of levels per frame, taken every `1 / frameRate` seconds, each element normalised to
    /// 0 … 1 over its own range. A crossing is a strict pass through 0.5: the level's side (below or above 0.5)
    /// changes, a level of exactly 0.5 keeping the side it came from. For each element the crossings are counted in
    /// every window of `frameRate` (rounded, at least 1) consecutive steps — the whole run when it is shorter — and the
    /// largest count over elements and windows is returned. Fewer than two samples give 0; only the elements present in
    /// every sample are measured.
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
    /// `samples` are normalised as for ``maxHalfRangeCrossingsPerSecond(_:frameRate:)``. Each element's samples are
    /// split into fades: maximal runs of consecutive frame steps that all move the level the same way (a step of no
    /// change ends a run). A fade whose total change exceeds 0.5 counts, and its time is its number of steps divided by
    /// `frameRate`. A fade still moving at the last sample is unfinished and is skipped. Returns `.infinity` when no
    /// element makes such a change (or the frame rate is not positive and finite).
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
