// HarmonicBridgesResonance — feature 411 (R02-G12-01) T-R02G1201-002 (FR-R02G1201-001, 002, 003, 005, 014;
// SC-R02G1201-003; clarifications Q1, Q2, Q4). The exact standing-wave rules of Harmonic Bridges, in integer arithmetic
// only. A string of length L (1 … 6) with peg p (1 … 12) has the harmonics f_n = n · p / L for n in 1 … 5; a sounding
// tone of frequency F (1 … 72) and strength w (1 … 3) resonates mode n exactly when n · p = F · L with n in 1 … 5 (so a
// tone matches at most one mode). The time-averaged mean square of the displacement is measured, in quarters, at the
// five interior sample points k = 1 … 5 of six equal segments: E(k) = Σ w · q(n, k) over the step's resonating tones,
// with the fixed table q(n, k) = 4 sin²(nπk/6) ∈ {0, 1, 3, 4} (integer literals, never computed with floating point).
// A string is a bridge in a step exactly when E(k) reaches the threshold at all five samples. The bridges of a step
// form a graph on the islands; the start's reachable set is found breadth-first, islands in index order. The report
// is the truth metric: every swing, every bridge and every reachable set, per step. The broken-string rule: the first
// step whose goal is not reached, and the lowest-index string that joins an island reached in that step to one not
// reached and is not a bridge then (none when no string crosses that cut).

/// The fixed swing table and the averaged swing of a set of resonating modes.
public enum HarmonicBridgesSwing {
    /// The interior sample points of a string (k = 1 … 5 of six equal segments).
    public static let samples: Int = 5
    /// The highest allowed mode.
    public static let maxMode: Int = 5
    /// q(n, k) = 4 sin²(nπk/6) for n in 1 … 5 (rows) and k in 1 … 5 (columns), in quarters.
    static let table: [[Int]] = [
        [1, 3, 4, 3, 1],
        [3, 3, 0, 3, 3],
        [4, 0, 4, 0, 4],
        [3, 3, 0, 3, 3],
        [1, 3, 4, 3, 1],
    ]

    /// q(n, k) = 4 sin²(nπk/6) ∈ {0, 1, 3, 4} for `mode` n in 1 … 5 and `sample` k in 1 … 5; 0 outside those ranges.
    public static func quarter(mode: Int, sample: Int) -> Int {
        guard (1...maxMode).contains(mode), (1...samples).contains(sample) else { return 0 }
        return table[mode - 1][sample - 1]
    }

    /// The averaged swing E(1 … 5) = Σ strength · q(mode, k) of the given resonating modes, in quarters.
    public static func swing(modes: [(mode: Int, strength: Int)]) -> [Int] {
        var result: [Int] = Array(repeating: 0, count: samples)
        for entry in modes {
            for k in 1...samples { result[k - 1] += entry.strength * quarter(mode: entry.mode, sample: k) }
        }
        return result
    }
}

/// A drawing position on the 16 × 10 grid (x 0 … 15, y 0 … 9); it never decides a rule. Stored as `[x, y]`.
public struct HarmonicBridgesIsland: Sendable, Hashable, Codable {
    /// The column, 0 … 15.
    public let x: Int
    /// The row, 0 … 9.
    public let y: Int

    /// An island at (`x`, `y`); the level checks the ranges.
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Decodes `[x, y]`.
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        x = try c.decode(Int.self)
        y = try c.decode(Int.self)
        guard c.isAtEnd else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "an island is [x, y]")
        }
    }

    /// Encodes `[x, y]`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
    }
}

/// A sounding tone: a frequency F (1 … 72) with a strength w (1 … 3). Stored as `[F, w]`.
public struct HarmonicBridgesTone: Sendable, Hashable, Codable {
    /// The frequency, 1 … 72.
    public let frequency: Int
    /// The strength, 1 … 3.
    public let strength: Int

    /// A tone; the level checks the ranges.
    public init(frequency: Int, strength: Int) {
        self.frequency = frequency
        self.strength = strength
    }

    /// Decodes `[F, w]`.
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        frequency = try c.decode(Int.self)
        strength = try c.decode(Int.self)
        guard c.isAtEnd else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "a tone is [frequency, strength]")
        }
    }

    /// Encodes `[F, w]`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(frequency)
        try c.encode(strength)
    }
}

/// A suspended string joining islands `a` < `b`, with a length 1 … 6, a starting peg 1 … 12 and a locked flag (a locked
/// string's peg cannot be turned). Stored as `[a, b, length, peg, locked]`.
public struct HarmonicBridgesString: Sendable, Hashable, Codable {
    /// The lower island index.
    public let a: Int
    /// The higher island index.
    public let b: Int
    /// The length L, 1 … 6 units.
    public let length: Int
    /// The starting peg value p, 1 … 12.
    public let peg: Int
    /// Whether the peg cannot be turned.
    public let locked: Bool

    /// A string; the level checks the ranges and rules.
    public init(a: Int, b: Int, length: Int, peg: Int, locked: Bool = false) {
        self.a = a
        self.b = b
        self.length = length
        self.peg = peg
        self.locked = locked
    }

    /// The mode n in 1 … 5 that `tone` resonates when the peg is `peg` (n · peg = F · length), or nil when none.
    public func mode(of tone: HarmonicBridgesTone, peg: Int) -> Int? {
        guard peg > 0 else { return nil }
        let product: Int = tone.frequency * length
        guard product % peg == 0 else { return nil }
        let n: Int = product / peg
        return (1...HarmonicBridgesSwing.maxMode).contains(n) ? n : nil
    }

    /// Whether the string joins `island`.
    public func touches(_ island: Int) -> Bool { a == island || b == island }

    /// Decodes `[a, b, length, peg, locked]`.
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        a = try c.decode(Int.self)
        b = try c.decode(Int.self)
        length = try c.decode(Int.self)
        peg = try c.decode(Int.self)
        locked = try c.decode(Bool.self)
        guard c.isAtEnd else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "a string is [a, b, length, peg, locked]")
        }
    }

    /// Encodes `[a, b, length, peg, locked]`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(a)
        try c.encode(b)
        try c.encode(length)
        try c.encode(peg)
        try c.encode(locked)
    }
}

/// One string's resonance in one step: the mode each of the step's tones resonates, the five swings and the bridge.
public struct HarmonicBridgesResonance: Sendable, Hashable {
    /// The string index.
    public let string: Int
    /// The step index.
    public let step: Int
    /// The peg the resonance was computed for.
    public let peg: Int
    /// For each tone of the step, in order, the mode it resonates (nil when none).
    public let modes: [Int?]
    /// E(1 … 5), in quarters.
    public let swing: [Int]
    /// Whether every E(k) reaches the threshold.
    public let bridge: Bool

    /// The resonating modes, ascending.
    public var resonatingModes: [Int] { modes.compactMap { $0 }.sorted() }

    /// The resonance of `string` (index `index`) at `peg` in step `step` sounding `tones`, against `threshold`.
    public init(string: HarmonicBridgesString, index: Int, step: Int, tones: [HarmonicBridgesTone], peg: Int,
                threshold: Int) {
        var modes: [Int?] = []
        var resonating: [(mode: Int, strength: Int)] = []
        for tone in tones {
            let mode: Int? = string.mode(of: tone, peg: peg)
            modes.append(mode)
            if let mode { resonating.append((mode, tone.strength)) }
        }
        let swing: [Int] = HarmonicBridgesSwing.swing(modes: resonating)
        var bridge: Bool = true
        for value in swing where value < threshold { bridge = false }
        self.string = index
        self.step = step
        self.peg = peg
        self.modes = modes
        self.swing = swing
        self.bridge = bridge
    }
}

/// Where a crossing breaks: the first step whose goal is not reached and the broken string (nil when no string crosses
/// the cut between the start's reachable set and the rest).
public struct HarmonicBridgesBreak: Sendable, Hashable, Codable {
    /// The step index.
    public let step: Int
    /// The lowest-index non-bridge string joining a reached island to an unreached one, or nil.
    public let string: Int?

    /// A break at `step` naming `string`.
    public init(step: Int, string: Int?) {
        self.step = step
        self.string = string
    }
}

/// The truth metric (FR-R02G1201-014): every string's swing, every bridge and the start's reachable set, per step.
public struct HarmonicBridgesReport: Sendable, Equatable {
    /// E(1 … 5) as `swings[step][string][sample − 1]`.
    public let swings: [[[Int]]]
    /// Whether each string is a bridge, as `bridges[step][string]`.
    public let bridges: [[Bool]]
    /// Whether the start reaches each island over bridges, as `reached[step][island]`.
    public let reached: [[Bool]]
    /// The goal island.
    public let goal: Int

    /// The report of `strings` at `pegs` over `steps`, against `threshold`, on `islandCount` islands from `start` to
    /// `goal`. `pegs` holds one peg per string.
    public init(strings: [HarmonicBridgesString], pegs: [Int], steps: [[HarmonicBridgesTone]], threshold: Int,
                islandCount: Int, start: Int, goal: Int) {
        precondition(pegs.count == strings.count, "one peg per string")
        var swings: [[[Int]]] = []
        var bridges: [[Bool]] = []
        var reached: [[Bool]] = []
        for (stepIndex, tones) in steps.enumerated() {
            var stepSwings: [[Int]] = []
            var stepBridges: [Bool] = []
            for (index, string) in strings.enumerated() {
                let resonance = HarmonicBridgesResonance(string: string, index: index, step: stepIndex, tones: tones,
                                                         peg: pegs[index], threshold: threshold)
                stepSwings.append(resonance.swing)
                stepBridges.append(resonance.bridge)
            }
            swings.append(stepSwings)
            bridges.append(stepBridges)
            reached.append(Self.reachable(strings: strings, bridges: stepBridges, islandCount: islandCount,
                                          start: start))
        }
        self.swings = swings
        self.bridges = bridges
        self.reached = reached
        self.goal = goal
    }

    /// The islands the start reaches over the bridges, breadth-first with neighbours in index order.
    public static func reachable(strings: [HarmonicBridgesString], bridges: [Bool], islandCount: Int,
                                 start: Int) -> [Bool] {
        var adjacency: [[Int]] = Array(repeating: [], count: islandCount)
        for (index, string) in strings.enumerated() where bridges[index] {
            adjacency[string.a].append(string.b)
            adjacency[string.b].append(string.a)
        }
        for island in 0..<islandCount { adjacency[island].sort() }
        var seen: [Bool] = Array(repeating: false, count: islandCount)
        var queue: [Int] = [start]
        seen[start] = true
        var head: Int = 0
        while head < queue.count {
            let island: Int = queue[head]
            head += 1
            for next in adjacency[island] where !seen[next] {
                seen[next] = true
                queue.append(next)
            }
        }
        return seen
    }

    /// Whether the goal is reached in every step of the crossing window.
    public var goalReachedInEveryStep: Bool {
        for stepReached in reached where !stepReached[goal] { return false }
        return true
    }

    /// The bridge count of each step.
    public var bridgeCounts: [Int] {
        var counts: [Int] = []
        for stepBridges in bridges {
            var count: Int = 0
            for bridge in stepBridges where bridge { count += 1 }
            counts.append(count)
        }
        return counts
    }

    /// The broken-string rule for `strings`: nil when the goal is reached in every step; otherwise the first step whose
    /// goal is not reached and the lowest-index string joining an island reached in that step to one not reached that
    /// is not a bridge then (nil when no string crosses that cut).
    public func firstBreak(strings: [HarmonicBridgesString]) -> HarmonicBridgesBreak? {
        for (step, stepReached) in reached.enumerated() where !stepReached[goal] {
            for (index, string) in strings.enumerated() {
                let crosses: Bool = stepReached[string.a] != stepReached[string.b]
                if crosses && !bridges[step][index] { return HarmonicBridgesBreak(step: step, string: index) }
            }
            return HarmonicBridgesBreak(step: step, string: nil)
        }
        return nil
    }
}
