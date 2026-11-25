// CelestialEclipseLabError — feature 461 (R02-G17-01) T-R02G1701-002 (FR-R02G1701-006, 009, 011; clarifications Q2,
// Q4). The refusals of Celestial Eclipse Lab's rule kernel, each with a stable reason code `r02-g17.*` that the
// experience logs with the level id and the action. Modelled on `StarlitCartoucheError` (feature 451).
// Feature 462 (R02-G17-02) T-R02G1702-002 (FR-R02G1702-006; clarification Q5) adds `generation` and `witness`.

/// A refusal of a Celestial Eclipse Lab level, action or event.
public enum CelestialEclipseLabError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an unknown or fixed body, an offset outside the period or equal to the current one,
    /// nothing to undo or redo; the payload names it.
    case action(String)
    /// A phase change was asked for with no action left (the run is still allowed).
    case budget
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``CelestialEclipseLabLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// No candidate of manifest entry `number` qualified within the generator's candidate bound.
    case generation(Int)
    /// A witness file is damaged, newer than its schema or no longer replays; the payload describes it.
    case witness(String)

    /// The stable reason code, `r02-g17.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g17.level"
        case .action: "r02-g17.action"
        case .budget: "r02-g17.budget"
        case .stage: "r02-g17.stage"
        case .stale: "r02-g17.stale"
        case .newerSchema: "r02-g17.newer-schema"
        case .malformed: "r02-g17.malformed"
        case .generation: "r02-g17.generation"
        case .witness: "r02-g17.witness"
        }
    }
}
