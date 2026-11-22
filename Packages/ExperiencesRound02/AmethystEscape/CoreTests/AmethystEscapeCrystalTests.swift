// AmethystEscapeCrystalTests — feature 361 (R02-G07-01) T-R02G0701-003 (FR-R02G0701-002, 003, 005; SC-R02G0701-003;
// clarification Q2). The crystal's rotations and advances checked against an independent reference written here: a
// pocket graph rebuilt from the absolute offsets after every move (outward edges, clockwise edges, the exit edge and the
// blocked pockets, all mapped forward from own sectors to absolute sectors), never through the crystal's methods. Covers
// seeded replays on 500 levels, full turns as the identity, which rotations move the pearl, the transition priority, the
// exit from the outermost shell only, wedges, the own-sector formula and the fixtures' winning sequences.
import Testing
@testable import AmethystEscapeCore

/// The reference's outcome of one advance.
enum AmethystEscapeReferenceStep: Equatable {
    /// The pearl moves to the pocket, which is not blocked.
    case moved(AmethystEscapePocket)
    /// The pearl leaves through the exit gap.
    case exited
    /// The pearl moves into a blocked pocket.
    case wedge(AmethystEscapePocket)
    /// No edge leaves the pearl's pocket.
    case stuck
}

/// An independent pocket-graph model of the crystal: absolute offsets and the pearl, with the graph rebuilt per state.
struct AmethystEscapeReference: Equatable {
    /// Every shell's absolute offset, innermost first.
    var offsets: [Int]
    /// The pearl's shell.
    var shell: Int
    /// The pearl's absolute sector.
    var sector: Int

    /// The opening state of `level`: offsets 0 and the pearl at the start in shell 0.
    init(level: AmethystEscapeLevel) {
        offsets = [Int](repeating: 0, count: level.shells.count)
        shell = 0
        sector = level.start
    }

    /// The pearl as a pocket.
    var pearl: AmethystEscapePocket { AmethystEscapePocket(shell: shell, sector: sector) }

    /// The pocket graph of one state.
    struct Graph {
        /// Outward edges: pocket → the pocket one shell out at the same absolute sector.
        var outward: [AmethystEscapePocket: AmethystEscapePocket] = [:]
        /// Pockets of the outermost shell lined up with its exit gap.
        var exits: Set<AmethystEscapePocket> = []
        /// Clockwise edges: pocket → the next absolute sector in the same shell.
        var clockwise: [AmethystEscapePocket: AmethystEscapePocket] = [:]
        /// The blocked pockets.
        var blocked: Set<AmethystEscapePocket> = []
    }

    /// Builds the graph from the current offsets by mapping each shell's own sector j forward to absolute (j + o) mod N.
    func graph(level: AmethystEscapeLevel) -> Graph {
        let n: Int = level.sectors
        var graph = Graph()
        for r in 0..<level.shells.count {
            let spec: AmethystEscapeShell = level.shells[r]
            let apertures: Set<Int> = Set(spec.apertures)
            let walls: Set<Int> = Set(spec.walls)
            for j in 0..<n {
                let absolute: Int = (j + offsets[r]) % n
                let pocket = AmethystEscapePocket(shell: r, sector: absolute)
                if spec.blocked.contains(j) { graph.blocked.insert(pocket) }
                if apertures.contains(j) {
                    if r == level.shells.count - 1 {
                        graph.exits.insert(pocket)
                    } else {
                        graph.outward[pocket] = AmethystEscapePocket(shell: r + 1, sector: absolute)
                    }
                } else if !walls.contains(j) {
                    graph.clockwise[pocket] = AmethystEscapePocket(shell: r, sector: (absolute + 1) % n)
                }
            }
        }
        return graph
    }

    /// The outcome of an advance from the current state.
    func step(level: AmethystEscapeLevel) -> AmethystEscapeReferenceStep {
        let graph: Graph = graph(level: level)
        let here: AmethystEscapePocket = pearl
        if graph.exits.contains(here) { return .exited }
        let next: AmethystEscapePocket
        if let out = graph.outward[here] {
            next = out
        } else if let roll = graph.clockwise[here] {
            next = roll
        } else {
            return .stuck
        }
        return graph.blocked.contains(next) ? .wedge(next) : .moved(next)
    }

    /// Turns shell `r` by `step`; the pearl turns with it when it is in that shell.
    mutating func rotate(_ r: Int, _ step: Int, sectors n: Int) {
        offsets[r] = (offsets[r] + step + n) % n
        if shell == r { sector = (sector + step + n) % n }
    }
}

/// The crystal's transition in the reference's terms.
func amethystReferenceView(_ transition: AmethystEscapeTransition) -> AmethystEscapeReferenceStep {
    switch transition {
    case let .moved(pocket): return .moved(pocket)
    case .exited: return .exited
    case let .wedge(pocket): return .wedge(pocket)
    case .stuck: return .stuck
    }
}

@Suite struct AmethystEscapeCrystalTests {
    /// The 500 seeded levels: 250 random levels and 250 fixtures (seed 2_361 family).
    static func levels() -> [AmethystEscapeLevel] {
        var result: [AmethystEscapeLevel] = []
        for index in 0..<250 { result.append(AmethystEscapeFixtures.randomLevel(index)) }
        for index in 0..<250 { result.append(AmethystEscapeFixtures.fixture(index).level) }
        return result
    }

    /// A hand-made level (throws on a broken rule).
    static func make(sectors: Int, shells: [AmethystEscapeShell], start: Int = 0) throws -> AmethystEscapeLevel {
        try AmethystEscapeLevel(id: "hand", seed: 1, difficulty: 1, sectors: sectors, shells: shells, start: start,
                                budget: 10)
    }

    /// Whether the crystal and the reference hold the same offsets and pearl.
    static func agree(_ crystal: AmethystEscapeCrystal, _ reference: AmethystEscapeReference) -> Bool {
        crystal.offsets == reference.offsets && crystal.pearl == reference.pearl
    }

    @Test func seededReplaysMatchTheReferenceAfterEveryMove() {
        let levels: [AmethystEscapeLevel] = Self.levels()
        var random = AmethystEscapeRandom(seed: AmethystEscapeFixtures.seed &+ 3_003)
        var seen: [String: Int] = ["moved": 0, "exited": 0, "wedge": 0, "stuck": 0, "rotate": 0]
        for level in levels {
            var crystal = AmethystEscapeCrystal(level: level)
            var reference = AmethystEscapeReference(level: level)
            var ended: Bool = false
            for _ in 0..<level.budget where !ended {
                if random.bool() {
                    let shell: Int = random.int(0..<level.shells.count)
                    let step: Int = random.bool() ? 1 : -1
                    crystal = crystal.rotating(shell: shell, step: step, level: level)
                    reference.rotate(shell, step, sectors: level.sectors)
                    seen["rotate", default: 0] += 1
                } else {
                    let expected: AmethystEscapeReferenceStep = reference.step(level: level)
                    let actual: AmethystEscapeReferenceStep = amethystReferenceView(crystal.transition(level: level))
                    #expect(actual == expected, "\(level.id) advance")
                    switch expected {
                    case let .moved(pocket):
                        crystal = crystal.placing(pearl: pocket)
                        reference.shell = pocket.shell
                        reference.sector = pocket.sector
                        seen["moved", default: 0] += 1
                    case let .wedge(pocket):
                        crystal = crystal.placing(pearl: pocket)
                        reference.shell = pocket.shell
                        reference.sector = pocket.sector
                        seen["wedge", default: 0] += 1
                        ended = true
                    case .exited:
                        #expect(reference.shell == level.outermost)
                        seen["exited", default: 0] += 1
                        ended = true
                    case .stuck:
                        seen["stuck", default: 0] += 1
                    }
                }
                #expect(Self.agree(crystal, reference), "\(level.id) state")
            }
        }
        for (kind, count) in seen { #expect(count > 0, "outcome \(kind) exercised") }
    }

    @Test func aFullTurnOfSingleStepsIsTheIdentity() {
        var random = AmethystEscapeRandom(seed: AmethystEscapeFixtures.seed &+ 4_004)
        for level in Self.levels() {
            let n: Int = level.sectors
            var offsets: [Int] = []
            for _ in 0..<level.shells.count { offsets.append(random.int(0..<n)) }
            let pearl = AmethystEscapePocket(shell: random.int(0..<level.shells.count), sector: random.int(0..<n))
            let origin = AmethystEscapeCrystal(offsets: offsets, pearl: pearl)
            for shell in 0..<level.shells.count {
                for step in [1, -1] {
                    var crystal: AmethystEscapeCrystal = origin
                    for count in 1...n {
                        crystal = crystal.rotating(shell: shell, step: step, level: level)
                        if count < n { #expect(crystal != origin, "\(level.id) shell \(shell) partial turn") }
                    }
                    #expect(crystal == origin, "\(level.id) shell \(shell) step \(step)")
                }
            }
        }
    }

    @Test func onlyThePearlsShellTurnsThePearlAndItKeepsItsOwnSector() {
        var random = AmethystEscapeRandom(seed: AmethystEscapeFixtures.seed &+ 5_005)
        for level in Self.levels() {
            let n: Int = level.sectors
            var offsets: [Int] = []
            for _ in 0..<level.shells.count { offsets.append(random.int(0..<n)) }
            let pearl = AmethystEscapePocket(shell: random.int(0..<level.shells.count), sector: random.int(0..<n))
            let crystal = AmethystEscapeCrystal(offsets: offsets, pearl: pearl)
            let own: Int = crystal.ownSector(pearl, level: level)
            for shell in 0..<level.shells.count {
                for step in [1, -1] {
                    let turned: AmethystEscapeCrystal = crystal.rotating(shell: shell, step: step, level: level)
                    #expect(turned.offsets[shell] == (offsets[shell] + step + n) % n)
                    for other in 0..<level.shells.count where other != shell {
                        #expect(turned.offsets[other] == offsets[other])
                    }
                    if shell == pearl.shell {
                        #expect(turned.pearl == AmethystEscapePocket(shell: shell, sector: (pearl.sector + step + n) % n))
                        #expect(turned.ownSector(turned.pearl, level: level) == own)
                    } else {
                        #expect(turned.pearl == pearl)
                    }
                }
            }
        }
    }

    @Test func anAlignedApertureWinsOverARollAndStuckNeedsAWall() throws {
        // Shell 0: aperture at own 2, wall at own 2 and 4; shell 1: exit gap at own 0.
        let level: AmethystEscapeLevel = try Self.make(sectors: 6, shells: [
            AmethystEscapeShell(apertures: [2], walls: [2, 4]),
            AmethystEscapeShell(apertures: [0])
        ])
        // Aperture lined up, wall present: outward.
        let atAperture = AmethystEscapeCrystal(offsets: [0, 3], pearl: AmethystEscapePocket(shell: 0, sector: 2))
        #expect(atAperture.transition(level: level) == .moved(AmethystEscapePocket(shell: 1, sector: 2)))
        // Not open, wall present: stuck.
        let atWall = AmethystEscapeCrystal(offsets: [0, 3], pearl: AmethystEscapePocket(shell: 0, sector: 4))
        #expect(atWall.transition(level: level) == .stuck)
        // Not open, no wall: clockwise roll.
        let rolling = AmethystEscapeCrystal(offsets: [0, 3], pearl: AmethystEscapePocket(shell: 0, sector: 1))
        #expect(rolling.transition(level: level) == .moved(AmethystEscapePocket(shell: 0, sector: 2)))
        // Rotated: offset 1 puts own 2 at absolute 3 and own 4 (wall) at absolute 5.
        let rotated = AmethystEscapeCrystal(offsets: [1, 0], pearl: AmethystEscapePocket(shell: 0, sector: 3))
        #expect(rotated.transition(level: level) == .moved(AmethystEscapePocket(shell: 1, sector: 3)))
        let rotatedWall = AmethystEscapeCrystal(offsets: [1, 0], pearl: AmethystEscapePocket(shell: 0, sector: 5))
        #expect(rotatedWall.transition(level: level) == .stuck)
        // Aperture with no wall anywhere: still outward, not a roll.
        let open: AmethystEscapeLevel = try Self.make(sectors: 6, shells: [
            AmethystEscapeShell(apertures: [3]),
            AmethystEscapeShell(apertures: [5])
        ])
        let noWall = AmethystEscapeCrystal(offsets: [0, 0], pearl: AmethystEscapePocket(shell: 0, sector: 3))
        #expect(noWall.transition(level: open) == .moved(AmethystEscapePocket(shell: 1, sector: 3)))
    }

    @Test func onlyTheOutermostShellsGapExits() throws {
        // Three shells of 8; shell 1's aperture at own 0 sits under shell 2's exit gap (own 0) at offset 0.
        let level: AmethystEscapeLevel = try Self.make(sectors: 8, shells: [
            AmethystEscapeShell(apertures: [0]),
            AmethystEscapeShell(apertures: [0, 4]),
            AmethystEscapeShell(apertures: [0])
        ])
        let inner = AmethystEscapeCrystal(offsets: [0, 0, 0], pearl: AmethystEscapePocket(shell: 1, sector: 0))
        #expect(inner.transition(level: level) == .moved(AmethystEscapePocket(shell: 2, sector: 0)))
        let innermost = AmethystEscapeCrystal(offsets: [0, 0, 0], pearl: AmethystEscapePocket(shell: 0, sector: 0))
        #expect(innermost.transition(level: level) == .moved(AmethystEscapePocket(shell: 1, sector: 0)))
        let atGap = AmethystEscapeCrystal(offsets: [0, 0, 0], pearl: AmethystEscapePocket(shell: 2, sector: 0))
        #expect(atGap.transition(level: level) == .exited)
        // Off the gap in the outermost shell: a roll, not an exit.
        let offGap = AmethystEscapeCrystal(offsets: [0, 0, 0], pearl: AmethystEscapePocket(shell: 2, sector: 4))
        #expect(offGap.transition(level: level) == .moved(AmethystEscapePocket(shell: 2, sector: 5)))
        // The gap turned to absolute 3: exit there, roll at absolute 0.
        let turnedGap = AmethystEscapeCrystal(offsets: [0, 0, 3], pearl: AmethystEscapePocket(shell: 2, sector: 3))
        #expect(turnedGap.transition(level: level) == .exited)
        let oldGap = AmethystEscapeCrystal(offsets: [0, 0, 3], pearl: AmethystEscapePocket(shell: 2, sector: 0))
        #expect(oldGap.transition(level: level) == .moved(AmethystEscapePocket(shell: 2, sector: 1)))
        // Every exit seen in seeded states is from the outermost shell at its gap.
        var random = AmethystEscapeRandom(seed: AmethystEscapeFixtures.seed &+ 6_006)
        for candidate in Self.levels() {
            let n: Int = candidate.sectors
            var offsets: [Int] = []
            for _ in 0..<candidate.shells.count { offsets.append(random.int(0..<n)) }
            for shell in 0..<candidate.shells.count {
                for sector in 0..<n {
                    let pocket = AmethystEscapePocket(shell: shell, sector: sector)
                    let crystal = AmethystEscapeCrystal(offsets: offsets, pearl: pocket)
                    let exits: Bool = crystal.transition(level: candidate) == .exited
                    let atExit: Bool = shell == candidate.outermost
                        && (sector - offsets[shell] + n) % n == candidate.exitGap
                    #expect(exits == atExit, "\(candidate.id) \(shell)/\(sector)")
                }
            }
        }
    }

    @Test func aMoveOntoABlockedWedgeNamesThatPocket() throws {
        // Shell 0: blocked own 3, aperture own 1; shell 1: blocked own 2, exit own 5.
        let level: AmethystEscapeLevel = try Self.make(sectors: 6, shells: [
            AmethystEscapeShell(apertures: [1], blocked: [3]),
            AmethystEscapeShell(apertures: [5], blocked: [2])
        ])
        let roll = AmethystEscapeCrystal(offsets: [0, 0], pearl: AmethystEscapePocket(shell: 0, sector: 2))
        #expect(roll.transition(level: level) == .wedge(AmethystEscapePocket(shell: 0, sector: 3)))
        // Shell 1 at offset 5: own 2 lies at absolute 1, under shell 0's aperture.
        let outward = AmethystEscapeCrystal(offsets: [0, 5], pearl: AmethystEscapePocket(shell: 0, sector: 1))
        #expect(outward.transition(level: level) == .wedge(AmethystEscapePocket(shell: 1, sector: 1)))
        let clear = AmethystEscapeCrystal(offsets: [0, 0], pearl: AmethystEscapePocket(shell: 0, sector: 1))
        #expect(clear.transition(level: level) == .moved(AmethystEscapePocket(shell: 1, sector: 1)))
        // Rotating shell 0 by one moves its blocked wedge to absolute 4.
        let turned = AmethystEscapeCrystal(offsets: [1, 0], pearl: AmethystEscapePocket(shell: 0, sector: 3))
        #expect(turned.transition(level: level) == .wedge(AmethystEscapePocket(shell: 0, sector: 4)))
        #expect(turned.isBlocked(AmethystEscapePocket(shell: 0, sector: 4), level: level))
        #expect(!turned.isBlocked(AmethystEscapePocket(shell: 0, sector: 3), level: level))
    }

    @Test func theOwnSectorIsTheAbsoluteSectorLessTheOffset() {
        var random = AmethystEscapeRandom(seed: AmethystEscapeFixtures.seed &+ 7_007)
        for level in Self.levels() {
            let n: Int = level.sectors
            var offsets: [Int] = []
            for _ in 0..<level.shells.count { offsets.append(random.int(0..<n)) }
            let crystal = AmethystEscapeCrystal(offsets: offsets, pearl: AmethystEscapePocket(shell: 0, sector: 0))
            for shell in 0..<level.shells.count {
                for j in 0..<n {
                    // Forward map: own sector j of shell r lies at absolute (j + o_r) mod N.
                    let pocket = AmethystEscapePocket(shell: shell, sector: (j + offsets[shell]) % n)
                    #expect(crystal.ownSector(pocket, level: level) == j)
                    #expect(crystal.isBlocked(pocket, level: level) == level.shells[shell].blocked.contains(j))
                }
            }
        }
    }

    @Test func theFixturesExitExactlyOnTheirLastAction() {
        for index in 0..<500 {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(index)
            let level: AmethystEscapeLevel = fixture.level
            var crystal = AmethystEscapeCrystal(level: level)
            var reference = AmethystEscapeReference(level: level)
            var exitedAt: Int? = nil
            for (position, action) in fixture.actions.enumerated() where exitedAt == nil {
                switch action {
                case let .rotate(shell, step):
                    crystal = crystal.rotating(shell: shell, step: step, level: level)
                    reference.rotate(shell, step, sectors: level.sectors)
                case .advance:
                    let expected: AmethystEscapeReferenceStep = reference.step(level: level)
                    #expect(amethystReferenceView(crystal.transition(level: level)) == expected)
                    switch expected {
                    case let .moved(pocket):
                        crystal = crystal.placing(pearl: pocket)
                        reference.shell = pocket.shell
                        reference.sector = pocket.sector
                    case .exited:
                        exitedAt = position
                    case .wedge, .stuck:
                        Issue.record("fixture \(index) wedged or stuck at \(position)")
                        exitedAt = -1
                    }
                }
                #expect(Self.agree(crystal, reference))
            }
            #expect(exitedAt == fixture.actions.count - 1, "fixture \(index)")
            #expect(fixture.actions.count <= level.budget)
        }
    }
}
