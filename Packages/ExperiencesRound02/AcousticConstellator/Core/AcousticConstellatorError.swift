// AcousticConstellatorError — feature 421 (R02-G13-01) T-R02G1301-002 (FR-R02G1301-006, 009, 011; clarifications Q3,
// Q5). The refusals of Acoustic Constellator's rule kernel, each with a stable reason code `r02-g13.*` that the
// experience logs with the level id and the action. Feature 422 (R02-G13-02) T-R02G1302-002 adds the content
// pipeline's refusals, `generation` and `witness`.

/// A refusal of an Acoustic Constellator level, action or event.
public enum AcousticConstellatorError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an unknown star, a self link, an existing link, a link over the degree or link limit,
    /// removing a missing or fixed link, a nudge step other than ±1, nothing to undo or redo; the payload names it.
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``AcousticConstellatorLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// No candidate of a manifest entry qualified within the candidate bound; the payload is the level number
    /// (feature 422).
    case generation(Int)
    /// A witness file is damaged, newer, edited or no longer replays; the payload names the part (feature 422).
    case witness(String)

    /// The stable reason code, `r02-g13.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g13.level"
        case .action: "r02-g13.action"
        case .stage: "r02-g13.stage"
        case .stale: "r02-g13.stale"
        case .newerSchema: "r02-g13.newer-schema"
        case .malformed: "r02-g13.malformed"
        case .generation: "r02-g13.generation"
        case .witness: "r02-g13.witness"
        }
    }
}
