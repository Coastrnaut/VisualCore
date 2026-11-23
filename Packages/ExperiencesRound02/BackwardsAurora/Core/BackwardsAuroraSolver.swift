// BackwardsAuroraSolver — feature 392 (R02-G10-02) T-R02G1002-003 (FR-R02G1002-002; clarification Q2). The smallest
// reversal count of a level and a winning sequence that proves it.
//
// The bad bends β of a wave are its interior positions with |b| > L. A reversal gives new values only to the bends at
// its at most four seam positions (the bends strictly inside the section keep their values in reverse order, the others
// are untouched), so β falls by at most 4 per reversal; a win needs a smooth wave (β = 0), so no sequence of fewer than
// ⌈β / 4⌉ reversals wins. The solver is an iterative-deepening depth-first search over reversible sections in the rules'
// order (start, then end; lengths within the level's sections; palindromes skipped) from the opening wave, with the
// bound starting at ⌈β / 4⌉ and growing up to the budget, pruning a node when its depth plus ⌈β / 4⌉ exceeds the bound;
// a reversal that tears the aurora (a seam bend above B) is a leaf, as is the budget. The first winning sequence found
// at a bound is the smallest, because every smaller bound was searched completely; when it is found at the starting
// bound, the seam count alone proves it. Work is the reversals evaluated, counted and bounded; beyond the bound the
// search gives up (nil). Integers only; deterministic.

/// The seam-count lower bound of a level.
public struct BackwardsAuroraBound: Sendable, Hashable, Codable {
    /// The opening wave's bad bends β.
    public let badBends: Int

    /// A bound of `badBends` bad bends.
    public init(badBends: Int) {
        self.badBends = badBends
    }

    /// The smallest reversal count the bound allows, ⌈β / 4⌉.
    public var smallest: Int { (badBends + 3) / 4 }
}

/// A certified solution: the smallest reversal count, a winning sequence of that length and the work spent.
public struct BackwardsAuroraSolution: Sendable, Equatable, Codable {
    /// The smallest reversal count.
    public let smallest: Int
    /// A winning sequence of `smallest` reversals; the last one wins.
    public let actions: [BackwardsAuroraAction]
    /// The reversals evaluated.
    public let work: Int

    /// A solution of the given values.
    public init(smallest: Int, actions: [BackwardsAuroraAction], work: Int) {
        self.smallest = smallest
        self.actions = actions
        self.work = work
    }
}

/// The solver of Backwards Aurora.
public enum BackwardsAuroraSolver {
    /// The most reversals one solve may evaluate.
    public static let workBound: Int = 20_000

    /// The number of interior bends of `wave` with |b| > `limit`.
    public static func badBends(_ wave: BackwardsAuroraWave, limit: Int) -> Int {
        var count: Int = 0
        for k in wave.interior where abs(wave.bend(at: k)) > limit { count += 1 }
        return count
    }

    /// The seam-count lower bound of `level`'s opening wave.
    public static func lowerBound(_ level: BackwardsAuroraLevel) -> BackwardsAuroraBound {
        BackwardsAuroraBound(badBends: badBends(level.opening, limit: level.bendLimit))
    }

    /// A winning sequence of the smallest length within the budget, or nil when the search finds none within
    /// `workBound` reversals evaluated (or none exists within the budget).
    public static func solve(_ level: BackwardsAuroraLevel, workBound: Int = workBound) -> BackwardsAuroraSolution? {
        deepen(level, from: level.opening, most: level.budget, workBound: workBound)
    }

    /// The iterative deepening shared by the certification and the continuation search: from `wave`, bounds from
    /// ⌈β / 4⌉ (β the bad bends of `wave`) up to `most`, each searched depth-first with the seam-count pruning; the
    /// first winning sequence found, or nil when ⌈β / 4⌉ exceeds `most`, when no bound up to `most` wins or when the
    /// search reaches `workBound` reversals evaluated.
    static func deepen(_ level: BackwardsAuroraLevel, from wave: BackwardsAuroraWave, most: Int,
                       workBound: Int) -> BackwardsAuroraSolution? {
        let start: Int = (badBends(wave, limit: level.bendLimit) + 3) / 4
        guard start <= most else { return nil }
        var search = Search(level: level, workBound: workBound)
        var bound: Int = start
        while bound <= most {
            var path: [BackwardsAuroraAction] = []
            let found: Bool = search.dfs(wave, depth: 0, bound: bound, path: &path)
            if found { return BackwardsAuroraSolution(smallest: path.count, actions: path, work: search.work) }
            if search.exhausted { return nil }
            bound += 1
        }
        return nil
    }

    /// Whether `actions` played from `level`'s opening win on the last one, without tearing, within the budget, and
    /// not earlier.
    public static func wins(_ level: BackwardsAuroraLevel, actions: [BackwardsAuroraAction]) -> Bool {
        guard !actions.isEmpty, actions.count <= level.budget else { return false }
        var wave: BackwardsAuroraWave = level.opening
        for (index, action) in actions.enumerated() {
            guard case let .reverse(start, end) = action, isReversible(level, wave, start: start, end: end) else {
                return false
            }
            wave = wave.reversed(start: start, end: end)
            if tears(level, wave, start: start, end: end) { return false }
            let won: Bool = level.wins(wave)
            if won != (index == actions.count - 1) { return false }
        }
        return true
    }

    /// Whether the section [start, end] may be reversed on `wave` in `level`: inside the wave, a length within the
    /// level's sections and not a palindrome.
    static func isReversible(_ level: BackwardsAuroraLevel, _ wave: BackwardsAuroraWave, start: Int, end: Int) -> Bool {
        guard start >= 0, start < end, end < wave.count, level.sectionLengths.contains(end - start + 1) else {
            return false
        }
        return !wave.isPalindrome(start: start, end: end)
    }

    /// Whether `wave`, just reversed on [start, end], has a seam bend beyond the breaking limit.
    static func tears(_ level: BackwardsAuroraLevel, _ wave: BackwardsAuroraWave, start: Int, end: Int) -> Bool {
        for k in BackwardsAuroraWave.seams(start: start, end: end, count: wave.count)
        where abs(wave.bend(at: k)) > level.breakingLimit {
            return true
        }
        return false
    }

    /// The search state: the level, the work counted and whether the work bound was reached.
    struct Search {
        let level: BackwardsAuroraLevel
        let workBound: Int
        var work: Int = 0
        var exhausted: Bool = false

        init(level: BackwardsAuroraLevel, workBound: Int) {
            self.level = level
            self.workBound = workBound
        }

        /// Depth-first search below `wave` at `depth` for a win within `bound` reversals; appends the winning
        /// reversals to `path`.
        mutating func dfs(_ wave: BackwardsAuroraWave, depth: Int, bound: Int,
                          path: inout [BackwardsAuroraAction]) -> Bool {
            if depth > 0 && level.wins(wave) { return true }
            if depth >= bound { return false }
            let count: Int = wave.count
            let limit: Int = level.bendLimit
            let bad: Int = BackwardsAuroraSolver.badBends(wave, limit: limit)
            for start in 0..<(count - 1) {
                for end in (start + 1)..<count {
                    guard BackwardsAuroraSolver.isReversible(level, wave, start: start, end: end) else { continue }
                    if work >= workBound {
                        exhausted = true
                        return false
                    }
                    work += 1
                    let seams: [Int] = BackwardsAuroraWave.seams(start: start, end: end, count: count)
                    var before: Int = 0
                    for k in seams where abs(wave.bend(at: k)) > limit { before += 1 }
                    let next: BackwardsAuroraWave = wave.reversed(start: start, end: end)
                    var after: Int = 0
                    var torn: Bool = false
                    for k in seams {
                        let b: Int = abs(next.bend(at: k))
                        if b > limit { after += 1 }
                        if b > level.breakingLimit { torn = true }
                    }
                    if torn { continue }
                    let remaining: Int = bad - before + after
                    if depth + 1 + (remaining + 3) / 4 > bound { continue }
                    path.append(.reverse(start, end))
                    if dfs(next, depth: depth + 1, bound: bound, path: &path) { return true }
                    path.removeLast()
                    if exhausted { return false }
                }
            }
            return false
        }
    }
}

// MARK: - Continuations — feature 395 (R02-G10-05) T-R02G1005-002 (FR-R02G1005-002; SC-R02G1005-002; clarification Q1)
//
// `solve(_:from:reversalsLeft:workBound:)` looks for the fewest further reversals that win from a wave of a play: the
// certification's iterative deepening (the same section order, the same seam-count pruning, a tearing reversal a leaf)
// started at the given wave, with the bound starting at ⌈β / 4⌉ of that wave and growing up to the reversals left. A
// found sequence never tears, wins on its last reversal and not before (every shorter bound was searched completely
// and every node is checked for a win before it is expanded), and fits in the reversals left, so the play never
// reaches its budget before the win: the play's order tear, win, budget accepts it. From the opening wave with the
// whole budget left it is exactly the certification. Following a found sequence one reversal at a time and searching
// again from each new wave finds the rest within the same work: the second search's bounds below n − 1 are the
// subtree under the first reversal that the first search explored completely at bounds below n, and its bound n − 1
// is the part of the first search's bound n under that reversal, explored until the same win.

extension BackwardsAuroraSolver {
    /// The fewest further reversals (at most `reversalsLeft`) that win from `wave` in `level`, without tearing on the
    /// way and winning on the last one only; nil when `reversalsLeft` is below 1, when ⌈β / 4⌉ of `wave` exceeds it,
    /// when none exists within it or when the search reaches `workBound` reversals evaluated. The solution's
    /// `smallest` is its reversal count and `work` the reversals evaluated.
    public static func solve(_ level: BackwardsAuroraLevel, from wave: BackwardsAuroraWave, reversalsLeft: Int,
                             workBound: Int = workBound) -> BackwardsAuroraSolution? {
        guard reversalsLeft >= 1, wave.count == level.count else { return nil }
        return deepen(level, from: wave, most: reversalsLeft, workBound: workBound)
    }
}
