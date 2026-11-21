// HueCompassLights — feature 336 (R02-G04-06) T-R02G0406-003 (FR-R02G0406-004; clarification Q3; research R3, R4).
// The presenter's eased light levels: one per probe mark, keyed by its probed bearing (target 1 while a clue at that
// bearing is in the snapshot, 0 once it is gone), the ember selection mark (target 1 while the snapshot has a
// selection), the sapphire target ring (target 1 while the snapshot shows the target, that is once the play has ended)
// and the win glow (target 1 while the play is won, else 0). Each level moves linearly toward its target in presentation
// time, across its whole range in 0.15 s normally and 0.45 s under Reduce Flashing, so no light switches in one frame.
// Under Reduce Flashing a level that has started moving finishes the move to the value it is heading for before it may
// turn back (features 316 and 326's rule), so a target that flickers faster than the fade cannot make a level hover and
// blink around half its range. The selection mark and the target ring remember the bearing they were last drawn at: one
// that disappears (a retry) fades out where it was. When either one is wanted at another bearing while it is still lit,
// it never jumps: it fades out at the old bearing, moves at level 0 and fades in at the new one (a mark that moves is an
// out-then-in sequence of two ordinary fades, so it obeys the same half-range bound). A probe level at 0 whose target is
// 0 is dropped, and so are a selection or ring at 0 that is not wanted. A new level number (or the first snapshot)
// settles the lights at once. The state and the digest never see these levels; they are presentation only and pure.

/// The eased light levels of Hue Compass's probe marks, selection mark, target ring and win glow (presentation only).
public struct HueCompassLights: Sendable, Equatable {
    /// A single light that sits at one bearing: the selection mark or the target ring.
    public struct Mark: Sendable, Equatable {
        /// The eased level 0 … 1.
        public let level: Double
        /// The bearing 0 … 95 the mark is drawn at (the last one it was wanted at, kept while it fades out).
        public let bearing: Int

        /// A mark of the given values (not checked).
        public init(level: Double, bearing: Int) {
            self.level = level
            self.bearing = bearing
        }
    }

    /// The time a level takes to move across its whole range normally, in seconds.
    public static let normalDuration = 0.15
    /// The time a level takes to move across its whole range under Reduce Flashing, in seconds.
    public static let reducedFlashDuration = 0.45

    /// Whether Reduce Flashing is on (slower fades that finish before they turn back).
    public let reducedFlash: Bool
    /// The probe mark levels by probed bearing: present probes and probes still fading out.
    public private(set) var probes: [Int: Double]
    /// The selection mark; nil when there is none and none is fading out.
    public private(set) var selection: Mark?
    /// The target ring; nil when the target is not shown and no ring is fading out.
    public private(set) var ring: Mark?
    /// The win glow 0 … 1.
    public private(set) var glow: Double

    /// The value each probe level is heading for; under Reduce Flashing it changes only when the level has reached it.
    private var probeHeadings: [Int: Double]
    /// The value the selection level is heading for.
    private var selectionHeading: Double
    /// The value the ring level is heading for.
    private var ringHeading: Double
    /// The value the glow is heading for.
    private var glowHeading: Double
    /// The probed bearings of the last snapshot (target 1).
    private var present: Set<Int>
    /// The selected bearing of the last snapshot; nil when it had none.
    private var wantedSelection: Int?
    /// The target bearing of the last snapshot; nil while it was hidden.
    private var wantedRing: Int?
    /// The glow target of the last snapshot.
    private var glowTarget: Double
    /// The level number of the last snapshot; nil before the first.
    private var levelNumber: Int?

    /// Dark lights (no marks, glow 0) with the fade speed for `reducedFlash`; the first ``settle(to:)`` or
    /// ``step(toward:elapsed:)`` settles them to its snapshot.
    public init(reducedFlash: Bool) {
        self.reducedFlash = reducedFlash
        probes = [:]
        selection = nil
        ring = nil
        glow = 0
        probeHeadings = [:]
        selectionHeading = 0
        ringHeading = 0
        glowHeading = 0
        present = []
        wantedSelection = nil
        wantedRing = nil
        glowTarget = 0
        levelNumber = nil
    }

    /// The time a level takes to cross its whole range with the current setting, in seconds.
    var duration: Double { reducedFlash ? Self.reducedFlashDuration : Self.normalDuration }

    /// Whether every level is at the target of the last snapshot: each present probe at 1 and no other probe, the
    /// selection and the ring at 1 at their wanted bearings (or absent when not wanted), the glow at its target.
    public var isSettled: Bool {
        guard glow == glowTarget, glowHeading == glowTarget else { return false }
        guard Set(probes.keys) == present else { return false }
        for (bearing, level) in probes where level != 1 || probeHeadings[bearing] != 1 { return false }
        return Self.markSettled(selection, heading: selectionHeading, wanted: wantedSelection)
            && Self.markSettled(ring, heading: ringHeading, wanted: wantedRing)
    }

    /// Whether `mark` is at rest for `wanted`: at level 1 heading 1 at the wanted bearing, or absent when not wanted.
    private static func markSettled(_ mark: Mark?, heading: Double, wanted: Int?) -> Bool {
        guard let wanted else { return mark == nil }
        guard let mark else { return false }
        return mark.bearing == wanted && mark.level == 1 && heading == 1
    }

    /// The probed bearings of `snapshot` (each clue's bearing, 0 … 95), as the scene draws them.
    static func probeTargets(_ snapshot: HueCompassSceneSnapshot) -> Set<Int> {
        Set(HueCompassSceneGeometry.probeBearings(snapshot))
    }

    /// The selection bearing of `snapshot` (0 … 95), nil when it has no selection.
    static func selectionTarget(_ snapshot: HueCompassSceneSnapshot) -> Int? {
        snapshot.selection.map { HueCompassWheel.mod($0.bearing, HueCompassWheel.bearings) }
    }

    /// The ring bearing of `snapshot` (0 … 95), nil while the target is hidden.
    static func ringTarget(_ snapshot: HueCompassSceneSnapshot) -> Int? {
        snapshot.target.map { HueCompassWheel.mod($0, HueCompassWheel.bearings) }
    }

    /// The glow target of `snapshot`: 1 when the stage is `won`, else 0.
    static func glowTarget(_ snapshot: HueCompassSceneSnapshot) -> Double {
        snapshot.stage == .won ? 1 : 0
    }

    /// Moves every level toward its target by `elapsed / duration` (at most to the target); a negative or non-finite
    /// `elapsed` counts as 0. Absent probes fade out and are dropped at 0; the selection and the ring fade out at their
    /// remembered bearing, and one wanted at another bearing fades out there first and then in at the new one. Under
    /// Reduce Flashing a level mid-fade keeps heading for the value it started toward. A snapshot of another level
    /// number (or the first snapshot) settles instead.
    public mutating func step(toward snapshot: HueCompassSceneSnapshot, elapsed: Double) {
        guard levelNumber == snapshot.levelNumber else {
            settle(to: snapshot)
            return
        }
        let time: Double = elapsed.isFinite ? max(elapsed, 0) : 0
        let delta: Double = time / duration
        let targets: Set<Int> = Self.probeTargets(snapshot)
        var bearings: Set<Int> = Set(probes.keys)
        bearings.formUnion(targets)
        var nextProbes: [Int: Double] = [:]
        var nextHeadings: [Int: Double] = [:]
        for bearing in bearings {
            let target: Double = targets.contains(bearing) ? 1 : 0
            let (level, heading) = advance(probes[bearing] ?? 0, heading: probeHeadings[bearing] ?? 0, target: target,
                                           delta: delta)
            if level == 0 && target == 0 && heading == 0 { continue }
            nextProbes[bearing] = level
            nextHeadings[bearing] = heading
        }
        probes = nextProbes
        probeHeadings = nextHeadings
        present = targets
        wantedSelection = Self.selectionTarget(snapshot)
        wantedRing = Self.ringTarget(snapshot)
        (selection, selectionHeading) = advanceMark(selection, heading: selectionHeading, wanted: wantedSelection,
                                                    delta: delta)
        (ring, ringHeading) = advanceMark(ring, heading: ringHeading, wanted: wantedRing, delta: delta)
        glowTarget = Self.glowTarget(snapshot)
        (glow, glowHeading) = advance(glow, heading: glowHeading, target: glowTarget, delta: delta)
    }

    /// Jumps every level to its target for `snapshot` (present probes 1, every other probe dropped; the selection and
    /// the ring at 1 at their bearings or absent; the glow at its target): used for the first frame and a new level, so
    /// the scene does not fade in from dark.
    public mutating func settle(to snapshot: HueCompassSceneSnapshot) {
        present = Self.probeTargets(snapshot)
        var nextProbes: [Int: Double] = [:]
        for bearing in present { nextProbes[bearing] = 1 }
        probes = nextProbes
        probeHeadings = nextProbes
        wantedSelection = Self.selectionTarget(snapshot)
        wantedRing = Self.ringTarget(snapshot)
        selection = wantedSelection.map { Mark(level: 1, bearing: $0) }
        selectionHeading = selection == nil ? 0 : 1
        ring = wantedRing.map { Mark(level: 1, bearing: $0) }
        ringHeading = ring == nil ? 0 : 1
        glowTarget = Self.glowTarget(snapshot)
        glow = glowTarget
        glowHeading = glowTarget
        levelNumber = snapshot.levelNumber
    }

    /// One mark's move toward `wanted`: target 1 at the wanted bearing when the mark is absent, at that bearing or
    /// dark (level and heading 0, where it may move); otherwise target 0 (fading out where it is). A mark that reaches
    /// 0 while unwanted is dropped; one that reaches 0 while wanted elsewhere moves there at level 0.
    private func advanceMark(_ mark: Mark?, heading: Double, wanted: Int?,
                             delta: Double) -> (Mark?, Double) {
        var bearing: Int? = mark?.bearing
        let level: Double = mark?.level ?? 0
        if let wanted, bearing == nil || (level == 0 && heading == 0) { bearing = wanted }
        guard let at = bearing else { return (nil, 0) }
        let target: Double = wanted == at ? 1 : 0
        let (next, nextHeading) = advance(level, heading: heading, target: target, delta: delta)
        if next == 0 && nextHeading == 0 {
            guard let wanted else { return (nil, 0) }
            return (Mark(level: 0, bearing: wanted), 0)
        }
        return (Mark(level: next, bearing: at), nextHeading)
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
