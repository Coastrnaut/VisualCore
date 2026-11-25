// ApsidesWorkshopError — feature 471 (R02-G18-01) T-R02G1801-002 (FR-R02G1801-006, 009, 011; clarification Q4). The
// refusals of Apsides Workshop's rule kernel, each with a stable reason code `r02-g18.*` that the experience logs with
// the level id and the action. Modelled on `CelestialEclipseLabError` (feature 461).

/// A refusal of an Apsides Workshop level, action or event.
public enum ApsidesWorkshopError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: a tuning out of range, unchanged or making the orbit invalid, nothing to undo or redo;
    /// the payload names it.
    case action(String)
    /// A tuning was asked for with no action left (playing is still allowed).
    case budget
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``ApsidesWorkshopLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g18.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g18.level"
        case .action: "r02-g18.action"
        case .budget: "r02-g18.budget"
        case .stage: "r02-g18.stage"
        case .stale: "r02-g18.stale"
        case .newerSchema: "r02-g18.newer-schema"
        case .malformed: "r02-g18.malformed"
        }
    }
}
