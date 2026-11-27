// BinaryGardensError — feature 501 (R02-G21-01) T-R02G2101-002 (FR-R02G2101-006, 009, 011; clarification Q5). The
// refusals of Binary Gardens' rule kernel, each with a stable reason code `r02-g21.*` that the experience logs with the
// level id and the action. Modelled on `MushroomWeatherError` (feature 491) and `MicroscopicAuroraError` (feature 481).

/// A refusal of a Binary Gardens level, action or event.
public enum BinaryGardensError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: a star, ring, phase, luminosity or tilt out of range, a locked control, an unchanged
    /// value, an arrangement that breaks the stars' minimum separation, nothing to undo or redo; the payload names it.
    case action(String)
    /// An arrangement action was asked for with no action left (running is still allowed).
    case budget
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``BinaryGardensLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g21.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g21.level"
        case .action: "r02-g21.action"
        case .budget: "r02-g21.budget"
        case .stage: "r02-g21.stage"
        case .stale: "r02-g21.stale"
        case .newerSchema: "r02-g21.newer-schema"
        case .malformed: "r02-g21.malformed"
        }
    }
}
