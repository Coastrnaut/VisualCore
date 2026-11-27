// MushroomWeatherForest — feature 491 (R02-G20-01) T-R02G2001-002 (FR-R02G2001-002, 003, 004, 005, 014;
// SC-R02G2001-003, 004; clarifications Q1 … Q4). The exact weather of Mushroom Weather: a forest floor of 6 … 12 rows by
// 6 … 14 columns of floor and blocked cells with a closed boundary; integer humidity per floor cell; one cycle is three
// synchronous steps, each computed from the state at the start of the step: (1) diffusion, one antisymmetric flow
// (hₐ − h_b)·D/64 truncated toward zero per pair of orthogonally adjacent floor cells; (2) evaporation
// ⌊h·rate·(4 + L)/4096⌋, never more than the cell holds, with each vent cell's open or closed rate; (3) release r by
// every placed pod, or g once grown. The ledger of every cycle (before, released, evaporated, after) balances exactly;
// a pod's integral adds its cell's humidity after every cycle and the pod is grown from the next cycle once the
// integral reaches G; each colony's in-band runs (low ≤ h ≤ high); and the judge (per cycle `dried`, the lowest-numbered
// sensitive colony below its floor, then `mold`, the first floor cell in row-major order above M; after T cycles won
// when every colony was in band for each of the last K cycles, else `unstable`). Integers only; no clock is read.

/// A forest-floor cell by row and column (from 0), ordered row-major.
public struct MushroomWeatherCell: Sendable, Hashable, Codable, Comparable {
    /// The row, from 0 at the top.
    public let row: Int
    /// The column, from 0 at the left.
    public let column: Int

    /// The cell at `row`, `column`.
    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    /// Row-major order.
    public static func < (a: MushroomWeatherCell, b: MushroomWeatherCell) -> Bool {
        a.row != b.row ? a.row < b.row : a.column < b.column
    }
}

/// A canopy vent: a fixed floor cell whose evaporation rate is `openRate` while open and `closedRate` while closed.
public struct MushroomWeatherVent: Sendable, Hashable, Codable {
    /// The cell under the vent.
    public let cell: MushroomWeatherCell
    /// The evaporation rate while the vent is open, 0 … 200.
    public let openRate: Int
    /// The evaporation rate while the vent is closed, 0 … 200.
    public let closedRate: Int

    /// A vent over `cell` with the given rates (checked by ``MushroomWeatherLevel``).
    public init(cell: MushroomWeatherCell, openRate: Int, closedRate: Int) {
        self.cell = cell
        self.openRate = openRate
        self.closedRate = closedRate
    }

    /// The rate for the vent's state.
    public func rate(open: Bool) -> Int { open ? openRate : closedRate }
}

/// A mushroom colony: a floor cell, its preferred band low … high and, when sensitive, its survival floor.
public struct MushroomWeatherColony: Sendable, Hashable, Codable {
    /// The colony's cell.
    public let cell: MushroomWeatherCell
    /// The lowest humidity inside the band.
    public let low: Int
    /// The highest humidity inside the band.
    public let high: Int
    /// The survival floor f (0 ≤ f ≤ low) of a sensitive colony, nil when the colony is not sensitive.
    public let survivalFloor: Int?

    /// A colony on `cell` with band `low` … `high` and an optional survival floor (checked by ``MushroomWeatherLevel``).
    public init(cell: MushroomWeatherCell, low: Int, high: Int, survivalFloor: Int? = nil) {
        self.cell = cell
        self.low = low
        self.high = high
        self.survivalFloor = survivalFloor
    }

    /// Whether `humidity` is inside the band (edges included).
    public func isInBand(_ humidity: Int) -> Bool { low <= humidity && humidity <= high }

    /// Whether `humidity` dries the colony out (only a sensitive colony, strictly below its floor).
    public func driesOut(_ humidity: Int) -> Bool {
        guard let survivalFloor else { return false }
        return humidity < survivalFloor
    }
}

/// The spore-pod rules of a level: the number of slots, the release, the grown release and the growth threshold.
public struct MushroomWeatherPodRules: Sendable, Hashable, Codable {
    /// The slot counts.
    public static let slotCounts: ClosedRange<Int> = 1...6
    /// The releases per cycle.
    public static let releases: ClosedRange<Int> = 1...40
    /// The largest grown release.
    public static let maximumGrownRelease: Int = 80
    /// The growth thresholds.
    public static let thresholds: ClosedRange<Int> = 100...200_000

    /// The number of pod slots P, 1 … 6.
    public let slots: Int
    /// The release r per cycle of an ungrown pod, 1 … 40.
    public let release: Int
    /// The release g per cycle of a grown pod, r … 80.
    public let grownRelease: Int
    /// The growth threshold G of a pod's humidity integral, 100 … 200000.
    public let growthThreshold: Int

    /// Pod rules of the given values (checked by ``MushroomWeatherLevel``).
    public init(slots: Int, release: Int, grownRelease: Int, growthThreshold: Int) {
        self.slots = slots
        self.release = release
        self.grownRelease = grownRelease
        self.growthThreshold = growthThreshold
    }

    /// The name of the first value outside its range, or nil.
    public var invalidValue: String? {
        guard Self.slotCounts.contains(slots) else { return "slots" }
        guard Self.releases.contains(release) else { return "release" }
        guard (release...Self.maximumGrownRelease).contains(grownRelease) else { return "grown release" }
        guard Self.thresholds.contains(growthThreshold) else { return "growth threshold" }
        return nil
    }
}

/// An arrangement: the pod in every slot (nil for an empty slot), every vent's state and the moonlight level.
public struct MushroomWeatherArrangement: Sendable, Hashable, Codable {
    /// The pod cell of every slot, nil for an empty slot.
    public let pods: [MushroomWeatherCell?]
    /// Whether each of the level's vents is open, by vent index.
    public let ventsOpen: [Bool]
    /// The moonlight level L, 0 … 3.
    public let moonlight: Int

    /// The arrangement of the given pods, vent states and moonlight (checked by ``MushroomWeatherLevel``).
    public init(pods: [MushroomWeatherCell?], ventsOpen: [Bool], moonlight: Int) {
        self.pods = pods
        self.ventsOpen = ventsOpen
        self.moonlight = moonlight
    }

    /// The placed pod cells, in slot order.
    public var placedPods: [MushroomWeatherCell] { pods.compactMap { $0 } }
}

/// Why a run of the weather failed.
public enum MushroomWeatherFailure: Sendable, Hashable, Codable {
    /// Sensitive colony `colony` (index from 0) fell below its survival floor at `cycle`.
    case dried(colony: Int, cycle: Int)
    /// `cell` rose above the mold bound at `cycle`.
    case mold(cell: MushroomWeatherCell, cycle: Int)
    /// The run ended without every colony in band for the last K cycles; `colony` (index from 0) had the shortest final
    /// in-band run, `run` cycles.
    case unstable(colony: Int, run: Int)

    /// The failure's code: `dried`, `mold` or `unstable`.
    public var code: String {
        switch self {
        case .dried: "dried"
        case .mold: "mold"
        case .unstable: "unstable"
        }
    }
}

/// The humidity ledger of one cycle: total after = total before + released − evaporated, exactly.
public struct MushroomWeatherLedger: Sendable, Hashable, Codable {
    /// The cycle, from 1 (0 for a lone ``MushroomWeatherForest/cycle(_:level:arrangement:grown:)``).
    public let cycle: Int
    /// The total humidity of the floor before the cycle.
    public let before: Int
    /// The humidity released by pods in the cycle.
    public let released: Int
    /// The humidity evaporated in the cycle.
    public let evaporated: Int
    /// The total humidity of the floor after the cycle.
    public let after: Int

    /// A ledger of the given values.
    public init(cycle: Int, before: Int, released: Int, evaporated: Int, after: Int) {
        self.cycle = cycle
        self.before = before
        self.released = released
        self.evaporated = evaporated
        self.after = after
    }

    /// Whether after = before + released − evaporated.
    public var balances: Bool { after == before + released - evaporated }

    /// The same ledger numbered `cycle`.
    func numbered(_ cycle: Int) -> MushroomWeatherLedger {
        MushroomWeatherLedger(cycle: cycle, before: before, released: released, evaporated: evaporated, after: after)
    }
}

/// A colony's in-band runs over one run of the weather: the survival interval of the truth metric.
public struct MushroomWeatherColonyRuns: Sendable, Hashable {
    /// The consecutive cycles in band ending at the last cycle run.
    public let finalRun: Int
    /// The longest run of consecutive cycles in band.
    public let longestRun: Int
    /// The first cycle at whose end the colony was out of band, nil when it never was.
    public let firstOutOfBand: Int?

    /// Runs of the given values.
    public init(finalRun: Int, longestRun: Int, firstOutOfBand: Int?) {
        self.finalRun = finalRun
        self.longestRun = longestRun
        self.firstOutOfBand = firstOutOfBand
    }
}

/// The exact report of one run: the truth metric (FR-R02G2001-014). It describes; the judge's result is `failure`.
public struct MushroomWeatherReport: Sendable, Equatable {
    /// The cycles run (T when the run completed, else the failing cycle).
    public let cycles: Int
    /// The humidity of every cell after the last cycle run, row-major, blocked cells 0.
    public let humidity: [Int]
    /// The ledger of every cycle run, cycle 1 first.
    public let ledger: [MushroomWeatherLedger]
    /// The cycle at which each pod slot's integral reached the threshold, nil when it did not (or the slot is empty).
    public let grownAt: [Int?]
    /// Each colony's in-band runs, by colony index.
    public let colonies: [MushroomWeatherColonyRuns]
    /// The judge's failure, or nil when the run wins.
    public let failure: MushroomWeatherFailure?

    /// A report of the given values.
    public init(cycles: Int, humidity: [Int], ledger: [MushroomWeatherLedger], grownAt: [Int?],
                colonies: [MushroomWeatherColonyRuns], failure: MushroomWeatherFailure?) {
        self.cycles = cycles
        self.humidity = humidity
        self.ledger = ledger
        self.grownAt = grownAt
        self.colonies = colonies
        self.failure = failure
    }

    /// Whether the run wins.
    public var wins: Bool { failure == nil }
}

/// A player action: place or move a pod, empty a pod slot, set a vent, set the moonlight, or run the weather.
public enum MushroomWeatherAction: Sendable, Hashable, Codable {
    /// Put the pod of slot `slot` on `cell`, or move it there; spends one action.
    case place(slot: Int, cell: MushroomWeatherCell)
    /// Empty slot `slot`; spends one action.
    case remove(slot: Int)
    /// Open or close vent `index`; spends one action.
    case vent(index: Int, open: Bool)
    /// Set the moonlight level; spends one action.
    case moonlight(level: Int)
    /// Run the weather; spends nothing and ends the level.
    case run
}

/// The forest floor and the exact weather.
public enum MushroomWeatherForest {
    /// The largest mold bound M.
    public static let maximumMoldBound: Int = 10_000
    /// The divisor of the diffusion flow.
    public static let diffusionDivisor: Int = 64
    /// The divisor of the evaporation.
    public static let evaporationDivisor: Int = 4096
    /// The moonlight offset: a cell loses ⌊h·rate·(offset + L)/4096⌋.
    public static let moonlightOffset: Int = 4

    /// The evaporation rate of every cell, row-major: the level's rate, or the vent's open or closed rate on a vent cell.
    public static func rates(_ level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement) -> [Int] {
        var rates: [Int] = level.rates
        for (index, vent) in level.vents.enumerated() {
            let open: Bool = index < arrangement.ventsOpen.count ? arrangement.ventsOpen[index] : false
            rates[level.index(of: vent.cell)] = vent.rate(open: open)
        }
        return rates
    }

    /// The evaporation of a cell holding `humidity` at `rate` under moonlight `moonlight`: ⌊h·rate·(4 + L)/4096⌋,
    /// never more than `humidity`.
    public static func evaporation(_ humidity: Int, rate: Int, moonlight: Int) -> Int {
        min(humidity, humidity * rate * (moonlightOffset + moonlight) / evaporationDivisor)
    }

    /// The diffusion flow from a cell holding `a` to a neighbour holding `b`: (a − b)·D/64 truncated toward zero.
    public static func flow(_ a: Int, _ b: Int, diffusion: Int) -> Int {
        (a - b) * diffusion / diffusionDivisor
    }

    /// One synchronous cycle of `humidity` (row-major): diffusion, then evaporation, then release by every placed pod
    /// (`grown[slot]` selects the grown release). The ledger's cycle is 0; ``run(_:arrangement:keepFields:)`` numbers
    /// it.
    public static func cycle(_ humidity: [Int], level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement,
                             grown: [Bool]) -> (humidity: [Int], ledger: MushroomWeatherLedger) {
        cycle(humidity, level: level, arrangement: arrangement, grown: grown,
              rates: rates(level, arrangement: arrangement))
    }

    /// One cycle with the cell rates already resolved.
    static func cycle(_ humidity: [Int], level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement,
                      grown: [Bool], rates: [Int]) -> (humidity: [Int], ledger: MushroomWeatherLedger) {
        let rows: Int = level.rows
        let columns: Int = level.columns
        let floor: [Bool] = level.floorMask
        var before: Int = 0
        for value in humidity { before += value }
        var next: [Int] = humidity
        for row in 0..<rows {
            for column in 0..<columns {
                let a: Int = row * columns + column
                guard floor[a] else { continue }
                if column + 1 < columns, floor[a + 1] {
                    let f: Int = flow(humidity[a], humidity[a + 1], diffusion: level.diffusion)
                    next[a] -= f
                    next[a + 1] += f
                }
                if row + 1 < rows, floor[a + columns] {
                    let f: Int = flow(humidity[a], humidity[a + columns], diffusion: level.diffusion)
                    next[a] -= f
                    next[a + columns] += f
                }
            }
        }
        var evaporated: Int = 0
        for a in next.indices where floor[a] {
            let e: Int = evaporation(next[a], rate: rates[a], moonlight: arrangement.moonlight)
            next[a] -= e
            evaporated += e
        }
        var released: Int = 0
        for (slot, pod) in arrangement.pods.enumerated() {
            guard let pod else { continue }
            let amount: Int = (slot < grown.count && grown[slot]) ? level.podRules.grownRelease : level.podRules.release
            next[level.index(of: pod)] += amount
            released += amount
        }
        var after: Int = 0
        for value in next { after += value }
        return (next, MushroomWeatherLedger(cycle: 0, before: before, released: released, evaporated: evaporated,
                                             after: after))
    }

    /// The run of `level` with `arrangement`, judged; with `keepFields`, the humidity of every cycle run (cycle 0, the
    /// start, first).
    public static func run(_ level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement,
                           keepFields: Bool) -> (report: MushroomWeatherReport, fields: [[Int]]) {
        let rates: [Int] = rates(level, arrangement: arrangement)
        let slots: Int = arrangement.pods.count
        var humidity: [Int] = level.humidity
        var fields: [[Int]] = []
        if keepFields { fields.append(humidity) }
        var ledger: [MushroomWeatherLedger] = []
        ledger.reserveCapacity(level.length)
        var grown: [Bool] = Array(repeating: false, count: slots)
        var integrals: [Int] = Array(repeating: 0, count: slots)
        var grownAt: [Int?] = Array(repeating: nil, count: slots)
        let colonyCount: Int = level.colonies.count
        var current: [Int] = Array(repeating: 0, count: colonyCount)
        var longest: [Int] = Array(repeating: 0, count: colonyCount)
        var firstOut: [Int?] = Array(repeating: nil, count: colonyCount)
        let colonyIndices: [Int] = level.colonies.map { level.index(of: $0.cell) }
        let podIndices: [Int?] = arrangement.pods.map { pod in pod.map { level.index(of: $0) } }
        let floor: [Bool] = level.floorMask
        var failure: MushroomWeatherFailure?
        var cycles: Int = 0
        for cycle in 1...level.length {
            let step = Self.cycle(humidity, level: level, arrangement: arrangement, grown: grown, rates: rates)
            humidity = step.humidity
            ledger.append(step.ledger.numbered(cycle))
            cycles = cycle
            if keepFields { fields.append(humidity) }
            for slot in 0..<slots {
                guard let index = podIndices[slot] else { continue }
                integrals[slot] += humidity[index]
                if !grown[slot] && integrals[slot] >= level.podRules.growthThreshold {
                    grown[slot] = true
                    grownAt[slot] = cycle
                }
            }
            for k in 0..<colonyCount {
                if level.colonies[k].isInBand(humidity[colonyIndices[k]]) {
                    current[k] += 1
                    longest[k] = max(longest[k], current[k])
                } else {
                    current[k] = 0
                    if firstOut[k] == nil { firstOut[k] = cycle }
                }
            }
            if let k = (0..<colonyCount).first(where: { level.colonies[$0].driesOut(humidity[colonyIndices[$0]]) }) {
                failure = .dried(colony: k, cycle: cycle)
                break
            }
            if let a = humidity.indices.first(where: { floor[$0] && humidity[$0] > level.moldBound }) {
                failure = .mold(cell: level.cell(at: a), cycle: cycle)
                break
            }
        }
        if failure == nil {
            var shortest: Int = 0
            for k in 1..<max(1, colonyCount) where current[k] < current[shortest] { shortest = k }
            if colonyCount > 0 && current[shortest] < level.required {
                failure = .unstable(colony: shortest, run: current[shortest])
            }
        }
        let runs: [MushroomWeatherColonyRuns] = (0..<colonyCount).map {
            MushroomWeatherColonyRuns(finalRun: current[$0], longestRun: longest[$0], firstOutOfBand: firstOut[$0])
        }
        let report = MushroomWeatherReport(cycles: cycles, humidity: humidity, ledger: ledger, grownAt: grownAt,
                                           colonies: runs, failure: failure)
        return (report, fields)
    }

    /// The report of `level` with `arrangement`.
    public static func report(_ level: MushroomWeatherLevel,
                              arrangement: MushroomWeatherArrangement) -> MushroomWeatherReport {
        run(level, arrangement: arrangement, keepFields: false).report
    }
}
