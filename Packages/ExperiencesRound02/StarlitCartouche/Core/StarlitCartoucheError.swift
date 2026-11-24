// StarlitCartoucheError — feature 451 (R02-G16-01) T-R02G1601-002 (FR-R02G1601-006, 009, 011; clarifications Q2, Q5).
// The refusals of Starlit Cartouche's rule kernel, each with a stable reason code `r02-g16.*` that the experience logs
// with the level id and the action. Modelled on `VoxelOrigamiError` (feature 441).

/// A refusal of a Starlit Cartouche level, action or event.
public enum StarlitCartoucheError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an unknown star, the ship's own star, no corridor, a wait out of range, stars out of range,
    /// nothing to undo or redo; the payload names it.
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``StarlitCartoucheLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r02-g16.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g16.level"
        case .action: "r02-g16.action"
        case .stage: "r02-g16.stage"
        case .stale: "r02-g16.stale"
        case .newerSchema: "r02-g16.newer-schema"
        case .malformed: "r02-g16.malformed"
        }
    }
}
