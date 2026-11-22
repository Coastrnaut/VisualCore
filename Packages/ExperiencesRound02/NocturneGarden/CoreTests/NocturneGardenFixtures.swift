// NocturneGardenFixtures — feature 381 (R02-G09-01) T-R02G0901-002 (SC-R02G0901-001 … 005). Seeded test levels
// shared by the Nocturne Garden kernel tests. Deterministic: `SeededRandom`, no clock. Fixture seed 2_381.
//
// `fixture(_:)` builds a level backwards from a known arrangement: a bed, a sun elevation and 1 … 4 blooms, each of
// which darkens at least one cell the earlier ones did not. The target is their exact mask; the forbidden cells are a
// random part of the ring of cells within two cells of the target (so the arrangement never leaks); the required match
// is 1/1 or a fraction above the match of every shorter prefix of the plants, so the level is won exactly on the last
// plant. When the opening sun differs from the arrangement's, a sun action comes first (on an empty bed, it neither
// leaks nor wins). The supply holds the planted kinds plus a few spares, the allowed sizes and elevations hold the used
// ones plus a few more, and the budget is the number of actions plus 0 … 3.
import Foundation
import VisualCoreSimulation
@testable import NocturneGardenCore

/// A fixture level with its known winning arrangement and actions.
struct NocturneGardenFixture {
    /// The level.
    let level: NocturneGardenLevel
    /// The blooms in planting order.
    let blooms: [NocturneGardenBloom]
    /// The arrangement's sun elevation.
    let elevation: Int
    /// The winning actions: a sun action first if the opening sun differs, then one plant per bloom; the last one wins.
    let actions: [NocturneGardenAction]
}

enum NocturneGardenFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_381

    /// The fixture of seed `seed`.
    static func fixture(_ seed: UInt64) -> NocturneGardenFixture {
        var random = SeededRandom(seed: seed)
        let width: Int = random.int(NocturneGardenLevel.widths)
        let height: Int = random.int(NocturneGardenLevel.heights)
        let elevation: Int = random.int(1...4)
        let wanted: Int = random.int(1...4)
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        var blooms: [NocturneGardenBloom] = []
        var mask: Set<Int> = []
        var prefix: Set<Int> = []
        var attempts: Int = 0
        while blooms.count < wanted && attempts < 256 {
            attempts += 1
            let bloom = NocturneGardenBloom(kind: kinds[random.int(0...5)], column: random.int(1...(width - 3)),
                                            row: random.int(0...(height / 2)), size: random.int(1...3))
            let cells: Set<Int> = bloom.cells(elevation: elevation, width: width, height: height)
            if cells.isSubset(of: mask) { continue }
            prefix = mask
            mask.formUnion(cells)
            blooms.append(bloom)
        }
        precondition(!blooms.isEmpty, "blooms \(seed)")
        var forbidden: Set<Int> = []
        for cell in mask.sorted() {
            let column: Int = cell % width
            let row: Int = cell / width
            for dr in -2...2 {
                for dc in -2...2 {
                    let c: Int = column + dc
                    let r: Int = row + dr
                    guard c >= 0, c < width, r >= 0, r < height else { continue }
                    let index: Int = r * width + c
                    if !mask.contains(index) && random.int(0...1) == 0 { forbidden.insert(index) }
                }
            }
        }
        let required: NocturneGardenRatio
        let low: Int = prefix.count + 1
        switch random.int(0...2) {
        case 0: required = .whole
        case 1: required = ratio(low, mask.count, seed)
        default: required = ratio(random.int(low...mask.count), mask.count, seed)
        }
        let opening: Int = random.int(1...4)
        var actions: [NocturneGardenAction] = []
        if opening != elevation { actions.append(.sun(elevation)) }
        var supply: [NocturneGardenKind: Int] = [:]
        var sizes: Set<Int> = [random.int(1...3)]
        for bloom in blooms {
            actions.append(.plant(bloom.kind, bloom.column, bloom.row, bloom.size))
            supply[bloom.kind, default: 0] += 1
            sizes.insert(bloom.size)
        }
        for _ in 0..<random.int(0...3) { supply[kinds[random.int(0...5)], default: 0] += 1 }
        let elevations: Set<Int> = [elevation, opening, random.int(1...4)]
        do {
            let level = try NocturneGardenLevel(id: "fixture-\(seed)", seed: seed, difficulty: 1 + Int(seed % 5),
                                                width: width, height: height, target: mask, forbidden: forbidden,
                                                supply: supply, sizes: sizes, elevations: elevations, sun: opening,
                                                budget: actions.count + random.int(0...3), required: required,
                                                leakAllowance: random.int(0...2), tutorial: seed % 7 == 0)
            return NocturneGardenFixture(level: level, blooms: blooms, elevation: elevation, actions: actions)
        } catch {
            preconditionFailure("level \(seed): \(error)")
        }
    }

    /// The ratio p / q, which the fixture guarantees is valid.
    static func ratio(_ p: Int, _ q: Int, _ seed: UInt64) -> NocturneGardenRatio {
        do { return try NocturneGardenRatio(p, q) } catch { preconditionFailure("ratio \(seed): \(error)") }
    }

    /// The fixtures of seeds `seed + 1 … seed + count`.
    static func fixtures(_ count: Int, seed: UInt64 = seed) -> [NocturneGardenFixture] {
        var result: [NocturneGardenFixture] = []
        for offset in 1...count { result.append(fixture(seed &+ UInt64(offset))) }
        return result
    }
}
