// ColorfallCanyonsSolver — feature 342 (R02-G05-02) T-R02G0502-003 (FR-R02G0502-002; clarification Q2). The edit-set
// solver of Colorfall Canyons. An edit set is a multiset of carves of the level's carvable cells plus a set of valve
// toggles (each spring at most once), applied before the first tick, followed by running to the tick limit. The solver
// tries edit sets of size 0, 1, 2, … up to the depth (at most 3), each size in the lexicographic order of non-decreasing
// move lists over `moves(_:)` (carvable cells in order, then springs), skipping sets that would carve a cell below height
// 0. Each set is keyed by its routing (every cell's downhill neighbour) and valve states: carves that change no downhill
// choice cannot change the outcome, so each distinct key is simulated once with R02-G05-01's `ColorfallCanyonsFluid.tick`,
// asserting exact conservation on every tick. The first winning set is a smallest one. Work = distinct keys simulated.
// Bound: Σ_{k ≤ depth} C(m + k − 1, k) sets for m moves. Two exact speed-ups: carves of cells that no fluid can reach
// within the depth (and that touch no such cell) are left out, since they change no routing any fluid follows; and the
// search simulates with a flat-array copy of the kernel's tick (`FastFlow`), whose result is re-run through the kernel
// for the set it returns.
import VisualCoreSimulation

/// One edit applied before the first tick: a carve of a cell or a toggle of a spring's valve.
public enum ColorfallCanyonsEdit: Sendable, Hashable, Codable, Comparable {
    /// Lower the given cell by one height step.
    case carve(Int)
    /// Toggle the valve of the given spring.
    case valve(Int)

    /// The play action of the edit.
    public var action: ColorfallCanyonsAction {
        switch self {
        case .carve(let cell): .carve(cell)
        case .valve(let spring): .valve(spring)
        }
    }
}

/// A smallest winning edit set found by ``ColorfallCanyonsSolver``.
public struct ColorfallCanyonsSolution: Sendable, Equatable {
    /// The edits in solver order (carves by cell, then valves by spring).
    public let edits: [ColorfallCanyonsEdit]
    /// The distinct routings simulated in all.
    public let work: Int
    /// The distinct routings of fewer edits than ``smallest`` simulated, every one failing.
    public let smaller: Int
    /// The tick at which the edits win.
    public let winTick: Int

    /// The smallest number of edits that wins.
    public var smallest: Int { edits.count }

    /// A solution of the given values.
    public init(edits: [ColorfallCanyonsEdit], work: Int, smaller: Int, winTick: Int) {
        self.edits = edits
        self.work = work
        self.smaller = smaller
        self.winTick = winTick
    }
}

/// The edit-set solver (clarification Q2).
public enum ColorfallCanyonsSolver {
    /// The largest edit set searched.
    public static let maximumDepth = 3

    /// The moves an edit set is made of: the level's carvable cells at the start, in cell order, then every spring.
    public static func moves(_ level: ColorfallCanyonsLevel) -> [ColorfallCanyonsEdit] {
        let carves: [ColorfallCanyonsEdit] = (0..<level.cellCount)
            .filter { level.isCarvable($0, heights: level.heights) }
            .map { .carve($0) }
        return carves + level.springs.indices.map { .valve($0) }
    }

    /// Every cell's downhill neighbour at `heights` (`ColorfallCanyonsFluid.downhill(of:level:)`'s rule), nil where none.
    public static func routing(_ level: ColorfallCanyonsLevel, heights: [Int]) -> [Int?] {
        Router(level: level).routing(heights)
    }

    /// The fluid of `level` after applying `edits`, or nil when a carve is not allowed (not a carvable cell, or below 0)
    /// or a valve appears twice or is out of range.
    static func edited(_ level: ColorfallCanyonsLevel, edits: [ColorfallCanyonsEdit]) -> ColorfallCanyonsFluid? {
        var fluid = ColorfallCanyonsFluid(level: level)
        var toggled: Set<Int> = []
        for edit in edits {
            switch edit {
            case .carve(let cell):
                guard level.isCarvable(cell, heights: fluid.heights) else { return nil }
                fluid.carve(cell)
            case .valve(let spring):
                guard level.springs.indices.contains(spring), toggled.insert(spring).inserted else { return nil }
                fluid.toggle(spring)
            }
        }
        return fluid
    }

    /// Runs `level` after `edits` until a verdict decides it (at the latest at the tick limit), asserting exact
    /// conservation on every tick; nil when the edit set is not allowed.
    public static func run(_ level: ColorfallCanyonsLevel,
                           edits: [ColorfallCanyonsEdit]) -> (verdict: ColorfallCanyonsVerdict, tick: Int)? {
        guard var fluid = edited(level, edits: edits) else { return nil }
        return simulate(level, fluid: &fluid)
    }

    /// Ticks `fluid` until the verdict is not `running`.
    static func simulate(_ level: ColorfallCanyonsLevel,
                         fluid: inout ColorfallCanyonsFluid) -> (verdict: ColorfallCanyonsVerdict, tick: Int) {
        while true {
            fluid.tick(level: level)
            precondition(fluid.isConserved(), "Colorfall Canyons fluid not conserved at tick \(fluid.tick)")
            let verdict: ColorfallCanyonsVerdict = fluid.verdict(level: level)
            if verdict != .running { return (verdict, fluid.tick) }
        }
    }

    /// The cells fluid can ever reach when at most `depth` cells are lowered by at most `depth` in all: from the springs,
    /// a passing cell x may reach a non-rock neighbour y whenever height(y) − depth < height(x).
    static func reachable(_ level: ColorfallCanyonsLevel, router: Router, depth: Int) -> Set<Int> {
        var seen: Set<Int> = Set(level.springs.map(\.cell))
        var stack: [Int] = Array(seen)
        while let cell = stack.popLast() {
            guard router.passes[cell] else { continue }
            for next in router.neighbours[cell] where level.heights[next] - depth < level.heights[cell] {
                if seen.insert(next).inserted { stack.append(next) }
            }
        }
        return seen
    }

    /// The moves the search uses: the carvable cells in or next to ``reachable(_:router:depth:)``, then every spring.
    static func relevantMoves(_ level: ColorfallCanyonsLevel, router: Router, depth: Int) -> [ColorfallCanyonsEdit] {
        let reach: Set<Int> = reachable(level, router: router, depth: depth)
        return moves(level).filter { edit in
            guard case .carve(let cell) = edit else { return true }
            return reach.contains(cell) || level.neighbours(of: cell).contains(where: reach.contains)
        }
    }

    /// A smallest winning edit set of at most `depth` edits, or nil when none wins within the depth.
    public static func solve(_ level: ColorfallCanyonsLevel, depth: Int = maximumDepth) -> ColorfallCanyonsSolution? {
        let bound: Int = max(0, min(depth, maximumDepth))
        let router = Router(level: level)
        let all: [ColorfallCanyonsEdit] = relevantMoves(level, router: router, depth: bound)
        let flow = FastFlow(level: level, router: router)
        let count: Int = level.cellCount
        // Zobrist keys: one 64-bit value per (cell, downhill + 1) and per toggled valve, from a fixed SplitMix64 stream.
        var stream = SplitMix64(seed: 0x00C0_1F0A_11CA_7E5E)
        var cellKeys: [UInt64] = []
        for _ in 0..<(count * (count + 1)) { cellKeys.append(stream.next()) }
        var valveKeys: [UInt64] = []
        for _ in level.springs { valveKeys.append(stream.next()) }
        var routing: [Int] = router.routing(level.heights).map { $0 ?? -1 }
        var hash: UInt64 = 0
        for cell in 0..<count { hash ^= cellKeys[cell * (count + 1) + routing[cell] + 1] }
        var heights: [Int] = level.heights
        var valves: [Bool] = level.springs.map(\.open)
        var outcomes: [UInt64: [(routing: [Int], valves: [Bool], won: Bool)]] = [:]
        var work: Int = 0
        for size in 0...bound {
            let smaller: Int = work
            var found: [ColorfallCanyonsEdit]?
            var indices: [Int] = []
            func leaf() {
                if let bucket = outcomes[hash], let known = bucket.first(where: { $0.routing == routing && $0.valves == valves }) {
                    if known.won { found = indices.map { all[$0] } }
                    return
                }
                let won: Bool = flow.run(routing: routing, valves: valves).won
                work += 1
                outcomes[hash, default: []].append((routing, valves, won))
                if won { found = indices.map { all[$0] } }
            }
            func visit(from start: Int) {
                if indices.count == size {
                    leaf()
                    return
                }
                guard start < all.count else { return }
                for index in start..<all.count {
                    switch all[index] {
                    case .carve(let cell):
                        guard heights[cell] > 0 else { continue }
                        heights[cell] -= 1
                        var changed: [(cell: Int, old: Int)] = []
                        for affected in [cell] + router.neighbours[cell] where router.passes[affected] {
                            let old: Int = routing[affected]
                            let new: Int = router.downhill(affected, heights) ?? -1
                            if new != old {
                                hash ^= cellKeys[affected * (count + 1) + old + 1] ^ cellKeys[affected * (count + 1) + new + 1]
                                routing[affected] = new
                                changed.append((affected, old))
                            }
                        }
                        indices.append(index)
                        visit(from: index)
                        indices.removeLast()
                        for (affected, old) in changed.reversed() {
                            hash ^= cellKeys[affected * (count + 1) + routing[affected] + 1] ^ cellKeys[affected * (count + 1) + old + 1]
                            routing[affected] = old
                        }
                        heights[cell] += 1
                    case .valve(let spring):
                        if let last = indices.last, last == index { continue }
                        valves[spring].toggle()
                        hash ^= valveKeys[spring]
                        indices.append(index)
                        visit(from: index)
                        indices.removeLast()
                        hash ^= valveKeys[spring]
                        valves[spring].toggle()
                    }
                    if found != nil { return }
                }
            }
            visit(from: 0)
            if let found {
                guard let checked = run(level, edits: found), checked.verdict == .won else {
                    preconditionFailure("Colorfall Canyons fast flow and kernel disagree on \(found)")
                }
                return ColorfallCanyonsSolution(edits: found, work: work, smaller: smaller, winTick: checked.tick)
            }
        }
        return nil
    }

    /// Precomputed cell kinds and non-rock neighbours for fast routing.
    struct Router {
        /// Whether each cell passes fluid on (open or spring).
        let passes: [Bool]
        /// Each cell's non-rock neighbours in the order east, south, west, north.
        let neighbours: [[Int]]

        init(level: ColorfallCanyonsLevel) {
            var passes: [Bool] = []
            var neighbours: [[Int]] = []
            for cell in 0..<level.cellCount {
                switch level.kind(of: cell) {
                case .open, .spring: passes.append(true)
                case .rock, .basin, .drain: passes.append(false)
                }
                neighbours.append(level.neighbours(of: cell).filter {
                    if case .rock = level.kind(of: $0) { return false }
                    return true
                })
            }
            self.passes = passes
            self.neighbours = neighbours
        }

        /// The downhill neighbour of one passing `cell` at `heights`.
        func downhill(_ cell: Int, _ heights: [Int]) -> Int? {
            guard passes[cell] else { return nil }
            var best: Int?
            var bestHeight: Int = heights[cell]
            for next in neighbours[cell] where heights[next] < bestHeight {
                best = next
                bestHeight = heights[next]
            }
            return best
        }

        /// Every cell's downhill neighbour at `heights`.
        func routing(_ heights: [Int]) -> [Int?] {
            var result = [Int?](repeating: nil, count: heights.count)
            for cell in heights.indices where passes[cell] {
                var best: Int?
                var bestHeight: Int = heights[cell]
                for next in neighbours[cell] where heights[next] < bestHeight {
                    best = next
                    bestHeight = heights[next]
                }
                result[cell] = best
            }
            return result
        }
    }

    /// A flat-array copy of R02-G05-01's tick and verdict for the search (clarification Q2), with conservation asserted on
    /// every tick. `ColorfallCanyonsSolverTests` checks that it agrees with the kernel.
    struct FastFlow {
        let level: ColorfallCanyonsLevel
        let count: Int
        let drains: [Int]
        let basinCells: [Int]

        init(level: ColorfallCanyonsLevel, router: Router) {
            self.level = level
            count = level.cellCount
            drains = (0..<level.cellCount).filter { level.grounds[$0] == .drain }
            basinCells = level.basins.map(\.cell)
        }

        /// Runs to the deciding tick with the given routing (-1: none) and valves; whether it won, and the tick. No
        /// allocation per tick: the colour sharing and the basin checks are written out for three colours.
        func run(routing: [Int], valves: [Bool]) -> (won: Bool, tick: Int) {
            var masses = [Int](repeating: 0, count: count * 3)
            var next = masses
            var supplies: [Int] = level.springs.map(\.supply)
            var released: (Int, Int, Int) = (0, 0, 0)
            var spilled: (Int, Int, Int) = (0, 0, 0)
            let rate: Int = level.flowRate
            var tick: Int = 0
            while true {
                for i in 0..<(count * 3) { next[i] = masses[i] }
                for cell in 0..<count {
                    let target: Int = routing[cell]
                    guard target >= 0 else { continue }
                    let m0: Int = masses[cell * 3], m1: Int = masses[cell * 3 + 1], m2: Int = masses[cell * 3 + 2]
                    let volume: Int = m0 + m1 + m2
                    guard volume > 0 else { continue }
                    let r: Int = min(volume, rate)
                    var p0: Int = r * m0 / volume, p1: Int = r * m1 / volume, p2: Int = r * m2 / volume
                    let q0: Int = r * m0 % volume, q1: Int = r * m1 % volume, q2: Int = r * m2 % volume
                    var left: Int = r - p0 - p1 - p2
                    // Largest remainder first, ties to the lower colour (as `ColorfallCanyonsFluid.share`).
                    var taken: (Bool, Bool, Bool) = (false, false, false)
                    while left > 0 {
                        var pick: Int = -1
                        var best: Int = -1
                        if !taken.0 && q0 > best { pick = 0; best = q0 }
                        if !taken.1 && q1 > best { pick = 1; best = q1 }
                        if !taken.2 && q2 > best { pick = 2; best = q2 }
                        switch pick {
                        case 0: p0 += 1; taken.0 = true
                        case 1: p1 += 1; taken.1 = true
                        default: p2 += 1; taken.2 = true
                        }
                        left -= 1
                    }
                    next[cell * 3] -= p0; next[cell * 3 + 1] -= p1; next[cell * 3 + 2] -= p2
                    next[target * 3] += p0; next[target * 3 + 1] += p1; next[target * 3 + 2] += p2
                }
                for (i, spring) in level.springs.enumerated() where valves[i] && supplies[i] > 0 {
                    let amount: Int = min(spring.release, supplies[i])
                    supplies[i] -= amount
                    next[spring.cell * 3 + spring.color.rawValue] += amount
                    switch spring.color {
                    case .cyan: released.0 += amount
                    case .coral: released.1 += amount
                    case .yellow: released.2 += amount
                    }
                }
                for cell in drains {
                    spilled.0 += next[cell * 3]; spilled.1 += next[cell * 3 + 1]; spilled.2 += next[cell * 3 + 2]
                    next[cell * 3] = 0; next[cell * 3 + 1] = 0; next[cell * 3 + 2] = 0
                }
                swap(&masses, &next)
                tick += 1
                var held: (Int, Int, Int) = spilled
                for cell in 0..<count {
                    held.0 += masses[cell * 3]; held.1 += masses[cell * 3 + 1]; held.2 += masses[cell * 3 + 2]
                }
                precondition(held == released, "Colorfall Canyons fast flow not conserved at tick \(tick)")
                var failed: Bool = false
                for basin in level.basins where basin.isProtected {
                    var wrong: Int = 0
                    for k in 0..<3 where basin.shares[k] == 0 { wrong += masses[basin.cell * 3 + k] }
                    if wrong > basin.toleratedWrong { failed = true }
                }
                if failed { return (false, tick) }
                for basin in level.basins {
                    let v: Int = masses[basin.cell * 3] + masses[basin.cell * 3 + 1] + masses[basin.cell * 3 + 2]
                    if v > basin.capacity { return (false, tick) }
                }
                var won: Bool = true
                for basin in level.basins where basin.fill > 0 {
                    let v: Int = masses[basin.cell * 3] + masses[basin.cell * 3 + 1] + masses[basin.cell * 3 + 2]
                    if v < basin.fill { won = false; break }
                    for k in 0..<3 where abs(1_000 * masses[basin.cell * 3 + k] - basin.shares[k] * v) > basin.tolerance * v {
                        won = false
                    }
                    if !won { break }
                }
                if won { return (true, tick) }
                if tick >= level.tickLimit { return (false, tick) }
                // Settled: no open spring has supply left and no passing cell holds fluid, so nothing changes any more
                // and the play can only fail on time at the tick limit.
                var moving: Bool = false
                for (i, _) in level.springs.enumerated() where valves[i] && supplies[i] > 0 { moving = true }
                if !moving {
                    for cell in 0..<count where routing[cell] >= 0
                        && masses[cell * 3] + masses[cell * 3 + 1] + masses[cell * 3 + 2] > 0 {
                        moving = true
                        break
                    }
                }
                if !moving { return (false, level.tickLimit) }
            }
        }
    }
}
