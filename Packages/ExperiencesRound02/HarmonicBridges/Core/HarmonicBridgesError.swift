// HarmonicBridgesError — feature 411 (R02-G12-01) T-R02G1201-002 (FR-R02G1201-006, 009, 011; clarifications Q3, Q5).
// The refusals of Harmonic Bridges' rule kernel, each with a stable reason code `r02-g12.*` that the experience logs with
// the level id and the action.

/// A refusal of a Harmonic Bridges level, action or event.
public enum HarmonicBridgesError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an unknown string, a peg outside 1 … 12, a locked string, nothing to undo or redo; the
    /// payload names it.
    case action(String)
    /// A tuning to the string's current peg (it would change nothing).
    case noop
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``HarmonicBridgesLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g12.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g12.level"
        case .action: "r02-g12.action"
        case .noop: "r02-g12.noop"
        case .stage: "r02-g12.stage"
        case .stale: "r02-g12.stale"
        case .newerSchema: "r02-g12.newer-schema"
        case .malformed: "r02-g12.malformed"
        }
    }
}
