// FacetedForgeError — feature 371 (R02-G08-01) T-R02G0801-002 (FR-R02G0801-011; clarification Q5). The refusals of
// Faceted Forge's rule kernel, each with a stable reason code `r02-g08.*` that the experience logs with the level id
// and cut.
// Feature 372 (R02-G08-02) T-R02G0802-002 (FR-R02G0802-006; clarification Q5): `generation` and `witness`.

/// A refusal of a Faceted Forge level, action or event.
public enum FacetedForgeError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused (`range`, `overflow`, `nothing-to-undo`, `nothing-to-redo`).
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// The cut's plane does not pass through the piece's interior (no corner strictly on one of its sides).
    case miss
    /// A stored level has a schema newer than ``FacetedForgeLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// No candidate of the manifest level (the payload is its number) was certified within 256 candidates (feature 372).
    case generation(Int)
    /// A witness is damaged, edited or no longer replays; the payload names the part (feature 372).
    case witness(String)

    /// The stable reason code, `r02-g08.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g08.level"
        case .action: "r02-g08.action"
        case .stage: "r02-g08.stage"
        case .stale: "r02-g08.stale"
        case .miss: "r02-g08.miss"
        case .newerSchema: "r02-g08.newer-schema"
        case .malformed: "r02-g08.malformed"
        case .generation: "r02-g08.generation"
        case .witness: "r02-g08.witness"
        }
    }
}
