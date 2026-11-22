// ChronoConstellatorError — feature 351 (R02-G06-01) T-R02G0601-002 (FR-R02G0601-011; clarification Q5). The refusals of
// Chrono Constellator's rule kernel, each with a stable reason code `r02-g06.*` that the experience logs with the level id
// and tick.
// Feature 352 (R02-G06-02) T-R02G0602-002 (FR-R02G0602-006; clarification Q5): `generation` and `witness`.

/// A refusal of a Chrono Constellator level, action or event.
public enum ChronoConstellatorError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused (`range`, `not-at-start`, `same-phase`, `overlap`, `no-hold`, `nothing-to-undo`,
    /// `nothing-to-redo`).
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// The edit would bring the edits in use above the level's budget.
    case budget
    /// A stored level has a schema newer than ``ChronoConstellatorLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// No candidate of the manifest level (the payload is its number) met its band within 512 candidates (feature 352).
    case generation(Int)
    /// A witness is damaged, edited or no longer replays; the payload names the part (feature 352).
    case witness(String)

    /// The stable reason code, `r02-g06.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g06.level"
        case .action: "r02-g06.action"
        case .stage: "r02-g06.stage"
        case .stale: "r02-g06.stale"
        case .budget: "r02-g06.budget"
        case .newerSchema: "r02-g06.newer-schema"
        case .malformed: "r02-g06.malformed"
        case .generation: "r02-g06.generation"
        case .witness: "r02-g06.witness"
        }
    }
}
