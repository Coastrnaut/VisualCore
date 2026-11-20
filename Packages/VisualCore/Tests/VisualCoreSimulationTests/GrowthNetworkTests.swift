// GrowthNetworkTests — feature 221 (R02-F21) T-R02F21-004 (FR-R02F21-005; clarification Q4; research R6, R7;
// SC-R02F21-005). Two seeded growth runs are identical; the network never passes its size or per-frame limit; every new
// cell was viable, held at least the cost and links to a 4-neighbour already in the network; eaten quanta are in the
// ledger; the ranking is food first, then index; nowhere viable gives zero growth; the grown network routes through
// `RouteSearch`; settings and seeds are refused with named reasons.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct GrowthNetworkTests {
    static let unit: Int64 = NutrientField.quantaPerUnit

    /// The error `body` throws, or nil.
    static func refusal(_ body: () throws(NutrientError) -> Void) -> NutrientError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// A seeded 32 × 32 two-channel field: random food on channel 0 (0 … 4 units), a band of 1 … 3 units with a ramp of
    /// 1 unit on channel 0, and three seeds.
    static func seededField() throws -> NutrientField {
        var random: SeededRandom = SeededRandom(seed: 2_021)
        var field: NutrientField = try NutrientField(width: 32, height: 32, channels: 2, diffusion: [0.5, 0.25])
        let cells: Int = field.cellCount
        for c in 0..<cells {
            let quanta: Int64 = Int64(random.next() % UInt64(4 * unit))
            try field.add(quanta, channel: 0, at: c)
            let other: Int64 = Int64(random.next() % UInt64(unit))
            try field.add(other, channel: 1, at: c)
        }
        try field.setBand(ViabilityBand(low: 1, high: 3, ramp: 1), channel: 0)
        let network: GrowthNetwork = try GrowthNetwork(limit: 400, perFrame: 9, threshold: 0.5, foodChannel: 0,
                                                       cost: 4_096)
        try field.setNetwork(network)
        var placed: Int = 0
        while placed < 3 {
            let c: Int = Int(random.next() % UInt64(cells))
            if field.network?.contains(c) == true { continue }
            try field.seed(at: c)
            placed += 1
        }
        return field
    }

    /// Whether a and b are 4-neighbours on a grid of `width` columns.
    static func adjacent(_ a: Int, _ b: Int, width: Int) -> Bool {
        let ax: Int = a % width
        let ay: Int = a / width
        let bx: Int = b % width
        let by: Int = b / width
        return abs(ax - bx) + abs(ay - by) == 1
    }

    @Test func twoSeededRunsAreIdentical() throws {
        var first: NutrientField = try Self.seededField()
        var second: NutrientField = try Self.seededField()
        var grownFirst: [Int] = []
        var grownSecond: [Int] = []
        for _ in 0..<50 {
            let a: (grown: Int, eaten: Int64) = first.growthPhase()
            let b: (grown: Int, eaten: Int64) = second.growthPhase()
            grownFirst.append(a.grown)
            grownSecond.append(b.grown)
            #expect(a.eaten == b.eaten)
        }
        #expect(grownFirst == grownSecond)
        #expect(first.network?.cells == second.network?.cells)
        #expect(first.network?.parents == second.network?.parents)
        #expect(first.amountQ == second.amountQ)
        #expect(first.ledger == second.ledger)
        #expect(first == second)
        let total: Int = grownFirst.reduce(0, +)
        #expect(total > 20, "the seeded scene grows")
    }

    @Test func everyFrameKeepsTheRules() throws {
        var field: NutrientField = try Self.seededField()
        let width: Int = field.width
        var totalGrown: Int = 0
        var violations: [String] = []
        for frame in 0..<50 {
            let before: NutrientField = field
            guard let old = before.network else { Issue.record("network missing"); return }
            let result: (grown: Int, eaten: Int64) = field.growthPhase()
            guard let net = field.network else { Issue.record("network lost"); return }
            totalGrown += result.grown
            if result.grown > net.perFrame { violations.append("frame \(frame): grew \(result.grown)") }
            if net.count > net.limit { violations.append("frame \(frame): count \(net.count)") }
            if net.count != old.count + result.grown { violations.append("frame \(frame): count mismatch") }
            if result.eaten != net.cost * Int64(result.grown) { violations.append("frame \(frame): eaten") }
            if Array(net.cells[0..<old.count]) != old.cells { violations.append("frame \(frame): old cells changed") }
            if Array(net.parents[0..<old.count]) != old.parents { violations.append("frame \(frame): old parents") }
            for i in old.count..<net.count {
                let cell: Int = net.cells[i]
                let parent: Int = net.parents[i]
                if before.viability(at: cell) < net.threshold { violations.append("cell \(cell) not viable") }
                let foodBefore: Int64 = before.amount(net.foodChannel, at: cell)
                if foodBefore < net.cost { violations.append("cell \(cell) too poor") }
                if field.amount(net.foodChannel, at: cell) != foodBefore - net.cost {
                    violations.append("cell \(cell) did not eat the cost")
                }
                if old.contains(cell) { violations.append("cell \(cell) was already in the network") }
                if !Self.adjacent(cell, parent, width: width) { violations.append("cell \(cell) parent not adjacent") }
                // The parent was in the network before this cell joined and is its lowest-index network neighbour then.
                let earlier: [Int] = Array(net.cells[0..<i])
                if !earlier.contains(parent) { violations.append("cell \(cell) parent not yet in the network") }
                for other in earlier where other < parent && Self.adjacent(cell, other, width: width) {
                    violations.append("cell \(cell) parent \(parent) not lowest (\(other))")
                }
            }
            if !field.isBalanced { violations.append("frame \(frame): unbalanced") }
        }
        #expect(violations.isEmpty, "\(violations.prefix(5))")
        guard let net = field.network else { return }
        #expect(field.ledger.accounts[0].eaten == net.cost * Int64(totalGrown))
        #expect(field.ledger.accounts[1].eaten == 0)
        #expect(Set(net.cells).count == net.count)
    }

    @Test func limitStopsGrowth() throws {
        var field: NutrientField = try NutrientField(width: 8, height: 8, diffusion: [0])
        try field.setNetwork(GrowthNetwork(limit: 10, perFrame: 3, threshold: 1, foodChannel: 0, cost: 0))
        try field.seed(at: 27)
        var counts: [Int] = []
        for _ in 0..<6 {
            let result: (grown: Int, eaten: Int64) = field.growthPhase()
            counts.append(result.grown)
        }
        #expect(counts == [3, 3, 3, 0, 0, 0])
        #expect(field.network?.count == 10)
        #expect(Self.refusal { () throws(NutrientError) in try field.seed(at: 0) } == .growth("limit"))
    }

    @Test func rankingIsFoodFirstThenIndex() throws {
        var field: NutrientField = try NutrientField(width: 4, height: 4, diffusion: [0])
        let foods: [(Int, Int64)] = [(1, 5), (4, 9), (6, 9), (9, 2)]
        for (cell, units) in foods { try field.add(units * Self.unit, channel: 0, at: cell) }
        try field.setNetwork(GrowthNetwork(limit: 16, perFrame: 2, threshold: 1, foodChannel: 0, cost: Self.unit))
        try field.seed(at: 5)
        let first: (grown: Int, eaten: Int64) = field.growthPhase()
        #expect(first.grown == 2)
        #expect(first.eaten == 2 * Self.unit)
        #expect(field.network?.cells == [5, 4, 6])
        #expect(field.network?.parents == [-1, 5, 5])
        let second: (grown: Int, eaten: Int64) = field.growthPhase()
        #expect(second.grown == 2)
        #expect(field.network?.cells == [5, 4, 6, 1, 9])
        #expect(field.network?.parents == [-1, 5, 5, 5, 5])
        #expect(field.amount(0, at: 4) == 8 * Self.unit)
        #expect(field.amount(0, at: 9) == 1 * Self.unit)
        // Only cells of 4 and 6 hold food now (8 units each, cost 1), both in the network: nothing left to grow.
        let third: (grown: Int, eaten: Int64) = field.growthPhase()
        #expect(third.grown == 0)
        #expect(third.eaten == 0)
        #expect(field.isBalanced)
    }

    @Test func parentIsLowestIndexNeighbourIncludingCellsGrownThisFrame() throws {
        var field: NutrientField = try NutrientField(width: 4, height: 4, diffusion: [0])
        try field.add(9 * Self.unit, channel: 0, at: 1)
        try field.add(8 * Self.unit, channel: 0, at: 5)
        try field.setNetwork(GrowthNetwork(limit: 16, perFrame: 2, threshold: 1, foodChannel: 0, cost: Self.unit))
        try field.seed(at: 0)
        try field.seed(at: 6)
        let result: (grown: Int, eaten: Int64) = field.growthPhase()
        #expect(result.grown == 2)
        // Cell 1 (9 units) links to seed 0; cell 5 then links to cell 1 (lower than seed 6), grown in the same frame.
        #expect(field.network?.cells == [0, 6, 1, 5])
        #expect(field.network?.parents == [-1, -1, 0, 1])
    }

    @Test func nowhereViableGivesZeroGrowth() throws {
        var field: NutrientField = try NutrientField(width: 6, height: 6, channels: 2, diffusion: [0, 0])
        for c in 0..<field.cellCount { try field.add(Self.unit, channel: 0, at: c) }
        let r1: (grown: Int, eaten: Int64) = field.growthPhase()
        #expect(r1.grown == 0 && r1.eaten == 0, "no network")
        try field.setBand(ViabilityBand(low: 10, high: 20), channel: 0)
        try field.setNetwork(GrowthNetwork(limit: 36, perFrame: 8, threshold: 0.1, foodChannel: 0, cost: 1))
        try field.seed(at: 14)
        let before: NutrientField = field
        let r2: (grown: Int, eaten: Int64) = field.growthPhase()
        #expect(r2.grown == 0 && r2.eaten == 0, "nothing viable")
        #expect(field == before)
        // Viable everywhere, but the food channel (1) is empty and the cost is 1 quantum.
        try field.setBand(nil, channel: 0)
        try field.setNetwork(GrowthNetwork(limit: 36, perFrame: 8, threshold: 1, foodChannel: 1, cost: 1))
        try field.seed(at: 14)
        let r3: (grown: Int, eaten: Int64) = field.growthPhase()
        #expect(r3.grown == 0 && r3.eaten == 0, "too poor")
        #expect(field.network?.count == 1)
        #expect(field.isBalanced)
    }

    @Test func zeroCostGrowsWithoutEating() throws {
        var field: NutrientField = try NutrientField(width: 4, height: 4, diffusion: [0])
        try field.setNetwork(GrowthNetwork(limit: 16, perFrame: 1_024, threshold: 1, foodChannel: 0, cost: 0))
        try field.seed(at: 0)
        var frames: Int = 0
        while (field.network?.count ?? 0) < 16 && frames < 10 {
            let result: (grown: Int, eaten: Int64) = field.growthPhase()
            #expect(result.eaten == 0)
            frames += 1
        }
        #expect(field.network?.count == 16)
        #expect(frames == 6, "a breadth-first wave from a corner of a 4 × 4 grid takes six frames")
        #expect(field.ledger.accounts[0].eaten == 0)
        #expect(field.isBalanced)
    }

    @Test func networkGraphRoutesBetweenAnyTwoCells() throws {
        var field: NutrientField = try NutrientField(width: 16, height: 16, diffusion: [0])
        var empty: RouteGraph = field.networkGraph()
        #expect(empty.nodeCount == 256)
        #expect(empty.edgeCount == 0)
        var random: SeededRandom = SeededRandom(seed: 2_021)
        for c in 0..<field.cellCount {
            try field.add(Int64(random.next() % UInt64(3 * Self.unit)), channel: 0, at: c)
        }
        try field.setNetwork(GrowthNetwork(limit: 90, perFrame: 5, threshold: 1, foodChannel: 0, cost: 0))
        try field.seed(at: 136)
        for _ in 0..<40 { _ = field.growthPhase() }
        guard let net = field.network else { Issue.record("network missing"); return }
        #expect(net.count == 90)
        empty = field.networkGraph()
        let graph: RouteGraph = empty
        #expect(graph.nodeCount == field.cellCount)
        #expect(graph.edgeCount == 2 * (net.count - 1))
        var failures: Int = 0
        for i in 0..<net.count {
            for j in (i + 1)..<net.count {
                let outcome: RouteOutcome = try RouteSearch.breadthFirst(in: graph, from: net.cells[i], to: net.cells[j])
                guard case .found(let path, _) = outcome else { failures += 1; continue }
                if path.nodes.count > net.count { failures += 1 }
                for node in path.nodes where !net.contains(node) { failures += 1 }
            }
        }
        #expect(failures == 0)
        // A cell outside the network is not reached.
        var outside: Int = 0
        while net.contains(outside) { outside += 1 }
        let lost: RouteOutcome = try RouteSearch.breadthFirst(in: graph, from: net.cells[0], to: outside)
        guard case .unreachable = lost else { Issue.record("outside cell reached"); return }
    }

    @Test func growthRunsOnlyForPositiveFrameTime() throws {
        var field: NutrientField = try NutrientField(width: 4, height: 4, diffusion: [0])
        for c in 0..<field.cellCount { try field.add(2 * Self.unit, channel: 0, at: c) }
        try field.setNetwork(GrowthNetwork(limit: 16, perFrame: 2, threshold: 1, foodChannel: 0, cost: Self.unit))
        try field.seed(at: 5)
        let still: NutrientStepReport = try field.step(by: 0)
        #expect(still.grown == 0)
        #expect(still.eaten == [0])
        #expect(field.network?.count == 1)
        let moving: NutrientStepReport = try field.step(by: 1.0 / 60.0)
        #expect(moving.grown == 2)
        #expect(moving.eaten == [2 * Self.unit])
        #expect(field.network?.cells == [5, 1, 4])
        #expect(field.ledger.accounts[0].eaten == 2 * Self.unit)
        #expect(field.isBalanced)
    }

    @Test func networkSettingsAreRefused() {
        let cases: [(Int, Int, Double, Int, Int64, String)] = [
            (0, 1, 0.5, 0, 0, "limit"),
            (65_537, 1, 0.5, 0, 0, "limit"),
            (1, 0, 0.5, 0, 0, "perFrame"),
            (1, 1_025, 0.5, 0, 0, "perFrame"),
            (1, 1, 0, 0, 0, "threshold"),
            (1, 1, 1.5, 0, 0, "threshold"),
            (1, 1, Double.nan, 0, 0, "threshold"),
            (1, 1, 0.5, -1, 0, "foodChannel"),
            (1, 1, 0.5, 0, -1, "cost"),
            (1, 1, 0.5, 0, (1 << 40) + 1, "cost"),
        ]
        for (limit, perFrame, threshold, food, cost, name) in cases {
            let error: NutrientError? = Self.refusal { () throws(NutrientError) in
                _ = try GrowthNetwork(limit: limit, perFrame: perFrame, threshold: threshold, foodChannel: food,
                                      cost: cost)
            }
            #expect(error == .growth(name), "\(name)")
            #expect(error?.reasonCode == "r2-f21.growth")
        }
        let largest: NutrientError? = Self.refusal { () throws(NutrientError) in
            _ = try GrowthNetwork(limit: 65_536, perFrame: 1_024, threshold: 1, foodChannel: 3, cost: 1 << 40)
        }
        #expect(largest == nil)
    }

    @Test func setNetworkAndSeedsAreRefused() throws {
        var field: NutrientField = try NutrientField(width: 4, height: 4, channels: 2, diffusion: [0, 0])
        let wrongFood: GrowthNetwork = try GrowthNetwork(limit: 2, perFrame: 1, threshold: 1, foodChannel: 2, cost: 0)
        let foodError: NutrientError? = Self.refusal { () throws(NutrientError) in try field.setNetwork(wrongFood) }
        #expect(foodError == .growth("foodChannel"))
        #expect(field.network == nil)
        let noNetwork: NutrientError? = Self.refusal { () throws(NutrientError) in try field.seed(at: 0) }
        #expect(noNetwork == .growth("network"))
        #expect(noNetwork?.reasonCode == "r2-f21.growth")
        try field.setNetwork(GrowthNetwork(limit: 2, perFrame: 1, threshold: 1, foodChannel: 1, cost: 0))
        let below: NutrientError? = Self.refusal { () throws(NutrientError) in try field.seed(at: -1) }
        #expect(below == .cellRange(-1))
        let above: NutrientError? = Self.refusal { () throws(NutrientError) in try field.seed(at: 16) }
        #expect(above == .cellRange(16))
        #expect(above?.reasonCode == "r2-f21.cell-range")
        try field.seed(at: 3)
        let twice: NutrientError? = Self.refusal { () throws(NutrientError) in try field.seed(at: 3) }
        #expect(twice == .growth("seed"))
        try field.seed(at: 12)
        let full: NutrientError? = Self.refusal { () throws(NutrientError) in try field.seed(at: 0) }
        #expect(full == .growth("limit"))
        #expect(field.network?.cells == [3, 12])
        #expect(field.network?.parents == [-1, -1])
    }
}
