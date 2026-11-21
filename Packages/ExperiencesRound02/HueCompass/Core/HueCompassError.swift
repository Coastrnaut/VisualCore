// HueCompassError — feature 331 (R02-G04-01) T-R02G0401-002 (FR-R02G0401-010; clarification Q5). The refusals of Hue
// Compass's rule kernel, each with a stable reason code `r02-g04.*` that the experience logs with the level id and tick.

/// A refusal of a Hue Compass level, action or event.
public enum HueCompassError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused (`range`, `nothing-to-undo`, `nothing-to-redo`).
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// The allowance is spent.
    case allowance
    /// A stored level has a schema newer than ``HueCompassLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g04.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g04.level"
        case .action: "r02-g04.action"
        case .stage: "r02-g04.stage"
        case .stale: "r02-g04.stale"
        case .allowance: "r02-g04.allowance"
        case .newerSchema: "r02-g04.newer-schema"
        case .malformed: "r02-g04.malformed"
        }
    }
}
