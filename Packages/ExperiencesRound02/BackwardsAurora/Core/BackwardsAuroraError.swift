// BackwardsAuroraError — feature 391 (R02-G10-01) T-R02G1001-002 (FR-R02G1001-006, 011; clarifications Q3, Q5). The
// refusals of Backwards Aurora's rule kernel, each with a stable reason code `r02-g10.*` that the experience logs with
// the level id and the action.

/// A refusal of a Backwards Aurora level, action or event.
public enum BackwardsAuroraError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an end outside the wave, start not before end, a section length outside the level's
    /// shortest … longest, nothing to undo or redo; the payload names it.
    case action(String)
    /// A reversal of a section that reads the same both ways (it would change nothing).
    case noop
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``BackwardsAuroraLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g10.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g10.level"
        case .action: "r02-g10.action"
        case .noop: "r02-g10.noop"
        case .stage: "r02-g10.stage"
        case .stale: "r02-g10.stale"
        case .newerSchema: "r02-g10.newer-schema"
        case .malformed: "r02-g10.malformed"
        }
    }
}
