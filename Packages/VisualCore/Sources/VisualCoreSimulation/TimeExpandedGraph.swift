// TimeExpandedGraph — feature 216 (R02-F16) T-R02F16-004 (FR-R02F16-003; SC-R02F16-002; clarification Q3; research R6).
// Earliest arrival through a schedule of open cells. The layered graph of states (node, t) is never built: a
// breadth-first search walks it layer by layer in increasing t, with a visited bit per state indexed t·n + node. From
// (v, t) the successors are (w, t + 1) for each edge v → w in insertion order (edge costs are ignored; every move takes
// one step), then (v, t + 1) when waiting is allowed; a successor must be open and t + 1 must be inside the schedule. The
// first goal state reached is the earliest arrival, and its route is rebuilt from the parent of each state (the first
// discovery wins, so the answer is deterministic). When the schedule ends first, every visited state, sorted by time and
// then node, is a set closed under moves (and waits) that holds the start state and no goal state: the proof that the
// goal cannot be reached before the schedule ends.

/// The answer of an earliest-arrival search through a schedule.
public enum TimedOutcome: Sendable, Equatable {
    /// The goal is reached; `states` run from the start state to the first goal state, one time step apart, and the
    /// certificate is ``SolverCertificate/timedRoute(states:allowWaiting:)``.
    case arrived(states: [TimedState], certificate: SolverCertificate)
    /// The goal cannot be reached before the schedule ends; the certificate is
    /// ``SolverCertificate/timedUnreachable(start:goal:startTime:allowWaiting:reachable:)``.
    case unreachable(SolverCertificate)
}

/// Routes through time over a graph whose cells open and close by a ``RouteSchedule``.
public enum TimeExpandedGraph {
    /// The earliest arrival from `from` at `startTime` to `to`, moving one edge per time step (edge costs ignored) and,
    /// when `allowWaiting` is true, optionally staying put for a step; every state on the route is open.
    ///
    /// Refuses a schedule whose cell count differs from the graph's node count or a `startTime` outside
    /// 0 ..< `schedule.steps` with ``RouteError/scheduleLimit``, an endpoint outside the graph with
    /// ``RouteError/nodeRange(_:)`` and a closed start state with ``RouteError/blockedEndpoint(_:)``.
    public static func earliestArrival(in graph: RouteGraph, schedule: RouteSchedule, from: Int, to: Int,
                                       startTime: Int = 0, allowWaiting: Bool = true) throws(RouteError) -> TimedOutcome {
        guard schedule.cellCount == graph.nodeCount else { throw .scheduleLimit }
        guard graph.contains(from) else { throw .nodeRange(from) }
        guard graph.contains(to) else { throw .nodeRange(to) }
        guard startTime >= 0, startTime < schedule.steps else { throw .scheduleLimit }
        guard schedule.isOpen(from, at: startTime) else { throw .blockedEndpoint(from) }

        let start = TimedState(node: from, time: startTime)
        if from == to {
            return .arrived(states: [start], certificate: .timedRoute(states: [start], allowWaiting: allowWaiting))
        }

        let n = graph.nodeCount
        var visited = [Bool](repeating: false, count: n * schedule.steps)
        // Parent node of each visited state (its time is one less); -1 for the start state.
        var parent = [Int32](repeating: -1, count: n * schedule.steps)
        var order: [TimedState] = [start]
        visited[startTime * n + from] = true
        var layer: [Int] = [from]
        var t = startTime

        while !layer.isEmpty, t + 1 < schedule.steps {
            let next = t + 1
            var nextLayer: [Int] = []
            for v in layer {
                var candidates: [Int] = graph.edges(from: v).map(\.to)
                if allowWaiting { candidates.append(v) }
                for w in candidates {
                    let index = next * n + w
                    guard !visited[index], schedule.isOpen(w, at: next) else { continue }
                    visited[index] = true
                    parent[index] = Int32(v)
                    if w == to {
                        let states = rebuild(goal: w, time: next, startTime: startTime, n: n, parent: parent)
                        return .arrived(states: states,
                                        certificate: .timedRoute(states: states, allowWaiting: allowWaiting))
                    }
                    nextLayer.append(w)
                    order.append(TimedState(node: w, time: next))
                }
            }
            layer = nextLayer
            t = next
        }

        let reachable = order.sorted { ($0.time, $0.node) < ($1.time, $1.node) }
        return .unreachable(.timedUnreachable(start: from, goal: to, startTime: startTime, allowWaiting: allowWaiting,
                                              reachable: reachable))
    }

    /// The states from the start state to (`goal`, `time`), following parents back one step at a time.
    private static func rebuild(goal: Int, time: Int, startTime: Int, n: Int, parent: [Int32]) -> [TimedState] {
        var states: [TimedState] = []
        var node = goal
        var t = time
        while t > startTime {
            states.append(TimedState(node: node, time: t))
            node = Int(parent[t * n + node])
            t -= 1
        }
        states.append(TimedState(node: node, time: startTime))
        return states.reversed()
    }
}
