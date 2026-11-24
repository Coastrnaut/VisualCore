// VoxelOrigamiError — feature 441 (R02-G15-01) T-R02G1501-002 (FR-R02G1501-006, 009, 011; clarifications Q2, Q5). The
// refusals of Voxel Origami's rule kernel, each with a stable reason code `r02-g15.*` that the experience logs with the
// level id and the action. Modelled on `MoonlitMechanismError` (feature 431). Feature 442 (R02-G15-02) T-R02G1502-002 adds
// the content pipeline's refusals, `generation` and `witness`.

/// A refusal of a Voxel Origami level, action or event.
public enum VoxelOrigamiError: Error, Equatable, Sendable {
    /// A level value is outside its range or breaks a level rule; the payload names it.
    case level(String)
    /// An action is refused: an unknown hinge, a step other than ±1, a hinge with nothing that would move, nothing to
    /// undo or redo; the payload names it.
    case action(String)
    /// An action or event is not allowed in the current life stage.
    case stage
    /// An action named a previous fingerprint that is not the current one.
    case stale
    /// A stored level has a schema newer than ``VoxelOrigamiLevel/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored level or trace is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// No candidate of a manifest entry qualified within the candidate bound; the payload is the level number
    /// (feature 442).
    case generation(Int)
    /// A witness file is damaged, newer, edited or no longer replays; the payload names the part (feature 442).
    case witness(String)

    /// The stable reason code, `r02-g15.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .level: "r02-g15.level"
        case .action: "r02-g15.action"
        case .stage: "r02-g15.stage"
        case .stale: "r02-g15.stale"
        case .newerSchema: "r02-g15.newer-schema"
        case .malformed: "r02-g15.malformed"
        case .generation: "r02-g15.generation"
        case .witness: "r02-g15.witness"
        }
    }
}
