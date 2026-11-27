// MyceliumArchitectError — feature 511 (R02-G22-01) T-R02G2201-002 (FR-R02G2201-007, 010, 012; clarifications Q4,
// Q5). The refusals of Mycelium Architect's rule kernel, each with a stable reason code `r02-g22.*` that the
// experience logs with the level id and the action. Modelled on `BinaryGardensError` (feature 501).

/// A refusal of a Mycelium Architect level, action or event.
public enum MyceliumArchitectError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: a cell off the board or not empty, a count at its limit, nothing placed to clear, a
    /// direction already seeded or not seeded, a locked starting seed, nothing to undo or redo; the payload names it.
    case action(String)
    /// An arrangement action was asked for with no action left (running is still allowed).
    case budget
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``MyceliumArchitectLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g22.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g22.level"
        case .action: "r02-g22.action"
        case .budget: "r02-g22.budget"
        case .stage: "r02-g22.stage"
        case .stale: "r02-g22.stale"
        case .newerSchema: "r02-g22.newer-schema"
        case .malformed: "r02-g22.malformed"
        }
    }
}
