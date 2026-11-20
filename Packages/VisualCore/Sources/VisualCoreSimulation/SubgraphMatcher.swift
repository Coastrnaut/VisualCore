// SubgraphMatcher — feature 216 (R02-F16) T-R02F16-006 (FR-R02F16-005; SC-R02F16-004; clarification Q4; research R8).
// Finds placements of a small pattern graph inside a graph and decides isomorphism of equal-size graphs. Both graphs are
// read in their undirected simple view (``RouteGraph/adjacent(_:_:)``): directions, costs, duplicate edges and
// self-loops are ignored. A placement is an injective map from pattern nodes to graph nodes that sends every pattern
// edge to a graph edge (non-induced: extra graph edges between placed nodes are allowed).
// Method: backtracking over the pattern nodes in a fixed search order. The first node is the one of highest degree
// (ties: lowest id); each next node is the unordered one with the most already-ordered neighbours (ties: higher degree,
// then lower id), so the search stays connected and prunes early. Candidates are tried in increasing graph node id —
// when the pattern node has an already-placed neighbour, only that neighbour's graph neighbours are candidates — and a
// candidate is kept only if it is unused, its graph degree is at least the pattern degree and it is adjacent to the
// images of all already-placed pattern neighbours. Every candidate tried is one extension step, counted against the
// budget. Placements therefore come out in lexicographic order of (map[order[0]], map[order[1]], …).

/// The result of a placement search.
public struct MatchOutcome: Sendable, Equatable {
    /// The placements found, each indexed by pattern node (`placement[i]` is the graph node of pattern node i), in the
    /// order found: lexicographic in the matcher's search order.
    public let placements: [[Int]]
    /// Whether the search space was exhausted; false when the search stopped at the placement limit or the budget.
    public let complete: Bool
    /// The number of extension steps (candidates tried) the search used.
    public let examined: Int
    /// One ``SolverCertificate/placement(map:)`` per placement, or `[.exhausted(examined:)]` when the search was
    /// complete and found none; empty when it stopped early without a placement.
    public let certificates: [SolverCertificate]
}

/// Pattern placement (subgraph monomorphism) and isomorphism on the undirected view of ``RouteGraph``.
public enum SubgraphMatcher {
    /// The most nodes a pattern has.
    public static let maxPatternNodes = 32
    /// The most placements one search reports.
    public static let maxPlacements = 100_000
    /// The most extension steps one search takes.
    public static let maxSteps = 10_000_000

    /// Finds up to `limit` placements of `pattern` in `graph` within `budget` extension steps.
    ///
    /// Refuses a pattern of more than ``maxPatternNodes`` nodes with ``RouteError/patternLimit(_:)`` and a `limit` or
    /// `budget` outside 1 … ``maxPlacements`` or 1 … ``maxSteps`` with ``RouteError/budget(_:)``. A pattern with more
    /// nodes than the graph has no placement and is complete after 0 steps.
    public static func placements(of pattern: RouteGraph, in graph: RouteGraph, limit: Int = maxPlacements,
                                  budget: Int = maxSteps) throws(RouteError) -> MatchOutcome {
        guard pattern.nodeCount <= maxPatternNodes else { throw .patternLimit(pattern.nodeCount) }
        guard (1...maxPlacements).contains(limit) else { throw .budget(limit) }
        guard (1...maxSteps).contains(budget) else { throw .budget(budget) }
        guard pattern.nodeCount <= graph.nodeCount else {
            return MatchOutcome(placements: [], complete: true, examined: 0, certificates: [.exhausted(examined: 0)])
        }
        var search = Search(pattern: pattern, graph: graph, limit: limit, budget: budget)
        search.extend(depth: 0)
        let complete = !search.stopped
        var certificates: [SolverCertificate] = []
        for map in search.found { certificates.append(.placement(map: map)) }
        if complete && search.found.isEmpty { certificates = [.exhausted(examined: search.examined)] }
        return MatchOutcome(placements: search.found, complete: complete, examined: search.examined,
                            certificates: certificates)
    }

    /// Whether `a` and `b` are isomorphic in the undirected simple view: true or false, or nil when `budget` extension
    /// steps did not decide it. Graphs of different node counts, undirected edge counts or degree sequences are not
    /// isomorphic without a search. Refuses graphs of more than ``maxPatternNodes`` nodes with
    /// ``RouteError/patternLimit(_:)`` and a `budget` outside 1 … ``maxSteps`` with ``RouteError/budget(_:)``.
    public static func isomorphic(_ a: RouteGraph, _ b: RouteGraph, budget: Int = maxSteps) throws(RouteError) -> Bool? {
        guard a.nodeCount <= maxPatternNodes else { throw .patternLimit(a.nodeCount) }
        guard (1...maxSteps).contains(budget) else { throw .budget(budget) }
        guard a.nodeCount == b.nodeCount else { return false }
        let neighboursA = undirectedNeighbours(a)
        let neighboursB = undirectedNeighbours(b)
        let degreesA = neighboursA.map(\.count).sorted()
        let degreesB = neighboursB.map(\.count).sorted()
        guard degreesA == degreesB else { return false }   // equal degree sequences imply equal edge counts
        let outcome = try placements(of: a, in: b, limit: 1, budget: budget)
        // With equal node and edge counts, a bijection sending every edge of `a` to an edge of `b` is an isomorphism.
        if !outcome.placements.isEmpty { return true }
        return outcome.complete ? false : nil
    }

    /// The undirected simple neighbours of every node: sorted, without duplicates or the node itself.
    static func undirectedNeighbours(_ graph: RouteGraph) -> [[Int]] {
        var lists: [[Int]] = Array(repeating: [], count: graph.nodeCount)
        for node in 0..<graph.nodeCount {
            for edge in graph.edges(from: node) where edge.to != node {
                lists[node].append(edge.to)
                lists[edge.to].append(node)
            }
        }
        for node in 0..<graph.nodeCount {
            var sorted = lists[node].sorted()
            var write = 0
            for index in 0..<sorted.count where write == 0 || sorted[write - 1] != sorted[index] {
                sorted[write] = sorted[index]
                write += 1
            }
            sorted.removeLast(sorted.count - write)
            lists[node] = sorted
        }
        return lists
    }

    /// The backtracking state of one placement search.
    private struct Search {
        let patternCount: Int
        let patternDegree: [Int]
        let graphNeighbours: [[Int]]
        let graphCount: Int
        /// The pattern nodes in search order.
        let order: [Int]
        /// For each depth, the pattern nodes adjacent to `order[depth]` that appear earlier in the order.
        let earlier: [[Int]]
        let limit: Int
        let budget: Int
        var map: [Int]
        var used: [Bool]
        var found: [[Int]] = []
        var examined = 0
        var stopped = false

        init(pattern: RouteGraph, graph: RouteGraph, limit: Int, budget: Int) {
            let n = pattern.nodeCount
            var bits: [UInt32] = Array(repeating: 0, count: n)
            for node in 0..<n {
                for edge in pattern.edges(from: node) where edge.to != node {
                    bits[node] |= UInt32(1) << UInt32(edge.to)
                    bits[edge.to] |= UInt32(1) << UInt32(node)
                }
            }
            var degree: [Int] = []
            for node in 0..<n { degree.append(bits[node].nonzeroBitCount) }
            var ordered: [Int] = []
            var inOrder: UInt32 = 0
            for _ in 0..<n {
                var best = -1
                var bestLinks = -1
                for node in 0..<n where inOrder & (UInt32(1) << UInt32(node)) == 0 {
                    let links = (bits[node] & inOrder).nonzeroBitCount
                    if links > bestLinks || (links == bestLinks && degree[node] > degree[best]) {
                        best = node
                        bestLinks = links
                    }
                }
                ordered.append(best)
                inOrder |= UInt32(1) << UInt32(best)
            }
            var earlierLists: [[Int]] = []
            for depth in 0..<n {
                var list: [Int] = []
                for previous in 0..<depth where bits[ordered[depth]] & (UInt32(1) << UInt32(ordered[previous])) != 0 {
                    list.append(ordered[previous])
                }
                earlierLists.append(list)
            }
            patternCount = n
            patternDegree = degree
            graphNeighbours = SubgraphMatcher.undirectedNeighbours(graph)
            graphCount = graph.nodeCount
            order = ordered
            earlier = earlierLists
            self.limit = limit
            self.budget = budget
            map = Array(repeating: -1, count: n)
            used = Array(repeating: false, count: graph.nodeCount)
        }

        /// Whether graph nodes `a` and `b` are adjacent (binary search in `a`'s sorted neighbours).
        func graphAdjacent(_ a: Int, _ b: Int) -> Bool {
            let list = graphNeighbours[a]
            var low = 0
            var high = list.count
            while low < high {
                let middle = (low + high) / 2
                if list[middle] < b { low = middle + 1 } else { high = middle }
            }
            return low < list.count && list[low] == b
        }

        /// Whether graph node `candidate` can take pattern node `node` at `depth`.
        func fits(_ candidate: Int, node: Int, depth: Int) -> Bool {
            if used[candidate] || graphNeighbours[candidate].count < patternDegree[node] { return false }
            for neighbour in earlier[depth] where !graphAdjacent(candidate, map[neighbour]) { return false }
            return true
        }

        /// Tries one candidate; returns false when the budget is spent.
        mutating func tryCandidate(_ candidate: Int, node: Int, depth: Int) -> Bool {
            guard examined < budget else {
                stopped = true
                return false
            }
            examined += 1
            guard fits(candidate, node: node, depth: depth) else { return true }
            map[node] = candidate
            used[candidate] = true
            extend(depth: depth + 1)
            used[candidate] = false
            map[node] = -1
            return !stopped
        }

        /// Places the pattern node at `depth` and everything after it.
        mutating func extend(depth: Int) {
            if depth == patternCount {
                found.append(map)
                if found.count >= limit { stopped = true }
                return
            }
            let node = order[depth]
            if let anchor = earlier[depth].first {
                let candidates = graphNeighbours[map[anchor]]
                for candidate in candidates where !tryCandidate(candidate, node: node, depth: depth) { return }
            } else {
                for candidate in 0..<graphCount where !tryCandidate(candidate, node: node, depth: depth) { return }
            }
        }
    }
}
