// ContentError — feature 224 (R02-F24) T-R02F24-002 (FR-R02F24-006; clarification Q5). The refusals of puzzle catalogs
// and tutorial contracts, each with a stable reason code `r2-f24.*` that consumers log with their experience id. What
// a checker finds in a catalog is reported as issues, not thrown.

/// A refusal of a catalog or tutorial request.
public enum ContentError: Error, Equatable, Sendable {
    /// A plan, stage or catalog value is outside its range; the payload names it.
    case plan(String)
    /// A stage could not be filled; the payloads are the stage index and the generator calls made.
    case planFailed(stage: Int, calls: Int)
    /// A finished catalog breaks its progression rule at this position.
    case progression(Int)
    /// A tutorial contract, step or progress value is refused; the payload names it.
    case tutorial(String)
    /// A stored form has a schema newer than the current one; the payload is that schema.
    case newerSchema(Int)
    /// A stored form is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// A stored catalog's digest does not match its entries.
    case edited

    /// The stable reason code, `r2-f24.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .plan: "r2-f24.plan"
        case .planFailed: "r2-f24.plan-failed"
        case .progression: "r2-f24.progression"
        case .tutorial: "r2-f24.tutorial"
        case .newerSchema: "r2-f24.newer-schema"
        case .malformed: "r2-f24.malformed"
        case .edited: "r2-f24.edited"
        }
    }
}
