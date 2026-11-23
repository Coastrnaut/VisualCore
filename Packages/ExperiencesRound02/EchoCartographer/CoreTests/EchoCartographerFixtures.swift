// EchoCartographerFixtures — feature 401 (R02-G11-01) T-R02G1101-002 (SC-R02G1101-001 … 005). Seeded test levels shared
// by the Echo Cartographer kernel tests. Deterministic: `SeededRandom`, no clock. Fixture seed 2_401.
//
// `fixture(_:)` draws a chamber of W × H cells (W, H 5 … 12) with roughly one wall in four, an open entry, and 1 … 4
// beacons on distinct open cells of the entry's connected region (side steps), other than the entry. Its known winning
// actions are one pulse from the entry followed by one claim on each beacon's own cell, in beacon order: each claim is
// at distance 0 of its beacon, so it locates exactly that beacon whatever the tolerance, and the last claim wins. The
// energy is 1 + 0 … 3 (the pulse costs 1; hits are free). With energy 2 or more the known actions win on the last claim;
// with energy 1 the opening pulse spends the last energy with beacons hidden and fails the level (an undo then returns
// to playing and the claims alone win). Both kinds occur among the 500 fixtures and the tests rely on both.
import Foundation
import VisualCoreSimulation
@testable import EchoCartographerCore

/// A fixture level with its known winning actions.
struct EchoCartographerFixture {
    /// The level.
    let level: EchoCartographerLevel
    /// The known pulses, in order (one: the entry).
    let pulses: [EchoCartographerCell]
    /// The known claims, in order, after the pulses; the last one wins.
    let claims: [EchoCartographerCell]
}

enum EchoCartographerFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_401

    /// The fixture of seed `seed`.
    static func fixture(_ seed: UInt64) -> EchoCartographerFixture {
        var random = SeededRandom(seed: seed)
        for _ in 0..<512 {
            if let fixture = attempt(seed, &random) { return fixture }
        }
        preconditionFailure("fixture \(seed): no level after 512 attempts")
    }

    /// The fixtures of seeds `seed` … `seed + count − 1`.
    static func fixtures(_ count: Int, from seed: UInt64 = seed) -> [EchoCartographerFixture] {
        (0..<UInt64(count)).map { fixture(seed &+ $0) }
    }

    /// A random chamber of W × H (5 … 12) with roughly one wall in four.
    static func chamber(_ random: inout SeededRandom) -> EchoCartographerChamber? {
        let width: Int = random.int(5...12)
        let height: Int = random.int(5...12)
        var walls: Set<Int> = []
        for index in 0..<(width * height) where random.int(0...3) == 0 { walls.insert(index) }
        return try? EchoCartographerChamber(width: width, height: height, walls: walls)
    }

    /// One attempt at a fixture of seed `seed`; nil when the drawn values do not make a valid level.
    static func attempt(_ seed: UInt64, _ random: inout SeededRandom) -> EchoCartographerFixture? {
        guard let chamber = chamber(&random) else { return nil }
        let open: [Int] = (0..<chamber.cellCount).filter { !chamber.walls.contains($0) }
        guard open.count >= 2 else { return nil }
        let entry: EchoCartographerCell = chamber.cell(open[random.int(0...(open.count - 1))])
        let reach: [Int?] = chamber.pathLengths(from: entry)
        let region: [Int] = open.filter { reach[$0] != nil && $0 != chamber.index(entry) }
        guard !region.isEmpty else { return nil }
        let wanted: Int = min(random.int(1...4), region.count)
        var pool: [Int] = region
        var beacons: [EchoCartographerCell] = []
        for _ in 0..<wanted {
            let pick: Int = random.int(0...(pool.count - 1))
            beacons.append(chamber.cell(pool.remove(at: pick)))
        }
        guard let level = try? EchoCartographerLevel(
            id: "fixture-\(seed)", seed: seed, difficulty: random.int(1...5), chamber: chamber, entry: entry,
            beacons: beacons, tolerance: random.int(0...2), energy: 1 + random.int(0...3),
            missCost: random.int(1...3), tutorial: random.int(0...3) == 0) else { return nil }
        return EchoCartographerFixture(level: level, pulses: [entry], claims: level.beacons)
    }

    /// A hand-made 7 × 5 chamber for exact cases:
    ///
    ///     row 0: . . . # . . .
    ///     row 1: . # . # . # .
    ///     row 2: . # . . . # .
    ///     row 3: . # # # . # .
    ///     row 4: . . . . . . .
    ///
    /// entry (0, 0); beacons (6, 0) and (2, 2) in cell-index order; tolerance 1; energy 6; a miss costs 2.
    static func handLevel(tolerance: Int = 1, energy: Int = 6, missCost: Int = 2) -> EchoCartographerLevel {
        let rows: [String] = ["...#...", ".#.#.#.", ".#...#.", ".###.#.", "......."]
        var walls: Set<Int> = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" { walls.insert(y * 7 + x) }
        }
        do {
            let chamber = try EchoCartographerChamber(width: 7, height: 5, walls: walls)
            return try EchoCartographerLevel(id: "hand", seed: 1, difficulty: 1, chamber: chamber,
                                             entry: EchoCartographerCell(x: 0, y: 0),
                                             beacons: [EchoCartographerCell(x: 2, y: 2), EchoCartographerCell(x: 6, y: 0)],
                                             tolerance: tolerance, energy: energy, missCost: missCost)
        } catch {
            preconditionFailure("the hand level is valid: \(error)")
        }
    }
}
