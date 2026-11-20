// Swarm — feature 220 (R02-F20) T-R02F20-005 (FR-R02F20-002, 003, 005, 006; SC-R02F20-002, 003, 005; clarifications
// Q3, Q5; research R3, R5, R7). A bounded swarm of steered, charged agents stepped in fixed steps: every force comes from
// the start-of-step state (steering through one `NeighbourGrid`, plus the field's poles); the velocity becomes v + a · h,
// is turned by the uniform field's exact rotation −q · B · h, and is capped at the speed limit; the position becomes
// p + v · h and is then reflected back inside (walled, flipping that velocity component, clamped if still outside) or
// wrapped modulo the bounds into [min, max). Every value stays finite and every agent inside its bounds with speed at
// most the limit. The stored form is JSON schema 1 with sorted keys; decoding re-runs every rule.
import Foundation
import VisualCoreMath

/// How a swarm treats its bounds.
public enum SwarmEdges: String, Sendable, Codable, CaseIterable {
    /// Agents bounce off the bounds: the overshoot is reflected and that velocity component flipped.
    case walled
    /// Agents leaving one side re-enter at the opposite side (position modulo the bounds).
    case wrapping
}

/// A bounded swarm of steered, optionally charged agents with a deterministic fixed-step integrator.
public struct Swarm: Sendable, Equatable, Codable {
    /// The stored-form schema this version writes and the newest it reads.
    public static let schema = 1
    /// The largest number of agents.
    public static let maxAgents = 65_536
    /// The largest allowed charge magnitude.
    public static let maxCharge = 100.0
    /// The largest allowed step length.
    public static let maxStep = 0.1

    /// The agents, in their original order.
    public private(set) var agents: [SteeringAgent]
    /// The charge of each agent, index for index with ``agents``.
    public private(set) var charges: [Double]
    /// The rectangle every agent stays inside.
    public let bounds: SteeringBounds
    /// How the bounds treat agents that reach them.
    public let edges: SwarmEdges
    /// The steering tuning.
    public let parameters: SteeringParameters
    /// The largest speed of any agent after a step (world units per second).
    public let speedLimit: Double
    /// The magnetic field acting on charged agents.
    public let field: MagneticField

    /// A swarm of `agents` with `charges` (all 0 when `nil`) inside `bounds`.
    ///
    /// - Throws: `.agentLimit(count)` for more than 65,536 agents; `.bounds` for invalid bounds;
    ///   `.parameter("agents")` for an agent with a non-finite position or velocity; `.parameter("charges")` when the
    ///   charge count differs from the agent count or a charge is non-finite or above 100 in magnitude;
    ///   `.parameter(name)` naming the `SteeringParameters` property when `neighbourRadius` is not finite and > 0,
    ///   `neighbourLimit` is below 1, or any other value is non-finite or negative; `.parameter("speedLimit")` unless
    ///   the speed limit is finite and > 0.
    public init(agents: [SteeringAgent], charges: [Double]? = nil, bounds: SteeringBounds, edges: SwarmEdges = .walled,
                parameters: SteeringParameters = .init(), speedLimit: Double = 5,
                field: MagneticField = .none) throws(SwarmError) {
        guard agents.count <= Self.maxAgents else { throw .agentLimit(agents.count) }
        guard bounds.isValid else { throw .bounds }
        for agent in agents where !(agent.position.isFinite && agent.velocity.isFinite) {
            throw .parameter("agents")
        }
        let charges = charges ?? [Double](repeating: 0, count: agents.count)
        guard charges.count == agents.count else { throw .parameter("charges") }
        for q in charges where !(q.isFinite && abs(q) <= Self.maxCharge) { throw .parameter("charges") }
        try Self.check(parameters)
        guard speedLimit.isFinite, speedLimit > 0 else { throw .parameter("speedLimit") }
        self.agents = agents
        self.charges = charges
        self.bounds = bounds
        self.edges = edges
        self.parameters = parameters
        self.speedLimit = speedLimit
        self.field = field
    }

    /// Refuses steering parameters that the swarm cannot store or step.
    private static func check(_ p: SteeringParameters) throws(SwarmError) {
        guard p.neighbourRadius.isFinite, p.neighbourRadius > 0 else { throw .parameter("neighbourRadius") }
        guard p.neighbourLimit >= 1 else { throw .parameter("neighbourLimit") }
        let others: [(String, Double)] = [
            ("separationRadius", p.separationRadius), ("separationWeight", p.separationWeight),
            ("alignmentWeight", p.alignmentWeight), ("cohesionWeight", p.cohesionWeight),
            ("boundaryWeight", p.boundaryWeight), ("boundaryMargin", p.boundaryMargin), ("maxForce", p.maxForce),
        ]
        for (name, value) in others where !(value.isFinite && value >= 0) { throw .parameter(name) }
    }

    /// Advances the swarm by one step of length `h`, computing every force from the start-of-step state.
    ///
    /// - Throws: `.step` unless `h` is finite and 0 < h ≤ 0.1. The swarm is unchanged when it throws.
    public mutating func step(by h: Double) throws(SwarmError) {
        guard h.isFinite, h > 0, h <= Self.maxStep else { throw .step }
        guard !agents.isEmpty else { return }
        let grid = try NeighbourGrid(agents: agents, cellSize: parameters.neighbourRadius)
        var next = agents
        for i in agents.indices {
            let agent = agents[i]
            let q = charges[i]
            let neighbours = grid.neighbours(of: i, radius: parameters.neighbourRadius,
                                             limit: parameters.neighbourLimit)
            let steering = Steering.force(for: i, agents: agents, neighbours: neighbours, parameters: parameters,
                                          bounds: bounds)
            let a = steering + field.poleForce(at: agent.position, charge: q)
            var v = agent.velocity + a * h
            v = field.turned(v, charge: q, step: h)
            v = Steering.capped(v, to: speedLimit)
            var p = agent.position + v * h
            switch edges {
            case .walled:
                Self.reflect(&p.x, &v.x, bounds.minX, bounds.maxX)
                Self.reflect(&p.y, &v.y, bounds.minY, bounds.maxY)
            case .wrapping:
                p.x = Self.wrap(p.x, bounds.minX, bounds.maxX)
                p.y = Self.wrap(p.y, bounds.minY, bounds.maxY)
            }
            next[i].position = p
            next[i].velocity = v
        }
        agents = next
    }

    /// Reflects the overshoot of `x` back inside [lo, hi], flips `v` when reflected, and clamps what is still outside.
    private static func reflect(_ x: inout Double, _ v: inout Double, _ lo: Double, _ hi: Double) {
        if x < lo {
            x = 2 * lo - x
            v = -v
        } else if x > hi {
            x = 2 * hi - x
            v = -v
        }
        if x < lo { x = lo } else if x > hi { x = hi }
    }

    /// `x` taken modulo [lo, hi) as lo + positive remainder of (x − lo) by the width; a result that rounds to `hi` or
    /// out of range becomes `lo`.
    private static func wrap(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        if x >= lo && x < hi { return x }
        let width = hi - lo
        var r = (x - lo).truncatingRemainder(dividingBy: width)
        if r < 0 { r += width }
        let result = lo + r
        return result >= lo && result < hi ? result : lo
    }

    // MARK: Stored form

    /// The stored form of one agent.
    private struct AgentForm: Codable {
        var position: Vec2
        var velocity: Vec2
        var group: Int
    }

    /// The stored form of the bounds.
    private struct BoundsForm: Codable {
        var minX: Double, maxX: Double, minY: Double, maxY: Double
    }

    /// The stored form of the steering parameters, field by field.
    private struct ParametersForm: Codable {
        var neighbourRadius: Double
        var neighbourLimit: Int
        var separationRadius: Double
        var separationWeight: Double
        var alignmentWeight: Double
        var cohesionWeight: Double
        var boundaryWeight: Double
        var boundaryMargin: Double
        var maxForce: Double
    }

    /// The whole stored form, schema 1.
    private struct StoredForm: Codable {
        var schema: Int
        var agents: [AgentForm]
        var charges: [Double]
        var bounds: BoundsForm
        var edges: SwarmEdges
        var parameters: ParametersForm
        var speedLimit: Double
        var field: MagneticField
    }

    /// Only the schema, read before the rest so a newer layout is recognised.
    private struct SchemaProbe: Decodable {
        var schema: Int
    }

    /// This swarm as its stored form.
    private var storedForm: StoredForm {
        var forms: [AgentForm] = []
        forms.reserveCapacity(agents.count)
        for agent in agents {
            forms.append(AgentForm(position: agent.position, velocity: agent.velocity, group: agent.group))
        }
        let p = parameters
        return StoredForm(
            schema: Self.schema, agents: forms, charges: charges,
            bounds: BoundsForm(minX: bounds.minX, maxX: bounds.maxX, minY: bounds.minY, maxY: bounds.maxY),
            edges: edges,
            parameters: ParametersForm(
                neighbourRadius: p.neighbourRadius, neighbourLimit: p.neighbourLimit,
                separationRadius: p.separationRadius, separationWeight: p.separationWeight,
                alignmentWeight: p.alignmentWeight, cohesionWeight: p.cohesionWeight,
                boundaryWeight: p.boundaryWeight, boundaryMargin: p.boundaryMargin, maxForce: p.maxForce),
            speedLimit: speedLimit, field: field)
    }

    /// Builds a swarm from a stored form with the rules of ``init(agents:charges:bounds:edges:parameters:speedLimit:field:)``.
    private init(stored s: StoredForm) throws(SwarmError) {
        guard s.schema <= Self.schema else { throw .newerSchema(s.schema) }
        guard s.schema >= 1 else { throw .malformed("schema \(s.schema)") }
        var agents: [SteeringAgent] = []
        agents.reserveCapacity(s.agents.count)
        for form in s.agents {
            agents.append(SteeringAgent(position: form.position, velocity: form.velocity, group: form.group))
        }
        let b = s.bounds, p = s.parameters
        try self.init(
            agents: agents, charges: s.charges,
            bounds: SteeringBounds(minX: b.minX, maxX: b.maxX, minY: b.minY, maxY: b.maxY), edges: s.edges,
            parameters: SteeringParameters(
                neighbourRadius: p.neighbourRadius, neighbourLimit: p.neighbourLimit,
                separationRadius: p.separationRadius, separationWeight: p.separationWeight,
                alignmentWeight: p.alignmentWeight, cohesionWeight: p.cohesionWeight,
                boundaryWeight: p.boundaryWeight, boundaryMargin: p.boundaryMargin, maxForce: p.maxForce),
            speedLimit: s.speedLimit, field: s.field)
    }

    /// Encodes the swarm as its schema-1 stored form.
    public func encode(to encoder: any Encoder) throws {
        try storedForm.encode(to: encoder)
    }

    /// Decodes a swarm and checks it with every rule of the initialiser; a broken rule or a newer schema is a
    /// `DecodingError.dataCorrupted` whose description is the reason code.
    public init(from decoder: any Decoder) throws {
        let stored = try StoredForm(from: decoder)
        do {
            try self.init(stored: stored)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// The stored form as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(storedForm)
        } catch {
            // Every stored value is finite (the initialiser refuses non-finite values and a step keeps them finite),
            // so JSONEncoder cannot fail here.
            preconditionFailure("Swarm.encoded: \(error)")
        }
    }

    /// Reads a swarm from its stored form and re-runs every rule.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.malformed(description)` for unreadable JSON,
    ///   missing or mistyped keys, a schema below 1, or any value that breaks a rule of the initialiser.
    public static func decode(_ data: Data) throws(SwarmError) -> Swarm {
        let decoder = JSONDecoder()
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        let stored: StoredForm
        do {
            stored = try decoder.decode(StoredForm.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        do {
            return try Swarm(stored: stored)
        } catch {
            throw .malformed(error.reasonCode)
        }
    }
}
