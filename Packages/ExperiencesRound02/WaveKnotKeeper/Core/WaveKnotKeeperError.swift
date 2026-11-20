// WaveKnotKeeperError — feature 321 (R02-G03-01) T-R02G0301-002 (FR-R02G0301-009; clarification Q5). The refusals of
// Wave Knot Keeper's rule kernel, each with a stable reason code `r02-g03.*` that the experience logs with the level id
// and tick.

/// A refusal of a Wave Knot Keeper level, move or event.
public enum WaveKnotKeeperError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// A move is refused (`range`, `bounds`, `coincident`, `crossing`, `tension`, `nothing-to-undo`,
    /// `nothing-to-redo`).
    case move(String)
    /// A move or event is not allowed in the current life stage.
    case stage
    /// A move named a previous fingerprint that is not the current one.
    case stale
    /// The move allowance is spent.
    case allowance
    /// A stored level has a schema newer than ``WaveKnotKeeperLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g03.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g03.level"
        case .move: "r02-g03.move"
        case .stage: "r02-g03.stage"
        case .stale: "r02-g03.stale"
        case .allowance: "r02-g03.allowance"
        case .newerSchema: "r02-g03.newer-schema"
        case .malformed: "r02-g03.malformed"
        }
    }
}
