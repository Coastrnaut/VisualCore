// LissajousLabyrinthSolver — feature 312 (R02-G02-02) T-R02G0202-002 (contract) and T-R02G0202-003 (FR-R02G0202-002;
// clarification Q2; research R1–R3). Decides every legal setting of a level and finds the shortest action list from the
// start to a winning setting through legal states.

/// A proven shortest solution of a level.
public struct LissajousLabyrinthSolution: Sendable, Equatable, Hashable, Codable {
    /// The fewest actions that win from the start.
    public let shortest: Int
    /// A shortest action list (tie rules of clarification Q2).
    public let actions: [LissajousLabyrinthAction]
    /// The winning setting the actions reach.
    public let setting: LissajousLabyrinthDials
    /// The number of legal settings that win.
    public let winningSettings: Int
    /// The exact verdicts the solver spent.
    public let work: Int

    /// A solution of the given values.
    public init(shortest: Int, actions: [LissajousLabyrinthAction], setting: LissajousLabyrinthDials,
                winningSettings: Int, work: Int) {
        self.shortest = shortest
        self.actions = actions
        self.setting = setting
        self.winningSettings = winningSettings
        self.work = work
    }
}

/// The exhaustive solver of Lissajous Labyrinth (feature 312, R02-G02-02, T-R02G0202-003, FR-R02G0202-002).
///
/// It decides all 14,080 legal settings of a level (research R1, R2). The x sample depends only on (a, φ), y on b and
/// z on ψ, so every axis test is a separable table of 4,096-tick bit sets, ANDed per setting. Sound prefilters reject a
/// setting only when no ordered sequence of ticks can visit the checkpoints (a sample inside a checkpoint ball lies in
/// its bounding box) or when a sample surely lies strictly inside an obstacle (inside its largest inscribed integer
/// cube). Every other setting gets the exact decision `wins(_:level:tables:)`, equal to the kernel's
/// `LissajousLabyrinthLap.verdict(_:level:) == .won`: the kernel's exact tests run only on the ticks the tables leave
/// possible. The shortest solution is a breadth-first search over legal states (research R3, clarification Q2).
public enum LissajousLabyrinthSolver {
    /// Words of a 4,096-tick bit set.
    private static let words = LissajousLabyrinthLap.ticks / 64
    /// Frequency values per frequency dial (1 … 9).
    private static let frequencies = 9
    /// Phase values per phase dial (0 … 15).
    private static let phases = 16

    /// Every legal setting (coprime frequencies, phases in range), ordered by a, then b, then φ, then ψ ascending:
    /// 14,080 settings.
    public static func legalSettings() -> [LissajousLabyrinthDials] {
        legal
    }

    /// The legal settings, computed once.
    private static let legal: [LissajousLabyrinthDials] = {
        var result: [LissajousLabyrinthDials] = []
        result.reserveCapacity(14_080)
        for a in LissajousLabyrinthDial.frequencyA.range {
            for b in LissajousLabyrinthDial.frequencyB.range where LissajousLabyrinthDials.gcd(a, b) == 1 {
                for phaseA in LissajousLabyrinthDial.phaseA.range {
                    for phaseC in LissajousLabyrinthDial.phaseC.range {
                        result.append(LissajousLabyrinthDials(frequencyA: a, frequencyB: b, phaseA: phaseA,
                                                              phaseC: phaseC))
                    }
                }
            }
        }
        return result
    }()

    /// The dense index of `dials` (a, b, φ, ψ in lexicographic order; 20,736 slots, legal or not).
    private static func index(_ dials: LissajousLabyrinthDials) -> Int {
        (((dials.frequencyA - 1) * frequencies + dials.frequencyB - 1) * phases + dials.phaseA) * phases + dials.phaseC
    }

    /// Writes to `out[0 ..< 64]` an axis bit set over the ticks n of the lap, where the axis angle at tick n is
    /// `frequency · n + offset` and `values[angle]` is the axis coordinate. Without `segment`, bit n says the sample of
    /// tick n lies in `low … high`; with `segment`, it says the coordinate interval of the segment from tick n to tick
    /// n + 1 (the closing segment from 4,095 to 0 included) meets `low … high`.
    private static func fill(_ out: UnsafeMutablePointer<UInt64>, values: UnsafePointer<Int>, frequency: Int,
                             offset: Int, low: Int, high: Int, segment: Bool) {
        let mask = LissajousLabyrinthSine.mask
        var angle = offset
        for w in 0..<words {
            var bits: UInt64 = 0
            for bit in 0..<64 {
                let u = values[angle & mask]
                let hit: Bool
                if segment {
                    let v = values[(angle + frequency) & mask]
                    hit = min(u, v) <= high && max(u, v) >= low
                } else {
                    hit = u >= low && u <= high
                }
                if hit { bits |= 1 << UInt64(bit) }
                angle += frequency
            }
            out[w] = bits
        }
    }

    /// The tick shift m (0 ..< 4,096) with frequency · m ≡ 256 · phase (mod 4,096), as `shifts[(frequency − 1) · 16 +
    /// phase]`: a phase step is a rotation of the zero-phase tick bit set. It exists for every frequency 1 … 9, whose
    /// factor of two (at most 8) divides 256.
    private static let shifts: [Int] = {
        var result: [Int] = []
        for frequency in 1...frequencies {
            for phase in 0..<phases {
                var m = 0
                let target = LissajousLabyrinthLap.phaseStep * phase
                while (frequency * m) & LissajousLabyrinthSine.mask != target { m += 1 }
                result.append(m)
            }
        }
        return result
    }()

    /// Writes to `out[0 ..< 64]` the bit set `source` rotated by `m` ticks: bit n of the result is bit
    /// (n + m) mod 4,096 of `source`.
    private static func rotate(_ out: UnsafeMutablePointer<UInt64>, _ source: UnsafePointer<UInt64>, by m: Int) {
        let q = m >> 6, r = UInt64(m & 63)
        for w in 0..<words {
            let low = source[(w + q) & (words - 1)]
            if r == 0 {
                out[w] = low
            } else {
                out[w] = (low >> r) | (source[(w + q + 1) & (words - 1)] << (64 - r))
            }
        }
    }

    /// The half side of the largest integer cube strictly inside a ball of `radius`: the largest h with 3·h² < r².
    static func innerHalf(_ radius: Int) -> Int {
        var h = 0
        while 3 * (h + 1) * (h + 1) < radius * radius { h += 1 }
        return h
    }

    /// Words of one block of axis bit sets: 144 x sets ((a − 1)·16 + φ), 9 y sets (144 + b − 1), 16 z sets (153 + ψ).
    private static let blockWords = (frequencies * phases + frequencies + phases) * words

    /// The decision tables of a level: per checkpoint the bounding-box sample hits, per obstacle the inner-cube sample
    /// hits and the bounding-box segment hits, each a block of axis bit sets.
    struct Tables: Sendable {
        /// The blocks: checkpoints, then obstacle cubes, then obstacle segments.
        let storage: [UInt64]
        /// The number of checkpoints.
        let checkpoints: Int
        /// The number of obstacles.
        let obstacles: Int
    }

    /// Fills `out` (one block) for the axis-aligned box of half side `half` around `ball`'s centre.
    private static func fillBlock(_ out: UnsafeMutablePointer<UInt64>, values: [UnsafePointer<Int>],
                                  ball: LissajousLabyrinthBall, half: Int, segment: Bool, frequencyC: Int) {
        for a in 1...frequencies {
            let zero = out + (a - 1) * phases * words
            fill(zero, values: values[0], frequency: a, offset: 0, low: ball.x - half, high: ball.x + half,
                 segment: segment)
            for phase in 1..<phases {
                rotate(zero + phase * words, zero, by: shifts[(a - 1) * phases + phase])
            }
        }
        for b in 1...frequencies {
            fill(out + (frequencies * phases + b - 1) * words, values: values[1], frequency: b, offset: 0,
                 low: ball.y - half, high: ball.y + half, segment: segment)
        }
        let zero = out + (frequencies * phases + frequencies) * words
        fill(zero, values: values[2], frequency: frequencyC, offset: LissajousLabyrinthSine.unitsPerTurn / 4,
             low: ball.z - half, high: ball.z + half, segment: segment)
        for phase in 1..<phases {
            rotate(zero + phase * words, zero, by: shifts[(frequencyC - 1) * phases + phase])
        }
    }

    /// The decision tables of `level`.
    static func tables(_ level: LissajousLabyrinthLevel) -> Tables {
        let turn = LissajousLabyrinthSine.unitsPerTurn
        var valuesX = [Int](repeating: 0, count: turn)
        var valuesY = [Int](repeating: 0, count: turn)
        var valuesZ = [Int](repeating: 0, count: turn)
        for angle in 0..<turn {
            let s = Int(LissajousLabyrinthSine.table[angle])
            valuesX[angle] = level.amplitudes[0] * s
            valuesY[angle] = level.amplitudes[1] * s
            valuesZ[angle] = level.amplitudes[2] * s
        }
        let k = level.checkpoints.count, o = level.obstacles.count
        var storage = [UInt64](repeating: 0, count: (k + 2 * o) * blockWords)
        valuesX.withUnsafeBufferPointer { x in
            valuesY.withUnsafeBufferPointer { y in
                valuesZ.withUnsafeBufferPointer { z in
                    storage.withUnsafeMutableBufferPointer { out in
                        let values = [x.baseAddress!, y.baseAddress!, z.baseAddress!]
                        let base = out.baseAddress!
                        for (j, ball) in level.checkpoints.enumerated() {
                            fillBlock(base + j * blockWords, values: values, ball: ball, half: ball.radius,
                                      segment: false, frequencyC: level.frequencyC)
                        }
                        for (i, ball) in level.obstacles.enumerated() {
                            fillBlock(base + (k + i) * blockWords, values: values, ball: ball,
                                      half: innerHalf(ball.radius), segment: false, frequencyC: level.frequencyC)
                            fillBlock(base + (k + o + i) * blockWords, values: values, ball: ball, half: ball.radius,
                                      segment: true, frequencyC: level.frequencyC)
                        }
                    }
                }
            }
        }
        return Tables(storage: storage, checkpoints: k, obstacles: o)
    }

    /// The x, y and z bit sets of `dials` in the block at `block`.
    private static func sets(_ block: UnsafePointer<UInt64>, _ dials: LissajousLabyrinthDials)
        -> (UnsafePointer<UInt64>, UnsafePointer<UInt64>, UnsafePointer<UInt64>) {
        (block + ((dials.frequencyA - 1) * phases + dials.phaseA) * words,
         block + (frequencies * phases + dials.frequencyB - 1) * words,
         block + (frequencies * phases + frequencies + dials.phaseC) * words)
    }

    /// The first tick at or after `from` set in all three bit sets, or −1.
    private static func first(_ s: (UnsafePointer<UInt64>, UnsafePointer<UInt64>, UnsafePointer<UInt64>),
                              from: Int) -> Int {
        if from >= LissajousLabyrinthLap.ticks { return -1 }
        var w = from >> 6
        var bits = s.0[w] & s.1[w] & s.2[w] & (UInt64.max << UInt64(from & 63))
        while true {
            if bits != 0 { return (w << 6) + bits.trailingZeroBitCount }
            w += 1
            if w == words { return -1 }
            bits = s.0[w] & s.1[w] & s.2[w]
        }
    }

    /// Whether the prefilters leave `dials` possible (false proves a loss).
    private static func possible(_ dials: LissajousLabyrinthDials, base: UnsafePointer<UInt64>,
                                 tables: Tables) -> Bool {
        var from = 0
        for j in 0..<tables.checkpoints {
            let tick = first(sets(base + j * blockWords, dials), from: from)
            if tick < 0 { return false }
            from = tick + 1
        }
        for i in 0..<tables.obstacles {
            let cube = sets(base + (tables.checkpoints + i) * blockWords, dials)
            if first(cube, from: 0) >= 0 { return false }
        }
        return true
    }

    /// The kernel's sample of `dials` at `tick` (the formula of `LissajousLabyrinthLap.samples`).
    private static func point(_ tick: Int, _ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel,
                              sine: UnsafePointer<Int16>) -> LissajousLabyrinthPoint {
        let mask = LissajousLabyrinthSine.mask
        let step = LissajousLabyrinthLap.phaseStep
        return LissajousLabyrinthPoint(
            x: level.amplitudes[0] * Int(sine[(dials.frequencyA * tick + step * dials.phaseA) & mask]),
            y: level.amplitudes[1] * Int(sine[(dials.frequencyB * tick) & mask]),
            z: level.amplitudes[2] * Int(sine[(level.frequencyC * tick + step * dials.phaseC
                                                  + LissajousLabyrinthSine.unitsPerTurn / 4) & mask]))
    }

    /// The exact decision on raw tables (see `wins(_:level:tables:)`).
    private static func exact(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel,
                              base: UnsafePointer<UInt64>, tables: Tables, sine: UnsafePointer<Int16>) -> Bool {
        let ticks = LissajousLabyrinthLap.ticks
        for i in 0..<tables.obstacles {
            let ball = level.obstacles[i]
            let s = sets(base + (tables.checkpoints + tables.obstacles + i) * blockWords, dials)
            for w in 0..<words {
                var bits = s.0[w] & s.1[w] & s.2[w]
                while bits != 0 {
                    let tick = (w << 6) + bits.trailingZeroBitCount
                    bits &= bits - 1
                    if LissajousLabyrinthLap.segmentTouches(point(tick, dials, level: level, sine: sine),
                                                            point((tick + 1) % ticks, dials, level: level, sine: sine),
                                                            ball: ball) {
                        return false
                    }
                }
            }
        }
        var from = 0
        for j in 0..<tables.checkpoints {
            let ball = level.checkpoints[j]
            let s = sets(base + j * blockWords, dials)
            while true {
                let tick = first(s, from: from)
                if tick < 0 { return false }
                from = tick + 1
                if LissajousLabyrinthLap.contains(ball, point(tick, dials, level: level, sine: sine)) { break }
            }
        }
        return true
    }

    /// Whether `dials` wins `level`, exactly: equal to `LissajousLabyrinthLap.verdict(dials, level:) == .won` for every
    /// valid setting. `tables` must be `tables(level)`.
    ///
    /// - Contact: a segment touches an obstacle only if its closest point lies strictly within the radius of the
    ///   centre, so on every axis the segment's coordinate interval meets the obstacle's bounding interval; only the
    ///   ticks whose segment passes all three axis tests get the kernel's `segmentTouches`.
    /// - Checkpoints: a sample inside a ball lies in its bounding box, so the kernel's greedy in-order scan (each
    ///   checkpoint taken at the first later tick whose sample is inside it) only needs the box ticks, in increasing
    ///   order, tested with the kernel's `contains`.
    static func wins(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel, tables: Tables) -> Bool {
        tables.storage.withUnsafeBufferPointer { storage in
            LissajousLabyrinthSine.table.withUnsafeBufferPointer { sine in
                exact(dials, level: level, base: storage.baseAddress!, tables: tables, sine: sine.baseAddress!)
            }
        }
    }

    /// Every legal setting that wins `level`, in `legalSettings()` order, and `work`, the number of settings that
    /// reached the exact decision.
    ///
    /// Two sound prefilters reject settings that cannot win:
    /// - checkpoints: the kernel's in-order checkpoint scan is followed on the checkpoint balls' bounding boxes,
    ///   supersets of the true visit ticks, so the greedy tick found for each checkpoint is never later than the
    ///   kernel's; a setting with no such tick cannot visit every checkpoint in order;
    /// - obstacles: a sample inside the largest integer cube strictly inside an obstacle ball (3·h² < r²) is strictly
    ///   inside the ball, so the segment starting there touches it and the lap is a contact.
    /// Every other setting gets the exact decision `wins(_:level:tables:)`.
    public static func winningSettings(_ level: LissajousLabyrinthLevel) -> (settings: [LissajousLabyrinthDials],
                                                                             work: Int) {
        winningSettings(level, in: 0..<legal.count)
    }

    /// The winning settings among `legalSettings()[range]` and the exact decisions spent (tests split the space).
    static func winningSettings(_ level: LissajousLabyrinthLevel,
                                in range: Range<Int>) -> (settings: [LissajousLabyrinthDials], work: Int) {
        let tables = tables(level)
        var settings: [LissajousLabyrinthDials] = []
        var work = 0
        tables.storage.withUnsafeBufferPointer { storage in
            LissajousLabyrinthSine.table.withUnsafeBufferPointer { sine in
                let base = storage.baseAddress!
                for dials in legal[range] where possible(dials, base: base, tables: tables) {
                    work += 1
                    if exact(dials, level: level, base: base, tables: tables, sine: sine.baseAddress!) {
                        settings.append(dials)
                    }
                }
            }
        }
        return (settings, work)
    }

    /// The legal settings the prefilters leave possible, in `legalSettings()` order: the ones the exact decision
    /// judges.
    static func admitted(_ level: LissajousLabyrinthLevel) -> [LissajousLabyrinthDials] {
        let tables = tables(level)
        var result: [LissajousLabyrinthDials] = []
        tables.storage.withUnsafeBufferPointer { storage in
            for dials in legal where possible(dials, base: storage.baseAddress!, tables: tables) {
                result.append(dials)
            }
        }
        return result
    }

    /// The proven shortest solution of `level`, or nil when no legal setting wins.
    ///
    /// Breadth-first search from the start over legal states, exploring `LissajousLabyrinthRules.moves(in:)` in order
    /// (dial order a, b, φ, ψ; values ascending) and keeping the first parent found; it stops at the first depth that
    /// holds a winning setting and picks the smallest winning (a, b, φ, ψ) of that depth.
    public static func solve(_ level: LissajousLabyrinthLevel) -> LissajousLabyrinthSolution? {
        let decided = winningSettings(level)
        guard !decided.settings.isEmpty else { return nil }
        let slots = frequencies * frequencies * phases * phases
        var winning = [Bool](repeating: false, count: slots)
        for dials in decided.settings { winning[index(dials)] = true }
        let rules = LissajousLabyrinthRules(level: level)
        var parent = [Int](repeating: -1, count: slots)
        var via = [LissajousLabyrinthAction?](repeating: nil, count: slots)
        var seen = [Bool](repeating: false, count: slots)
        var states: [LissajousLabyrinthDials?] = [LissajousLabyrinthDials?](repeating: nil, count: slots)
        let origin = index(level.start)
        seen[origin] = true
        states[origin] = level.start
        var frontier: [LissajousLabyrinthDials] = [level.start]
        var goal = -1
        while goal < 0 && !frontier.isEmpty {
            for dials in frontier {
                let i = index(dials)
                if winning[i] && (goal < 0 || i < goal) { goal = i }
            }
            if goal >= 0 { break }
            var next: [LissajousLabyrinthDials] = []
            for dials in frontier {
                let from = index(dials)
                for action in rules.moves(in: dials) {
                    guard let reached = rules.apply(action, to: dials) else { continue }
                    let to = index(reached)
                    if seen[to] { continue }
                    seen[to] = true
                    parent[to] = from
                    via[to] = action
                    states[to] = reached
                    next.append(reached)
                }
            }
            frontier = next
        }
        guard goal >= 0, let setting = states[goal] else { return nil }
        var actions: [LissajousLabyrinthAction] = []
        var cursor = goal
        while cursor != origin, let action = via[cursor] {
            actions.append(action)
            cursor = parent[cursor]
        }
        actions.reverse()
        return LissajousLabyrinthSolution(shortest: actions.count, actions: actions, setting: setting,
                                          winningSettings: decided.settings.count, work: decided.work)
    }
}
