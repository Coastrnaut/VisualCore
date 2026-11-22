// NocturneGardenSolver — feature 382 (R02-G09-02) T-R02G0902-003 (FR-R02G0902-002; clarification Q2). Finds a winning
// sequence of the smallest number of moves and proves it is the smallest:
//
// - `needed` is the least shared cell count s with s·q ≥ p·|T| (a winning mask's union with the target is at least the
//   target, so the match p/q needs at least that many target cells dark).
// - `cover(e)` is the most target cells one plant darkens at sun elevation e (any kind with supply, any allowed size,
//   any anchor in the bed) among the plants whose own leak stays within the allowance (a plant leaking more makes every
//   mask holding it leak more, which fails).
// - The lower bound is L = min over the allowed elevations e of [e ≠ the opening sun] + ⌈needed / cover(e)⌉: a winning
//   mask under sun e needs at least that many planted blooms, and a sun move when e is not the opening one.
// - The search looks, elevation by elevation (ascending, only those whose own bound is L), for a sequence of exactly L
//   moves: the sun move first when needed, then plants in ascending candidate order (shape score descending: cells in
//   the target minus cells outside; then kind order, row, column, size), pruned when the shared cells plus the
//   remaining plants times the cover cannot reach `needed`, when the leak exceeds the allowance or when the cells
//   outside the target exceed what the match tolerates. A sequence of L moves found proves L is the smallest.
//
// Work is the number of plant evaluations, counted and bounded (20,000 by default); a search over its bound gives nil.
// Every reported sequence is replayed through `NocturneGardenPlay` and reported only when it wins on its last move.

/// The lower-bound argument: the elevation, the needed shared cells, the single-plant cover and whether a sun move is
/// needed.
public struct NocturneGardenBound: Sendable, Hashable, Codable {
    /// The sun elevation of the bound.
    public let elevation: Int
    /// The least shared cell count a winning mask needs.
    public let needed: Int
    /// The most target cells one plant darkens at ``elevation`` without leaking beyond the allowance.
    public let cover: Int
    /// Whether ``elevation`` differs from the opening sun.
    public let sunMove: Bool

    /// A bound of the given values.
    public init(elevation: Int, needed: Int, cover: Int, sunMove: Bool) {
        self.elevation = elevation
        self.needed = needed
        self.cover = cover
        self.sunMove = sunMove
    }

    /// The smallest move count it proves: [sun move] + ⌈needed / cover⌉ (cover is positive).
    public var smallest: Int { (sunMove ? 1 : 0) + (needed + cover - 1) / max(1, cover) }
}

/// A certified solution: the smallest move count, the winning actions and the plant evaluations spent.
public struct NocturneGardenSolution: Sendable, Equatable, Codable {
    /// The smallest move count (the actions' count).
    public let smallest: Int
    /// The winning actions; the last one wins.
    public let actions: [NocturneGardenAction]
    /// The plant evaluations the search spent.
    public let work: Int

    /// A solution of the given values.
    public init(smallest: Int, actions: [NocturneGardenAction], work: Int) {
        self.smallest = smallest
        self.actions = actions
        self.work = work
    }
}

/// The exact solver of Nocturne Garden levels.
public enum NocturneGardenSolver {
    /// The default bound on plant evaluations per level.
    public static let workBound: Int = 20_000

    /// One candidate plant at one elevation, with its cells clipped to the bed.
    struct Plant {
        let kind: NocturneGardenKind
        let column: Int
        let row: Int
        let size: Int
        let cells: [Int]
        let inside: Int
        let outside: Int
        let leak: Int

        var action: NocturneGardenAction { .plant(kind, column, row, size) }
    }

    /// The least shared cell count s with s·q ≥ p·|T|.
    public static func needed(_ level: NocturneGardenLevel) -> Int {
        let p: Int = level.required.numerator
        let q: Int = level.required.denominator
        return (p * level.target.count + q - 1) / q
    }

    /// The cells (dx, dy) a bloom of `kind` and `size` anchored at (0, 0) darkens under sun `elevation`, unclipped. A
    /// bloom anchored at (c, r) darkens exactly these cells shifted by (c, r): its cast polygon is shifted by (2c, 2r)
    /// in doubled coordinates, and so are the cell centres.
    static func stamp(_ kind: NocturneGardenKind, size: Int, elevation: Int) -> [(dx: Int, dy: Int)] {
        let polygon: [NocturneGardenLattice] = NocturneGardenBloom.cast(kind.outline, column: 0, row: 0, size: size,
                                                                        elevation: elevation)
        var minX: Int = Int.max
        var maxX: Int = Int.min
        var minY: Int = Int.max
        var maxY: Int = Int.min
        for point in polygon {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        var result: [(dx: Int, dy: Int)] = []
        for dy in (minY / 2 - 1)...(maxY / 2 + 1) {
            for dx in (minX / 2 - 1)...(maxX / 2 + 1)
            where NocturneGardenBloom.contains(polygon, NocturneGardenLattice(x: 2 * dx + 1, y: 2 * dy + 1)) {
                result.append((dx, dy))
            }
        }
        return result
    }

    /// Every plant of `level` at sun `elevation` (kinds with supply in case order, rows, columns, allowed sizes
    /// ascending) that darkens at least one target cell, with its counts.
    static func plants(_ level: NocturneGardenLevel, elevation: Int) -> [Plant] {
        let width: Int = level.width
        let height: Int = level.height
        var target: [Bool] = Array(repeating: false, count: width * height)
        for cell in level.target { target[cell] = true }
        var forbidden: [Bool] = Array(repeating: false, count: width * height)
        for cell in level.forbidden { forbidden[cell] = true }
        let sizes: [Int] = level.sizes.sorted()
        var stamps: [String: [(dx: Int, dy: Int)]] = [:]
        var result: [Plant] = []
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 {
            for size in sizes {
                stamps[kind.rawValue + String(size)] = stamp(kind, size: size, elevation: elevation)
            }
        }
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 {
            for row in 0..<height {
                for column in 0..<width {
                    for size in sizes {
                        let offsets: [(dx: Int, dy: Int)] = stamps[kind.rawValue + String(size)] ?? []
                        var cells: [Int] = []
                        var inside: Int = 0
                        var leak: Int = 0
                        for offset in offsets {
                            let c: Int = column + offset.dx
                            let r: Int = row + offset.dy
                            guard c >= 0, c < width, r >= 0, r < height else { continue }
                            let cell: Int = r * width + c
                            cells.append(cell)
                            if target[cell] {
                                inside += 1
                            } else if forbidden[cell] {
                                leak += 1
                            }
                        }
                        guard inside > 0 else { continue }
                        result.append(Plant(kind: kind, column: column, row: row, size: size, cells: cells,
                                            inside: inside, outside: cells.count - inside, leak: leak))
                    }
                }
            }
        }
        return result
    }

    /// The most target cells one plant darkens at `elevation` without leaking beyond the allowance on its own (0 when
    /// none darkens a target cell).
    public static func cover(_ level: NocturneGardenLevel, elevation: Int) -> Int {
        cover(plants(level, elevation: elevation), allowance: level.leakAllowance)
    }

    static func cover(_ plants: [Plant], allowance: Int) -> Int {
        var best: Int = 0
        for plant in plants where plant.leak <= allowance { best = max(best, plant.inside) }
        return best
    }

    /// The lower bound: the elevation (ascending, first on ties) with the least [sun move] + ⌈needed / cover⌉; nil when
    /// no plant at any allowed elevation darkens a target cell within the allowance.
    public static func lowerBound(_ level: NocturneGardenLevel) -> NocturneGardenBound? {
        bounds(level).min { $0.bound.smallest < $1.bound.smallest }?.bound
    }

    /// The bound of every allowed elevation with a positive cover, ascending, with its plants.
    static func bounds(_ level: NocturneGardenLevel) -> [(bound: NocturneGardenBound, plants: [Plant])] {
        let needed: Int = needed(level)
        var result: [(bound: NocturneGardenBound, plants: [Plant])] = []
        for elevation in level.elevations.sorted() {
            let plants: [Plant] = plants(level, elevation: elevation)
            let cover: Int = cover(plants, allowance: level.leakAllowance)
            guard cover > 0 else { continue }
            result.append((NocturneGardenBound(elevation: elevation, needed: needed, cover: cover,
                                               sunMove: elevation != level.sun), plants))
        }
        return result
    }

    /// A winning sequence of exactly the lower bound's move count, or nil when there is none within `workBound` plant
    /// evaluations (or no bound).
    public static func solve(_ level: NocturneGardenLevel, workBound: Int = workBound) -> NocturneGardenSolution? {
        let all = bounds(level)
        guard let smallest = all.map(\.bound.smallest).min() else { return nil }
        var search = Search(level: level, workBound: workBound)
        for entry in all where entry.bound.smallest == smallest {
            let plantsNeeded: Int = smallest - (entry.bound.sunMove ? 1 : 0)
            guard plantsNeeded >= 1, plantsNeeded <= level.supplyTotal else { continue }
            if let plants = search.run(entry.plants, count: plantsNeeded, cover: entry.bound.cover) {
                var actions: [NocturneGardenAction] = entry.bound.sunMove ? [.sun(entry.bound.elevation)] : []
                actions += plants.map(\.action)
                guard actions.count <= level.budget, wins(level, actions: actions) else { return nil }
                return NocturneGardenSolution(smallest: smallest, actions: actions, work: search.work)
            }
            if search.work > workBound { return nil }
        }
        return nil
    }

    /// Whether `actions` replayed on a fresh play of `level` win on the last action and not before.
    public static func wins(_ level: NocturneGardenLevel, actions: [NocturneGardenAction]) -> Bool {
        var play = NocturneGardenPlay(level: level)
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for action in actions {
                guard play.stage == .playing else { return false }
                try play.apply(action, expecting: play.fingerprint)
            }
        } catch {
            return false
        }
        return play.stage == .won
    }

    /// The depth-first search over plants at one elevation.
    struct Search {
        let level: NocturneGardenLevel
        let workBound: Int
        let needed: Int
        let maxOutside: Int
        var work: Int = 0
        var dark: [Bool]
        var target: [Bool]
        var forbidden: [Bool]

        init(level: NocturneGardenLevel, workBound: Int) {
            self.level = level
            self.workBound = workBound
            needed = NocturneGardenSolver.needed(level)
            let p: Int = level.required.numerator
            let q: Int = level.required.denominator
            // A win needs shared·q ≥ p·(|T| + outside) with shared ≤ |T|, so outside ≤ |T|·(q − p) / p.
            maxOutside = p > 0 ? level.target.count * (q - p) / p : Int.max
            dark = Array(repeating: false, count: level.cellCount)
            target = Array(repeating: false, count: level.cellCount)
            forbidden = Array(repeating: false, count: level.cellCount)
            for cell in level.target { target[cell] = true }
            for cell in level.forbidden { forbidden[cell] = true }
        }

        /// The first `count` plants (ascending candidate order) whose union wins, or nil.
        mutating func run(_ plants: [Plant], count: Int, cover: Int) -> [Plant]? {
            let usable: [Plant] = plants.filter {
                $0.leak <= level.leakAllowance && $0.outside <= maxOutside
            }.sorted { a, b in
                let sa: Int = a.inside - a.outside
                let sb: Int = b.inside - b.outside
                if sa != sb { return sa > sb }
                if a.kind.order != b.kind.order { return a.kind.order < b.kind.order }
                if a.row != b.row { return a.row < b.row }
                if a.column != b.column { return a.column < b.column }
                return a.size < b.size
            }
            for index in dark.indices { dark[index] = false }
            var chosen: [Plant] = []
            var used: [NocturneGardenKind: Int] = [:]
            let found: Bool = descend(usable, from: 0, left: count, cover: cover, shared: 0, outside: 0, leak: 0,
                                      chosen: &chosen, used: &used)
            return found ? chosen : nil
        }

        private mutating func descend(_ plants: [Plant], from start: Int, left: Int, cover: Int, shared: Int,
                                      outside: Int, leak: Int, chosen: inout [Plant],
                                      used: inout [NocturneGardenKind: Int]) -> Bool {
            if left == 0 {
                let either: Int = level.target.count + outside
                return shared > 0 && shared * level.required.denominator >= level.required.numerator * either
            }
            guard shared + left * cover >= needed, start < plants.count else { return false }
            for index in start..<plants.count {
                let plant: Plant = plants[index]
                guard (used[plant.kind] ?? 0) < level.supplyCount(plant.kind) else { continue }
                work += 1
                if work > workBound { return false }
                var added: [Int] = []
                var newShared: Int = shared
                var newOutside: Int = outside
                var newLeak: Int = leak
                for cell in plant.cells where !dark[cell] {
                    dark[cell] = true
                    added.append(cell)
                    if target[cell] {
                        newShared += 1
                    } else {
                        newOutside += 1
                        if forbidden[cell] { newLeak += 1 }
                    }
                }
                if !added.isEmpty, newLeak <= level.leakAllowance, newOutside <= maxOutside {
                    chosen.append(plant)
                    used[plant.kind, default: 0] += 1
                    if descend(plants, from: index + 1, left: left - 1, cover: cover, shared: newShared,
                               outside: newOutside, leak: newLeak, chosen: &chosen, used: &used) {
                        return true
                    }
                    chosen.removeLast()
                    used[plant.kind, default: 0] -= 1
                }
                for cell in added { dark[cell] = false }
                if work > workBound { return false }
            }
            return false
        }
    }
}
