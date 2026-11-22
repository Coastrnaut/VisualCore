// AmethystEscapeLights — feature 366 (R02-G07-06) T-R02G0706-004 (FR-R02G0706-004; SC-R02G0706-003; clarification
// Q3). The presenter's eased light levels: the pearl glow (target 1 while the play has not failed, 0.6 once it has),
// the exit glow (target 0.5 normally, 1 once the pearl has escaped) and the failed wedge's amber (target 1 while the
// play's failure is a blocked wedge, else 0).
//
// Each level moves linearly toward its target in presentation time, and every fade, from the level where it starts to
// the value it heads for, takes exactly the duration: 0.15 s normally and 0.45 s under Reduce Flashing (feature 346's
// rule, as in Chrono Constellator: with a fixed fade time every fade of more than half an element's range lasts 0.45 s
// ≥ 0.4 s, and a level crosses the middle of its range at most once per fade, so at most 3 times a second). Normally
// the heading follows the target at once, starting a new fade from where the level is, so a target is reached within
// 0.15 s of its last change. Under Reduce Flashing a level that has started moving finishes the fade to the value it is
// heading for before it may turn back, so a target that flickers faster than the fade (a wedge failure undone every
// frame) cannot make a level blink. The first step (no snapshot seen yet) settles at once; afterwards every change,
// a retry or another level included, fades, because the three levels exist on every level and a jump on a level change
// could flash. `settle(to:)` jumps explicitly. The state and the digest never see these levels; they are presentation
// only and pure.

/// The eased light levels of Amethyst Escape's pearl glow, exit glow and failed-wedge amber (presentation only).
public struct AmethystEscapeLights: Sendable, Equatable {
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
        var isDone: Bool { progress >= 1 - AmethystEscapeLights.tolerance }

        /// The current level: the heading once done, else the linear mix of start and heading, clamped to 0 … 1.
        var level: Double {
            if isDone { return heading }
            return min(max(start + (heading - start) * progress, 0), 1)
        }
    }

    /// The light targets of one snapshot.
    struct Targets: Sendable, Equatable {
        /// The pearl glow target.
        var pearl: Double
        /// The exit glow target.
        var exit: Double
        /// The failed wedge's amber target.
        var wedge: Double

        /// The targets of `snapshot`: the pearl ``pearlPlaying`` unless the play failed (``pearlFailed``), the exit
        /// ``exitEscaped`` once the pearl escaped (``exitResting`` otherwise), the wedge 1 when the failure is a
        /// blocked wedge, else 0.
        init(_ snapshot: AmethystEscapeSceneSnapshot) {
            pearl = snapshot.failure == nil ? AmethystEscapeLights.pearlPlaying : AmethystEscapeLights.pearlFailed
            exit = snapshot.escaped ? AmethystEscapeLights.exitEscaped : AmethystEscapeLights.exitResting
            if case .wedge = snapshot.failure {
                wedge = 1
            } else {
                wedge = 0
            }
        }

        /// The targets of the dark lights before the first snapshot: everything 0.
        init() {
            pearl = 0
            exit = 0
            wedge = 0
        }
    }

    /// The time every fade takes normally, in seconds.
    public static let normalDuration = 0.15
    /// The time every fade takes under Reduce Flashing, in seconds.
    public static let reducedFlashDuration = 0.45
    /// The pearl glow while the play has not failed.
    public static let pearlPlaying = 1.0
    /// The pearl glow once the play has failed.
    public static let pearlFailed = 0.6
    /// The exit glow while the pearl has not escaped.
    public static let exitResting = 0.5
    /// The exit glow once the pearl has escaped.
    public static let exitEscaped = 1.0
    /// The rounding tolerance for a finished fade.
    static let tolerance = 1e-9

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The pearl glow, ``pearlFailed`` … ``pearlPlaying`` (0 before the first snapshot).
    public private(set) var pearl: Double
    /// The exit glow, ``exitResting`` … ``exitEscaped`` (0 before the first snapshot).
    public private(set) var exit: Double
    /// The failed wedge's amber, 0 … 1.
    public private(set) var wedge: Double

    /// The fade of the pearl glow.
    private var pearlFade: Fade
    /// The fade of the exit glow.
    private var exitFade: Fade
    /// The fade of the wedge amber.
    private var wedgeFade: Fade
    /// The targets of the last snapshot.
    private var targets: Targets
    /// Whether a snapshot has been seen (the first step settles).
    private var started: Bool

    /// Dark lights (every level 0) with the fade time for `reducedFlash`; the first ``settle(to:)`` or
    /// ``step(toward:elapsed:)`` settles them to its snapshot.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        pearl = 0
        exit = 0
        wedge = 0
        pearlFade = Fade.resting(0)
        exitFade = Fade.resting(0)
        wedgeFade = Fade.resting(0)
        targets = Targets()
        started = false
    }

    /// The time every fade takes with the current setting, in seconds.
    var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// Whether every level rests at the target of the last snapshot with no fade under way.
    public var isSettled: Bool {
        Self.rests(pearlFade, at: targets.pearl) && Self.rests(exitFade, at: targets.exit)
            && Self.rests(wedgeFade, at: targets.wedge)
    }

    /// Whether `fade` has finished at `value`.
    private static func rests(_ fade: Fade, at value: Double) -> Bool { fade.isDone && fade.heading == value }

    /// Moves every level toward its target for `snapshot` by `elapsed` seconds of its fade (each fade lasts
    /// ``normalDuration`` or ``reducedFlashDuration``); a negative or non-finite `elapsed` counts as 0. Under Reduce
    /// Flashing a level mid-fade keeps heading for the value it started toward. The first snapshot settles instead;
    /// later ones, of any level, fade.
    public mutating func step(toward snapshot: AmethystEscapeSceneSnapshot, elapsed: Double) {
        guard started else {
            settle(to: snapshot)
            return
        }
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let share: Double = time / duration
        targets = Targets(snapshot)
        pearlFade = advance(pearlFade, target: targets.pearl, share: share)
        exitFade = advance(exitFade, target: targets.exit, share: share)
        wedgeFade = advance(wedgeFade, target: targets.wedge, share: share)
        publish()
    }

    /// Jumps every level to its target for `snapshot`: used for the first frame, so the scene does not fade in from
    /// dark.
    public mutating func settle(to snapshot: AmethystEscapeSceneSnapshot) {
        targets = Targets(snapshot)
        pearlFade = Fade.resting(targets.pearl)
        exitFade = Fade.resting(targets.exit)
        wedgeFade = Fade.resting(targets.wedge)
        started = true
        publish()
    }

    /// Copies the fades' current levels into the public levels.
    private mutating func publish() {
        pearl = pearlFade.level
        exit = exitFade.level
        wedge = wedgeFade.level
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
