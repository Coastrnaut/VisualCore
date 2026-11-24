// MoonlitMechanismError — feature 431 (R02-G14-01) T-R02G1401-002 (FR-R02G1401-006, 009, 011; clarification Q5). The
// refusals of Moonlit Mechanism's rule kernel, each with a stable reason code `r02-g14.*` that the experience logs with
// the level id and the action. Feature 432 (R02-G14-02) T-R02G1402-002 adds the content pipeline's refusals,
// `generation` and `witness`.

/// A refusal of a Moonlit Mechanism level, action or event.
public enum MoonlitMechanismError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an unknown gear, re-seating the driver, a step other than ±1, a lamp step out of range,
    /// nothing to undo or redo; the payload names it.
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``MoonlitMechanismLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// No candidate of a manifest entry qualified within the candidate bound; the payload is the level number
    /// (feature 432).
    case generation(Int)
    /// A witness file is damaged, newer, edited or no longer replays; the payload names the part (feature 432).
    case witness(String)

    /// The stable reason code, `r02-g14.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g14.level"
        case .action: "r02-g14.action"
        case .stage: "r02-g14.stage"
        case .stale: "r02-g14.stale"
        case .newerSchema: "r02-g14.newer-schema"
        case .malformed: "r02-g14.malformed"
        case .generation: "r02-g14.generation"
        case .witness: "r02-g14.witness"
        }
    }
}
