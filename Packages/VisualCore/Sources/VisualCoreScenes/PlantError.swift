// PlantError — feature 219 (R02-F19) T-R02F19-002 (FR-R02F19-007; clarification Q5). The refusals of the grammar,
// turtle, shapes and scatter, each with a stable reason code `r2-f19.*` that consumers log with their experience id,
// seed and tick.

/// A refusal of a vegetation request.
public enum PlantError: Error, Equatable, Sendable {
    /// The generation count is outside 0 … ``PlantGrammar/maxGenerations``; the payload is the value given.
    case generations(Int)
    /// A word would pass ``PlantGrammar/maxWord`` symbols; the payload is the length it would reach.
    case wordLimit(Int)
    /// A rule is invalid (duplicate predecessor, too many rules or successors, an empty or too long word); the payload
    /// says which.
    case rule(String)
    /// A successor weight is not finite and positive; the payload names the rule.
    case weight(String)
    /// The word's branch brackets do not balance.
    case brackets
    /// A turtle setting (angle, step, radius, radius factor) is outside its range; the payload names it.
    case turtleParameter(String)
    /// A petal, cap or stem parameter is outside its range; the payload names it.
    case shapeParameter(String)
    /// The word would draw more than ``PlantGrammar/maxBranches`` branches; the payload is the count it reached.
    case branchLimit(Int)
    /// The scatter area is empty or not finite.
    case scatterArea
    /// A scatter setting (spacing, count, scale, variants) is outside its range; the payload names it.
    case scatterParameter(String)
    /// A stored grammar has a schema newer than ``PlantGrammar/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored grammar is damaged or incomplete; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f19.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .generations: "r2-f19.generations"
        case .wordLimit: "r2-f19.word-limit"
        case .rule: "r2-f19.rule"
        case .weight: "r2-f19.weight"
        case .brackets: "r2-f19.brackets"
        case .turtleParameter: "r2-f19.turtle-parameter"
        case .shapeParameter: "r2-f19.shape-parameter"
        case .branchLimit: "r2-f19.branch-limit"
        case .scatterArea: "r2-f19.scatter-area"
        case .scatterParameter: "r2-f19.scatter-parameter"
        case .newerSchema: "r2-f19.newer-schema"
        case .malformed: "r2-f19.malformed"
        }
    }
}
