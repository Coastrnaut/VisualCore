// LissajousLabyrinthError — feature 311 (R02-G02-01) T-R02G0201-002 (FR-R02G0201-009; clarification Q5). The refusals of
// Lissajous Labyrinth's rule kernel, each with a stable reason code `r02-g02.*` that the experience logs with the level id
// and tick.

/// A refusal of a Lissajous Labyrinth level, action or event.
public enum LissajousLabyrinthError: Error, Equatable, Sendable {
    /// A level value is outside its range; the payload names it.
    case level(String)
    /// An action is refused (`range`, `no-change`, `not-coprime`, `nothing-to-undo`, `nothing-to-redo`).
    case move(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// The action allowance is spent.
    case allowance
    /// A stored level has a schema newer than ``LissajousLabyrinthLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g02.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g02.level"
        case .move: "r02-g02.move"
        case .stage: "r02-g02.stage"
        case .stale: "r02-g02.stale"
        case .allowance: "r02-g02.allowance"
        case .newerSchema: "r02-g02.newer-schema"
        case .malformed: "r02-g02.malformed"
        }
    }
}
