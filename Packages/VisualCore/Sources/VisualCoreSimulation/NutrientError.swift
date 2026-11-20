// NutrientError — feature 221 (R02-F21) T-R02F21-002 (FR-R02F21-008; clarification Q5). The refusals of the nutrient
// field, its sources, bands and growth network, each with a stable reason code `r2-f21.*` that consumers log with their
// experience id, seed and tick. What a frame step did (sub-steps, dropped time, capped and short amounts) is reported,
// not thrown.

/// A refusal of a nutrient field request.
public enum NutrientError: Error, Equatable, Sendable {
    /// A side is outside 2 … 512, or the grid has more than 262,144 cells.
    case gridSize
    /// A channel (or channel count) is outside its range; the payload is the value given.
    case channel(Int)
    /// A cell index is outside the grid; the payload is the index.
    case cellRange(Int)
    /// An amount is negative, or a cell or a channel's grid total would pass 2⁴⁰ quanta.
    case amountLimit
    /// A rate, band or other parameter is outside its range; the payload names it.
    case parameter(String)
    /// A frame time is negative or not finite.
    case time
    /// More than 256 sources and sinks.
    case sourceLimit
    /// A growth network setting or seed is refused; the payload names the reason.
    case growth(String)
    /// A stored field has a schema newer than ``NutrientField/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored field is damaged, breaks a rule or does not balance; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f21.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .gridSize: "r2-f21.grid-size"
        case .channel: "r2-f21.channel"
        case .cellRange: "r2-f21.cell-range"
        case .amountLimit: "r2-f21.amount-limit"
        case .parameter: "r2-f21.parameter"
        case .time: "r2-f21.time"
        case .sourceLimit: "r2-f21.source-limit"
        case .growth: "r2-f21.growth"
        case .newerSchema: "r2-f21.newer-schema"
        case .malformed: "r2-f21.malformed"
        }
    }
}
