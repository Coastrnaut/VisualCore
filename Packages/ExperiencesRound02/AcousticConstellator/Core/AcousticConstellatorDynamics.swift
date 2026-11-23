// AcousticConstellatorDynamics — feature 421 (R02-G13-01) T-R02G1301-002 (FR-R02G1301-002, 003, 005, 007, 014;
// SC-R02G1301-003, 004; clarifications Q2, Q4). The exact phase rules of Acoustic Constellator, in integer arithmetic
// only. Phases live on a 12-step clock (0 … 11, modulo 12); the signed gap from star i to star j is φⱼ − φᵢ reduced to
// −5 … 6. The coupling table s(d) = sign(d) · t(|d|) with t(0 … 6) = 0, 1, 2, 2, 2, 1, 0 (2·sin(πd/6) rounded, fixed
// integer literals, never computed with floating point). One tick: star i's pull P is the sum of s(gap from i to j)
// over its current links, its coupling step is c = ⌊K · P / 4⌋ (toward minus infinity) clamped to −1 … 1, and every
// star moves at once to (φᵢ + ωᵢ + c) mod 12, every pull computed from the phases before the tick. The Kuramoto order
// parameter is exact: n²R² = |Σ e^{iπφ/6}|² = A + B√3 with A = n + Σ_{i<j} a(|gap|) and B = Σ_{i<j} b(|gap|) from the
// fixed table (a, b) for |gap| 0 … 6 = (2, 0), (0, 1), (1, 0), (0, 0), (−1, 0), (0, −1), (−2, 0); it is compared with
// an integer threshold by squaring with sign care. A listen decides in the fixed order: missing symbol pairs first,
// then per tick 1 … W: move, snap (every link whose |gap| exceeds the snap limit, for the rest of the listen), the
// symbol's connectivity over the remaining links, coherence (every symbol pair still linked and A + B√3 ≥ θ), hold
// (H consecutive coherent ticks win on that tick). The graph-isomorphism label is the lexicographically smallest
// upper-triangle adjacency string over all orderings of the stars (at most 8! orderings); it only reports.

/// A link between stars `a` < `b`, ordered by (`a`, `b`). Stored as `[a, b]`.
public struct AcousticConstellatorLink: Sendable, Hashable, Codable, Comparable {
    /// The lower star index.
    public let a: Int
    /// The higher star index.
    public let b: Int

    /// A link between `a` and `b` as given; the level and the play check that a < b and both stars exist.
    public init(a: Int, b: Int) {
        self.a = a
        self.b = b
    }

    /// The link between two distinct stars in either order, stored with the lower index first.
    public static func between(_ u: Int, _ v: Int) -> AcousticConstellatorLink {
        AcousticConstellatorLink(a: min(u, v), b: max(u, v))
    }

    /// Whether the link touches `star`.
    public func touches(_ star: Int) -> Bool { a == star || b == star }

    /// Ordered by `a`, then `b`.
    public static func < (lhs: AcousticConstellatorLink, rhs: AcousticConstellatorLink) -> Bool {
        lhs.a != rhs.a ? lhs.a < rhs.a : lhs.b < rhs.b
    }

    /// Decodes `[a, b]`.
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        a = try c.decode(Int.self)
        b = try c.decode(Int.self)
        guard c.isAtEnd else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "a link is [a, b]") }
    }

    /// Encodes `[a, b]`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(a)
        try c.encode(b)
    }
}

/// The 12-step phase clock: gaps, the coupling table, the tick and the exact order parameter.
public enum AcousticConstellatorClock {
    /// The number of phase steps on the clock.
    public static let steps: Int = 12
    /// t(0 … 6) = 0, 1, 2, 2, 2, 1, 0: 2·sin(πd/6) rounded to whole numbers.
    static let pullTable: [Int] = [0, 1, 2, 2, 2, 1, 0]
    /// (a, b) for |gap| 0 … 6: 2·cos(πd/6) = a + b√3.
    static let orderTable: [(a: Int, b: Int)] = [(2, 0), (0, 1), (1, 0), (0, 0), (-1, 0), (0, -1), (-2, 0)]

    /// `phase` reduced to 0 … 11.
    public static func reduce(_ phase: Int) -> Int {
        let r: Int = phase % steps
        return r < 0 ? r + steps : r
    }

    /// The signed gap from phase `from` to phase `to`, `to − from` reduced to −5 … 6.
    public static func gap(_ from: Int, _ to: Int) -> Int {
        let d: Int = reduce(to - from)
        return d > steps / 2 ? d - steps : d
    }

    /// The coupling s(d) = sign(d) · t(|d|) of signed gap `gap` (reduced to −5 … 6 first).
    public static func coupling(_ gap: Int) -> Int {
        let d: Int = Self.gap(0, gap)
        return d < 0 ? -pullTable[-d] : pullTable[d]
    }

    /// ⌊`value` / `divisor`⌋, rounded toward minus infinity (`divisor` > 0).
    static func floorDivide(_ value: Int, _ divisor: Int) -> Int {
        value >= 0 ? value / divisor : -((-value + divisor - 1) / divisor)
    }

    /// The coupling step of a pull: ⌊K · P / 4⌋ clamped to −1 … 1.
    public static func step(pull: Int, coupling strength: Int) -> Int {
        max(-1, min(1, floorDivide(strength * pull, 4)))
    }

    /// Star `star`'s pull: Σ s(gap from `star` to the other star) over the links in `links` that touch it.
    public static func pull(_ star: Int, phases: [Int], links: [AcousticConstellatorLink]) -> Int {
        var total: Int = 0
        for link in links where link.touches(star) {
            let other: Int = link.a == star ? link.b : link.a
            total += coupling(gap(phases[star], phases[other]))
        }
        return total
    }

    /// One tick: every star moves at once to (φᵢ + ωᵢ + c) mod 12 with c = ⌊K · P / 4⌋ clamped to −1 … 1, each pull
    /// computed over `links` from the phases before the tick.
    public static func tick(phases: [Int], rates: [Int], links: [AcousticConstellatorLink], coupling: Int) -> [Int] {
        var next: [Int] = phases
        for star in 0..<phases.count {
            let c: Int = step(pull: pull(star, phases: phases, links: links), coupling: coupling)
            next[star] = reduce(phases[star] + rates[star] + c)
        }
        return next
    }

    /// The exact order parameter n²R² = |Σ e^{iπφ/6}|² = a + b√3 of `phases`.
    public static func orderParts(_ phases: [Int]) -> (a: Int, b: Int) {
        var a: Int = phases.count
        var b: Int = 0
        for i in 0..<phases.count {
            for j in (i + 1)..<max(i + 1, phases.count) {
                let entry: (a: Int, b: Int) = orderTable[abs(gap(phases[i], phases[j]))]
                a += entry.a
                b += entry.b
            }
        }
        return (a, b)
    }

    /// Whether a + b√3 ≥ `threshold`, decided exactly: with D = θ − a, true when b ≥ 0 and (D ≤ 0 or 3b² ≥ D²), or
    /// b < 0 and D ≤ 0 and D² ≥ 3b².
    public static func atLeast(a: Int, b: Int, threshold: Int) -> Bool {
        let d: Int = threshold - a
        if b >= 0 { return d <= 0 || 3 * b * b >= d * d }
        return d <= 0 && d * d >= 3 * b * b
    }

    /// Whether `link` snaps at `phases`: its |gap| exceeds `limit`.
    public static func snaps(_ link: AcousticConstellatorLink, phases: [Int], limit: Int) -> Bool {
        abs(gap(phases[link.a], phases[link.b])) > limit
    }

    /// Whether `links` join every star of `stars` into one connected piece (stars indexed 0 ..< `count`).
    public static func joins(_ stars: [Int], links: [AcousticConstellatorLink], count: Int) -> Bool {
        guard let first = stars.first else { return true }
        var reached: [Bool] = Array(repeating: false, count: count)
        reached[first] = true
        var queue: [Int] = [first]
        var head: Int = 0
        while head < queue.count {
            let star: Int = queue[head]
            head += 1
            for link in links where link.touches(star) {
                let other: Int = link.a == star ? link.b : link.a
                if !reached[other] {
                    reached[other] = true
                    queue.append(other)
                }
            }
        }
        for star in stars where !reached[star] { return false }
        return true
    }
}

/// What a listen decides.
public enum AcousticConstellatorOutcome: Sendable, Hashable {
    /// H consecutive coherent ticks ended on `tick`.
    case won(tick: Int)
    /// A symbol pair is not linked; the payload is the lowest missing pair.
    case missing(AcousticConstellatorLink)
    /// On `tick` the remaining links stopped joining the symbol's stars; `link` is the lowest-index link snapped then.
    case disconnected(tick: Int, link: AcousticConstellatorLink)
    /// The window ended without a hold; the payload is the longest coherent run.
    case incoherent(longestRun: Int)
}

/// The truth metric of one listen: the phases, the snapped links, the order parameter and coherence at every tick
/// (tick 0 is the start, and is never counted as coherent), the longest coherent run and the outcome. When a listen
/// stops early (won, disconnected) the arrays end at that tick; a `missing` listen holds tick 0 only.
public struct AcousticConstellatorListen: Sendable, Equatable {
    /// The phases of every star, per tick 0 … the last tick.
    public let phases: [[Int]]
    /// The indices (into the listen's link list) of the links snapped on each tick; tick 0 is empty.
    public let snapped: [[Int]]
    /// [A, B] per tick, with n²R² = A + B√3.
    public let order: [[Int]]
    /// Whether each tick counted as coherent; tick 0 is false.
    public let coherent: [Bool]
    /// The longest run of consecutive coherent ticks.
    public let longestRun: Int
    /// The decision.
    public let outcome: AcousticConstellatorOutcome

    /// The last tick reported.
    public var lastTick: Int { phases.count - 1 }

    /// The coherent run ending on the last tick.
    public var currentRun: Int {
        var run: Int = 0
        for value in coherent.reversed() {
            guard value else { break }
            run += 1
        }
        return run
    }

    /// The number of links snapped over the whole listen.
    public var snappedCount: Int { snapped.reduce(0) { $0 + $1.count } }

    /// Whether the listen won.
    public var won: Bool {
        if case .won = outcome { return true }
        return false
    }

    /// Runs a listen of `links` (in their list order) from `phases`, with the stars' `rates`, the target `symbol`,
    /// coupling `coupling`, snap limit `snapLimit`, threshold `threshold`, hold `hold` and window `window`, in the
    /// fixed order: missing pairs, then per tick: move, snap, disconnection, coherence, hold.
    public static func run(rates: [Int], phases: [Int], links: [AcousticConstellatorLink],
                           symbol: [AcousticConstellatorLink], coupling: Int, snapLimit: Int, threshold: Int,
                           hold: Int, window: Int) -> AcousticConstellatorListen {
        let start: [Int] = phases
        let startOrder: (a: Int, b: Int) = AcousticConstellatorClock.orderParts(start)
        let present: Set<AcousticConstellatorLink> = Set(links)
        var missing: [AcousticConstellatorLink] = []
        for pair in symbol where !present.contains(pair) { missing.append(pair) }
        if let lowest = missing.min() {
            return AcousticConstellatorListen(phases: [start], snapped: [[]], order: [[startOrder.a, startOrder.b]],
                                              coherent: [false], longestRun: 0, outcome: .missing(lowest))
        }
        var symbolStars: [Int] = []
        for pair in symbol.sorted() {
            if !symbolStars.contains(pair.a) { symbolStars.append(pair.a) }
            if !symbolStars.contains(pair.b) { symbolStars.append(pair.b) }
        }
        var allPhases: [[Int]] = [start]
        var allSnapped: [[Int]] = [[]]
        var allOrder: [[Int]] = [[startOrder.a, startOrder.b]]
        var allCoherent: [Bool] = [false]
        var alive: [Bool] = Array(repeating: true, count: links.count)
        var current: [Int] = start
        var run: Int = 0
        var longest: Int = 0
        var outcome: AcousticConstellatorOutcome = .incoherent(longestRun: 0)
        var decided: Bool = false
        var tick: Int = 1
        while tick <= window && !decided {
            var remaining: [AcousticConstellatorLink] = []
            for index in 0..<links.count where alive[index] { remaining.append(links[index]) }
            current = AcousticConstellatorClock.tick(phases: current, rates: rates, links: remaining,
                                                     coupling: coupling)
            var snappedNow: [Int] = []
            for index in 0..<links.count where alive[index] {
                if AcousticConstellatorClock.snaps(links[index], phases: current, limit: snapLimit) {
                    snappedNow.append(index)
                }
            }
            for index in snappedNow { alive[index] = false }
            var left: [AcousticConstellatorLink] = []
            var leftSet: Set<AcousticConstellatorLink> = []
            for index in 0..<links.count where alive[index] {
                left.append(links[index])
                leftSet.insert(links[index])
            }
            let order: (a: Int, b: Int) = AcousticConstellatorClock.orderParts(current)
            allPhases.append(current)
            allSnapped.append(snappedNow)
            allOrder.append([order.a, order.b])
            if !AcousticConstellatorClock.joins(symbolStars, links: left, count: current.count) {
                allCoherent.append(false)
                outcome = .disconnected(tick: tick, link: links[snappedNow.first ?? 0])
                decided = true
                break
            }
            var whole: Bool = true
            for pair in symbol where !leftSet.contains(pair) { whole = false }
            let coherent: Bool = whole && AcousticConstellatorClock.atLeast(a: order.a, b: order.b,
                                                                             threshold: threshold)
            allCoherent.append(coherent)
            run = coherent ? run + 1 : 0
            longest = max(longest, run)
            if run >= hold {
                outcome = .won(tick: tick)
                decided = true
                break
            }
            tick += 1
        }
        if !decided { outcome = .incoherent(longestRun: longest) }
        return AcousticConstellatorListen(phases: allPhases, snapped: allSnapped, order: allOrder,
                                          coherent: allCoherent, longestRun: longest, outcome: outcome)
    }
}

/// The graph-isomorphism label of a link graph.
public enum AcousticConstellatorLabel {
    /// The lexicographically smallest upper-triangle adjacency string ("0" or "1" per pair (i < j), row by row) of
    /// `links` on `stars` stars, over all orderings of the stars. Isomorphic graphs have equal labels.
    public static func label(stars: Int, links: [AcousticConstellatorLink]) -> String {
        guard stars > 1 else { return "" }
        var adjacent: [[Bool]] = Array(repeating: Array(repeating: false, count: stars), count: stars)
        for link in links where link.a >= 0 && link.b < stars && link.a != link.b {
            adjacent[link.a][link.b] = true
            adjacent[link.b][link.a] = true
        }
        let pairCount: Int = stars * (stars - 1) / 2
        // The string as bits, the first pair the most significant: the smallest string is the smallest number.
        var best: UInt64 = UInt64.max
        var order: [Int] = Array(0..<stars)
        while true {
            var bits: UInt64 = 0
            for i in 0..<stars {
                for j in (i + 1)..<stars {
                    bits = (bits << 1) | (adjacent[order[i]][order[j]] ? 1 : 0)
                }
            }
            best = min(best, bits)
            guard nextOrdering(&order) else { break }
        }
        var text: String = ""
        for position in stride(from: pairCount - 1, through: 0, by: -1) {
            text.append((best >> UInt64(position)) & 1 == 1 ? "1" : "0")
        }
        return text
    }

    /// Advances `order` to the next ordering in lexicographic order; false after the last one.
    static func nextOrdering(_ order: inout [Int]) -> Bool {
        guard order.count > 1 else { return false }
        var i: Int = order.count - 2
        while i >= 0 && order[i] >= order[i + 1] { i -= 1 }
        guard i >= 0 else { return false }
        var j: Int = order.count - 1
        while order[j] <= order[i] { j -= 1 }
        order.swapAt(i, j)
        order[(i + 1)...].reverse()
        return true
    }
}
