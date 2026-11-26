// MicroscopicAuroraFixtures — feature 481 (R02-G19-01) T-R02G1901-002 (SC-R02G1901-001 … 004). Seeded Microscopic
// Aurora levels with known winning wells. A fixture draws an enclosure of 10 … 11 cells, a swim of 120 … 160 ticks,
// swarm rules with a wide coherence radius, 4 … 10 swimmers bunched near a point with a shared drift, and one or two
// winning wells in slots 0 and 1; it swims them and keeps the fixture only when no swimmer leaves and the swarm stays
// linked. The stencil is the largest four-neighbour group of usable cells lit at a threshold of 1 … 4 (4 … 120 cells),
// so the winning swim covers it fully as one group; the required coverage is 500 … 1000 and the required coherence 2 …
// the winning swim's smallest coherence. The start is either no well, or one well in slot 2 on another cell, kept only
// when it does not win; the known actions empty slot 2 when needed and place the winning wells, then play; the budget
// is their number plus 0 … 2. A fixture without a non-winning start is skipped. Explicit types, plain loops.
import Foundation
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

/// A seeded level with its known winning actions.
struct MicroscopicAuroraFixture: Sendable {
    /// The level.
    let level: MicroscopicAuroraLevel
    /// The winning wells, one entry per slot.
    let winning: [MicroscopicAuroraWell?]
    /// The known actions: the placements and removals that reach the winning wells, then `play`.
    let actions: [MicroscopicAuroraAction]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_481

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [MicroscopicAuroraFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [MicroscopicAuroraFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// Random swarm rules with a wide coherence radius.
    static func rules(_ random: inout SeededRandom) -> MicroscopicAuroraSwarmRules {
        let rho: Int = random.int(2...4)
        return MicroscopicAuroraSwarmRules(neighbourRadius: rho, separationRadius: random.int(1...rho),
                                           coherenceRadius: random.int(6...8), separationWeight: random.int(0...3),
                                           alignmentWeight: random.int(1...6), cohesionWeight: random.int(1...6),
                                           maxAcceleration: random.int(4...12), maxSpeed: random.int(12...24))
    }

    /// A random usable cell of an enclosure of `radius` cells.
    static func cell(_ random: inout SeededRandom, radius: Int) -> MicroscopicAuroraCell {
        while true {
            let cell = MicroscopicAuroraCell(row: random.int(0...23), column: random.int(0...23))
            if MicroscopicAuroraLevel.isUsable(cell, radius: radius) { return cell }
        }
    }

    /// One fixture from `random`, or nil when the draw does not make a level.
    static func make(_ random: inout SeededRandom, index: Int) -> MicroscopicAuroraFixture? {
        let radius: Int = random.int(10...11)
        let length: Int = random.int(120...160)
        let rules: MicroscopicAuroraSwarmRules = rules(&random)
        let count: Int = random.int(4...10)
        let cx: Int = MicroscopicAuroraDish.centre + random.int(-384...384)
        let cy: Int = MicroscopicAuroraDish.centre + random.int(-384...384)
        let driftX: Int = random.int(-2...2)
        let driftY: Int = random.int(-2...2)
        var swimmers: [MicroscopicAuroraSwimmer] = []
        for _ in 0..<count {
            let position = MicroscopicAuroraPoint(x: cx + random.int(-384...384), y: cy + random.int(-384...384))
            let velocity = MicroscopicAuroraPoint(x: driftX + random.int(-2...2), y: driftY + random.int(-2...2))
            swimmers.append(MicroscopicAuroraSwimmer(position: position, velocity: velocity))
        }
        var winning: [MicroscopicAuroraWell?] = [nil, nil, nil]
        let wellCount: Int = random.int(1...2)
        var used: Set<MicroscopicAuroraCell> = []
        for slot in 0..<wellCount {
            var c: MicroscopicAuroraCell = cell(&random, radius: radius)
            while used.contains(c) { c = cell(&random, radius: radius) }
            used.insert(c)
            winning[slot] = MicroscopicAuroraWell(cell: c, strength: random.int(1...4),
                                                  sense: random.int(0...1) == 0 ? .clockwise : .counterclockwise)
        }
        let placeholder: [MicroscopicAuroraCell] = [MicroscopicAuroraCell(row: 11, column: 11),
                                                    MicroscopicAuroraCell(row: 11, column: 12),
                                                    MicroscopicAuroraCell(row: 12, column: 11),
                                                    MicroscopicAuroraCell(row: 12, column: 12)]
        guard let probe = try? MicroscopicAuroraLevel.probe(radius: radius, length: length, rules: rules,
                                                            swimmers: swimmers, stencil: placeholder, threshold: 1,
                                                            coverage: 500, coherence: 2, wells: winning) else {
            return nil
        }
        let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(probe, wells: probe.placedWells)
        if case .exit = report.failure { return nil }
        if case .coherence = report.failure { return nil }
        let threshold: Int = random.int(1...4)
        var lit: [MicroscopicAuroraCell] = []
        for row in 0..<MicroscopicAuroraDish.cells {
            for column in 0..<MicroscopicAuroraDish.cells {
                let c = MicroscopicAuroraCell(row: row, column: column)
                if report.density[c.index] >= threshold && MicroscopicAuroraLevel.isUsable(c, radius: radius) {
                    lit.append(c)
                }
            }
        }
        var stencil: [MicroscopicAuroraCell] = []
        for group in MicroscopicAuroraDish.groupsOf(lit) where group.count > stencil.count { stencil = group }
        guard MicroscopicAuroraLevel.stencilSizes.contains(stencil.count) else { return nil }
        let coverage: Int = random.int(500...1000)
        let coherence: Int = random.int(2...max(2, report.smallestCoherence))
        guard coherence <= report.smallestCoherence else { return nil }
        for attempt in 0..<8 {
            var start: [MicroscopicAuroraWell?] = [nil, nil, nil]
            if attempt % 2 == 1 {
                var c: MicroscopicAuroraCell = cell(&random, radius: radius)
                while used.contains(c) { c = cell(&random, radius: radius) }
                start[2] = MicroscopicAuroraWell(cell: c, strength: random.int(1...4),
                                                 sense: random.int(0...1) == 0 ? .clockwise : .counterclockwise)
            }
            var actions: [MicroscopicAuroraAction] = []
            if start[2] != nil { actions.append(.remove(slot: 2)) }
            for slot in 0..<wellCount {
                if let well = winning[slot] { actions.append(.place(slot: slot, well: well)) }
            }
            let budget: Int = min(MicroscopicAuroraLevel.budgets.upperBound, actions.count + random.int(0...2))
            actions.append(.play)
            guard let level = try? MicroscopicAuroraLevel(
                id: "fixture-\(index)", seed: UInt64(index), difficulty: 1, radius: radius, length: length,
                rules: rules, swimmers: swimmers, stencil: stencil, threshold: threshold, coverage: coverage,
                coherence: coherence, wells: start, budget: budget, tutorial: false) else { continue }
            return MicroscopicAuroraFixture(level: level, winning: winning, actions: actions)
        }
        return nil
    }
}
