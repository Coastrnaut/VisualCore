// SpatialControlError — feature 222 (R02-F22) T-R02F22-002 (FR-R02F22-007; clarification Q5). The refusals of the
// spatial controls (handles, picking, history, assistive steps), each with a stable reason code `r2-f22.*` that
// consumers log with their experience id.

/// A refusal of a spatial control request.
public enum SpatialControlError: Error, Equatable, Sendable {
    /// A viewport is not finite and positive.
    case viewport
    /// More handles than ``HandlePicker/maxHandles``.
    case handleLimit
    /// A parameter is outside its range; the payload names it.
    case parameter(String)
    /// A history depth is outside 1 … 1,000.
    case historyDepth
    /// A stored history has a schema newer than the current one; the payload is that schema.
    case newerSchema(Int)
    /// A stored history is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f22.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .viewport: "r2-f22.viewport"
        case .handleLimit: "r2-f22.handle-limit"
        case .parameter: "r2-f22.parameter"
        case .historyDepth: "r2-f22.history-depth"
        case .newerSchema: "r2-f22.newer-schema"
        case .malformed: "r2-f22.malformed"
        }
    }
}
