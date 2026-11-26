// MicroscopicAuroraSolver — feature 482 (R02-G19-02) T-R02G1902-003 (FR-R02G1902-002; SC-R02G1902-001, 002, 005;
// clarification Q2; research R2, R3, R5). The certifying solver of Microscopic Aurora: on a level with sites and no
// starting well, the settings reachable with at most d actions are exactly the sets of at most d wells on distinct
// sites (a report depends only on the set of wells), so the solver judges depth 0 (no well), then every set of one well,
// then of two, …, each set listed by site, then strength 1 … 4, then sense (clockwise first). Each depth is ordered by the
// shape loss of each set's prefix (the set without its last well) judged one depth earlier, ties keeping the fixed order;
// every depth below the winning one is judged in full, so only the winning (last) depth's order affects the work. The first winning set ends the search: its placements in
// slot order, then `play`, replayed through the kernel's play. Work = sets judged, bounded at 1,200. The minimality proof
// is the count of sets at each smaller depth, every one judged and none winning; the nearest miss is the smallest loss
// among them.
import VisualCoreSimulation

/// The certifying solver.
public enum MicroscopicAuroraSolver {
    /// The bound on sets judged per level (the largest catalog search space is 1 + 48 + 960 = 1,009).
    public static let workBound: Int = 1_200

    /// The senses in search order.
    static let senses: [MicroscopicAuroraSense] = [.clockwise, .counterclockwise]

    /// Every set of `size` wells on distinct `sites`, in the fixed order: by site (ascending index), then strength
    /// 1 … 4, then sense (clockwise first); each set lists its wells in site order.
    public static func sets(sites: [MicroscopicAuroraCell], size: Int) -> [[MicroscopicAuroraWell]] {
        var result: [[MicroscopicAuroraWell]] = []
        var current: [MicroscopicAuroraWell] = []
        func extend(from start: Int) {
            if current.count == size {
                result.append(current)
                return
            }
            if start >= sites.count { return }
            for site in start..<sites.count {
                for strength in MicroscopicAuroraWell.strengths {
                    for sense in senses {
                        current.append(MicroscopicAuroraWell(cell: sites[site], strength: strength, sense: sense))
                        extend(from: site + 1)
                        current.removeLast()
                    }
                }
            }
        }
        extend(from: 0)
        return result
    }

    /// The shape loss of `report` on `level`: the stencil cells left unlit plus the cells lit outside the stencil.
    public static func loss(_ level: MicroscopicAuroraLevel, report: MicroscopicAuroraReport) -> Int {
        let stencil: Set<Int> = Set(level.stencil.map(\.index))
        var outside: Int = 0
        for index in report.density.indices where report.density[index] >= level.threshold {
            if !stencil.contains(index) { outside += 1 }
        }
        return (level.stencil.count - report.litStencil.count) + outside
    }

    /// The placements of `wells` in slot order (slot 0, 1, …).
    public static func placements(_ wells: [MicroscopicAuroraWell]) -> [MicroscopicAuroraAction] {
        var actions: [MicroscopicAuroraAction] = []
        for (slot, well) in wells.enumerated() { actions.append(.place(slot: slot, well: well)) }
        return actions
    }

    /// The fewest placements that win `level`, or nil for a level without sites, with a starting well, without a win
    /// within ``MicroscopicAuroraLevel/slots`` wells, or over `workBound` sets judged.
    public static func plan(_ level: MicroscopicAuroraLevel, workBound: Int = workBound) -> MicroscopicAuroraPlan? {
        guard let sites = level.sites, level.placedWells.isEmpty else { return nil }
        var work: Int = 0
        var setsByDepth: [Int] = []
        var nearestMiss: Int = Int.max
        var losses: [[MicroscopicAuroraWell]: Int] = [:]
        let deepest: Int = min(MicroscopicAuroraLevel.slots, sites.count)
        for depth in 0...deepest {
            var candidates: [[MicroscopicAuroraWell]] = sets(sites: sites, size: depth)
            if depth > 0 {
                var keys: [Int] = []
                keys.reserveCapacity(candidates.count)
                for set in candidates { keys.append(losses[Array(set.dropLast())] ?? Int.max) }
                let order: [Int] = candidates.indices.sorted { (keys[$0], $0) < (keys[$1], $1) }
                candidates = order.map { candidates[$0] }
            }
            var judged: Int = 0
            var depthNearest: Int = Int.max
            var next: [[MicroscopicAuroraWell]: Int] = [:]
            for set in candidates {
                guard work < workBound else { return nil }
                work += 1
                judged += 1
                let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(level, wells: set)
                if report.wins {
                    return MicroscopicAuroraPlan(actions: placements(set), wells: set, setsByDepth: setsByDepth,
                                                 nearestMiss: nearestMiss == Int.max ? 0 : nearestMiss, work: work)
                }
                let value: Int = loss(level, report: report)
                next[set] = value
                depthNearest = min(depthNearest, value)
            }
            setsByDepth.append(judged)
            // The nearest miss counts only fully judged smaller depths, never the winning depth's misses.
            nearestMiss = min(nearestMiss, depthNearest)
            losses = next
        }
        return nil
    }

    /// Whether replaying `actions` and then the play through the kernel's play wins `level`.
    public static func replayWins(_ level: MicroscopicAuroraLevel, actions: [MicroscopicAuroraAction]) -> Bool {
        var play: MicroscopicAuroraPlay = MicroscopicAuroraPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            try play.apply(.play, expecting: play.fingerprint)
        } catch {
            return false
        }
        return play.stage == .won
    }
}
