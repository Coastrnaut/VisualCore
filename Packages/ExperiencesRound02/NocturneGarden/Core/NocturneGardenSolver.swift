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

// MARK: - Continuations — feature 385 (R02-G09-05) T-R02G0905-002 (FR-R02G0905-002; SC-R02G0905-002; clarification Q1)
//
// `solve(_:from:sun:movesLeft:supplyLeft:workBound:)` looks for the fewest further moves that win from a state of a
// play (its blooms, its sun, the moves and supply left). For each total length n = 1 … movesLeft, in this order: (a) n
// plants at the current sun and (b) a sun move to another allowed elevation, then n − 1 plants, taken together by
// elevation ascending as the certification takes them (the current sun's plants-only search in its place: a failing
// plants-only search can be costly while the certified solution starts with a sun move to a lower elevation); (c) the
// removal of one planted bloom (canonical order), then n − 1 plants at the current sun; (d) a removal, then a sun move,
// then n − 2 plants. A run needing more plants than the supply left is skipped. The plants come from the same
// depth-first search and pruning as the certification (candidate order, the cover bound, the leak allowance and the
// outside limit), started with the remaining blooms' cells already dark and with the supply left (a removed bloom
// returns to it). Every length below n is searched exhaustively first, so no proper prefix of a found sequence wins.
// The work bound is shared by the whole call; a call over it gives nil. Every found sequence is replayed on a copy of
// the state (blooms and sun) with the play's rules — no leak beyond the allowance after any move, a win on the last
// move and not before — and reported only when it passes.

extension NocturneGardenSolver {
    /// The fewest further moves (at most `movesLeft`) that win from `blooms` (canonical order) under sun `sun` with
    /// `supplyLeft` blooms of each kind still in the supply, by increasing total length: plants at the current sun or a
    /// sun move first (elevations ascending), then the removal of one planted bloom first, then a removal and a sun
    /// move. Nil when none is found within `workBound` plant evaluations shared by the whole call, or when `movesLeft`
    /// is below 1. The solution's `smallest` is its action count and `work` the evaluations spent.
    public static func solve(_ level: NocturneGardenLevel, from blooms: [NocturneGardenBloom], sun: Int,
                             movesLeft: Int, supplyLeft: [NocturneGardenKind: Int],
                             workBound: Int = workBound) -> NocturneGardenSolution? {
        guard movesLeft >= 1 else { return nil }
        let current: [NocturneGardenBloom] = blooms.sorted()
        let elevations: [Int] = level.elevations.sorted()
        let others: [Int] = elevations.filter { $0 != sun }
        var search = Continuation(level: level, workBound: workBound)
        for length in 1...movesLeft {
            // (a) Plants only at the current sun and (b) a sun move first, then plants: elevations ascending, as the
            // certification searches them (a failing plants-only search can be costly, and the certified solution
            // may start with a sun move to a lower elevation).
            for elevation in elevations {
                let move: [NocturneGardenAction] = elevation == sun ? [] : [.sun(elevation)]
                if let plants = search.run(base: current, elevation: elevation, supply: supplyLeft,
                                           count: length - move.count) {
                    return verified(level, from: current, sun: sun, supplyLeft: supplyLeft,
                                    actions: move + plants.map(\.action), work: search.work)
                }
                if search.work > workBound { return nil }
            }
            // (c) The removal of one planted bloom first, then plants at the current sun.
            for index in current.indices {
                var rest: [NocturneGardenBloom] = current
                let removed: NocturneGardenBloom = rest.remove(at: index)
                var supply: [NocturneGardenKind: Int] = supplyLeft
                supply[removed.kind, default: 0] += 1
                if let plants = search.run(base: rest, elevation: sun, supply: supply, count: length - 1) {
                    return verified(level, from: current, sun: sun, supplyLeft: supplyLeft,
                                    actions: [.remove(index)] + plants.map(\.action), work: search.work)
                }
                if search.work > workBound { return nil }
            }
            // (d) A removal, then a sun move, then plants.
            guard length >= 2 else { continue }
            for index in current.indices {
                var rest: [NocturneGardenBloom] = current
                let removed: NocturneGardenBloom = rest.remove(at: index)
                var supply: [NocturneGardenKind: Int] = supplyLeft
                supply[removed.kind, default: 0] += 1
                for elevation in others {
                    if let plants = search.run(base: rest, elevation: elevation, supply: supply, count: length - 2) {
                        return verified(level, from: current, sun: sun, supplyLeft: supplyLeft,
                                        actions: [.remove(index), .sun(elevation)] + plants.map(\.action),
                                        work: search.work)
                    }
                    if search.work > workBound { return nil }
                }
            }
        }
        return nil
    }

    /// The solution of `actions` when ``continues(_:from:sun:supplyLeft:actions:)`` accepts them, else nil.
    static func verified(_ level: NocturneGardenLevel, from blooms: [NocturneGardenBloom], sun: Int,
                         supplyLeft: [NocturneGardenKind: Int], actions: [NocturneGardenAction],
                         work: Int) -> NocturneGardenSolution? {
        guard continues(level, from: blooms, sun: sun, supplyLeft: supplyLeft, actions: actions) else { return nil }
        return NocturneGardenSolution(smallest: actions.count, actions: actions, work: work)
    }

    /// Whether `actions` replayed on a copy of the state (`blooms` in canonical order, sun `sun`, `supplyLeft`) with
    /// the play's rules are each legal (anchor in the bed, an allowed size or elevation, supply left, a bloom index in
    /// range, no no-op sun), leak no more than the allowance after any action, and win on the last action and not
    /// before (a win needs at least one bloom and the required match).
    public static func continues(_ level: NocturneGardenLevel, from blooms: [NocturneGardenBloom], sun: Int,
                                 supplyLeft: [NocturneGardenKind: Int], actions: [NocturneGardenAction]) -> Bool {
        guard !actions.isEmpty else { return false }
        var current: [NocturneGardenBloom] = blooms.sorted()
        var elevation: Int = sun
        var supply: [NocturneGardenKind: Int] = supplyLeft
        for (step, action) in actions.enumerated() {
            switch action {
            case let .plant(kind, column, row, size):
                guard column >= 0, column < level.width, row >= 0, row < level.height, level.sizes.contains(size),
                      (supply[kind] ?? 0) > 0 else { return false }
                supply[kind, default: 0] -= 1
                current.append(NocturneGardenBloom(kind: kind, column: column, row: row, size: size))
            case let .remove(index):
                guard current.indices.contains(index) else { return false }
                let removed: NocturneGardenBloom = current.remove(at: index)
                supply[removed.kind, default: 0] += 1
            case let .sun(value):
                guard level.elevations.contains(value), value != elevation else { return false }
                elevation = value
            case .move, .resize:
                return false
            }
            current.sort()
            let mask = NocturneGardenMask.union(current, elevation: elevation, width: level.width,
                                                height: level.height)
            guard mask.leak(forbidden: level.forbidden) <= level.leakAllowance else { return false }
            let won: Bool = !current.isEmpty && NocturneGardenMask.matches(mask: mask, target: level.target,
                                                                            required: level.required)
            if won != (step == actions.count - 1) { return false }
        }
        return true
    }

    /// Every plant of `level` at sun `elevation`, exactly as ``plants(_:elevation:)`` lists them (kinds with supply in
    /// case order, rows, columns, allowed sizes ascending; only those darkening a target cell), with the stamps held in
    /// an array per kind and size instead of a keyed table read once per anchor (a hint is asked many times a play).
    static func continuationPlants(_ level: NocturneGardenLevel, elevation: Int) -> [Plant] {
        let width: Int = level.width
        let height: Int = level.height
        var target: [Bool] = Array(repeating: false, count: width * height)
        for cell in level.target { target[cell] = true }
        var forbidden: [Bool] = Array(repeating: false, count: width * height)
        for cell in level.forbidden { forbidden[cell] = true }
        let sizes: [Int] = level.sizes.sorted()
        var result: [Plant] = []
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 {
            var stamps: [[(dx: Int, dy: Int)]] = []
            for size in sizes { stamps.append(stamp(kind, size: size, elevation: elevation)) }
            for row in 0..<height {
                for column in 0..<width {
                    for (sizeIndex, size) in sizes.enumerated() {
                        var cells: [Int] = []
                        var inside: Int = 0
                        var leak: Int = 0
                        for offset in stamps[sizeIndex] {
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

    /// The depth-first plant search of the certification started from a partly dark bed: the same candidate order,
    /// cover bound, leak allowance and outside limit, with the supply left instead of the level's and the work counted
    /// across every run of one call.
    struct Continuation {
        let level: NocturneGardenLevel
        let workBound: Int
        let needed: Int
        let maxOutside: Int
        var work: Int = 0
        var dark: [Bool]
        var target: [Bool]
        var forbidden: [Bool]
        /// The usable plants (candidate order) and their cover, per elevation, computed once per call.
        var usable: [Int: (plants: [Plant], cover: Int)] = [:]

        init(level: NocturneGardenLevel, workBound: Int) {
            self.level = level
            self.workBound = workBound
            needed = NocturneGardenSolver.needed(level)
            let p: Int = level.required.numerator
            let q: Int = level.required.denominator
            // As in the certification: shared·q ≥ p·(|T| + outside) with shared ≤ |T|, so outside ≤ |T|·(q − p) / p.
            maxOutside = p > 0 ? level.target.count * (q - p) / p : Int.max
            dark = Array(repeating: false, count: level.cellCount)
            target = Array(repeating: false, count: level.cellCount)
            forbidden = Array(repeating: false, count: level.cellCount)
            for cell in level.target { target[cell] = true }
            for cell in level.forbidden { forbidden[cell] = true }
        }

        /// The usable plants at `elevation` in the certification's candidate order, with their cover.
        mutating func candidates(_ elevation: Int) -> (plants: [Plant], cover: Int) {
            if let cached = usable[elevation] { return cached }
            let all: [Plant] = NocturneGardenSolver.continuationPlants(level, elevation: elevation)
            let cover: Int = NocturneGardenSolver.cover(all, allowance: level.leakAllowance)
            let sorted: [Plant] = all.filter {
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
            usable[elevation] = (sorted, cover)
            return (sorted, cover)
        }

        /// The first `count` plants (candidate order) that, added to `base` under sun `elevation` within `supply`,
        /// win; an empty array when `count` is 0 and `base` already wins; nil otherwise (or over the work bound).
        mutating func run(base: [NocturneGardenBloom], elevation: Int, supply: [NocturneGardenKind: Int],
                          count: Int) -> [Plant]? {
            guard count >= 0, work <= workBound else { return nil }
            for index in dark.indices { dark[index] = false }
            var shared: Int = 0
            var outside: Int = 0
            var leak: Int = 0
            for bloom in base {
                for cell in bloom.cells(elevation: elevation, width: level.width, height: level.height)
                where !dark[cell] {
                    dark[cell] = true
                    if target[cell] {
                        shared += 1
                    } else {
                        outside += 1
                        if forbidden[cell] { leak += 1 }
                    }
                }
            }
            // The base itself is reached by the moves before the plants; it must not leak beyond the allowance.
            guard leak <= level.leakAllowance else { return nil }
            if count == 0 {
                let either: Int = level.target.count + outside
                let wins: Bool = shared > 0 && shared * level.required.denominator >= level.required.numerator * either
                return wins ? [] : nil
            }
            guard outside <= maxOutside else { return nil }
            // More plants than the supply left can never be planted.
            var supplyTotal: Int = 0
            for value in supply.values { supplyTotal += max(0, value) }
            guard count <= supplyTotal else { return nil }
            let (plants, cover) = candidates(elevation)
            var chosen: [Plant] = []
            var left: [NocturneGardenKind: Int] = supply
            let found: Bool = descend(plants, from: 0, left: count, cover: cover, shared: shared, outside: outside,
                                      leak: leak, chosen: &chosen, supply: &left)
            return found ? chosen : nil
        }

        private mutating func descend(_ plants: [Plant], from start: Int, left: Int, cover: Int, shared: Int,
                                      outside: Int, leak: Int, chosen: inout [Plant],
                                      supply: inout [NocturneGardenKind: Int]) -> Bool {
            if left == 0 {
                let either: Int = level.target.count + outside
                return shared > 0 && shared * level.required.denominator >= level.required.numerator * either
            }
            guard shared + left * cover >= needed, start < plants.count else { return false }
            for index in start..<plants.count {
                let plant: Plant = plants[index]
                guard (supply[plant.kind] ?? 0) > 0 else { continue }
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
                    supply[plant.kind, default: 0] -= 1
                    if descend(plants, from: index + 1, left: left - 1, cover: cover, shared: newShared,
                               outside: newOutside, leak: newLeak, chosen: &chosen, supply: &supply) {
                        return true
                    }
                    chosen.removeLast()
                    supply[plant.kind, default: 0] += 1
                }
                for cell in added { dark[cell] = false }
                if work > workBound { return false }
            }
            return false
        }
    }
}
