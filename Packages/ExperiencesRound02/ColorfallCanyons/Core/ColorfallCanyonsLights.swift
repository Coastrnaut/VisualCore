// ColorfallCanyonsLights — feature 346 (R02-G05-06) T-R02G0506-003 (FR-R02G0506-004; SC-R02G0506-003; clarification
// Q3; research R3, R4, R5). The presenter's eased light levels: one fluid sheet per cell, keyed by its cell (target the
// sheet brightness of feature 343, `ColorfallCanyonsPalette.brightness(volume:)` = 0.35 + 0.65 · min(volume, 24) / 24,
// and 0 when the cell is empty), one emitter per spring (target 1 while it flows, `ColorfallCanyonsSceneGeometry.dimming`
// = 0.3 when its valve is closed or its supply is spent) and the win glow (target 1 while the play is won, else 0).
// A sheet carries the colour weights of its cell's masses (`ColorfallCanyonsShaders.weights(masses:)`); a cell that
// empties keeps the weights of the last frame it held fluid, so it fades out in its last colour.
//
// Each level moves linearly toward its target in presentation time. Every fade, from the level where it starts to the
// value it heads for, takes exactly the duration: 0.15 s normally and 0.45 s under Reduce Flashing. (A fixed rate of one
// range per duration, Hue Compass's rule, is not enough here: sheet targets lie anywhere in 0.35 … 1, so a change of
// 0.6 would finish in 0.27 s and two targets on either side of 0.5 — volumes 5 and 6 — would let a level cross half its
// range in one frame. With a fixed fade time every fade of more than half the range lasts 0.45 s ≥ 0.4 s and a level
// crosses 0.5 at most once per fade.) Normally the heading follows the target at once, starting a new fade from where
// the level is, so a target is reached within 0.15 s of its last change. Under Reduce Flashing a level that has started
// moving finishes the fade to the value it is heading for before it may turn back (features 316, 326 and 336's rule), so
// a target that flickers faster than the fade cannot make a level blink. A sheet at 0 whose target is 0 is dropped. A
// new level number, a change of the grid size or of the spring count (or the first snapshot) settles the lights at once.
// The state and the digest never see these levels; they are presentation only and pure.

/// The eased light levels of Colorfall Canyons's fluid sheets, spring emitters and win glow (presentation only).
public struct ColorfallCanyonsLights: Sendable, Equatable {
    /// The eased light of one fluid sheet.
    public struct Sheet: Sendable, Equatable {
        /// The eased brightness 0 … 1 (0 dark; a lit sheet heads for 0.35 … 1).
        public let level: Double
        /// The colour weights (cyan, coral, yellow mass shares) the sheet is drawn with: its cell's current ones, or the
        /// last non-empty ones while it fades out.
        public let weights: SIMD3<Double>

        /// A sheet of the given values (not checked).
        public init(level: Double, weights: SIMD3<Double>) {
            self.level = level
            self.weights = weights
        }
    }

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
        var isDone: Bool { progress >= 1 - ColorfallCanyonsLights.tolerance }

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
    /// The rounding tolerance for a finished fade.
    static let tolerance = 1e-9

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The sheets by cell: cells holding fluid and cells still fading out.
    public private(set) var sheets: [Int: Sheet]
    /// The emitter levels, one per spring in the snapshot's order.
    public private(set) var emitters: [Double]
    /// The win glow 0 … 1.
    public private(set) var glow: Double

    /// The fade of each sheet, by cell.
    private var sheetFades: [Int: Fade]
    /// The fade of each emitter.
    private var emitterFades: [Fade]
    /// The fade of the glow.
    private var glowFade: Fade
    /// The sheet targets of the last snapshot: the cells holding fluid and their brightness.
    private var sheetTargets: [Int: Double]
    /// The emitter targets of the last snapshot.
    private var emitterTargets: [Double]
    /// The glow target of the last snapshot.
    private var glowTarget: Double
    /// The level number, cell count and spring count of the last snapshot; nil before the first.
    private var shape: [Int]?

    /// Dark lights (no sheets, no emitters, glow 0) with the fade time for `reducedFlash`; the first ``settle(to:)`` or
    /// ``step(toward:elapsed:)`` settles them to its snapshot.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        sheets = [:]
        emitters = []
        glow = 0
        sheetFades = [:]
        emitterFades = []
        glowFade = Fade.resting(0)
        sheetTargets = [:]
        emitterTargets = []
        glowTarget = 0
        shape = nil
    }

    /// The time every fade takes with the current setting, in seconds.
    var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// Whether every level rests at the target of the last snapshot: a sheet for exactly the cells holding fluid, each
    /// at its brightness, every emitter at its target and the glow at its target, with no fade under way.
    public var isSettled: Bool {
        guard glowFade.isDone, glowFade.heading == glowTarget else { return false }
        guard emitterFades.count == emitterTargets.count else { return false }
        for index in emitterFades.indices {
            guard emitterFades[index].isDone, emitterFades[index].heading == emitterTargets[index] else { return false }
        }
        guard Set(sheetFades.keys) == Set(sheetTargets.keys) else { return false }
        for (cell, fade) in sheetFades {
            guard fade.isDone, fade.heading == sheetTargets[cell] else { return false }
        }
        return true
    }

    /// The sheet targets of `snapshot`: every cell holding fluid with its brightness (cells without fluid target 0).
    static func sheetTargets(_ snapshot: ColorfallCanyonsSceneSnapshot) -> [Int: Double] {
        var targets: [Int: Double] = [:]
        for cell in 0..<min(snapshot.cellCount, snapshot.masses.count) {
            let volume: Int = snapshot.volume(cell)
            if volume > 0 { targets[cell] = ColorfallCanyonsPalette.brightness(volume: volume) }
        }
        return targets
    }

    /// The emitter targets of `snapshot`: 1 for a flowing spring, ``ColorfallCanyonsSceneGeometry/dimming`` otherwise.
    static func emitterTargets(_ snapshot: ColorfallCanyonsSceneSnapshot) -> [Double] {
        var targets: [Double] = []
        targets.reserveCapacity(snapshot.springs.count)
        for spring in snapshot.springs { targets.append(spring.flowing ? 1 : ColorfallCanyonsSceneGeometry.dimming) }
        return targets
    }

    /// The glow target of `snapshot`: 1 when the stage is `won`, else 0.
    static func glowTarget(_ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        snapshot.stage == .won ? 1 : 0
    }

    /// The level number, cell count and spring count of `snapshot`; another shape settles instead of fading.
    static func shape(_ snapshot: ColorfallCanyonsSceneSnapshot) -> [Int] {
        [snapshot.levelNumber, snapshot.cellCount, snapshot.springs.count]
    }

    /// The colour weights of `cell` in `snapshot` (its mass shares), nil when the cell holds no fluid.
    static func weights(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double>? {
        guard snapshot.masses.indices.contains(cell), snapshot.volume(cell) > 0 else { return nil }
        return ColorfallCanyonsShaders.weights(masses: snapshot.masses[cell])
    }

    /// Moves every level toward its target by `elapsed` seconds of its fade (each fade lasts ``normalDuration`` or
    /// ``reducedFlashDuration``); a negative or non-finite `elapsed` counts as 0. A cell that empties keeps its last
    /// weights while it fades out and is dropped at 0. Under Reduce Flashing a level mid-fade keeps heading for the value
    /// it started toward. A snapshot of another level number, grid size or spring count (or the first) settles instead.
    public mutating func step(toward snapshot: ColorfallCanyonsSceneSnapshot, elapsed: Double) {
        guard shape == Self.shape(snapshot) else {
            settle(to: snapshot)
            return
        }
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let share: Double = time / duration
        let targets: [Int: Double] = Self.sheetTargets(snapshot)
        var cells: Set<Int> = Set(sheetFades.keys)
        cells.formUnion(targets.keys)
        var nextFades: [Int: Fade] = [:]
        var nextSheets: [Int: Sheet] = [:]
        for cell in cells {
            let target: Double = targets[cell] ?? 0
            let fade: Fade = advance(sheetFades[cell] ?? Fade.resting(0), target: target, share: share)
            if fade.isDone && fade.heading == 0 && target == 0 { continue }
            let weights: SIMD3<Double> = Self.weights(cell, snapshot) ?? sheets[cell]?.weights ?? SIMD3<Double>(0, 0, 0)
            nextFades[cell] = fade
            nextSheets[cell] = Sheet(level: fade.level, weights: weights)
        }
        sheetFades = nextFades
        sheets = nextSheets
        sheetTargets = targets
        emitterTargets = Self.emitterTargets(snapshot)
        var nextEmitters: [Fade] = []
        nextEmitters.reserveCapacity(emitterTargets.count)
        for index in emitterTargets.indices {
            let current: Fade = emitterFades.indices.contains(index) ? emitterFades[index] : Fade.resting(0)
            nextEmitters.append(advance(current, target: emitterTargets[index], share: share))
        }
        emitterFades = nextEmitters
        emitters = nextEmitters.map(\.level)
        glowTarget = Self.glowTarget(snapshot)
        glowFade = advance(glowFade, target: glowTarget, share: share)
        glow = glowFade.level
    }

    /// Jumps every level to its target for `snapshot` (a sheet at its brightness for every cell holding fluid, every
    /// other sheet dropped; the emitters and the glow at their targets): used for the first frame and a new level, so
    /// the scene does not fade in from dark.
    public mutating func settle(to snapshot: ColorfallCanyonsSceneSnapshot) {
        sheetTargets = Self.sheetTargets(snapshot)
        var fades: [Int: Fade] = [:]
        var lit: [Int: Sheet] = [:]
        for (cell, target) in sheetTargets {
            fades[cell] = Fade.resting(target)
            lit[cell] = Sheet(level: target, weights: Self.weights(cell, snapshot) ?? SIMD3<Double>(0, 0, 0))
        }
        sheetFades = fades
        sheets = lit
        emitterTargets = Self.emitterTargets(snapshot)
        emitterFades = emitterTargets.map { Fade.resting($0) }
        emitters = emitterTargets
        glowTarget = Self.glowTarget(snapshot)
        glowFade = Fade.resting(glowTarget)
        glow = glowTarget
        shape = Self.shape(snapshot)
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
