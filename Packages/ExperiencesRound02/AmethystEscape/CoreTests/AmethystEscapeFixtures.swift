// AmethystEscapeFixtures — feature 361 (R02-G07-01) T-R02G0701-002 (SC-R02G0701-001 … 005). Seeded test levels shared by
// the Amethyst Escape kernel tests. Deterministic: a SplitMix64 generator, no clock. Fixture seed 2_361.
//
// `fixture(_:)` builds a level around a planned route, so it has a known winning action sequence: in each shell r the
// pearl rolls d_r = 0 … 2 sectors clockwise to an aperture (no aperture, wall or blocked wedge on the way), then — before
// it advances outward — the next shell is turned k = −2 … 2 steps so the pearl arrives in an own sector that is not
// blocked; from the outermost shell it advances out through the exit gap. Extra apertures, walls and blocked wedges are
// added only off the route. The budget is the route's length plus 0 … 3. The route is replayed on `AmethystEscapeCrystal`
// while it is built, so the fixture's actions win exactly on their last action.
//
// `randomLevel(_:)` builds an arbitrary valid level (no known solution) for the transition, replay and refusal checks.
import Foundation
@testable import AmethystEscapeCore

/// A small deterministic generator (SplitMix64).
struct AmethystEscapeRandom {
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

    /// A uniform integer in the non-empty half-open `range`.
    mutating func int(_ range: Range<Int>) -> Int { int(range.lowerBound...(range.upperBound - 1)) }

    /// A fair coin.
    mutating func bool() -> Bool { next() & 1 == 1 }
}

/// A fixture level with its known winning actions.
struct AmethystEscapeFixture {
    /// The level.
    let level: AmethystEscapeLevel
    /// The winning actions; the last one is the advance through the exit gap.
    let actions: [AmethystEscapeAction]
}

enum AmethystEscapeFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_361

    /// A shell under construction: its own-sector lists and the sectors the route forbids changing.
    private struct Draft {
        var apertures: Set<Int> = []
        var walls: Set<Int> = []
        var blocked: Set<Int> = []
        /// Own sectors the route rolls through or rests in (never an aperture except the route's, never blocked).
        var path: Set<Int> = []
        /// Walls the route needs absent.
        var openWalls: Set<Int> = []
        /// The route's aperture.
        var exit: Int? = nil
    }

    /// Fixture `index` (0 …): a level with a known winning action sequence (see the file header).
    static func fixture(_ index: Int) -> AmethystEscapeFixture {
        var random = AmethystEscapeRandom(seed: seed &+ UInt64(index) &* 7_919)
        let n: Int = random.int(AmethystEscapeLevel.sectorCounts)
        let k: Int = random.int(AmethystEscapeLevel.shellCounts)
        let start: Int = random.int(0..<n)
        var drafts: [Draft] = Array(repeating: Draft(), count: k)
        var actions: [AmethystEscapeAction] = []
        // Plan the route in own sectors: offsets start at 0, so shell 0's own sector is the absolute one.
        var offsets: [Int] = Array(repeating: 0, count: k)
        var absolute: Int = start
        for shell in 0..<k {
            var own: Int = modulo(absolute - offsets[shell], n)
            let rolls: Int = random.int(0...2)
            for _ in 0..<rolls {
                drafts[shell].path.insert(own)
                drafts[shell].openWalls.insert(own)
                own = modulo(own + 1, n)
                absolute = modulo(absolute + 1, n)
                actions.append(.advance)
            }
            drafts[shell].path.insert(own)
            drafts[shell].exit = own
            drafts[shell].apertures.insert(own)
            if shell + 1 < k {
                let turn: Int = random.int(-2...2)
                let step: Int = turn < 0 ? -1 : 1
                for _ in 0..<abs(turn) { actions.append(.rotate(shell + 1, step)) }
                offsets[shell + 1] = modulo(turn, n)
            }
            actions.append(.advance)
        }
        // Off-route extras.
        for shell in 0..<k {
            let free: [Int] = (0..<n).filter { !drafts[shell].path.contains($0) }
            for sector in free where random.int(0...3) == 0 { drafts[shell].blocked.insert(sector) }
            if shell + 1 < k {
                for sector in free where !drafts[shell].blocked.contains(sector) && random.int(0...4) == 0 {
                    drafts[shell].apertures.insert(sector)
                }
            }
            for wall in 0..<n where !drafts[shell].openWalls.contains(wall) && random.int(0...3) == 0 {
                drafts[shell].walls.insert(wall)
            }
            if drafts[shell].walls.count >= n { drafts[shell].walls.remove(drafts[shell].walls.min() ?? 0) }
            if drafts[shell].blocked.count >= n - 1 { drafts[shell].blocked.removeAll() }
        }
        // Arrival pockets must not be blocked: unblock every pocket the route stands in.
        var crystalOffsets: [Int] = Array(repeating: 0, count: k)
        var pearl = AmethystEscapePocket(shell: 0, sector: start)
        for action in actions {
            switch action {
            case let .rotate(shell, step):
                crystalOffsets[shell] = modulo(crystalOffsets[shell] + step, n)
            case .advance:
                let own: Int = modulo(pearl.sector - crystalOffsets[pearl.shell], n)
                if drafts[pearl.shell].apertures.contains(own) {
                    if pearl.shell + 1 < k { pearl = AmethystEscapePocket(shell: pearl.shell + 1, sector: pearl.sector) }
                } else {
                    pearl = AmethystEscapePocket(shell: pearl.shell, sector: modulo(pearl.sector + 1, n))
                }
                if pearl.shell < k {
                    drafts[pearl.shell].blocked.remove(modulo(pearl.sector - crystalOffsets[pearl.shell], n))
                }
            }
        }
        let shells: [AmethystEscapeShell] = drafts.map {
            AmethystEscapeShell(apertures: Array($0.apertures), walls: Array($0.walls), blocked: Array($0.blocked))
        }
        let budget: Int = min(AmethystEscapeLevel.budgets.upperBound, actions.count + random.int(0...3))
        let level: AmethystEscapeLevel
        do {
            level = try AmethystEscapeLevel(id: "fixture-\(index)", seed: seed &+ UInt64(index), difficulty: 1 + index % 5,
                                            sectors: n, shells: shells, start: start, budget: budget,
                                            tutorial: index % 3 == 0)
        } catch {
            preconditionFailure("fixture \(index) is a valid level: \(error)")
        }
        precondition(wins(level: level, actions: actions), "fixture \(index) wins on its last action")
        return AmethystEscapeFixture(level: level, actions: actions)
    }

    /// Whether `actions` from the opening crystal of `level` exit exactly on the last action, never stuck or wedged.
    static func wins(level: AmethystEscapeLevel, actions: [AmethystEscapeAction]) -> Bool {
        var crystal = AmethystEscapeCrystal(level: level)
        for (index, action) in actions.enumerated() {
            switch action {
            case let .rotate(shell, step):
                crystal = crystal.rotating(shell: shell, step: step, level: level)
            case .advance:
                switch crystal.transition(level: level) {
                case let .moved(pocket): crystal = crystal.placing(pearl: pocket)
                case .exited: return index == actions.count - 1
                case .wedge, .stuck: return false
                }
            }
        }
        return false
    }

    /// An arbitrary valid level for seed `index` (no known solution).
    static func randomLevel(_ index: Int) -> AmethystEscapeLevel {
        var random = AmethystEscapeRandom(seed: seed &+ 1_000_003 &+ UInt64(index) &* 104_729)
        let n: Int = random.int(AmethystEscapeLevel.sectorCounts)
        let k: Int = random.int(AmethystEscapeLevel.shellCounts)
        var shells: [AmethystEscapeShell] = []
        for shell in 0..<k {
            var apertures: Set<Int> = [random.int(0..<n)]
            if shell + 1 < k { for s in 0..<n where random.int(0...3) == 0 { apertures.insert(s) } }
            var walls: Set<Int> = []
            for s in 0..<n where random.int(0...2) == 0 { walls.insert(s) }
            if walls.count >= n { walls.remove(0) }
            var blocked: Set<Int> = []
            for s in 0..<n where random.int(0...3) == 0 { blocked.insert(s) }
            if blocked.count >= n { blocked.remove(0) }
            shells.append(AmethystEscapeShell(apertures: Array(apertures), walls: Array(walls), blocked: Array(blocked)))
        }
        let open: [Int] = (0..<n).filter { !shells[0].isBlocked($0) }
        let start: Int = open[random.int(0..<open.count)]
        do {
            return try AmethystEscapeLevel(id: "random-\(index)", seed: seed &+ UInt64(index), difficulty: 1 + index % 5,
                                           sectors: n, shells: shells, start: start,
                                           budget: random.int(AmethystEscapeLevel.budgets), tutorial: index % 4 == 0)
        } catch {
            preconditionFailure("random level \(index) is valid: \(error)")
        }
    }

    /// `value` mod `n` in 0 ..< n.
    static func modulo(_ value: Int, _ n: Int) -> Int { ((value % n) + n) % n }
}
