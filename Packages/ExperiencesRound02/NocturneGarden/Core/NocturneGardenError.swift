// NocturneGardenError — feature 381 (R02-G09-01) T-R02G0901-002 (FR-R02G0901-006, 011; clarifications Q3, Q5). The
// refusals of Nocturne Garden's rule kernel, each with a stable reason code `r02-g09.*` that the experience logs with
// the level id and the action.

/// A refusal of a Nocturne Garden level, action or event.
public enum NocturneGardenError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an anchor outside the bed, a size or elevation out of range, a bloom number that does not
    /// exist, nothing to undo or redo; the payload names it.
    case action(String)
    /// A plant of a kind whose supply is used up.
    case supply
    /// An action that changes nothing (the same cell, size or elevation).
    case noop
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``NocturneGardenLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g09.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g09.level"
        case .action: "r02-g09.action"
        case .supply: "r02-g09.supply"
        case .noop: "r02-g09.noop"
        case .stage: "r02-g09.stage"
        case .stale: "r02-g09.stale"
        case .newerSchema: "r02-g09.newer-schema"
        case .malformed: "r02-g09.malformed"
        }
    }
}
