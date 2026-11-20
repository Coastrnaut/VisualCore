// NeighbourGridTests — feature 220 (R02-F20) T-R02F20-003 (FR-R02F20-001, 002; clarification Q2; research R1, R2).
// The grid's neighbour lists equal `NeighbourSearch` list for list, order included: 50 seeded swarms of 10 … 990 agents
// and one of 2,000 (every 7th agent queried), radii 0.4 … 7 (below and above the cell size), limits 1, 6 and 10,000;
// non-finite agents mixed in; agents at ±1e300; a radius of 1e300; radius 0 with coincident agents; the refusals. Test
// data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

@Suite struct NeighbourGridTests {
    static let radii: [Double] = [0.4, 1, 2.5, 7]
    static let limits: [Int] = [1, 6, 10_000]

    /// A seeded swarm of `count` agents in a square whose side grows with √count; every 9th agent repeats an earlier
    /// position so ties by index are exercised.
    static func swarm(count: Int, random: inout SeededRandom) -> [SteeringAgent] {
        let spread = Double(random.int(1...4))
        let side = Double(count).squareRoot() * spread
        var agents: [SteeringAgent] = []
        agents.reserveCapacity(count)
        for i in 0..<count {
            var p = Vec2((random.double() * 2 - 1) * side, (random.double() * 2 - 1) * side)
            if i > 0, i % 9 == 0 { p = agents[random.int(0...(i - 1))].position }
            agents.append(SteeringAgent(position: p, velocity: .zero, group: i % 3))
        }
        return agents
    }

    /// Checks every queried agent's list against `NeighbourSearch` for every radius and limit; returns the mismatches.
    static func mismatches(_ agents: [SteeringAgent], cellSize: Double, stride step: Int = 1,
                           radii: [Double] = radii) throws -> Int {
        let grid = try NeighbourGrid(agents: agents, cellSize: cellSize)
        var bad = 0
        var i = 0
        while i < agents.count {
            for r in radii {
                let reference: [Int] = NeighbourSearch.neighbours(of: i, in: agents, radius: r, limit: 10_000)
                for limit in limits {
                    let expected: [Int] = Array(reference.prefix(limit))
                    let got: [Int] = grid.neighbours(of: i, radius: r, limit: limit)
                    if got != expected { bad += 1 }
                }
                if i % 16 == 0 {
                    let direct: [Int] = NeighbourSearch.neighbours(of: i, in: agents, radius: r, limit: 6)
                    if grid.neighbours(of: i, radius: r, limit: 6) != direct { bad += 1 }
                }
            }
            i += step
        }
        return bad
    }

    /// Runs swarms `first ..< first + 5` of the 50 seeded swarms (10 + 20 · k agents each).
    static func seededSwarms(_ first: Int) throws {
        for k in first..<(first + 5) {
            var random = SeededRandom(seed: 2_020 + UInt64(k))
            let agents: [SteeringAgent] = swarm(count: 10 + 20 * k, random: &random)
            let cellSize: Double = k % 2 == 0 ? 1 : 2.5
            let bad = try mismatches(agents, cellSize: cellSize)
            #expect(bad == 0, "swarm \(k) of \(agents.count) agents")
        }
    }

    @Test func seededSwarms0to4() throws { try Self.seededSwarms(0) }
    @Test func seededSwarms5to9() throws { try Self.seededSwarms(5) }
    @Test func seededSwarms10to14() throws { try Self.seededSwarms(10) }
    @Test func seededSwarms15to19() throws { try Self.seededSwarms(15) }
    @Test func seededSwarms20to24() throws { try Self.seededSwarms(20) }
    @Test func seededSwarms25to29() throws { try Self.seededSwarms(25) }
    @Test func seededSwarms30to34() throws { try Self.seededSwarms(30) }
    @Test func seededSwarms35to39() throws { try Self.seededSwarms(35) }
    @Test func seededSwarms40to44() throws { try Self.seededSwarms(40) }
    @Test func seededSwarms45to49() throws { try Self.seededSwarms(45) }

    @Test func swarmOf2000EverySeventh() throws {
        var random = SeededRandom(seed: 2_020)
        let agents: [SteeringAgent] = Self.swarm(count: 2_000, random: &random)
        #expect(try Self.mismatches(agents, cellSize: 1.5, stride: 7) == 0)
    }

    @Test func nonFiniteAgentsMixedIn() throws {
        var random = SeededRandom(seed: 2_020)
        var agents: [SteeringAgent] = Self.swarm(count: 300, random: &random)
        let bad: [Vec2] = [Vec2(.nan, 0), Vec2(0, .nan), Vec2(.infinity, 1), Vec2(1, -.infinity),
                           Vec2(.nan, .infinity)]
        var i = 0
        while i < agents.count {
            agents[i].position = bad[(i / 11) % bad.count]
            i += 11
        }
        #expect(try Self.mismatches(agents, cellSize: 1) == 0)
        let grid = try NeighbourGrid(agents: agents, cellSize: 1)
        #expect(grid.neighbours(of: 0, radius: 5, limit: 10).isEmpty)
        for j in 1..<agents.count {
            let list: [Int] = grid.neighbours(of: j, radius: 1e6, limit: 10_000)
            for n in list { #expect(agents[n].position.isFinite) }
        }
    }

    @Test func farAgentsAndHugeRadius() throws {
        var agents: [SteeringAgent] = []
        let coords: [Double] = [1e300, -1e300, 1e300 * (1 + 1e-15), 5e299, 1e20, -1e20, 0, 1, 2.5, 1e300 - 1e285]
        for x in coords {
            for y in coords {
                agents.append(SteeringAgent(position: Vec2(x, y), velocity: .zero, group: 0))
            }
        }
        let radii: [Double] = [0, 1, 1e285, 1e286, 1e300, .greatestFiniteMagnitude]
        #expect(try Self.mismatches(agents, cellSize: 1, radii: radii) == 0)
        #expect(try Self.mismatches(agents, cellSize: 1e290, radii: radii) == 0)
        #expect(try Self.mismatches(agents, cellSize: 1e-300, radii: radii) == 0)
        var random = SeededRandom(seed: 2_020)
        let swarm: [SteeringAgent] = Self.swarm(count: 200, random: &random)
        #expect(try Self.mismatches(swarm, cellSize: 1, radii: [1e300]) == 0)
        let grid = try NeighbourGrid(agents: swarm, cellSize: 1)
        #expect(grid.neighbours(of: 0, radius: 1e300, limit: 10_000).count == 199)
    }

    @Test func radiusZeroWithCoincidentAgents() throws {
        var agents: [SteeringAgent] = []
        for i in 0..<12 {
            let p = i % 3 == 0 ? Vec2(0.5, 0.5) : Vec2(Double(i), -Double(i))
            agents.append(SteeringAgent(position: p, velocity: .zero, group: 0))
        }
        agents.append(SteeringAgent(position: Vec2(1, 1), velocity: .zero, group: 0))
        agents.append(SteeringAgent(position: Vec2(1, 1), velocity: .zero, group: 0))
        let grid = try NeighbourGrid(agents: agents, cellSize: 1)
        #expect(grid.neighbours(of: 3, radius: 0, limit: 10) == [0, 6, 9])
        #expect(grid.neighbours(of: 12, radius: 0, limit: 10) == [13])
        #expect(grid.neighbours(of: 1, radius: 0, limit: 10).isEmpty)
        let radii: [Double] = [0, 0.4, 1, 3]
        #expect(try Self.mismatches(agents, cellSize: 1, radii: radii) == 0)
        #expect(try Self.mismatches(agents, cellSize: 0.25, radii: radii) == 0)
        var random = SeededRandom(seed: 2_020)
        let swarm: [SteeringAgent] = Self.swarm(count: 400, random: &random)
        #expect(try Self.mismatches(swarm, cellSize: 1, radii: [0]) == 0)
    }

    @Test func guardsMatchNeighbourSearch() throws {
        var random = SeededRandom(seed: 2_020)
        let agents: [SteeringAgent] = Self.swarm(count: 50, random: &random)
        let grid = try NeighbourGrid(agents: agents, cellSize: 1)
        #expect(grid.neighbours(of: -1, radius: 3, limit: 5).isEmpty)
        #expect(grid.neighbours(of: 50, radius: 3, limit: 5).isEmpty)
        #expect(grid.neighbours(of: 0, radius: -0.1, limit: 5).isEmpty)
        #expect(grid.neighbours(of: 0, radius: .nan, limit: 5).isEmpty)
        #expect(grid.neighbours(of: 0, radius: .infinity, limit: 5).isEmpty)
        #expect(grid.neighbours(of: 0, radius: 3, limit: 0).isEmpty)
        #expect(grid.neighbours(of: 0, radius: 3, limit: -4).isEmpty)
        #expect(grid.cellSize == 1)
        let empty = try NeighbourGrid(agents: [], cellSize: 1)
        #expect(empty.neighbours(of: 0, radius: 1, limit: 1).isEmpty)
    }

    @Test func refusals() throws {
        let one = SteeringAgent(position: .zero, velocity: .zero, group: 0)
        let tooMany: [SteeringAgent] = Array(repeating: one, count: 65_537)
        #expect(throws: SwarmError.agentLimit(65_537)) { try NeighbourGrid(agents: tooMany, cellSize: 1) }
        let most: [SteeringAgent] = Array(repeating: one, count: NeighbourGrid.maxAgents)
        #expect(throws: Never.self) { try NeighbourGrid(agents: most, cellSize: 1) }
        let sizes: [Double] = [0, -1, .nan, .infinity, -.infinity]
        for size in sizes {
            #expect(throws: SwarmError.parameter("cellSize")) { try NeighbourGrid(agents: [one], cellSize: size) }
        }
        #expect(SwarmError.agentLimit(65_537).reasonCode == "r2-f20.agent-limit")
    }
}
