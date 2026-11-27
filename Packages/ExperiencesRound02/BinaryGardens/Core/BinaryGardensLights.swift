// BinaryGardensLights — feature 506 (R02-G21-06) T-R02G2106-004 (FR-R02G2106-004; SC-R02G2106-003; clarification Q3;
// research R2, R3). The presenter's eased light levels of Binary Gardens: the glow (target 0.7 while the play is
// neither won nor failed, 1 once won — stage `won`, or the result after a win — and 0.35 once failed, the result after
// a failure included), which the scene multiplies into the glow gain; the won look (target 1 once won, else 0), which
// the scene passes as the won uniform and, in the fallback path, as the blend of the not-won and won colours; and one
// bloom level per world (target 1 when the world is comfortable at the drawn snapshot's shown tick or the level is won,
// else 0), which the scene writes as that world's glow shell factor
// (`BinaryGardensSceneGeometry.glowPart(_:tier:wonLevel:camera:bloom:)`, rebuilt when a level crosses a 1/32 step).
// A failure counts only once the run has failed (stage `failed`, or the result after it): the snapshot's `failure`
// also carries the predicted report's failure while the level is under way, and a ring, phase, luminosity or tilt
// action that would make a run fail or win does not change the glow. The bloom targets are read from the drawn snapshot
// (`BinaryGardensSceneGeometry.drawnSnapshot(_:)`, the accepted preview applied; a snapshot without a preview is drawn
// as it is), so the shells match the drawn worlds whether the presenter passes the snapshot or the drawn one.
//
// Each level moves linearly toward its target by the frame clock's elapsed time between drawn frames, never by the
// presentation time (which Reduce Motion holds at 0, so the fades finish under Reduce Motion too). Every fade, from the
// level where it starts to the value it heads for, takes exactly the duration: 0.15 s normally and 0.45 s under Reduce
// Flashing (feature 346's rule, as in features 486 and 496: with a fixed fade time every fade of more than half an
// element's range lasts 0.45 s ≥ 0.4 s, and a level crosses the middle of its range at most once per fade, so at most
// 3 times a second). Normally the heading follows the target at once, starting a new fade from where the level is, so
// a target is reached within 0.15 s of its last change. Under Reduce Flashing a level that has started moving finishes
// the fade to the value it is heading for before it may turn back, so a target that flickers faster than the fade (a
// ring change undone and redone every frame, a failed run undone and redone every frame, the shown tick stepped back
// and forth every frame, a level change every frame) cannot make a level blink. The first step (no snapshot seen yet)
// settles at once; afterwards every change, a retry or another level included, fades. `settle(to:)` jumps explicitly.
// A level with another world count carries the bloom levels (and their fades) by world index, drops the worlds it
// lacks and starts each new world at 0, from where it fades toward its target. The glow is a gain, so its range for the
// flash measure is 0 … 1 (0 before the first snapshot): its midpoint 0.5 lies between the failed 0.35 and the playing
// 0.7. The stars, rings, phases, pips, dial, gauges, trails and band tints change only with the player's actions and the
// shown tick and are not faded. The state and the digest never see these levels; they are presentation only and pure.
// No clock: the caller passes the elapsed time. Modelled on `MushroomWeatherLights` (feature 496).
import Foundation

/// The eased light levels of Binary Gardens' glow, won look and world blooms (presentation only).
public struct BinaryGardensLights: Sendable, Equatable {
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
        var isDone: Bool { progress >= 1 - BinaryGardensLights.tolerance }

        /// The current level: the heading once done, else the linear mix of start and heading, clamped to 0 … 1.
        var level: Double {
            if isDone { return heading }
            return min(max(start + (heading - start) * progress, 0), 1)
        }

        /// Whether the fade has finished at `value`.
        func rests(at value: Double) -> Bool { isDone && heading == value }
    }

    /// The light targets of one snapshot.
    struct Targets: Sendable, Equatable {
        /// The glow target.
        var glow: Double
        /// The won look target.
        var won: Double
        /// The bloom target of each world, by world index.
        var bloom: [Double]

        /// The targets of `snapshot`: the glow ``glowWon`` once won (``isWon(_:)``), ``glowFailed`` once failed
        /// (``isFailed(_:)``), ``glowPlaying`` otherwise; the won look 1 once won, else 0; each world's bloom 1 when it
        /// blooms in the drawn snapshot (comfortable at the shown tick, or the level won), else 0.
        init(_ snapshot: BinaryGardensSceneSnapshot) {
            let isWon: Bool = BinaryGardensLights.isWon(snapshot)
            if isWon {
                glow = BinaryGardensLights.glowWon
            } else if BinaryGardensLights.isFailed(snapshot) {
                glow = BinaryGardensLights.glowFailed
            } else {
                glow = BinaryGardensLights.glowPlaying
            }
            won = isWon ? 1 : 0
            let drawn: BinaryGardensSceneSnapshot = BinaryGardensSceneGeometry.drawnSnapshot(snapshot)
            var levels: [Double] = []
            for world in drawn.worlds.indices {
                levels.append(BinaryGardensSceneGeometry.blooms(world, drawn, won: isWon) ? 1 : 0)
            }
            bloom = levels
        }

        /// The targets of the dark lights before the first snapshot: everything 0, no worlds.
        init() {
            glow = 0
            won = 0
            bloom = []
        }
    }

    /// The time every fade takes normally, in seconds.
    public static let normalDuration = 0.15
    /// The time every fade takes under Reduce Flashing, in seconds.
    public static let reducedFlashDuration = 0.45
    /// The glow while the play is neither won nor failed.
    public static let glowPlaying = 0.7
    /// The glow once the play is won.
    public static let glowWon = 1.0
    /// The glow once the play has failed.
    public static let glowFailed = 0.35
    /// The rounding tolerance for a finished fade.
    static let tolerance = 1e-9

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The glow, ``glowFailed`` … ``glowWon`` (0 before the first snapshot).
    public private(set) var glow: Double
    /// The won look, 0 … 1.
    public private(set) var won: Double
    /// The bloom level of each world of the last snapshot, by world index, each 0 … 1 (empty before the first
    /// snapshot); the scene's shell factors.
    public private(set) var bloom: [Double]

    /// The fade of the glow.
    private var glowFade: Fade
    /// The fade of the won look.
    private var wonFade: Fade
    /// The fade of each world's bloom.
    private var bloomFades: [Fade]
    /// The targets of the last snapshot.
    private var targets: Targets
    /// Whether a snapshot has been seen (the first step settles).
    private var started: Bool

    /// Dark lights (every level 0, no worlds) with the fade time for `reducedFlash`; the first ``settle(to:)`` or
    /// ``step(toward:elapsed:)`` settles them to its snapshot.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        glow = 0
        won = 0
        bloom = []
        glowFade = Fade.resting(0)
        wonFade = Fade.resting(0)
        bloomFades = []
        targets = Targets()
        started = false
    }

    /// Whether `snapshot` shows a won play: stage `won`, or stage `result` without a failure
    /// (`BinaryGardensSceneSnapshot.isWon`).
    static func isWon(_ snapshot: BinaryGardensSceneSnapshot) -> Bool { snapshot.isWon }

    /// Whether `snapshot` shows a failed play: stage `failed`, or stage `result` with a failure (the result after a
    /// failed play). The predicted report's failure that the snapshot carries while the level is under way does not
    /// count: only the run ends a level.
    static func isFailed(_ snapshot: BinaryGardensSceneSnapshot) -> Bool {
        snapshot.stage == .failed || (snapshot.stage == .result && snapshot.failure != nil)
    }

    /// The time every fade takes with the current setting, in seconds.
    var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// Whether every level rests at the target of the last snapshot with no fade under way.
    public var isSettled: Bool {
        guard glowFade.rests(at: targets.glow), wonFade.rests(at: targets.won),
              bloomFades.count == targets.bloom.count else { return false }
        for index in bloomFades.indices where !bloomFades[index].rests(at: targets.bloom[index]) { return false }
        return true
    }

    /// Moves every level toward its target for `snapshot` by `elapsed` seconds of its fade (each fade lasts
    /// ``normalDuration`` or ``reducedFlashDuration``). `elapsed` is the frame clock's time since the last drawn frame,
    /// not the presentation time (held at 0 under Reduce Motion); a negative or non-finite `elapsed` counts as 0. Under
    /// Reduce Flashing a level mid-fade keeps heading for the value it started toward. A snapshot with another world
    /// count keeps the bloom fades by index and starts each new world at 0. The first snapshot settles instead; later
    /// ones, of any level, fade.
    public mutating func step(toward snapshot: BinaryGardensSceneSnapshot, elapsed: Double) {
        guard started else {
            settle(to: snapshot)
            return
        }
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let share: Double = time / duration
        targets = Targets(snapshot)
        glowFade = advance(glowFade, target: targets.glow, share: share)
        wonFade = advance(wonFade, target: targets.won, share: share)
        var fades: [Fade] = []
        fades.reserveCapacity(targets.bloom.count)
        for index in targets.bloom.indices {
            let current: Fade = index < bloomFades.count ? bloomFades[index] : Fade.resting(0)
            fades.append(advance(current, target: targets.bloom[index], share: share))
        }
        bloomFades = fades
        publish()
    }

    /// Jumps every level to its target for `snapshot`: used for the first frame, so the scene does not fade in from
    /// dark.
    public mutating func settle(to snapshot: BinaryGardensSceneSnapshot) {
        targets = Targets(snapshot)
        glowFade = Fade.resting(targets.glow)
        wonFade = Fade.resting(targets.won)
        bloomFades = targets.bloom.map { Fade.resting($0) }
        started = true
        publish()
    }

    /// Copies the fades' current levels into the public levels.
    private mutating func publish() {
        glow = glowFade.level
        won = wonFade.level
        bloom = bloomFades.map(\.level)
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
    /// element makes such a change (or the frame rate is not positive and finite); only the elements present in every
    /// sample are measured.
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
