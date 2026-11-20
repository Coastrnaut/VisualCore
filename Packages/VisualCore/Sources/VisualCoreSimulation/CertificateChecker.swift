// CertificateChecker — feature 216 (R02-F16) T-R02F16-007 (FR-R02F16-006; SC-R02F16-005; clarifications Q2–Q4; research R4, R5, R7).
// Checks a `SolverCertificate` against its graph (and schedule or pattern) without running any solver. Every check is
// O(V + E) of the graph plus the certificate's size, apart from the cut's separation search (a breadth-first search
// over the graph with the cut removed). A failed rule throws `RouteError.certificateRejected(<rule>)` with one of these
// stable rule names:
//
// Any kind
// - `not-checkable` — `.exhausted` records an exhaustive search; it is never accepted.
// - `needs-schedule` — a timed kind given to an overload without a schedule.
// - `needs-pattern` — `.placement` given to an overload without a pattern.
//
// Route (`.route`). The route's cost is the sum over its steps of `cheapestCost(from:to:)` (the cheapest parallel edge).
// - `empty-route` — no nodes.
// - `node-range` — a route node is outside the graph.
// - `missing-edge` — two consecutive nodes have no edge between them.
// - `cost-mismatch` — the stated cost is not the route's cost.
// - `potentials-size` — not exactly one potential per graph node.
// - `potential-start` — π(start) ≠ 0.
// - `potential-edge` — some edge u → v of the graph has π(v) > π(u) + c.
// - `potential-goal` — π(goal) ≠ the stated cost.
// A breadth-first route states its cost in steps with step potentials. So when the costed check fails and the stated
// cost equals the number of steps, the potential rules are checked again with every edge cost taken as 1 (a fewest-steps
// certificate); the certificate is accepted if that passes and otherwise rejected with the costed check's rule.
//
// Unreachable (`.unreachable`)
// - `node-range` — the start, the goal or a member is outside the graph.
// - `unsorted` — the members are not strictly increasing.
// - `start-missing` — the start is not a member.
// - `goal-present` — the goal is a member.
// - `not-closed` — an edge leaves the set.
//
// Timed route (`.timedRoute`, schedule overload)
// - `empty-route` — no states.
// - `node-range` — a state's node is outside the graph.
// - `closed-state` — a state is not open in the schedule.
// - `time-step` — consecutive times do not increase by exactly 1.
// - `missing-edge` — the node changes without an edge.
// - `wait-forbidden` — the node stays the same while waiting is not allowed (a self-loop edge counts as a move).
//
// Timed unreachable (`.timedUnreachable`, schedule overload)
// - `node-range` — the start, the goal or a member's node is outside the graph, or a member's time or the start time
//   is outside the schedule.
// - `unsorted` — the members are not strictly increasing by time, then node.
// - `start-missing` — (start, startTime) is not a member.
// - `goal-present` — a member's node is the goal.
// - `not-closed` — for a member (v, t) with t + 1 < steps, an open (w, t + 1) for an edge v → w, or the open (v, t + 1)
//   when waiting is allowed, is not a member.
//
// Cut (`.cut`). Edges count as units: k copies of u → v need k parallel edges u → v.
// - `node-range` — the source or sink is outside the graph.
// - `unsorted` — the cut edges are not in non-decreasing order.
// - `count-mismatch` — the number of routes differs from the number of cut edges.
// - `route-invalid` — a route does not start at the source, end at the sink and follow edges.
// - `not-disjoint` — the routes together use some edge u → v more often than the graph has parallel edges u → v.
// - `edge-missing` — the cut names an edge more often than the graph has it.
// - `not-separating` — the sink is still reachable from the source with the cut edges removed.
// The routes' stated costs are not checked; a cut route is a unit-capacity route.
//
// Placement (`.placement`, pattern overload). Pattern edges are read undirected and self-loops are ignored.
// - `size-mismatch` — not exactly one graph node per pattern node.
// - `node-range` — a mapped node is outside the graph.
// - `not-injective` — two pattern nodes map to the same graph node.
// - `missing-edge` — a pattern edge maps to a pair that is not `adjacent` in the graph.

/// Verifies solver certificates independently of the solvers that produced them.
public enum CertificateChecker {
    /// Verifies a route, unreachable or cut certificate in `graph`; timed kinds are refused with `needs-schedule`,
    /// placements with `needs-pattern` and `.exhausted` with `not-checkable` (rules in the file header).
    public static func verify(_ certificate: SolverCertificate, in graph: RouteGraph) throws(RouteError) {
        switch certificate {
        case let .route(path, potentials):
            try verifyRoute(path, potentials: potentials, in: graph)
        case let .unreachable(start, goal, reachable):
            try verifyUnreachable(start: start, goal: goal, reachable: reachable, in: graph)
        case .timedRoute, .timedUnreachable:
            throw .certificateRejected("needs-schedule")
        case let .cut(source, sink, edges, routes):
            try verifyCut(source: source, sink: sink, edges: edges, routes: routes, in: graph)
        case .placement:
            throw .certificateRejected("needs-pattern")
        case .exhausted:
            throw .certificateRejected("not-checkable")
        }
    }

    /// Verifies a certificate in `graph` with `schedule`: timed kinds are checked against the schedule, every other kind
    /// as by ``verify(_:in:)`` (rules in the file header).
    public static func verify(_ certificate: SolverCertificate, in graph: RouteGraph,
                              schedule: RouteSchedule) throws(RouteError) {
        switch certificate {
        case let .timedRoute(states, allowWaiting):
            try verifyTimedRoute(states, allowWaiting: allowWaiting, in: graph, schedule: schedule)
        case let .timedUnreachable(start, goal, startTime, allowWaiting, reachable):
            try verifyTimedUnreachable(start: start, goal: goal, startTime: startTime, allowWaiting: allowWaiting,
                                       reachable: reachable, in: graph, schedule: schedule)
        default:
            try verify(certificate, in: graph)
        }
    }

    /// Verifies a placement of `pattern` in `graph`; every other kind is checked as by ``verify(_:in:)`` (rules in the
    /// file header).
    public static func verify(_ certificate: SolverCertificate, pattern: RouteGraph,
                              in graph: RouteGraph) throws(RouteError) {
        switch certificate {
        case let .placement(map):
            try verifyPlacement(map, pattern: pattern, in: graph)
        default:
            try verify(certificate, in: graph)
        }
    }

    // MARK: Route

    private static func verifyRoute(_ path: RoutePath, potentials: [Int], in graph: RouteGraph) throws(RouteError) {
        let nodes = path.nodes
        guard !nodes.isEmpty else { throw .certificateRejected("empty-route") }
        for node in nodes where !graph.contains(node) { throw .certificateRejected("node-range") }
        var cost = 0
        var costOverflow = false
        for i in 1..<max(1, nodes.count) {
            guard let c = graph.cheapestCost(from: nodes[i - 1], to: nodes[i]) else {
                throw .certificateRejected("missing-edge")
            }
            let (sum, overflow) = cost.addingReportingOverflow(c)
            cost = sum
            costOverflow = costOverflow || overflow
        }
        let costed = potentialRule(potentials, start: nodes[0], goal: nodes[nodes.count - 1], target: path.cost,
                                   unitCosts: false, in: graph)
        let costedRule: String? = (costOverflow || cost != path.cost) ? "cost-mismatch" : costed
        guard let rule = costedRule else { return }
        if path.cost == path.steps,
           potentialRule(potentials, start: nodes[0], goal: nodes[nodes.count - 1], target: path.steps,
                         unitCosts: true, in: graph) == nil {
            return
        }
        throw .certificateRejected(rule)
    }

    /// The first failed potential rule, or nil when π proves no route from `start` to `goal` costs less than `target`.
    private static func potentialRule(_ potentials: [Int], start: Int, goal: Int, target: Int, unitCosts: Bool,
                                      in graph: RouteGraph) -> String? {
        guard potentials.count == graph.nodeCount else { return "potentials-size" }
        guard potentials[start] == 0 else { return "potential-start" }
        for u in 0..<graph.nodeCount {
            let pu = potentials[u]
            for edge in graph.edges(from: u) {
                let (bound, overflow) = pu.addingReportingOverflow(unitCosts ? 1 : edge.cost)
                if !overflow && potentials[edge.to] > bound { return "potential-edge" }
            }
        }
        guard potentials[goal] == target else { return "potential-goal" }
        return nil
    }

    // MARK: Unreachable

    private static func verifyUnreachable(start: Int, goal: Int, reachable: [Int],
                                          in graph: RouteGraph) throws(RouteError) {
        guard graph.contains(start), graph.contains(goal) else { throw .certificateRejected("node-range") }
        var member = Array(repeating: false, count: graph.nodeCount)
        var previous = Int.min
        for node in reachable {
            guard graph.contains(node) else { throw .certificateRejected("node-range") }
            guard node > previous else { throw .certificateRejected("unsorted") }
            previous = node
            member[node] = true
        }
        guard member[start] else { throw .certificateRejected("start-missing") }
        guard !member[goal] else { throw .certificateRejected("goal-present") }
        for node in reachable {
            for edge in graph.edges(from: node) where !member[edge.to] { throw .certificateRejected("not-closed") }
        }
    }

    // MARK: Timed

    private static func verifyTimedRoute(_ states: [TimedState], allowWaiting: Bool, in graph: RouteGraph,
                                         schedule: RouteSchedule) throws(RouteError) {
        guard !states.isEmpty else { throw .certificateRejected("empty-route") }
        for state in states where !graph.contains(state.node) { throw .certificateRejected("node-range") }
        for state in states where !schedule.isOpen(state.node, at: state.time) {
            throw .certificateRejected("closed-state")
        }
        for i in 1..<max(1, states.count) {
            let a = states[i - 1], b = states[i]
            guard a.time < Int.max, b.time == a.time + 1 else { throw .certificateRejected("time-step") }
            if a.node == b.node {
                guard allowWaiting || graph.hasEdge(from: a.node, to: a.node) else {
                    throw .certificateRejected("wait-forbidden")
                }
            } else if !graph.hasEdge(from: a.node, to: b.node) {
                throw .certificateRejected("missing-edge")
            }
        }
    }

    private static func verifyTimedUnreachable(start: Int, goal: Int, startTime: Int, allowWaiting: Bool,
                                               reachable: [TimedState], in graph: RouteGraph,
                                               schedule: RouteSchedule) throws(RouteError) {
        let steps = schedule.steps
        guard graph.contains(start), graph.contains(goal), startTime >= 0, startTime < steps else {
            throw .certificateRejected("node-range")
        }
        var members = Set<TimedState>()
        members.reserveCapacity(reachable.count)
        var previous: TimedState?
        for state in reachable {
            guard graph.contains(state.node), state.time >= 0, state.time < steps else {
                throw .certificateRejected("node-range")
            }
            if let p = previous, (p.time, p.node) >= (state.time, state.node) {
                throw .certificateRejected("unsorted")
            }
            previous = state
            members.insert(state)
        }
        guard members.contains(TimedState(node: start, time: startTime)) else {
            throw .certificateRejected("start-missing")
        }
        for state in reachable where state.node == goal { throw .certificateRejected("goal-present") }
        for state in reachable where state.time + 1 < steps {
            let next = state.time + 1
            if allowWaiting, schedule.isOpen(state.node, at: next),
               !members.contains(TimedState(node: state.node, time: next)) {
                throw .certificateRejected("not-closed")
            }
            for edge in graph.edges(from: state.node) where schedule.isOpen(edge.to, at: next) {
                guard members.contains(TimedState(node: edge.to, time: next)) else {
                    throw .certificateRejected("not-closed")
                }
            }
        }
    }

    // MARK: Cut

    private static func verifyCut(source: Int, sink: Int, edges: [CutEdge], routes: [RoutePath],
                                  in graph: RouteGraph) throws(RouteError) {
        guard graph.contains(source), graph.contains(sink) else { throw .certificateRejected("node-range") }
        for i in 1..<max(1, edges.count) where edges[i] < edges[i - 1] { throw .certificateRejected("unsorted") }
        guard routes.count == edges.count else { throw .certificateRejected("count-mismatch") }
        for route in routes {
            let nodes = route.nodes
            guard let first = nodes.first, let last = nodes.last, first == source, last == sink else {
                throw .certificateRejected("route-invalid")
            }
            for node in nodes where !graph.contains(node) { throw .certificateRejected("route-invalid") }
            for i in 1..<max(1, nodes.count) where !graph.hasEdge(from: nodes[i - 1], to: nodes[i]) {
                throw .certificateRejected("route-invalid")
            }
        }
        var units = [CutEdge: Int]()
        for u in 0..<graph.nodeCount {
            for edge in graph.edges(from: u) { units[CutEdge(from: u, to: edge.to), default: 0] += 1 }
        }
        var used = [CutEdge: Int]()
        for route in routes {
            let nodes = route.nodes
            for i in 1..<max(1, nodes.count) {
                let edge = CutEdge(from: nodes[i - 1], to: nodes[i])
                let count = used[edge, default: 0] + 1
                guard count <= units[edge, default: 0] else { throw .certificateRejected("not-disjoint") }
                used[edge] = count
            }
        }
        var removed = [CutEdge: Int]()
        for edge in edges {
            let count = removed[edge, default: 0] + 1
            guard count <= units[edge, default: 0] else { throw .certificateRejected("edge-missing") }
            removed[edge] = count
        }
        // Breadth-first search from the source with the cut's edge units removed (the first copies of each pair).
        var seen = Array(repeating: false, count: graph.nodeCount)
        seen[source] = true
        var queue = [source]
        var head = 0
        while head < queue.count {
            let u = queue[head]
            head += 1
            var skipped = [Int: Int]()
            for edge in graph.edges(from: u) {
                let key = CutEdge(from: u, to: edge.to)
                let cutUnits = removed[key, default: 0]
                if cutUnits > 0, skipped[edge.to, default: 0] < cutUnits {
                    skipped[edge.to, default: 0] += 1
                    continue
                }
                if !seen[edge.to] {
                    seen[edge.to] = true
                    queue.append(edge.to)
                }
            }
        }
        guard !seen[sink] else { throw .certificateRejected("not-separating") }
    }

    // MARK: Placement

    private static func verifyPlacement(_ map: [Int], pattern: RouteGraph, in graph: RouteGraph) throws(RouteError) {
        guard map.count == pattern.nodeCount else { throw .certificateRejected("size-mismatch") }
        var taken = Array(repeating: false, count: graph.nodeCount)
        for node in map {
            guard graph.contains(node) else { throw .certificateRejected("node-range") }
            guard !taken[node] else { throw .certificateRejected("not-injective") }
            taken[node] = true
        }
        for i in 0..<pattern.nodeCount {
            for edge in pattern.edges(from: i) where edge.to != i && !graph.adjacent(map[i], map[edge.to]) {
                throw .certificateRejected("missing-edge")
            }
        }
    }
}
