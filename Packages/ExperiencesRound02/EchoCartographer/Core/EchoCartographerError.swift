// EchoCartographerError — feature 401 (R02-G11-01) T-R02G1101-002 (FR-R02G1101-006, 011; clarifications Q3, Q5). The
// refusals of Echo Cartographer's rule kernel, each with a stable reason code `r02-g11.*` that the experience logs with
// the level id and the action.

/// A refusal of an Echo Cartographer level, action or event.
public enum EchoCartographerError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: a cell outside the chamber, a pulse from a cell not known open, a claim on a known wall,
    /// a ninth marker, nothing to undo or redo; the payload names it.
    case action(String)
    /// A claim whose cell is within the tolerance only of beacons already located (it would change nothing).
    case noop
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``EchoCartographerLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g11.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g11.level"
        case .action: "r02-g11.action"
        case .noop: "r02-g11.noop"
        case .stage: "r02-g11.stage"
        case .stale: "r02-g11.stale"
        case .newerSchema: "r02-g11.newer-schema"
        case .malformed: "r02-g11.malformed"
        }
    }
}
