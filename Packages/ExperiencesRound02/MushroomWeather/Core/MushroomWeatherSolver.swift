// MushroomWeatherSolver — feature 492 (R02-G20-02) T-R02G2002-003 (FR-R02G2002-002; SC-R02G2002-001, 002, 005;
// clarification Q2). The certifying solver of Mushroom Weather: a report depends only on the set of pod cells, the vent
// states and the moonlight, and from a start with no pod the fewest actions reaching an arrangement are its pod count
// plus the vents it toggles plus one when the moonlight differs (a move replaces a removal and a placement, so this is
// exact). On a level with sites and no starting pod the solver judges depth 0 (the start), then every arrangement at
// distance 1, 2, …; within a depth by pod count ascending, then vent count ascending, then pod site combinations and
// vent combinations in lexicographic order, then the new moonlight ascending, skipping the start's. Each depth after
// the first is ordered by the band loss of each arrangement's parent (the arrangement without its last action: the
// moonlight change, else the last vent toggle, else the last pod) judged one depth earlier, ties keeping the fixed
// order; every depth below the winning one is judged in full, so only the winning (last) depth's order affects the
// work and the plan, and the smaller depths are in effect judged in the fixed order. The first winning arrangement ends
// the search: its placements in slot order, then its vent toggles, then its moonlight change, then `run`, replayed
// through the kernel's play. Work = arrangements judged, bounded at 1,500 (above the largest catalog search space up to
// a plan depth, band 5: 1 + 12 + 63 + 192 + 378 = 1,144). The minimality proof is the count of arrangements at each
// smaller depth, every one judged and none winning; the nearest miss is the smallest band loss among them. Integers
// only; no clock, no random source. Modelled on `MicroscopicAuroraSolver` (feature 482).
import VisualCoreSimulation

/// The certifying solver.
public enum MushroomWeatherSolver {
    /// The bound on arrangements judged per level.
    public static let workBound: Int = 1_500

    /// An arrangement in the solver's terms: pod site indices (ascending, placed in slots 0, 1, …), toggled vent indices
    /// (ascending) and the new moonlight (nil when unchanged).
    struct Choice: Hashable {
        /// The site indices of the pods, ascending.
        let pods: [Int]
        /// The toggled vent indices, ascending.
        let vents: [Int]
        /// The new moonlight, nil when unchanged.
        let moonlight: Int?

        /// The choice without its last action: the moonlight change, else the last vent toggle, else the last pod.
        var parent: Choice {
            if moonlight != nil { return Choice(pods: pods, vents: vents, moonlight: nil) }
            if !vents.isEmpty { return Choice(pods: pods, vents: Array(vents.dropLast()), moonlight: nil) }
            return Choice(pods: Array(pods.dropLast()), vents: [], moonlight: nil)
        }
    }

    /// Every `k`-combination of 0 ..< `n` in lexicographic order.
    static func combinations(_ n: Int, _ k: Int) -> [[Int]] {
        guard k >= 0, k <= n else { return [] }
        var result: [[Int]] = []
        var current: [Int] = []
        func extend(_ start: Int) {
            if current.count == k {
                result.append(current)
                return
            }
            if start >= n { return }
            for i in start..<n {
                current.append(i)
                extend(i + 1)
                current.removeLast()
            }
        }
        extend(0)
        return result
    }

    /// Every choice at distance exactly `depth` in the fixed order: pod count ascending, then vent count ascending (so a
    /// moonlight change comes last), then pod site combinations and vent combinations in lexicographic order, then the
    /// new moonlight ascending, skipping `startMoonlight`.
    static func choices(sites: Int, slots: Int, vents: Int, startMoonlight: Int, depth: Int) -> [Choice] {
        var result: [Choice] = []
        guard depth >= 0 else { return result }
        for podCount in 0...min(slots, sites, depth) {
            for ventCount in 0...min(vents, depth - podCount) {
                let moonlightChanges: Int = depth - podCount - ventCount
                guard moonlightChanges <= 1 else { continue }
                let podSets: [[Int]] = combinations(sites, podCount)
                let ventSets: [[Int]] = combinations(vents, ventCount)
                for pods in podSets {
                    for toggled in ventSets {
                        if moonlightChanges == 0 {
                            result.append(Choice(pods: pods, vents: toggled, moonlight: nil))
                        } else {
                            for level in MushroomWeatherLevel.moonlightLevels where level != startMoonlight {
                                result.append(Choice(pods: pods, vents: toggled, moonlight: level))
                            }
                        }
                    }
                }
            }
        }
        return result
    }

    /// The choices of `level` at distance `depth` from its start.
    static func choices(_ level: MushroomWeatherLevel, depth: Int) -> [Choice] {
        choices(sites: level.sites?.count ?? 0, slots: level.podRules.slots, vents: level.vents.count,
                startMoonlight: level.start.moonlight, depth: depth)
    }

    /// The arrangement `choice` asks for on `level`.
    static func arrangement(_ level: MushroomWeatherLevel, _ choice: Choice) -> MushroomWeatherArrangement {
        let sites: [MushroomWeatherCell] = level.sites ?? []
        var pods: [MushroomWeatherCell?] = Array(repeating: nil, count: level.podRules.slots)
        for (slot, site) in choice.pods.enumerated() { pods[slot] = sites[site] }
        var vents: [Bool] = level.start.ventsOpen
        for index in choice.vents { vents[index].toggle() }
        return MushroomWeatherArrangement(pods: pods, ventsOpen: vents,
                                          moonlight: choice.moonlight ?? level.start.moonlight)
    }

    /// Every arrangement of `level` at distance exactly `depth` from its start, in the fixed order: pod count, vent
    /// count, pod site and vent combinations (lexicographic), new moonlight (ascending, skipping the start's). Pods
    /// stand in slots 0, 1, … in site order; empty for a level without sites.
    public static func arrangements(_ level: MushroomWeatherLevel, depth: Int) -> [MushroomWeatherArrangement] {
        guard level.sites != nil else { return [] }
        return choices(level, depth: depth).map { arrangement(level, $0) }
    }

    /// The fewest arrangement actions from `start`, which holds no pod, to `arrangement`: its pod count plus the vents
    /// whose state differs plus one when the moonlight differs.
    public static func distance(_ arrangement: MushroomWeatherArrangement,
                                from start: MushroomWeatherArrangement) -> Int {
        var toggled: Int = 0
        for (index, open) in arrangement.ventsOpen.enumerated()
            where index < start.ventsOpen.count && open != start.ventsOpen[index] { toggled += 1 }
        return arrangement.placedPods.count + toggled + (arrangement.moonlight == start.moonlight ? 0 : 1)
    }

    /// The band loss of `report` on `level`: Σ over colonies of max(0, low − h, h − high) for its humidity h after the
    /// last cycle run, plus K − min(K, final run); plus M per colony when the run fails `dried` or `mold`.
    public static func loss(_ level: MushroomWeatherLevel, report: MushroomWeatherReport) -> Int {
        var total: Int = 0
        for (index, colony) in level.colonies.enumerated() {
            let humidity: Int = report.humidity[level.index(of: colony.cell)]
            total += max(0, colony.low - humidity, humidity - colony.high)
            total += level.required - min(level.required, report.colonies[index].finalRun)
        }
        switch report.failure {
        case .dried, .mold: total += level.moldBound * level.colonies.count
        default: break
        }
        return total
    }

    /// The actions reaching `arrangement` from `level`'s start: the placements in slot order, then the vent toggles
    /// (ascending index), then the moonlight change.
    public static func actions(_ arrangement: MushroomWeatherArrangement,
                               level: MushroomWeatherLevel) -> [MushroomWeatherAction] {
        var result: [MushroomWeatherAction] = []
        for (slot, pod) in arrangement.pods.enumerated() {
            if let pod, level.start.pods.indices.contains(slot), level.start.pods[slot] != pod {
                result.append(.place(slot: slot, cell: pod))
            }
        }
        for (index, open) in arrangement.ventsOpen.enumerated()
            where index < level.start.ventsOpen.count && open != level.start.ventsOpen[index] {
            result.append(.vent(index: index, open: open))
        }
        if arrangement.moonlight != level.start.moonlight { result.append(.moonlight(level: arrangement.moonlight)) }
        return result
    }

    /// The fewest arrangement actions that win `level`, or nil for a level without sites, with a starting pod, without
    /// a win within its budget or over `workBound` arrangements judged.
    public static func plan(_ level: MushroomWeatherLevel, workBound: Int = workBound) -> MushroomWeatherPlan? {
        guard let sites = level.sites, level.start.placedPods.isEmpty else { return nil }
        let deepest: Int = min(level.budget, min(level.podRules.slots, sites.count) + level.vents.count + 1)
        var work: Int = 0
        var arrangementsByDepth: [Int] = []
        var nearestMiss: Int = Int.max
        var losses: [Choice: Int] = [:]
        for depth in 0...deepest {
            var candidates: [Choice] = choices(level, depth: depth)
            if depth > 0 {
                var keys: [Int] = []
                keys.reserveCapacity(candidates.count)
                for choice in candidates { keys.append(losses[choice.parent] ?? Int.max) }
                let order: [Int] = candidates.indices.sorted { (keys[$0], $0) < (keys[$1], $1) }
                candidates = order.map { candidates[$0] }
            }
            var next: [Choice: Int] = [:]
            var depthNearest: Int = Int.max
            for choice in candidates {
                guard work < workBound else { return nil }
                work += 1
                let arrangement: MushroomWeatherArrangement = arrangement(level, choice)
                let report: MushroomWeatherReport = MushroomWeatherForest.report(level, arrangement: arrangement)
                if report.wins {
                    return MushroomWeatherPlan(actions: actions(arrangement, level: level), arrangement: arrangement,
                                               arrangementsByDepth: arrangementsByDepth,
                                               nearestMiss: nearestMiss == Int.max ? 0 : nearestMiss, work: work)
                }
                let value: Int = loss(level, report: report)
                next[choice] = value
                depthNearest = min(depthNearest, value)
            }
            arrangementsByDepth.append(candidates.count)
            nearestMiss = min(nearestMiss, depthNearest)
            losses = next
        }
        return nil
    }

    /// Whether `actions` followed by `run` win `level` through the kernel's play (begin, dismissTutorial when the level
    /// has one, each action against the current fingerprint, then the run).
    public static func replayWins(_ level: MushroomWeatherLevel, actions: [MushroomWeatherAction]) -> Bool {
        var play: MushroomWeatherPlay = MushroomWeatherPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            try play.apply(.run, expecting: play.fingerprint)
        } catch {
            return false
        }
        return play.stage == .won
    }
}
