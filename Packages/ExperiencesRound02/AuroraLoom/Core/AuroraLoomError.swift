// AuroraLoomError — feature 301 (R02-G01-01) T-R02G0101-002 (FR-R02G0101-009; clarification Q5). The refusals of Aurora
// Loom's rule kernel, each with a stable reason code `r02-g01.*` that the experience logs with the level id and tick.

/// A refusal of an Aurora Loom level, move or event.
public enum AuroraLoomError: Error, Equatable, Sendable {
    /// A level value is outside its range; the payload names it.
    case level(String)
    /// A move is refused (out of range or no change); the payload names why.
    case move(String)
    /// An action is not allowed in the current life stage.
    case stage
    /// A move named a previous fingerprint that is not the current one.
    case stale
    /// The move allowance is spent.
    case allowance
    /// A stored level has a schema newer than ``AuroraLoomLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g01.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g01.level"
        case .move: "r02-g01.move"
        case .stage: "r02-g01.stage"
        case .stale: "r02-g01.stale"
        case .allowance: "r02-g01.allowance"
        case .newerSchema: "r02-g01.newer-schema"
        case .malformed: "r02-g01.malformed"
        }
    }
}
