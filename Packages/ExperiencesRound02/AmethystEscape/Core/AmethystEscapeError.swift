// AmethystEscapeError — feature 361 (R02-G07-01) T-R02G0701-002 (FR-R02G0701-011; clarification Q5). The refusals of
// Amethyst Escape's rule kernel, each with a stable reason code `r02-g07.*` that the experience logs with the level id and
// move.

/// A refusal of an Amethyst Escape level, action or event.
public enum AmethystEscapeError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused (`range`, `nothing-to-undo`, `nothing-to-redo`).
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// The pearl cannot advance: no aperture is lined up under it and a radial wall stands ahead.
    case stuck
    /// A stored level has a schema newer than ``AmethystEscapeLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g07.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g07.level"
        case .action: "r02-g07.action"
        case .stage: "r02-g07.stage"
        case .stale: "r02-g07.stale"
        case .stuck: "r02-g07.stuck"
        case .newerSchema: "r02-g07.newer-schema"
        case .malformed: "r02-g07.malformed"
        }
    }
}
