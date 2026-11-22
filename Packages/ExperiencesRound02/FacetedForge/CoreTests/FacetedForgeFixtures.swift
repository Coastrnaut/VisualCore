// FacetedForgeFixtures — feature 371 (R02-G08-01) T-R02G0801-002 (SC-R02G0801-001 … 005). Seeded test levels shared by
// the Faceted Forge kernel tests. Deterministic: a SplitMix64 generator, no clock. Fixture seed 2_371.
//
// `fixture(_:)` builds a level around a planned cut sequence, so it has a known winning sequence: a crystal of one of
// four shapes (a cube, a box, an octahedron or a cube with one corner truncated), then 1 … 4 cuts, each of a random
// piece by a random direction at a depth that crosses it. The target is the resulting multiset of (share, face count);
// the sliver limit is half the smallest share any piece had along the way, and the budget is the number of cuts plus 0
// … 2. The cuts are applied to `FacetedForgePiece` while the level is built, so the fixture's actions win exactly on
// their last cut.
import Foundation
@testable import FacetedForgeCore

/// A small deterministic generator (SplitMix64).
struct FacetedForgeRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform integer in `range`.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }

    /// A uniform element of a non-empty array.
    mutating func pick<T>(_ values: [T]) -> T { values[int(0...(values.count - 1))] }
}

/// A fixture level with its known winning actions.
struct FacetedForgeFixture {
    /// The level.
    let level: FacetedForgeLevel
    /// The winning cuts; the last one makes the pieces match the target.
    let actions: [FacetedForgeAction]
}

enum FacetedForgeFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_371

    /// The half-spaces lo ≤ n·p ≤ hi of direction `direction`.
    static func slab(_ direction: Int, _ lo: Int, _ hi: Int) -> [FacetedForgeHalfSpace] {
        [FacetedForgeHalfSpace(direction: direction, sign: 1, depth: hi),
         FacetedForgeHalfSpace(direction: direction, sign: -1, depth: lo)]
    }

    /// One of the four crystal shapes, chosen by `random`.
    static func crystal(_ random: inout FacetedForgeRandom) -> [FacetedForgeHalfSpace] {
        switch random.int(0...3) {
        case 0:
            let a: Int = random.int(2...6)
            return (slab(0, -a, a) + slab(1, -a, a) + slab(2, -a, a)).sorted()
        case 1:
            let x: Int = random.int(1...6)
            let y: Int = random.int(1...6)
            let z: Int = random.int(1...6)
            return (slab(0, -x, random.int(1...6)) + slab(1, -y, random.int(1...6)) + slab(2, -z, random.int(1...6)))
                .sorted()
        case 2:
            let a: Int = random.int(3...6)
            return (slab(9, -a, a) + slab(10, -a, a) + slab(11, -a, a) + slab(12, -a, a)).sorted()
        default:
            let a: Int = random.int(2...6)
            let b: Int = random.int((a + 1)...(3 * a - 1))
            return (slab(0, -a, a) + slab(1, -a, a) + slab(2, -a, a)
                    + [FacetedForgeHalfSpace(direction: 9, sign: 1, depth: b)]).sorted()
        }
    }

    /// A random cut of a random piece of `pieces` (canonical order): (index, direction, depth).
    static func randomCut(_ pieces: [FacetedForgePiece], _ random: inout FacetedForgeRandom) -> (Int, Int, Int) {
        while true {
            let index: Int = random.int(0...(pieces.count - 1))
            let direction: Int = random.int(0...12)
            var depths: [Int] = []
            for depth in FacetedForgeHalfSpace.depths
            where pieces[index].isCrossed(direction: direction, depth: depth) {
                depths.append(depth)
            }
            if !depths.isEmpty { return (index, direction, random.pick(depths)) }
        }
    }

    /// The fixture of seed `seed`.
    static func fixture(_ seed: UInt64) -> FacetedForgeFixture {
        var random = FacetedForgeRandom(seed: seed)
        let planes: [FacetedForgeHalfSpace] = crystal(&random)
        guard let crystal = try? FacetedForgePiece(halfSpaces: planes) else { preconditionFailure("crystal \(seed)") }
        var pieces: [FacetedForgePiece] = [crystal]
        var actions: [FacetedForgeAction] = []
        var smallest: FacetedForgeFraction = .one
        let cuts: Int = random.int(1...4)
        for _ in 0..<cuts {
            let (index, direction, depth) = randomCut(pieces, &random)
            guard let halves = try? pieces[index].cut(direction: direction, depth: depth) else {
                preconditionFailure("cut \(seed)")
            }
            pieces.remove(at: index)
            pieces = FacetedForgePiece.canonical(pieces + [halves.below, halves.above])
            actions.append(.cut(index, direction, depth))
            for half in [halves.below, halves.above] {
                if let share = try? half.volume.dividing(by: crystal.volume), share < smallest { smallest = share }
            }
        }
        var target: [FacetedForgeTargetPiece] = []
        for piece in pieces {
            guard let share = try? piece.volume.dividing(by: crystal.volume) else {
                preconditionFailure("share \(seed)")
            }
            target.append(FacetedForgeTargetPiece(share: share, faces: piece.faceCount))
        }
        guard let sliver = try? smallest.dividing(by: FacetedForgeFraction(2)),
              let level = try? FacetedForgeLevel(id: "fixture-\(seed)", seed: seed, difficulty: 1 + Int(seed % 5),
                                                 planes: planes, budget: min(12, cuts + random.int(0...2)),
                                                 sliver: sliver, target: target.sorted(), tutorial: seed % 7 == 0)
        else { preconditionFailure("level \(seed)") }
        return FacetedForgeFixture(level: level, actions: actions)
    }

    /// The fixtures of seeds `seed + 1 … seed + count`.
    static func fixtures(_ count: Int, seed: UInt64 = seed) -> [FacetedForgeFixture] {
        (1...count).map { fixture(seed &+ UInt64($0)) }
    }
}
