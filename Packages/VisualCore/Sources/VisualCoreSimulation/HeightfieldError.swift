// HeightfieldError — feature 217 (R02-F17) T-R02F17-002 (FR-R02F17-009; clarification Q5). The refusals of the
// heightfield transport model, each with a stable reason code `r2-f17.*` that consumers log with their experience id,
// seed and tick. What a frame step did (sub-steps, dropped time, clamps) is reported, not thrown.

/// A refusal of a heightfield request.
public enum HeightfieldError: Error, Equatable, Sendable {
    /// A side is outside 4 … 1,024 or the grid has more than 262,144 cells.
    case gridSize
    /// A cell index is outside the grid; the payload is the index.
    case cellRange(Int)
    /// An amount is negative, or a cell or a grid total would pass 2⁴⁰ quanta.
    case amountLimit
    /// A step time is negative or not finite.
    case invalidTime
    /// A parameter is outside its range; the payload names it.
    case invalidParameter(String)
    /// A dye channel (or channel count) is outside its range; the payload is the value given.
    case dyeChannel(Int)
    /// A stored state has a schema newer than ``Heightfield/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored state is damaged or inconsistent; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f17.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .gridSize: "r2-f17.grid-size"
        case .cellRange: "r2-f17.cell-range"
        case .amountLimit: "r2-f17.amount-limit"
        case .invalidTime: "r2-f17.invalid-time"
        case .invalidParameter: "r2-f17.invalid-parameter"
        case .dyeChannel: "r2-f17.dye-channel"
        case .newerSchema: "r2-f17.newer-schema"
        case .malformed: "r2-f17.malformed"
        }
    }
}
