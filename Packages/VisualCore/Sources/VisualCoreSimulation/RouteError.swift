// RouteError — feature 216 (R02-F16) T-R02F16-002 (FR-R02F16-008; clarification Q5). The refusals of the grid, graph and
// route-solver toolkit, each with a stable reason code `r2-f16.*` that consumers log with their experience id, seed and
// tick. Running out of budget is a result ("gave up"), not a refusal.

/// A refusal of a graph, search, cut, match or certificate request.
public enum RouteError: Error, Equatable, Sendable {
    /// A graph, grid or schedule has no nodes, cells or steps.
    case emptyGraph
    /// A size limit is exceeded; the payload names it.
    case graphLimit(String)
    /// A node id is outside the graph; the payload is the id.
    case nodeRange(Int)
    /// An edge cost is negative or above ``RouteGraph/maxCost``; the payload is the cost.
    case negativeCost(Int)
    /// A start or goal cell is blocked or closed; the payload is the node.
    case blockedEndpoint(Int)
    /// A schedule's size is outside its limits or does not fit the graph.
    case scheduleLimit
    /// A pattern has more than ``SubgraphMatcher/maxPatternNodes`` nodes; the payload is its node count.
    case patternLimit(Int)
    /// A budget or limit argument is outside its range; the payload is the value given.
    case budget(Int)
    /// A certificate failed a check; the payload names the rule.
    case certificateRejected(String)
    /// A stored certificate has a schema newer than ``SolverCertificate/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored certificate is damaged or incomplete; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f16.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .emptyGraph: "r2-f16.empty-graph"
        case .graphLimit: "r2-f16.graph-limit"
        case .nodeRange: "r2-f16.node-range"
        case .negativeCost: "r2-f16.negative-cost"
        case .blockedEndpoint: "r2-f16.blocked-endpoint"
        case .scheduleLimit: "r2-f16.schedule-limit"
        case .patternLimit: "r2-f16.pattern-limit"
        case .budget: "r2-f16.budget"
        case .certificateRejected: "r2-f16.certificate-rejected"
        case .newerSchema: "r2-f16.newer-schema"
        case .malformed: "r2-f16.malformed"
        }
    }
}
