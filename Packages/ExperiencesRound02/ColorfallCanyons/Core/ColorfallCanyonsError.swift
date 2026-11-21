// ColorfallCanyonsError — feature 341 (R02-G05-01) T-R02G0501-002 (FR-R02G0501-011; clarification Q5). The refusals of
// Colorfall Canyons's rule kernel, each with a stable reason code `r02-g05.*` that the experience logs with the level id
// and tick.

/// A refusal of a Colorfall Canyons level, action or event.
public enum ColorfallCanyonsError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused (`range`, `not-carvable`, `nothing-to-undo`, `nothing-to-redo`).
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// The action budget is spent.
    case budget
    /// A stored level has a schema newer than ``ColorfallCanyonsLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g05.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g05.level"
        case .action: "r02-g05.action"
        case .stage: "r02-g05.stage"
        case .stale: "r02-g05.stale"
        case .budget: "r02-g05.budget"
        case .newerSchema: "r02-g05.newer-schema"
        case .malformed: "r02-g05.malformed"
        }
    }
}
