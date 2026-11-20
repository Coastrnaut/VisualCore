// TerrainError — feature 218 (R02-F18) T-R02F18-002 (FR-R02F18-008; clarification Q5). The refusals of terrain levels of
// detail, piece meshes and terrain settings, each with a stable reason code `r2-f18.*` that consumers log with their
// experience id, seed and tick.

/// A refusal of a terrain request.
public enum TerrainError: Error, Equatable, Sendable {
    /// The number of pieces per side is outside 1 … 64; the payload is the value given.
    case terrainSize(Int)
    /// The base cells per piece side are not a power of two in 4 … 128; the payload is the value given.
    case pieceSize(Int)
    /// The level count is outside 1 … log₂(piece cells); the payload is the value given.
    case levelCount(Int)
    /// The cell size or the distance per level is not finite and positive.
    case levelDistance
    /// The vertex budget is outside 1 … 4,194,304, or even the coarsest tiling exceeds it; the payload is the budget
    /// given or the vertices the coarsest tiling needs.
    case budget(Int)
    /// The viewpoint is not finite.
    case viewpoint
    /// Stored settings have a schema newer than ``TerrainSettings/schema``; the payload is that schema.
    case newerSchema(Int)
    /// Stored settings are damaged or incomplete; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f18.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .terrainSize: "r2-f18.terrain-size"
        case .pieceSize: "r2-f18.piece-size"
        case .levelCount: "r2-f18.level-count"
        case .levelDistance: "r2-f18.level-distance"
        case .budget: "r2-f18.budget"
        case .viewpoint: "r2-f18.viewpoint"
        case .newerSchema: "r2-f18.newer-schema"
        case .malformed: "r2-f18.malformed"
        }
    }
}
