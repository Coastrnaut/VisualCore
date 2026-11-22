// ChronoConstellatorSolver — feature 352 (R02-G06-02) T-R02G0602-003 (FR-R02G0602-002; clarification Q2). The integer-tick
// phase search. For every tick T = 1 … tick limit, m(T) is the number of stars whose default timeline (the level's
// phases, no holds) does not put them on their target at T. Every edit (a phase change or a hold) acts on one star, and a
// star off its target at T needs at least one edit on it, so any timeline winning at T has at least m(T) edits; the lower
// bound is m* = min over T of m(T). The windows are the ticks with m(T) = m*, in order. A window's phase-only timeline
// sets each star that is off its target at T to phase (index of its target − T) mod L and keeps the others; the window is
// blocked when that timeline puts two stars on one cell on some tick 1 … T. The first unblocked window gives the solution,
// so the smallest edit count is exactly m*. Work = ticks scanned plus window ticks checked. Integers only; no clock, no
// random source.

/// The certified result of the phase search.
public struct ChronoConstellatorSolution: Sendable, Equatable, Hashable, Codable {
    /// The smallest edit count m* (also the number of phase changes of the witness timeline).
    public let lowerBound: Int
    /// The witness timeline's start phase of every star.
    public let phases: [Int]
    /// The first unblocked window, the tick the witness is built for.
    public let window: Int
    /// The windows considered (ticks with the smallest misaligned count).
    public let windows: Int
    /// The windows blocked by a collision.
    public let blocked: Int
    /// The ticks scanned plus the window ticks checked.
    public let work: Int

    /// A solution of the given values (not checked).
    public init(lowerBound: Int, phases: [Int], window: Int, windows: Int, blocked: Int, work: Int) {
        self.lowerBound = lowerBound
        self.phases = phases
        self.window = window
        self.windows = windows
        self.blocked = blocked
        self.work = work
    }
}

/// The integer-tick phase search of a Chrono Constellator level.
public enum ChronoConstellatorSolver {
    /// m(T): the stars whose default timeline does not put them on their target at tick `tick`.
    public static func misaligned(_ level: ChronoConstellatorLevel, at tick: Int) -> Int {
        var count = 0
        for star in level.stars {
            let loop: [Int] = star.loop
            if loop[((star.phase + tick) % loop.count + loop.count) % loop.count] != star.target { count += 1 }
        }
        return count
    }

    /// The phase-only timeline of window `tick`: each star off its target at `tick` starts at (index of its target −
    /// tick) mod L; the others keep their default phase.
    public static func windowPhases(_ level: ChronoConstellatorLevel, window tick: Int) -> [Int] {
        var phases: [Int] = []
        for star in level.stars {
            let loop: [Int] = star.loop
            let length: Int = loop.count
            if loop[((star.phase + tick) % length + length) % length] == star.target {
                phases.append(star.phase)
            } else {
                let index: Int = loop.firstIndex(of: star.target) ?? 0
                phases.append(((index - tick) % length + length) % length)
            }
        }
        return phases
    }

    /// Whether the phase-only timeline of window `tick` puts two stars on one cell on some tick 1 … `tick`.
    public static func isBlocked(_ level: ChronoConstellatorLevel, window tick: Int) -> Bool {
        collisionTick(level, phases: windowPhases(level, window: tick), through: tick) != nil
    }

    /// The first tick 1 … `last` on which two stars with start `phases` (no holds) stand on one cell, or nil.
    static func collisionTick(_ level: ChronoConstellatorLevel, phases: [Int], through last: Int) -> Int? {
        guard last >= 1 else { return nil }
        var cells: [Int] = Array(repeating: 0, count: level.stars.count)
        for t in 1...last {
            for index in level.stars.indices {
                let loop: [Int] = level.stars[index].loop
                cells[index] = loop[(phases[index] + t) % loop.count]
            }
            for a in cells.indices {
                for b in cells.indices where b > a && cells[a] == cells[b] { return t }
            }
        }
        return nil
    }

    /// The certified solution of `level`: the lower bound m*, the first unblocked window and its phase-only timeline;
    /// nil when the default timeline already aligns every star on some tick (m* = 0) or every window is blocked.
    public static func solve(_ level: ChronoConstellatorLevel) -> ChronoConstellatorSolution? {
        var counts: [Int] = []
        counts.reserveCapacity(level.tickLimit)
        for tick in 1...level.tickLimit { counts.append(misaligned(level, at: tick)) }
        guard let lowest = counts.min(), lowest > 0 else { return nil }
        var work: Int = level.tickLimit
        var windows = 0
        var blocked = 0
        var first: Int? = nil
        for tick in 1...level.tickLimit where counts[tick - 1] == lowest {
            windows += 1
            work += tick
            if isBlocked(level, window: tick) {
                blocked += 1
            } else if first == nil {
                first = tick
            }
        }
        guard let window = first else { return nil }
        return ChronoConstellatorSolution(lowerBound: lowest, phases: windowPhases(level, window: window), window: window,
                                          windows: windows, blocked: blocked, work: work)
    }
}
