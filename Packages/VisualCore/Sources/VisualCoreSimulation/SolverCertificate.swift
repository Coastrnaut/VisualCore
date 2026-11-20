// SolverCertificate — feature 216 (R02-F16) T-R02F16-002 (FR-R02F16-006, FR-R02F16-007; clarifications Q2–Q5; research
// R4, R5, R7). The proof that comes with every answer of the route solvers, checked by `CertificateChecker` without the
// solvers: a route with node potentials proving it is cheapest; a reachable set closed under edges proving a goal
// unreachable; a timed route and a closed set of timed states for routes through time; a cut with as many edge-disjoint
// routes; a pattern placement; and the count of an exhaustive search, which records but does not prove "no placement".
// Stored as JSON schema 1 with sorted keys: `{"kind":…,"schema":1,…}` plus the kind's fields. Schema 1 is the first
// stored form; a newer schema is refused, damaged data is refused as malformed.
import Foundation

/// A directed edge named by its ends.
public struct CutEdge: Sendable, Equatable, Hashable, Codable, Comparable {
    /// The node the edge leaves.
    public let from: Int
    /// The node the edge enters.
    public let to: Int

    /// Creates the edge.
    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }

    /// Orders edges by `from`, then `to`.
    public static func < (a: CutEdge, b: CutEdge) -> Bool { (a.from, a.to) < (b.from, b.to) }
}

/// The proof that accompanies a solver's answer.
public enum SolverCertificate: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema = 1

    /// A route and node potentials π with π(start) = 0, π(v) ≤ π(u) + c for every edge and π(goal) = the route's cost,
    /// which proves no cheaper route exists.
    case route(path: RoutePath, potentials: [Int])
    /// A set of nodes (sorted) containing `start`, not `goal`, and closed under edges, which proves `goal` unreachable.
    case unreachable(start: Int, goal: Int, reachable: [Int])
    /// A route through time: every state open, every step a move along an edge or (when allowed) a wait.
    case timedRoute(states: [TimedState], allowWaiting: Bool)
    /// A set of timed states (sorted by time, then node) containing the start state, no goal state and closed under
    /// moves (and waits when allowed) within the schedule, which proves the goal unreachable before the schedule ends.
    case timedUnreachable(start: Int, goal: Int, startTime: Int, allowWaiting: Bool, reachable: [TimedState])
    /// A minimum cut (edges sorted) between `source` and `sink` with as many pairwise edge-disjoint routes.
    case cut(source: Int, sink: Int, edges: [CutEdge], routes: [RoutePath])
    /// A placement: `map[i]` is the graph node of pattern node i.
    case placement(map: [Int])
    /// An exhaustive search that examined `examined` extension steps and found nothing; recorded, not checkable.
    case exhausted(examined: Int)

    /// The kind's stored name.
    public var kind: String {
        switch self {
        case .route: "route"
        case .unreachable: "unreachable"
        case .timedRoute: "timedRoute"
        case .timedUnreachable: "timedUnreachable"
        case .cut: "cut"
        case .placement: "placement"
        case .exhausted: "exhausted"
        }
    }

    /// The stored form: JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Every field is an integer, a Boolean or an array of them, so encoding cannot fail.
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Reads a stored certificate; refuses a newer schema with ``RouteError/newerSchema(_:)`` and damaged data with
    /// ``RouteError/malformed(_:)``.
    public static func decode(_ data: Data) throws(RouteError) -> SolverCertificate {
        do {
            return try JSONDecoder().decode(SolverCertificate.self, from: data)
        } catch let error as RouteError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }
}

extension SolverCertificate: Codable {
    private enum Key: String, CodingKey {
        case schema, kind, path, potentials, start, goal, reachable, states, allowWaiting, startTime, source, sink,
             edges, routes, map, examined
    }

    /// Reads the stored form; throws ``RouteError/newerSchema(_:)`` for a schema above ``schema`` and
    /// ``RouteError/malformed(_:)`` for anything else that does not read.
    public init(from decoder: any Decoder) throws {
        let c: KeyedDecodingContainer<Key>
        let schemaValue: Int
        let kindValue: String
        do {
            c = try decoder.container(keyedBy: Key.self)
            schemaValue = try c.decode(Int.self, forKey: .schema)
            kindValue = try c.decode(String.self, forKey: .kind)
        } catch {
            throw RouteError.malformed(String(describing: error))
        }
        guard schemaValue <= Self.schema else { throw RouteError.newerSchema(schemaValue) }
        guard schemaValue == Self.schema else { throw RouteError.malformed("schema \(schemaValue)") }
        do {
            switch kindValue {
            case "route":
                self = .route(path: try c.decode(RoutePath.self, forKey: .path),
                              potentials: try c.decode([Int].self, forKey: .potentials))
            case "unreachable":
                self = .unreachable(start: try c.decode(Int.self, forKey: .start),
                                    goal: try c.decode(Int.self, forKey: .goal),
                                    reachable: try c.decode([Int].self, forKey: .reachable))
            case "timedRoute":
                self = .timedRoute(states: try c.decode([TimedState].self, forKey: .states),
                                   allowWaiting: try c.decode(Bool.self, forKey: .allowWaiting))
            case "timedUnreachable":
                self = .timedUnreachable(start: try c.decode(Int.self, forKey: .start),
                                         goal: try c.decode(Int.self, forKey: .goal),
                                         startTime: try c.decode(Int.self, forKey: .startTime),
                                         allowWaiting: try c.decode(Bool.self, forKey: .allowWaiting),
                                         reachable: try c.decode([TimedState].self, forKey: .reachable))
            case "cut":
                self = .cut(source: try c.decode(Int.self, forKey: .source),
                            sink: try c.decode(Int.self, forKey: .sink),
                            edges: try c.decode([CutEdge].self, forKey: .edges),
                            routes: try c.decode([RoutePath].self, forKey: .routes))
            case "placement":
                self = .placement(map: try c.decode([Int].self, forKey: .map))
            case "exhausted":
                self = .exhausted(examined: try c.decode(Int.self, forKey: .examined))
            default:
                throw RouteError.malformed("kind \(kindValue)")
            }
        } catch let error as RouteError {
            throw error
        } catch {
            throw RouteError.malformed(String(describing: error))
        }
    }

    /// Writes the stored form with the schema and kind.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(kind, forKey: .kind)
        switch self {
        case let .route(path, potentials):
            try c.encode(path, forKey: .path)
            try c.encode(potentials, forKey: .potentials)
        case let .unreachable(start, goal, reachable):
            try c.encode(start, forKey: .start)
            try c.encode(goal, forKey: .goal)
            try c.encode(reachable, forKey: .reachable)
        case let .timedRoute(states, allowWaiting):
            try c.encode(states, forKey: .states)
            try c.encode(allowWaiting, forKey: .allowWaiting)
        case let .timedUnreachable(start, goal, startTime, allowWaiting, reachable):
            try c.encode(start, forKey: .start)
            try c.encode(goal, forKey: .goal)
            try c.encode(startTime, forKey: .startTime)
            try c.encode(allowWaiting, forKey: .allowWaiting)
            try c.encode(reachable, forKey: .reachable)
        case let .cut(source, sink, edges, routes):
            try c.encode(source, forKey: .source)
            try c.encode(sink, forKey: .sink)
            try c.encode(edges, forKey: .edges)
            try c.encode(routes, forKey: .routes)
        case let .placement(map):
            try c.encode(map, forKey: .map)
        case let .exhausted(examined):
            try c.encode(examined, forKey: .examined)
        }
    }
}
