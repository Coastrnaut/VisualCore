// SwarmTests — feature 220 (R02-F20) T-R02F20-005 (FR-R02F20-002, 003, 005, 006; SC-R02F20-002, 003, 005;
// clarifications Q3, Q5). Twenty seeded swarms of 20 … 200 agents (walled and wrapping, seeded charges, uniform fields
// and poles on some) run 500 steps twice bit-identically, every agent inside its bounds, finite, with speed at most the
// limit after every step; a lone charge in a uniform field keeps its speed and closes its whole-step orbit; an attracting
// pole pulls inward; an empty swarm steps; every rule and step refusal; the stored form round-trips byte for byte and
// continues bit-identically; newer, damaged and rule-breaking forms are refused. Test data uses explicit types and plain
// loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

@Suite struct SwarmTests {
    /// The seeded swarm number `index` (0 … 19) of 20 + 180 · index / 19 agents, with its step length.
    static func seededSwarm(_ index: Int) throws -> (swarm: Swarm, step: Double) {
        var rng = SeededRandom(seed: 2_020 &+ UInt64(index))
        let count: Int = 20 + (180 * index) / 19
        let side: Double = 8 + 0.5 * Double(count).squareRoot() * 2
        let bounds = SteeringBounds(minX: -side / 2, maxX: side / 2, minY: -side * 0.3, maxY: side * 0.7)
        let speedLimit: Double = 2 + 4 * rng.double()
        var agents: [SteeringAgent] = []
        var charges: [Double] = []
        for _ in 0..<count {
            let p = Vec2(bounds.minX + (bounds.maxX - bounds.minX) * rng.double(),
                         bounds.minY + (bounds.maxY - bounds.minY) * rng.double())
            let v = Vec2(speedLimit * (2 * rng.double() - 1), speedLimit * (2 * rng.double() - 1))
            agents.append(SteeringAgent(position: p, velocity: v, group: rng.int(0...2)))
            charges.append(index % 3 == 0 ? 0 : 4 * rng.double() - 2)
        }
        var field = MagneticField.none
        if index % 2 == 1 {
            var poles: [MagneticPole] = []
            let poleCount: Int = index % 4 == 1 ? rng.int(1...3) : 0
            for _ in 0..<poleCount {
                let c = Vec2(bounds.minX + (bounds.maxX - bounds.minX) * rng.double(),
                             bounds.minY + (bounds.maxY - bounds.minY) * rng.double())
                poles.append(try MagneticPole(position: c, strength: 20 * rng.double() - 10, softening: 0.2))
            }
            field = try MagneticField(uniform: 6 * rng.double() - 3, poles: poles)
        }
        let parameters = SteeringParameters(neighbourRadius: 1.5 + 2 * rng.double(), neighbourLimit: rng.int(1...8))
        let edges: SwarmEdges = index % 2 == 0 ? .walled : .wrapping
        let step: Double = 0.005 + 0.095 * rng.double()
        let swarm = try Swarm(agents: agents, charges: charges, bounds: bounds, edges: edges, parameters: parameters,
                              speedLimit: speedLimit, field: field)
        return (swarm, step)
    }

    /// True when both agent lists agree bit for bit.
    static func bitIdentical(_ a: [SteeringAgent], _ b: [SteeringAgent]) -> Bool {
        guard a.count == b.count else { return false }
        for i in a.indices {
            let x = a[i], y = b[i]
            if x.position.x.bitPattern != y.position.x.bitPattern || x.position.y.bitPattern != y.position.y.bitPattern
                || x.velocity.x.bitPattern != y.velocity.x.bitPattern
                || x.velocity.y.bitPattern != y.velocity.y.bitPattern || x.group != y.group {
                return false
            }
        }
        return true
    }

    /// The number of agents outside the bounds, non-finite, or faster than the limit (with 1e-12 relative slack).
    static func violations(_ swarm: Swarm) -> Int {
        var bad = 0
        let b = swarm.bounds
        for agent in swarm.agents {
            let p = agent.position, v = agent.velocity
            let inside = p.x >= b.minX && p.x <= b.maxX && p.y >= b.minY && p.y <= b.maxY
            if !agent.isFinite || !inside || v.length > swarm.speedLimit * (1 + 1e-12) { bad += 1 }
        }
        return bad
    }

    @Test(arguments: Array(0..<20))
    func seededSwarmsAreDeterministicAndBounded(index: Int) throws {
        let start = Date()
        let made = try Self.seededSwarm(index)
        var first = made.swarm
        var second = made.swarm
        var violations = 0
        for _ in 0..<500 {
            try first.step(by: made.step)
            violations += Self.violations(first)
        }
        for _ in 0..<500 { try second.step(by: made.step) }
        #expect(violations == 0)
        #expect(Self.bitIdentical(first.agents, second.agents))
        #expect(first.encoded() == second.encoded())
        #expect(first != made.swarm)
        print("SwarmTests seeded \(index): \(first.agents.count) agents, \(first.edges), h \(made.step), "
              + "violations \(violations), \(String(format: "%.2f", Date().timeIntervalSince(start))) s")
    }

    /// A lone charge with every steering weight 0 in a big wrapping box.
    static func loneCharge(uniform: Double, speed: Double) throws -> Swarm {
        let quiet = SteeringParameters(separationWeight: 0, alignmentWeight: 0, cohesionWeight: 0, boundaryWeight: 0,
                                       boundaryMargin: 0)
        let agent = SteeringAgent(position: Vec2(3, -2), velocity: Vec2(speed, 0), group: 0)
        return try Swarm(agents: [agent], charges: [1], bounds: SteeringBounds(minX: -1_000, maxX: 1_000, minY: -1_000,
                                                                               maxY: 1_000),
                         edges: .wrapping, parameters: quiet, speedLimit: 5, field: MagneticField(uniform: uniform))
    }

    @Test func uniformFieldKeepsSpeedAndClosesOrbit() throws {
        let n = 200
        let h = 0.01
        let speed = 2.0
        let qB = 2 * Double.pi / (Double(n) * h)
        var swarm = try Self.loneCharge(uniform: qB, speed: speed)
        let start = swarm.agents[0].position
        let radius = speed / abs(qB)
        var worstSpeed = 0.0
        var closure = 0.0
        for k in 1...1_000 {
            try swarm.step(by: h)
            let error = abs(swarm.agents[0].velocity.length - speed) / speed
            worstSpeed = max(worstSpeed, error)
            if k == n { closure = swarm.agents[0].position.distance(to: start) / radius }
        }
        let after5 = swarm.agents[0].position.distance(to: start) / radius
        #expect(worstSpeed <= 1e-9)
        #expect(closure <= 1e-9)
        #expect(after5 <= 1e-9)
        print("SwarmTests orbit: speed error \(worstSpeed), closure after \(n) steps \(closure) radius, "
              + "after 1000 steps \(after5) radius")
    }

    @Test func attractingPolePullsCloser() throws {
        let quiet = SteeringParameters(separationWeight: 0, alignmentWeight: 0, cohesionWeight: 0, boundaryWeight: 0,
                                       boundaryMargin: 0)
        let pole = try MagneticPole(position: .zero, strength: 10, softening: 0.1)
        let agent = SteeringAgent(position: Vec2(5, 0), velocity: .zero, group: 0)
        var swarm = try Swarm(agents: [agent], charges: [1], bounds: SteeringBounds(minX: -10, maxX: 10, minY: -10,
                                                                                   maxY: 10),
                              parameters: quiet, field: MagneticField(poles: [pole]))
        var distance = 5.0
        for _ in 0..<10 {
            try swarm.step(by: 0.05)
            let d = swarm.agents[0].position.length
            #expect(d < distance)
            distance = d
        }
        print("SwarmTests pole: distance 5 -> \(distance) after 10 steps")
    }

    @Test func emptySwarmSteps() throws {
        var swarm = try Swarm(agents: [], bounds: SteeringBounds(minX: 0, maxX: 1, minY: 0, maxY: 1), edges: .wrapping)
        for _ in 0..<10 { try swarm.step(by: 0.1) }
        #expect(swarm.agents.isEmpty)
        #expect(swarm.charges.isEmpty)
        let back = try Swarm.decode(swarm.encoded())
        #expect(back == swarm)
    }

    @Test func initAndStepRefusals() throws {
        let box = SteeringBounds(minX: 0, maxX: 10, minY: 0, maxY: 10)
        let one = SteeringAgent(position: Vec2(1, 1), velocity: Vec2(1, 0), group: 0)
        let many: [SteeringAgent] = Array(repeating: one, count: 65_537)
        #expect(throws: SwarmError.agentLimit(65_537)) { try Swarm(agents: many, bounds: box) }
        #expect(throws: SwarmError.bounds) {
            try Swarm(agents: [one], bounds: SteeringBounds(minX: 1, maxX: 1, minY: 0, maxY: 1))
        }
        #expect(throws: SwarmError.bounds) {
            try Swarm(agents: [one], bounds: SteeringBounds(minX: 0, maxX: .infinity, minY: 0, maxY: 1))
        }
        let badPosition = SteeringAgent(position: Vec2(.nan, 1), velocity: .zero, group: 0)
        let badVelocity = SteeringAgent(position: Vec2(1, 1), velocity: Vec2(0, .infinity), group: 0)
        #expect(throws: SwarmError.parameter("agents")) { try Swarm(agents: [one, badPosition], bounds: box) }
        #expect(throws: SwarmError.parameter("agents")) { try Swarm(agents: [badVelocity], bounds: box) }
        #expect(throws: SwarmError.parameter("charges")) { try Swarm(agents: [one], charges: [1, 2], bounds: box) }
        #expect(throws: SwarmError.parameter("charges")) { try Swarm(agents: [one], charges: [.nan], bounds: box) }
        #expect(throws: SwarmError.parameter("charges")) { try Swarm(agents: [one], charges: [-100.5], bounds: box) }
        _ = try Swarm(agents: [one], charges: [-100], bounds: box)

        var parameterCases: [(SteeringParameters, String)] = []
        var p = SteeringParameters()
        p.neighbourRadius = 0
        parameterCases.append((p, "neighbourRadius"))
        p = SteeringParameters()
        p.neighbourRadius = .infinity
        parameterCases.append((p, "neighbourRadius"))
        p = SteeringParameters()
        p.neighbourLimit = 0
        parameterCases.append((p, "neighbourLimit"))
        p = SteeringParameters()
        p.separationRadius = -1
        parameterCases.append((p, "separationRadius"))
        p = SteeringParameters()
        p.separationWeight = .nan
        parameterCases.append((p, "separationWeight"))
        p = SteeringParameters()
        p.alignmentWeight = -0.5
        parameterCases.append((p, "alignmentWeight"))
        p = SteeringParameters()
        p.cohesionWeight = .infinity
        parameterCases.append((p, "cohesionWeight"))
        p = SteeringParameters()
        p.boundaryWeight = -2
        parameterCases.append((p, "boundaryWeight"))
        p = SteeringParameters()
        p.boundaryMargin = .nan
        parameterCases.append((p, "boundaryMargin"))
        p = SteeringParameters()
        p.maxForce = -1
        parameterCases.append((p, "maxForce"))
        for (parameters, name) in parameterCases {
            #expect(throws: SwarmError.parameter(name)) { try Swarm(agents: [one], bounds: box, parameters: parameters) }
        }
        let speeds: [Double] = [0, -1, .nan, .infinity]
        for speed in speeds {
            #expect(throws: SwarmError.parameter("speedLimit")) {
                try Swarm(agents: [one], bounds: box, speedLimit: speed)
            }
        }

        var swarm = try Swarm(agents: [one], bounds: box)
        let before = swarm
        let steps: [Double] = [0, -1, 0.1000001, .nan, .infinity]
        for h in steps {
            #expect(throws: SwarmError.step) { try swarm.step(by: h) }
        }
        #expect(swarm == before)
        try swarm.step(by: 0.1)
        #expect(swarm != before)
    }

    @Test func roundTripContinuesBitIdentically() throws {
        let made = try Self.seededSwarm(7)
        var swarm = made.swarm
        for _ in 0..<50 { try swarm.step(by: made.step) }
        let data = swarm.encoded()
        var restored = try Swarm.decode(data)
        #expect(restored == swarm)
        #expect(restored.encoded() == data)
        let viaCodable = try JSONDecoder().decode(Swarm.self, from: JSONEncoder().encode(swarm))
        #expect(viaCodable == swarm)
        for _ in 0..<200 {
            try swarm.step(by: made.step)
            try restored.step(by: made.step)
        }
        #expect(Self.bitIdentical(swarm.agents, restored.agents))
        #expect(swarm.encoded() == restored.encoded())
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"agents\":"))
        print("SwarmTests round trip: \(data.count) bytes, 200 steps bit-identical")
    }

    /// The stored form of a small swarm with one key replaced (or removed when `value` is nil).
    static func edited(_ key: String, _ value: Any?) throws -> Data {
        let swarm = try Swarm(agents: [SteeringAgent(position: Vec2(1, 1), velocity: Vec2(1, 0), group: 0)],
                              charges: [1], bounds: SteeringBounds(minX: 0, maxX: 10, minY: 0, maxY: 10))
        let object = try JSONSerialization.jsonObject(with: swarm.encoded())
        var dictionary: [String: Any] = try #require(object as? [String: Any])
        dictionary[key] = value
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    @Test func storedFormRefusals() throws {
        #expect(throws: SwarmError.newerSchema(2)) { try Swarm.decode(Self.edited("schema", 2)) }
        #expect(throws: SwarmError.newerSchema(7)) { try Swarm.decode(Data("{\"schema\":7}".utf8)) }
        let good = try Self.edited("schema", 1)
        _ = try Swarm.decode(good)

        var damaged: [Data] = [Data("not json".utf8), Data(), good.prefix(good.count / 2)]
        damaged.append(try Self.edited("charges", nil))
        damaged.append(try Self.edited("field", nil))
        damaged.append(try Self.edited("schema", nil))
        damaged.append(try Self.edited("schema", 0))
        damaged.append(try Self.edited("charges", [500.0]))
        damaged.append(try Self.edited("charges", [1.0, 2.0]))
        damaged.append(try Self.edited("speedLimit", -1.0))
        damaged.append(try Self.edited("edges", "sideways"))
        let badBounds: [String: Double] = ["minX": 5, "maxX": 1, "minY": 0, "maxY": 10]
        damaged.append(try Self.edited("bounds", badBounds))
        let badField: [String: Any] = ["uniform": 500.0, "poles": [Any]()]
        damaged.append(try Self.edited("field", badField))
        let badAgent: [String: Any] = ["position": ["x": 1e300, "y": "1"], "velocity": ["x": 0, "y": 0], "group": 0]
        damaged.append(try Self.edited("agents", [badAgent]))
        let farParameters: [String: Any] = [
            "neighbourRadius": 0.0, "neighbourLimit": 6, "separationRadius": 1.0, "separationWeight": 2.0,
            "alignmentWeight": 1.0, "cohesionWeight": 0.8, "boundaryWeight": 3.0, "boundaryMargin": 1.0, "maxForce": 2.0,
        ]
        damaged.append(try Self.edited("parameters", farParameters))
        for (i, data) in damaged.enumerated() {
            do {
                _ = try Swarm.decode(data)
                Issue.record("damaged form \(i) was accepted")
            } catch {
                if case .malformed = error {} else { Issue.record("damaged form \(i): \(error)") }
                #expect(error.reasonCode == "r2-f20.malformed")
            }
        }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Swarm.self, from: Self.edited("speedLimit", -1.0)) }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Swarm.self, from: Self.edited("schema", 2)) }
    }
}
