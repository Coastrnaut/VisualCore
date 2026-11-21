// HueCompassSolver — feature 332 (R02-G04-02) T-R02G0402-002/003 (FR-R02G0402-002; clarification Q2). The deduction
// solver of Hue Compass. The candidates are the bearings farther from the start than the bearing tolerance (the kernel
// forbids the others). A probe set partitions them by their clues at its bearings; it settles the level when every class
// is acceptable — some bearing within the bearing tolerance of every member and some band within the band tolerance of
// every member's band. The solver tries the empty set, then every single bearing, then every pair, each in increasing
// lexicographic order, and returns the first set that settles (depth bound 2); its work is the number of sets tried, at
// most 1 + 96 + 4,560 = 4,657.

/// Two targets that share every clue of a probe set and that no one selection accepts together.
public struct HueCompassAmbiguity: Sendable, Equatable, Hashable, Codable {
    /// The probe bearings, ascending (empty or one bearing).
    public let probes: [Int]
    /// The two targets, ascending.
    public let targets: [Int]

    /// An ambiguity of the given values.
    public init(probes: [Int], targets: [Int]) {
        self.probes = probes
        self.targets = targets
    }
}

/// The solver's result for one level.
public struct HueCompassSolution: Sendable, Equatable {
    /// The first settling probe set, bearings ascending.
    public let probes: [Int]
    /// The probe sets tried.
    public let work: Int
    /// The single bearing whose largest class is smallest (lowest bearing on a tie).
    public let bestSingle: Int
    /// The size of the largest class after `bestSingle`.
    public let largestAfterBestSingle: Int
    /// A smaller probe set that does not settle the level, with two targets it cannot separate; nil when `smallest` is 0.
    public let ambiguity: HueCompassAmbiguity?

    /// The smallest probe count.
    public var smallest: Int { probes.count }

    /// A solution of the given values.
    public init(probes: [Int], work: Int, bestSingle: Int, largestAfterBestSingle: Int, ambiguity: HueCompassAmbiguity?) {
        self.probes = probes
        self.work = work
        self.bestSingle = bestSingle
        self.largestAfterBestSingle = largestAfterBestSingle
        self.ambiguity = ambiguity
    }
}

/// The deduction solver of Hue Compass.
public enum HueCompassSolver {
    /// The largest probe set searched.
    public static let maximumDepth: Int = 2

    /// The candidate targets of `level`: the bearings 0 … 95 farther from the start than the bearing tolerance,
    /// ascending (the kernel forbids a target within the tolerance of the start).
    public static func candidates(_ level: HueCompassLevel) -> [Int] {
        var result: [Int] = []
        for b in 0..<HueCompassWheel.bearings
        where HueCompassWheel.bearingDistance(b, level.start) > level.bearingTolerance {
            result.append(b)
        }
        return result
    }

    /// The candidates of `level` grouped by their clues (hue gap and fog depth) at every bearing of `probes`: classes
    /// ordered by their smallest member, members ascending; one class of every candidate for no probes.
    public static func classes(_ level: HueCompassLevel, probes: [Int]) -> [[Int]] {
        let table: [[Int]] = clueTable(level)
        var groups: [[Int]] = [candidates(level)]
        for probe in probes { groups = refine(groups, by: table[HueCompassWheel.mod(probe, HueCompassWheel.bearings)]) }
        groups.sort { $0[0] < $1[0] }
        return groups
    }

    /// The smallest selection that wins for every bearing of `targets`: the first bearing 0 … 95 within the bearing
    /// tolerance of every target, then the first band 0 … 23 within the band tolerance of every target's band; nil
    /// when either does not exist.
    public static func selection(for targets: [Int], in level: HueCompassLevel) -> HueCompassSelection? {
        var bearing: Int?
        for b in 0..<HueCompassWheel.bearings {
            var fits: Bool = true
            for t in targets where HueCompassWheel.bearingDistance(b, t) > level.bearingTolerance {
                fits = false
                break
            }
            if fits {
                bearing = b
                break
            }
        }
        guard let bearing else { return nil }
        for band in 0..<HueCompassWheel.bands {
            var fits: Bool = true
            for t in targets where HueCompassWheel.bandDistance(band, level.band(of: t)) > level.bandTolerance {
                fits = false
                break
            }
            if fits { return HueCompassSelection(bearing: bearing, band: band) }
        }
        return nil
    }

    /// The first probe set of at most `depth` bearings that settles `level` — the empty set, then every single bearing,
    /// then every pair, each in increasing lexicographic order — with the work (sets tried, the settling one included),
    /// the best single probe and the ambiguity of the next smaller set; nil when no set within `depth` settles.
    public static func solve(_ level: HueCompassLevel, depth: Int = maximumDepth) -> HueCompassSolution? {
        let n: Int = HueCompassWheel.bearings
        let table: [[Int]] = clueTable(level)
        let masks: Masks = Masks(level)
        let all: [[Int]] = [candidates(level)]
        var singles: [[[Int]]] = []
        singles.reserveCapacity(n)
        var bestSingle: Int = 0
        var largestAfterBestSingle: Int = Int.max
        for a in 0..<n {
            let groups: [[Int]] = refine(all, by: table[a])
            singles.append(groups)
            var largest: Int = 0
            for g in groups where g.count > largest { largest = g.count }
            if largest < largestAfterBestSingle {
                largestAfterBestSingle = largest
                bestSingle = a
            }
        }
        var work: Int = 0
        var found: [Int]?
        if depth >= 0 {
            work += 1
            if masks.settles(all) { found = [] }
        }
        if found == nil && depth >= 1 {
            for a in 0..<n {
                work += 1
                if masks.settles(singles[a]) {
                    found = [a]
                    break
                }
            }
        }
        if found == nil && depth >= 2 {
            search: for a in 0..<n {
                for b in (a + 1)..<n {
                    work += 1
                    if masks.settles(refine(singles[a], by: table[b])) {
                        found = [a, b]
                        break search
                    }
                }
            }
        }
        guard let probes = found else { return nil }
        var ambiguity: HueCompassAmbiguity?
        if !probes.isEmpty {
            let smaller: [Int] = probes.count == 1 ? [] : [0]
            ambiguity = firstAmbiguity(level, probes: smaller)
        }
        return HueCompassSolution(probes: probes, work: work, bestSingle: bestSingle,
                                  largestAfterBestSingle: largestAfterBestSingle, ambiguity: ambiguity)
    }

    /// The first pair (t, u), t < u, in the first class of `probes` that has one, whose members no one selection
    /// accepts together; nil when every pair of every class has a selection.
    static func firstAmbiguity(_ level: HueCompassLevel, probes: [Int]) -> HueCompassAmbiguity? {
        for group in classes(level, probes: probes) where selection(for: group, in: level) == nil {
            for i in 0..<group.count {
                for j in (i + 1)..<group.count where selection(for: [group[i], group[j]], in: level) == nil {
                    return HueCompassAmbiguity(probes: probes, targets: [group[i], group[j]])
                }
            }
        }
        return nil
    }

    /// The clue code of every probe bearing (row) for every hypothetical target (column): hue gap × 512 + fog depth,
    /// the same values `level.clue(at:)` gives when the target is the column's bearing.
    static func clueTable(_ level: HueCompassLevel) -> [[Int]] {
        let n: Int = HueCompassWheel.bearings
        // Prefix sums over the fog repeated twice, so any circular run is one difference.
        var prefix: [Int] = [0]
        prefix.reserveCapacity(2 * n + 1)
        for i in 0..<(2 * n) { prefix.append(prefix[i] + level.fog[i % n]) }
        var bands: [Int] = []
        for b in 0..<n { bands.append(level.band(of: b)) }
        var table: [[Int]] = []
        table.reserveCapacity(n)
        for probe in 0..<n {
            var row: [Int] = []
            row.reserveCapacity(n)
            for t in 0..<n {
                let d: Int = HueCompassWheel.mod(t - probe, n)
                var depth: Int = 0
                if d > 1 && d < n - 1 {
                    // Counter-clockwise from the probe when that arc is the shorter or equal one, else clockwise.
                    let start: Int = d <= n / 2 ? (probe + 1) % n : (t + 1) % n
                    let count: Int = d <= n / 2 ? d - 1 : n - d - 1
                    depth = prefix[start + count] - prefix[start]
                }
                row.append(HueCompassWheel.bandDistance(bands[probe], bands[t]) * 512 + depth)
            }
            table.append(row)
        }
        return table
    }

    /// Every group split by the clue codes of one probe row; subgroups in order of first appearance, members in order.
    static func refine(_ groups: [[Int]], by row: [Int]) -> [[Int]] {
        var result: [[Int]] = []
        var slot: [Int: Int] = [:]
        for group in groups {
            slot.removeAll(keepingCapacity: true)
            for t in group {
                let code: Int = row[t]
                if let index = slot[code] {
                    result[index].append(t)
                } else {
                    slot[code] = result.count
                    result.append([t])
                }
            }
        }
        return result
    }

    /// Bit masks of the acceptable bearings and bands of each target, for fast class checks.
    struct Masks {
        /// For each target bearing: the bearings within the bearing tolerance (bits 0 … 63, then 64 … 95).
        let low: [UInt64]
        let high: [UInt64]
        /// For each target bearing: the bands within the band tolerance of its band.
        let bands: [UInt32]

        init(_ level: HueCompassLevel) {
            var low: [UInt64] = []
            var high: [UInt64] = []
            var bands: [UInt32] = []
            for t in 0..<HueCompassWheel.bearings {
                var l: UInt64 = 0
                var h: UInt64 = 0
                for b in 0..<HueCompassWheel.bearings
                where HueCompassWheel.bearingDistance(b, t) <= level.bearingTolerance {
                    if b < 64 { l |= UInt64(1) << UInt64(b) } else { h |= UInt64(1) << UInt64(b - 64) }
                }
                var m: UInt32 = 0
                for band in 0..<HueCompassWheel.bands
                where HueCompassWheel.bandDistance(band, level.band(of: t)) <= level.bandTolerance {
                    m |= UInt32(1) << UInt32(band)
                }
                low.append(l)
                high.append(h)
                bands.append(m)
            }
            self.low = low
            self.high = high
            self.bands = bands
        }

        /// Whether every group has a bearing and a band acceptable for all its members.
        func settles(_ groups: [[Int]]) -> Bool {
            for group in groups {
                var l: UInt64 = ~0
                var h: UInt64 = ~0
                var m: UInt32 = ~0
                for t in group {
                    l &= low[t]
                    h &= high[t]
                    m &= bands[t]
                }
                if (l == 0 && h == 0) || m == 0 { return false }
            }
            return true
        }
    }
}
