// MicroscopicAuroraError — feature 481 (R02-G19-01) T-R02G1901-002 (FR-R02G1901-006, 009, 011; clarification Q5). The
// refusals of Microscopic Aurora's rule kernel, each with a stable reason code `r02-g19.*` that the experience logs
// with the level id and the action. Modelled on `ApsidesWorkshopError` (feature 471).

/// A refusal of a Microscopic Aurora level, action or event.
public enum MicroscopicAuroraError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: a placement out of range, unchanged or on an occupied or outside cell, a removal of an
    /// empty slot, nothing to undo or redo; the payload names it.
    case action(String)
    /// A placement or removal was asked for with no action left (playing is still allowed).
    case budget
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``MicroscopicAuroraLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g19.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g19.level"
        case .action: "r02-g19.action"
        case .budget: "r02-g19.budget"
        case .stage: "r02-g19.stage"
        case .stale: "r02-g19.stale"
        case .newerSchema: "r02-g19.newer-schema"
        case .malformed: "r02-g19.malformed"
        }
    }
}
