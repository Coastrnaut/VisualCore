// MushroomWeatherError — feature 491 (R02-G20-01) T-R02G2001-002 (FR-R02G2001-006, 009, 011; clarification Q5). The
// refusals of Mushroom Weather's rule kernel, each with a stable reason code `r02-g20.*` that the experience logs with
// the level id and the action. Modelled on `MicroscopicAuroraError` (feature 481). Feature 492 (R02-G20-02)
// T-R02G2002-002 (FR-R02G2002-006; clarification Q5) adds `generation` and `witness`.

/// A refusal of a Mushroom Weather level, action or event.
public enum MushroomWeatherError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: out of range, unchanged, on a forbidden cell, a removal of an empty slot, nothing to undo
    /// or redo; the payload names it.
    case action(String)
    /// An arrangement action was asked for with no action left (running is still allowed).
    case budget
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``MushroomWeatherLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// No candidate within the generator's bound qualified for a manifest entry; the payload is its level number.
    case generation(Int)
    /// A stored witness is damaged, no longer replays or disagrees with its level; the payload names the problem.
    case witness(String)

    /// The stable reason code, `r02-g20.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g20.level"
        case .action: "r02-g20.action"
        case .budget: "r02-g20.budget"
        case .stage: "r02-g20.stage"
        case .stale: "r02-g20.stale"
        case .newerSchema: "r02-g20.newer-schema"
        case .malformed: "r02-g20.malformed"
        case .generation: "r02-g20.generation"
        case .witness: "r02-g20.witness"
        }
    }
}
