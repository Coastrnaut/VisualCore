// SwarmError — feature 220 (R02-F20) T-R02F20-002 (FR-R02F20-006; clarification Q5). The refusals of the swarm,
// neighbourhood grid, magnetic field and density raster, each with a stable reason code `r2-f20.*` that consumers log
// with their experience id, seed and tick.

/// A refusal of a swarm, neighbourhood grid, magnetic field or density raster request.
public enum SwarmError: Error, Equatable, Sendable {
    /// More agents than allowed (65,536); the payload is the count given.
    case agentLimit(Int)
    /// The bounds are not valid (non-finite, or a minimum not below its maximum).
    case bounds
    /// A step length is not finite or outside 0 < h ≤ 0.1.
    case step
    /// A parameter is outside its range; the payload names it.
    case parameter(String)
    /// A magnetic field or pole value is outside its range; the payload names it.
    case field(String)
    /// A raster side is outside 1 … 1,024 or the raster has more than 1,048,576 cells.
    case rasterSize
    /// A stored swarm has a schema newer than ``Swarm/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored swarm is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f20.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .agentLimit: "r2-f20.agent-limit"
        case .bounds: "r2-f20.bounds"
        case .step: "r2-f20.step"
        case .parameter: "r2-f20.parameter"
        case .field: "r2-f20.field"
        case .rasterSize: "r2-f20.raster-size"
        case .newerSchema: "r2-f20.newer-schema"
        case .malformed: "r2-f20.malformed"
        }
    }
}
