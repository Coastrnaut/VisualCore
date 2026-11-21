// ColorfallCanyonsGenerator — feature 342 (R02-G05-02) T-R02G0502-004 (FR-R02G0502-001, 005; clarifications Q1, Q3, Q5).
// Builds each catalog level from its manifest entry. Candidate k of entry n draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`, in this order: per cell row-major a height
// clamp(12 − 2·row + draw(−2 … 2), 0 … 15) and rock with chance 15 %; each bottom-row cell a drain (height 0) with chance
// 20 %, and one drawn bottom cell when none did; the band's depressions (the first cells of the shuffled open cells of
// rows 2 … rows − 2, lowered to their lowest neighbour's height minus draw(1 … 2), at least 0); the springs on the first
// cells of the shuffled open cells of rows 0 … 1, colours a shuffled cyan, coral, yellow, release draw(1 … 3), supply
// draw(8 … 24), valves open; flow rate draw(3 … 6); tick limit draw(60 … 120). A planted plan then gives each spring in
// turn one path change (a carvable cell on or next to its current path, carved the smallest 1 … 3 times that changes the
// path, chosen by draw). Basins sit on the distinct pooled end cells of the planted paths that hold at least 3 units more
// after the planted run than after the unedited one; their targets come from the planted run. The candidate is kept when
// the planted plan wins, the unedited level does not, and the solver's smallest edit count lies in the band's range;
// otherwise k grows, at most 512 candidates.
import VisualCoreSimulation

/// What the generator builds for one band (clarification Q1).
public struct ColorfallCanyonsBandProfile: Sendable, Equatable {
    /// The grid's columns.
    public let columns: Int
    /// The grid's rows.
    public let rows: Int
    /// The springs.
    public let springs: Int
    /// The depressions lowered into the middle rows.
    public let depressions: Int
    /// The smallest edit counts a level of the band may need.
    public let smallest: ClosedRange<Int>

    /// A profile of the given values.
    public init(columns: Int, rows: Int, springs: Int, depressions: Int, smallest: ClosedRange<Int>) {
        self.columns = columns
        self.rows = rows
        self.springs = springs
        self.depressions = depressions
        self.smallest = smallest
    }

    /// The profile of `band` (1 … 5; others clamp).
    public static func of(band: Int) -> ColorfallCanyonsBandProfile {
        switch band {
        case ...1: ColorfallCanyonsBandProfile(columns: 6, rows: 5, springs: 1, depressions: 3, smallest: 1...2)
        case 2: ColorfallCanyonsBandProfile(columns: 6, rows: 5, springs: 2, depressions: 4, smallest: 2...3)
        case 3: ColorfallCanyonsBandProfile(columns: 7, rows: 5, springs: 2, depressions: 5, smallest: 3...3)
        case 4: ColorfallCanyonsBandProfile(columns: 8, rows: 6, springs: 3, depressions: 8, smallest: 3...3)
        default: ColorfallCanyonsBandProfile(columns: 8, rows: 6, springs: 3, depressions: 8, smallest: 3...3)
        }
    }
}

/// A generated catalog level with its proof.
public struct ColorfallCanyonsGenerated: Sendable, Equatable {
    /// The manifest entry it was built from.
    public let entry: ColorfallCanyonsManifestEntry
    /// The level.
    public let level: ColorfallCanyonsLevel
    /// The planted edits the basins' targets were taken from (they win).
    public let planted: [ColorfallCanyonsEdit]
    /// The solver's smallest winning edit set.
    public let solution: ColorfallCanyonsSolution
    /// The difficulty metrics.
    public let difficulty: ColorfallCanyonsDifficulty
    /// The candidates skipped before this one.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: ColorfallCanyonsManifestEntry, level: ColorfallCanyonsLevel, planted: [ColorfallCanyonsEdit],
                solution: ColorfallCanyonsSolution, difficulty: ColorfallCanyonsDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.planted = planted
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The seeded level generator (clarification Q1).
public enum ColorfallCanyonsGenerator {
    /// The catalog id the digest is taken over.
    public static let catalogID = "colorfall-canyons"
    /// The levels that show a tutorial first.
    public static let tutorialLevels: ClosedRange<Int> = 1...3
    /// The candidates tried per level.
    public static let maximumCandidates = 512

    /// The id of level `number`: `colorfall-canyons-NNN` (three digits).
    public static func levelID(_ number: Int) -> String {
        "colorfall-canyons-" + String(String(number + 1_000).suffix(3))
    }

    /// Candidate `index` of `entry` and its planted edits, or nil when the draws do not give a level (too few spring
    /// cells, no path change, too few pooled ends).
    public static func candidate(_ entry: ColorfallCanyonsManifestEntry,
                                 index: Int) -> (level: ColorfallCanyonsLevel, planted: [ColorfallCanyonsEdit])? {
        let profile = ColorfallCanyonsBandProfile.of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let columns: Int = profile.columns
        let rows: Int = profile.rows
        let count: Int = columns * rows
        var heights: [Int] = []
        var grounds: [ColorfallCanyonsGround] = []
        for cell in 0..<count {
            let row: Int = cell / columns
            heights.append(min(15, max(0, 12 - 2 * row + random.int(-2...2))))
            grounds.append(random.int(0...99) < 15 ? .rock : .open)
        }
        let bottom: Int = columns * (rows - 1)
        for cell in bottom..<count where random.int(0...99) < 20 {
            grounds[cell] = .drain
            heights[cell] = 0
        }
        if !grounds.contains(.drain) {
            let cell: Int = bottom + random.int(0...(columns - 1))
            grounds[cell] = .drain
            heights[cell] = 0
        }
        let draft = Draft(columns: columns, rows: rows, grounds: grounds)
        var middle: [Int] = (columns * 2..<columns * (rows - 1)).filter { grounds[$0] == .open }
        shuffle(&middle, &random)
        for cell in middle.prefix(profile.depressions) {
            let lowest: Int = draft.neighbours(of: cell).map { heights[$0] }.min() ?? heights[cell]
            heights[cell] = max(0, lowest - random.int(1...2))
        }
        var top: [Int] = (0..<columns * 2).filter { grounds[$0] == .open }
        shuffle(&top, &random)
        guard top.count >= profile.springs else { return nil }
        var colours: [Int] = [0, 1, 2]
        shuffle(&colours, &random)
        var springs: [ColorfallCanyonsSpring] = []
        for i in 0..<profile.springs {
            springs.append(ColorfallCanyonsSpring(cell: top[i], color: ColorfallCanyonsColor(rawValue: colours[i]) ?? .cyan,
                                                  release: random.int(1...3), supply: random.int(8...24), open: true))
        }
        let flowRate: Int = random.int(3...6)
        let tickLimit: Int = random.int(60...120)
        let springCells: Set<Int> = Set(springs.map(\.cell))

        // The planted plan: one path change per spring, in order.
        var planted: [ColorfallCanyonsEdit] = []
        var carvedHeights: [Int] = heights
        for spring in springs {
            let path: [Int] = draft.path(from: spring.cell, heights: carvedHeights, springs: springCells)
            let onPath: Set<Int> = Set(path)
            var options: [(cell: Int, depth: Int)] = []
            for cell in 0..<count where grounds[cell] == .open && !springCells.contains(cell) && carvedHeights[cell] > 0 {
                guard onPath.contains(cell) || draft.neighbours(of: cell).contains(where: onPath.contains) else { continue }
                for depth in 1...3 where carvedHeights[cell] - depth >= 0 {
                    var trial: [Int] = carvedHeights
                    trial[cell] -= depth
                    if draft.path(from: spring.cell, heights: trial, springs: springCells) != path {
                        options.append((cell, depth))
                        break
                    }
                }
            }
            guard !options.isEmpty else { return nil }
            let choice = options[random.int(0...(options.count - 1))]
            carvedHeights[choice.cell] -= choice.depth
            planted += Array(repeating: .carve(choice.cell), count: choice.depth)
        }

        // Pools of the planted run that the unedited run leaves (much) emptier.
        let plantedMasses: [[Int]] = draft.run(heights: carvedHeights, springs: springs, flowRate: flowRate,
                                               ticks: tickLimit)
        let uneditedMasses: [[Int]] = draft.run(heights: heights, springs: springs, flowRate: flowRate, ticks: tickLimit)
        let plantedRouting: [Int?] = draft.routing(carvedHeights, springs: springCells)
        let carved: Set<Int> = Set(planted.compactMap { if case .carve(let cell) = $0 { cell } else { nil } })
        func volume(_ masses: [Int]) -> Int { masses.reduce(0, +) }
        var ends: [Int] = []
        for spring in springs {
            guard let end = draft.path(from: spring.cell, heights: carvedHeights, springs: springCells).last else {
                continue
            }
            let pooled: Bool = grounds[end] == .open && plantedRouting[end] == nil && !springCells.contains(end)
                && !carved.contains(end) && volume(plantedMasses[end]) > 0
                && volume(uneditedMasses[end]) < volume(plantedMasses[end]) - 2
            if pooled && !ends.contains(end) { ends.append(end) }
        }
        guard ends.count >= min(profile.springs, 2) else { return nil }
        let tolerances: [Int] = [50, 100, 150]
        var basins: [ColorfallCanyonsBasin] = []
        for end in ends {
            let masses: [Int] = plantedMasses[end]
            let total: Int = volume(masses)
            var shares: [Int] = masses.map { 1_000 * $0 / total }
            var largest: Int = 0
            for c in 1..<3 where masses[c] > masses[largest] { largest = c }
            shares[largest] += 1_000 - shares.reduce(0, +)
            let capacity: Int = total + random.int(0...4)
            let fill: Int = max(1, total - random.int(0...2))
            let tolerance: Int = tolerances[random.int(0...2)]
            let isProtected: Bool = random.int(0...99) < 60
            basins.append(ColorfallCanyonsBasin(cell: end, capacity: min(999, capacity), fill: min(fill, 999),
                                                shares: shares, tolerance: tolerance, isProtected: isProtected,
                                                toleratedWrong: 0))
        }
        let id: String = levelID(entry.number)
        guard let level = try? ColorfallCanyonsLevel(
            id: id, seed: entry.seed, difficulty: entry.band, columns: columns, rows: rows, heights: heights,
            grounds: grounds, springs: springs, basins: basins, flowRate: flowRate, budget: entry.budget,
            tickLimit: tickLimit, tutorial: tutorialLevels.contains(entry.number)) else { return nil }
        return (level, planted)
    }

    /// Generates `entry`'s level: the first candidate whose planted plan wins, whose unedited level does not, and whose
    /// smallest edit count lies in the band's range.
    ///
    /// - Throws: `.generation(number)` when none of the 512 candidates qualifies.
    public static func generate(_ entry: ColorfallCanyonsManifestEntry) throws(ColorfallCanyonsError)
        -> ColorfallCanyonsGenerated {
        let profile = ColorfallCanyonsBandProfile.of(band: entry.band)
        for index in 0..<maximumCandidates {
            guard let (level, planted) = candidate(entry, index: index) else { continue }
            guard ColorfallCanyonsSolver.run(level, edits: planted)?.verdict == .won,
                  let unedited = ColorfallCanyonsSolver.run(level, edits: []), unedited.verdict != .won else { continue }
            guard let solution = ColorfallCanyonsSolver.solve(level, depth: profile.smallest.upperBound),
                  profile.smallest.contains(solution.smallest) else { continue }
            let difficulty = ColorfallCanyonsDifficulty(
                smallest: solution.smallest, work: solution.work, winTick: solution.winTick,
                springs: level.springs.count, basins: level.basins.count,
                protectedBasins: level.basins.filter(\.isProtected).count,
                carvableCells: (0..<level.cellCount).filter { level.isCarvable($0, heights: level.heights) }.count)
            return ColorfallCanyonsGenerated(entry: entry, level: level, planted: planted, solution: solution,
                                             difficulty: difficulty, skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest (R02-F24) over the levels' fingerprints in order.
    public static func catalogDigest(_ levels: [ColorfallCanyonsLevel]) -> String {
        PuzzleCatalog<ColorfallCanyonsRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }

    /// A Fisher–Yates shuffle with the generator's own draws (stable across Swift versions).
    static func shuffle<T>(_ values: inout [T], _ random: inout SeededRandom) {
        guard values.count > 1 else { return }
        for i in stride(from: values.count - 1, to: 0, by: -1) {
            values.swapAt(i, random.int(0...i))
        }
    }

    /// The terrain before basins exist, with the kernel's routing and flow rules (a cell without a lower non-rock
    /// neighbour pools; drains collect).
    struct Draft {
        let columns: Int
        let rows: Int
        let grounds: [ColorfallCanyonsGround]

        /// The in-grid neighbours of `cell`, east, south, west, north.
        func neighbours(of cell: Int) -> [Int] {
            let column: Int = cell % columns
            let row: Int = cell / columns
            var result: [Int] = []
            if column + 1 < columns { result.append(cell + 1) }
            if row + 1 < rows { result.append(cell + columns) }
            if column > 0 { result.append(cell - 1) }
            if row > 0 { result.append(cell - columns) }
            return result
        }

        /// Every open (or spring) cell's downhill neighbour.
        func routing(_ heights: [Int], springs: Set<Int>) -> [Int?] {
            var result = [Int?](repeating: nil, count: grounds.count)
            for cell in grounds.indices where grounds[cell] == .open {
                var best: Int?
                var bestHeight: Int = heights[cell]
                for next in neighbours(of: cell) where grounds[next] != .rock && heights[next] < bestHeight {
                    best = next
                    bestHeight = heights[next]
                }
                result[cell] = best
            }
            return result
        }

        /// The cells fluid released at `start` visits, ending where it pools or drains.
        func path(from start: Int, heights: [Int], springs: Set<Int>) -> [Int] {
            let routing: [Int?] = routing(heights, springs: springs)
            var path: [Int] = [start]
            var seen: Set<Int> = [start]
            while let next = routing[path[path.count - 1]], !seen.contains(next) {
                path.append(next)
                seen.insert(next)
            }
            return path
        }

        /// The colour masses of every cell after `ticks` ticks with every spring open (drains emptied each tick).
        func run(heights: [Int], springs: [ColorfallCanyonsSpring], flowRate: Int, ticks: Int) -> [[Int]] {
            let routing: [Int?] = routing(heights, springs: Set(springs.map(\.cell)))
            var masses: [[Int]] = Array(repeating: [0, 0, 0], count: grounds.count)
            var supplies: [Int] = springs.map(\.supply)
            for _ in 0..<ticks {
                var next: [[Int]] = masses
                for cell in masses.indices {
                    let total: Int = masses[cell].reduce(0, +)
                    guard total > 0, let target = routing[cell] else { continue }
                    let parts: [Int] = ColorfallCanyonsFluid.share(min(total, flowRate), of: masses[cell])
                    for c in 0..<3 {
                        next[cell][c] -= parts[c]
                        next[target][c] += parts[c]
                    }
                }
                for (i, spring) in springs.enumerated() where supplies[i] > 0 {
                    let amount: Int = min(spring.release, supplies[i])
                    supplies[i] -= amount
                    next[spring.cell][spring.color.rawValue] += amount
                }
                for cell in grounds.indices where grounds[cell] == .drain { next[cell] = [0, 0, 0] }
                masses = next
            }
            return masses
        }
    }
}
