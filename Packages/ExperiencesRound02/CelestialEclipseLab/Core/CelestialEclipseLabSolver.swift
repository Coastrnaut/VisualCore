// CelestialEclipseLabSolver — feature 462 (R02-G17-02) T-R02G1702-003 (FR-R02G1702-002; SC-R02G1702-001, 002, 005;
// clarification Q2). The certifying solver of Celestial Eclipse Lab: the catalog's "analytical overlap interval
// enumeration and phase search". A later phase change of a body overrides an earlier one, so the settings reachable
// with at most d phase changes are exactly the phase vectors that differ from the start on at most d movable bodies;
// the solver searches them by depth d = 1, 2, … (depth 0 is the start, which a valid level never wins): at each depth
// the subsets of d movable bodies in lexicographic order of body numbers, and within a subset the new phases in
// lexicographic order (each 0 … period − 1 except the starting phase). Each setting is judged with a pair-interval
// table built once per level: for every pair of bodies and every pair of their phases, the pair's eclipse intervals
// over the horizon by the kernel's exact overlap and visibility rules; a setting's intervals are the merge of its
// pairs' lists in timeline order (first tick, front, back), walked by the kernel's judge (a match advances; any other
// event fails; events after the last match are ignored; targets left at the end fail). The first winning setting ends
// the search; the plan is its phase changes in body order. Work = settings judged (the start included), counted and
// bounded; over the bound, or past the most changes asked for, there is no plan. The minimality proof is the count of
// settings at each smaller depth, every one judged and none winning. Nothing here reads a clock.

/// A minimal plan of a level: its phase changes in body order, the settings judged at each smaller depth and the work.
public struct CelestialEclipseLabPlan: Sendable, Equatable, Codable {
    /// The phase changes of the plan, in body order (each `.phase(body, offset)`); the `run` is not part of it.
    public let actions: [CelestialEclipseLabAction]
    /// The settings judged at depths 0 … size − 1 (depth 0 is the start alone: 1); none won.
    public let settingsByDepth: [Int]
    /// The settings judged before the plan was found, the start included.
    public let work: Int

    /// A plan of the given values.
    public init(actions: [CelestialEclipseLabAction], settingsByDepth: [Int], work: Int) {
        self.actions = actions
        self.settingsByDepth = settingsByDepth
        self.work = work
    }

    /// The number of phase changes.
    public var size: Int { actions.count }

    /// The settings judged at every smaller depth together.
    public var settingsSearched: Int { settingsByDepth.reduce(0, +) }

    /// The phases of `level` after the plan's phase changes.
    public func phases(from level: CelestialEclipseLabLevel) -> [Int] {
        var phases: [Int] = level.phases
        for action in actions {
            if case .phase(let body, let offset) = action, body >= 0, body < phases.count { phases[body] = offset }
        }
        return phases
    }
}

/// The phase-search solver of Celestial Eclipse Lab (see the file header).
public enum CelestialEclipseLabSolver {
    /// The most settings judged for one level.
    public static let workBound: Int = 60_000
    /// The most phase changes a plan may have.
    public static let maxChanges: Int = 5

    /// The pair-interval table of a level: for every pair (i < j) and every pair of phases (pi · period j + pj), the
    /// pair's eclipse intervals over the horizon in tick order.
    struct Table {
        /// The pairs (i, j) with i < j, in order.
        let pairs: [(Int, Int)]
        /// The intervals of each pair, indexed by pi · period(j) + pj.
        let intervals: [[[CelestialEclipseLabInterval]]]
        /// The periods of the bodies.
        let periods: [Int]

        /// The table of `level`, by the kernel's exact overlap and visibility rules.
        init(_ level: CelestialEclipseLabLevel) {
            let bodies: [CelestialEclipseLabBody] = level.bodies
            var pairs: [(Int, Int)] = []
            var all: [[[CelestialEclipseLabInterval]]] = []
            for i in 0..<bodies.count {
                for j in (i + 1)..<max(bodies.count, i + 1) {
                    pairs.append((i, j))
                    let order: (front: Int, back: Int) = CelestialEclipseLabSky.order(level, i, j)
                    let front: CelestialEclipseLabBody = bodies[order.front]
                    let back: CelestialEclipseLabBody = bodies[order.back]
                    let reach: Int = front.radius + back.radius
                    var row: [[CelestialEclipseLabInterval]] = []
                    for pi in 0..<bodies[i].period {
                        for pj in 0..<bodies[j].period {
                            let pf: Int = order.front == i ? pi : pj
                            let pb: Int = order.front == i ? pj : pi
                            var list: [CelestialEclipseLabInterval] = []
                            var start: Int = -1
                            var deepest: CelestialEclipseLabVisibility = .partial
                            for tick in 0..<level.horizon {
                                let d2: Int = front.position(at: tick, phase: pf)
                                    .projectedSquaredDistance(to: back.position(at: tick, phase: pb))
                                if d2 < reach * reach {
                                    let now: CelestialEclipseLabVisibility =
                                        CelestialEclipseLabSky.visibility(front: front, back: back, squaredDistance: d2)
                                    if start < 0 {
                                        start = tick
                                        deepest = now
                                    } else if now.rank > deepest.rank {
                                        deepest = now
                                    }
                                } else if start >= 0 {
                                    list.append(CelestialEclipseLabInterval(front: order.front, back: order.back,
                                                                            first: start, last: tick - 1,
                                                                            visibility: deepest))
                                    start = -1
                                }
                            }
                            if start >= 0 {
                                list.append(CelestialEclipseLabInterval(front: order.front, back: order.back,
                                                                        first: start, last: level.horizon - 1,
                                                                        visibility: deepest))
                            }
                            row.append(list)
                        }
                    }
                    all.append(row)
                }
            }
            self.pairs = pairs
            self.intervals = all
            self.periods = bodies.map(\.period)
        }

        /// The intervals of the setting `phases`, merged in timeline order (first tick, front body, back body).
        func merged(_ phases: [Int]) -> [CelestialEclipseLabInterval] {
            var all: [CelestialEclipseLabInterval] = []
            for (index, pair) in pairs.enumerated() {
                all += intervals[index][phases[pair.0] * periods[pair.1] + phases[pair.1]]
            }
            all.sort { lhs, rhs in
                if lhs.first != rhs.first { return lhs.first < rhs.first }
                if lhs.front != rhs.front { return lhs.front < rhs.front }
                return lhs.back < rhs.back
            }
            return all
        }

        /// Whether the setting `phases` wins `level`'s target, by the kernel's judge over the merged intervals.
        func wins(_ level: CelestialEclipseLabLevel, _ phases: [Int]) -> Bool {
            var matched: Int = 0
            for interval in merged(phases) {
                if matched == level.target.count { break }
                let next: CelestialEclipseLabTarget = level.target[matched]
                guard interval.front == next.front, interval.back == next.back, next.admits(interval.first) else {
                    return false
                }
                matched += 1
            }
            return matched == level.target.count
        }
    }

    /// The minimal plan of `level` within `maxChanges` phase changes and `workBound` settings judged, or nil.
    public static func plan(_ level: CelestialEclipseLabLevel, maxChanges: Int = maxChanges,
                            workBound: Int = workBound) -> CelestialEclipseLabPlan? {
        let table = Table(level)
        let movable: [Int] = level.bodies.indices.filter { !level.bodies[$0].fixed }
        var phases: [Int] = level.phases
        var work: Int = 1
        if table.wins(level, phases) { return CelestialEclipseLabPlan(actions: [], settingsByDepth: [], work: work) }
        var settingsByDepth: [Int] = [1]
        guard maxChanges >= 1 else { return nil }
        for depth in 1...maxChanges {
            if depth > movable.count { return nil }
            var count: Int = 0
            var chosen: [Int] = []
            var found: [Int]? = nil
            var over: Bool = false

            func assign(_ position: Int) {
                if found != nil || over { return }
                if position == chosen.count {
                    work += 1
                    count += 1
                    if work > workBound {
                        over = true
                        return
                    }
                    if table.wins(level, phases) { found = phases }
                    return
                }
                let body: Int = chosen[position]
                let start: Int = level.phases[body]
                for offset in 0..<level.bodies[body].period where offset != start {
                    phases[body] = offset
                    assign(position + 1)
                    if found != nil || over { break }
                }
                phases[body] = start
            }

            func subsets(_ from: Int) {
                if found != nil || over { return }
                if chosen.count == depth {
                    assign(0)
                    return
                }
                var index: Int = from
                while index < movable.count {
                    chosen.append(movable[index])
                    subsets(index + 1)
                    chosen.removeLast()
                    if found != nil || over { return }
                    index += 1
                }
            }

            subsets(0)
            if over { return nil }
            if let winning = found {
                var actions: [CelestialEclipseLabAction] = []
                for body in level.bodies.indices where winning[body] != level.phases[body] {
                    actions.append(.phase(body, winning[body]))
                }
                return CelestialEclipseLabPlan(actions: actions, settingsByDepth: settingsByDepth, work: work)
            }
            settingsByDepth.append(count)
        }
        return nil
    }

    /// Whether `actions` followed by the run win `level` through the kernel's play (begun, the tutorial dismissed when
    /// the level has one, every action accepted).
    public static func wins(_ level: CelestialEclipseLabLevel, actions: [CelestialEclipseLabAction]) -> Bool {
        var play = CelestialEclipseLabPlay(level: level)
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
