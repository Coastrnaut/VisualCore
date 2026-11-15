// SteeringTests — feature 069 (A09-P02) T-A09-202 (FR-A09-201–203; SC-A09-205; contract specs/069-da-p02-schools/
// contracts/api.md; research D1, D2). Neighbour search, weighted steering terms, caps and determinism.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func agent(_ x: Double, _ y: Double, vx: Double = 0, vy: Double = 0, group: Int = 0) -> SteeringAgent {
    SteeringAgent(position: Vec2(x, y), velocity: Vec2(vx, vy), group: group)
}

/// Bounds far away from every test agent, so no boundary force acts.
private let wide = SteeringBounds(minX: -1_000, maxX: 1_000, minY: -1_000, maxY: 1_000)

/// Parameters with only one term weighted.
private func only(separation: Double = 0, alignment: Double = 0, cohesion: Double = 0, boundary: Double = 0,
                  maxForce: Double = 100) -> SteeringParameters {
    SteeringParameters(separationWeight: separation, alignmentWeight: alignment, cohesionWeight: cohesion,
                       boundaryWeight: boundary, maxForce: maxForce)
}

private func near(_ a: Vec2, _ b: Vec2, _ tolerance: Double = 1e-12) -> Bool { a.distance(to: b) <= tolerance }

struct NeighbourSearchTests {
    @Test func respectsLimitAndNeverReturnsSelf() {
        let agents = (0..<10).map { agent(Double($0) * 0.1, 0) }
        let found = NeighbourSearch.neighbours(of: 0, in: agents, radius: 10, limit: 4)
        #expect(found == [1, 2, 3, 4])
        #expect(NeighbourSearch.neighbours(of: 5, in: agents, radius: 10, limit: 100).count == 9)
        #expect(!NeighbourSearch.neighbours(of: 5, in: agents, radius: 10, limit: 100).contains(5))
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: 10, limit: 0).isEmpty)
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: 10, limit: -3).isEmpty)
    }

    @Test func ordersByDistanceThenIndex() {
        // Agents 1 and 3 tie at distance 1; 2 is at 0.5; 4 at 2.
        let agents = [agent(0, 0), agent(1, 0), agent(0, 0.5), agent(0, -1), agent(2, 0)]
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: 5, limit: 10) == [2, 1, 3, 4])
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: 5, limit: 2) == [2, 1])
    }

    @Test func filtersByRadiusInclusive() {
        let agents = [agent(0, 0), agent(1, 0), agent(1.5, 0), agent(3, 0)]
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: 1.5, limit: 10) == [1, 2])
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: 0.5, limit: 10).isEmpty)
    }

    @Test func rejectsInvalidInput() {
        let agents = [agent(0, 0), agent(1, 0)]
        #expect(NeighbourSearch.neighbours(of: -1, in: agents, radius: 5, limit: 5).isEmpty)
        #expect(NeighbourSearch.neighbours(of: 2, in: agents, radius: 5, limit: 5).isEmpty)
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: .nan, limit: 5).isEmpty)
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: .infinity, limit: 5).isEmpty)
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: -1, limit: 5).isEmpty)
        let bad = [agent(.nan, 0), agent(1, 0)]
        #expect(NeighbourSearch.neighbours(of: 0, in: bad, radius: 5, limit: 5).isEmpty)
        #expect(NeighbourSearch.neighbours(of: 1, in: bad, radius: 5, limit: 5).isEmpty)
    }

    @Test func excludesNonFiniteAgents() {
        let agents = [agent(0, 0), agent(.infinity, 0), agent(0.5, 0), agent(0, .nan)]
        #expect(NeighbourSearch.neighbours(of: 0, in: agents, radius: 1e300, limit: 10) == [2])
    }
}

struct SteeringForceTests {
    @Test func separationPushesApart() {
        let agents = [agent(0, 0), agent(0.5, 0)]
        let p = only(separation: 2)
        let f0 = Steering.force(for: 0, agents: agents, neighbours: [1], parameters: p, bounds: wide)
        let f1 = Steering.force(for: 1, agents: agents, neighbours: [0], parameters: p, bounds: wide)
        // (1 − 0.5 / 1) × 2 = 1 along the away direction.
        #expect(near(f0, Vec2(-1, 0)))
        #expect(near(f1, Vec2(1, 0)))
        // Outside the separation radius there is no push.
        let far = [agent(0, 0), agent(1.2, 0)]
        #expect(Steering.force(for: 0, agents: far, neighbours: [1], parameters: p, bounds: wide) == .zero)
    }

    @Test func coincidentAgentsSeparateDeterministically() {
        let agents = [agent(3, 4), agent(3, 4)]
        let p = only(separation: 2)
        let f0 = Steering.force(for: 0, agents: agents, neighbours: [1], parameters: p, bounds: wide)
        let f1 = Steering.force(for: 1, agents: agents, neighbours: [0], parameters: p, bounds: wide)
        #expect(near(f0, Vec2(2, 0)))
        #expect(near(f1, Vec2(-2, 0)))
    }

    @Test func alignmentAndCohesionOnlyWithinGroup() {
        let same = [agent(0, 0, vx: 1, group: 1), agent(2, 0, vx: 0, vy: 1, group: 1)]
        let align = Steering.force(for: 0, agents: same, neighbours: [1], parameters: only(alignment: 1), bounds: wide)
        #expect(near(align, Vec2(-1, 1)))
        let cohere = Steering.force(for: 0, agents: same, neighbours: [1], parameters: only(cohesion: 0.5), bounds: wide)
        #expect(near(cohere, Vec2(1, 0)))

        // Cross-group neighbour inside the separation radius: only separation acts.
        let cross = [agent(0, 0, vx: 1, group: 1), agent(0.5, 0, vy: 3, group: 2)]
        let all = SteeringParameters(separationWeight: 2, alignmentWeight: 1, cohesionWeight: 0.8, boundaryWeight: 0,
                                     maxForce: 100)
        let f = Steering.force(for: 0, agents: cross, neighbours: [1], parameters: all, bounds: wide)
        #expect(near(f, Vec2(-1, 0)))
        let noSeparation = SteeringParameters(separationWeight: 0, alignmentWeight: 1, cohesionWeight: 0.8,
                                              boundaryWeight: 0, maxForce: 100)
        #expect(Steering.force(for: 0, agents: cross, neighbours: [1], parameters: noSeparation, bounds: wide) == .zero)
    }

    @Test func ignoresInvalidNeighbourIndices() {
        let agents = [agent(0, 0), agent(0.5, 0), agent(.nan, 0)]
        let p = only(separation: 2)
        let reference = Steering.force(for: 0, agents: agents, neighbours: [1], parameters: p, bounds: wide)
        let noisy = Steering.force(for: 0, agents: agents, neighbours: [1, 0, -1, 7, 2], parameters: p, bounds: wide)
        #expect(noisy == reference)
    }

    @Test func boundaryPushesInwardInsideMargin() {
        let bounds = SteeringBounds(minX: 0, maxX: 10, minY: 0, maxY: 10)
        let p = only(boundary: 3)
        // 0.25 inside the left margin of 1: push 0.75 × 3 = 2.25 to +x.
        let left = Steering.force(for: 0, agents: [agent(0.25, 5)], neighbours: [], parameters: p, bounds: bounds)
        #expect(near(left, Vec2(2.25, 0)))
        // Near the top-right corner: push toward −x and −y.
        let corner = Steering.force(for: 0, agents: [agent(9.5, 9.5)], neighbours: [], parameters: p, bounds: bounds)
        #expect(near(corner, Vec2(-1.5, -1.5)))
        // Beyond the bound the push stays at 1 per axis.
        let outside = Steering.force(for: 0, agents: [agent(-4, 5)], neighbours: [], parameters: p, bounds: bounds)
        #expect(near(outside, Vec2(3, 0)))
        // Outside the margin there is none.
        let middle = Steering.force(for: 0, agents: [agent(5, 5)], neighbours: [], parameters: p, bounds: bounds)
        #expect(middle == .zero)
        let edgeOfMargin = Steering.force(for: 0, agents: [agent(1, 5)], neighbours: [], parameters: p, bounds: bounds)
        #expect(edgeOfMargin == .zero)
    }

    @Test func invalidBoundsOrZeroMarginGiveNoBoundaryForce() {
        let p = only(boundary: 3)
        let invalid: [SteeringBounds] = [
            SteeringBounds(minX: 10, maxX: 0, minY: 0, maxY: 10),
            SteeringBounds(minX: 0, maxX: 0, minY: 0, maxY: 10),
            SteeringBounds(minX: 0, maxX: .nan, minY: 0, maxY: 10),
            SteeringBounds(minX: 0, maxX: 10, minY: -.infinity, maxY: 10),
        ]
        for b in invalid {
            #expect(!b.isValid)
            #expect(Steering.force(for: 0, agents: [agent(0.1, 0.1)], neighbours: [], parameters: p, bounds: b) == .zero)
        }
        #expect(SteeringBounds(minX: 0, maxX: 10, minY: 0, maxY: 10).isValid)
        var zeroMargin = p
        zeroMargin.boundaryMargin = 0
        let b = SteeringBounds(minX: 0, maxX: 10, minY: 0, maxY: 10)
        #expect(Steering.force(for: 0, agents: [agent(-1, 0.1)], neighbours: [], parameters: zeroMargin, bounds: b)
                == .zero)
    }

    @Test func invalidOwnAgentGivesZero() {
        let agents = [agent(0, 0), agent(0.5, 0), agent(.nan, 0), agent(0.2, 0, vx: .infinity)]
        let p = SteeringParameters()
        #expect(Steering.force(for: -1, agents: agents, neighbours: [1], parameters: p, bounds: wide) == .zero)
        #expect(Steering.force(for: 4, agents: agents, neighbours: [1], parameters: p, bounds: wide) == .zero)
        #expect(Steering.force(for: 2, agents: agents, neighbours: [0, 1], parameters: p, bounds: wide) == .zero)
        #expect(Steering.force(for: 3, agents: agents, neighbours: [0, 1], parameters: p, bounds: wide) == .zero)
    }

    @Test func negativeOrNonFiniteParametersActAsZero() {
        let agents = [agent(0, 0, vx: 1), agent(0.5, 0, vy: 1)]
        let p = SteeringParameters(separationWeight: -2, alignmentWeight: .nan, cohesionWeight: -.infinity,
                                   boundaryWeight: .infinity)
        #expect(Steering.force(for: 0, agents: agents, neighbours: [1], parameters: p, bounds: wide) == .zero)
        var noCap = SteeringParameters()
        noCap.maxForce = .nan
        #expect(Steering.force(for: 0, agents: agents, neighbours: [1], parameters: noCap, bounds: wide) == .zero)
    }

    @Test func cappedBehaviour() {
        #expect(Steering.capped(Vec2(3, 4), to: 10) == Vec2(3, 4))
        #expect(near(Steering.capped(Vec2(3, 4), to: 1), Vec2(0.6, 0.8)))
        #expect(Steering.capped(Vec2(3, 4), to: 0) == .zero)
        #expect(Steering.capped(Vec2(3, 4), to: -1) == .zero)
        #expect(Steering.capped(Vec2(3, 4), to: .nan) == .zero)
        #expect(Steering.capped(Vec2(.nan, 4), to: 1) == .zero)
        #expect(Steering.capped(Vec2(.infinity, 0), to: 1) == .zero)
    }

    @Test func everyForceFiniteAndCappedOverSeededConfigurations() {
        var random = SeededRandom(seed: 0x0069_A09_202)
        let defaults = SteeringParameters()
        for _ in 0..<200 {
            let count = random.int(1...24)
            let agents = (0..<count).map { _ in
                SteeringAgent(position: Vec2(random.range(-12...12), random.range(-12...12)),
                              velocity: Vec2(random.range(-5...5), random.range(-5...5)), group: random.int(0...2))
            }
            let bounds = SteeringBounds(minX: -10, maxX: 10, minY: -10, maxY: 10)
            for i in 0..<count {
                let n = NeighbourSearch.neighbours(of: i, in: agents, radius: defaults.neighbourRadius,
                                                   limit: defaults.neighbourLimit)
                #expect(n.count <= defaults.neighbourLimit)
                let f = Steering.force(for: i, agents: agents, neighbours: n, parameters: defaults, bounds: bounds)
                #expect(f.isFinite)
                #expect(f.length <= defaults.maxForce * (1 + 1e-12))
            }
        }
    }

    @Test func identicalInputGivesIdenticalOutput() {
        func run() -> [Vec2] {
            var random = SeededRandom(seed: 42)
            let agents = (0..<20).map { _ in
                SteeringAgent(position: Vec2(random.range(-5...5), random.range(-5...5)),
                              velocity: Vec2(random.range(-1...1), random.range(-1...1)), group: random.int(0...1))
            }
            let bounds = SteeringBounds(minX: -6, maxX: 6, minY: -6, maxY: 6)
            let p = SteeringParameters()
            return agents.indices.map { i in
                let n = NeighbourSearch.neighbours(of: i, in: agents, radius: p.neighbourRadius, limit: p.neighbourLimit)
                return Steering.force(for: i, agents: agents, neighbours: n, parameters: p, bounds: bounds)
            }
        }
        #expect(run() == run())
    }
}
