// SDFCoding — feature 211 (R02-F11) T-R02F11-003 (FR-R02F11-007; clarification Q4; research R6, R10). The stored
// form of a signed-distance description: JSON `{"schema":1,"shape":<node>}` where every node is an object with a
// `kind` tag (`plane`, `sphere`, `box`, `roundedBox`, `capsule`, `torus`, `union`, `intersection`, `subtraction`,
// `smoothUnion`, `translated`, `rotated`, `scaled`) and fields named as the associated values of `SDFShape.Node`
// (`normal`, `offset`, `radius`, `halfExtents`, `a`, `b`, `major`, `minor`, `children`, `first`, `second`, `child`,
// `rotation` as {"x","y","z","w"}, `factor`). Keys are sorted so the bytes are deterministic. Reading checks the
// schema first, refuses unknown kinds and malformed data, refuses nesting deeper than 64 nodes before it recurses
// further, and re-validates the tree through `SDFShape.validated(_:)`, so a stored value is refused with the same
// error its maker gives. Nothing here traps.
import Foundation
import VisualCoreMath

/// A stored signed-distance description: the schema-1 JSON form of an `SDFShape` (see the file header).
public struct SDFDocument: Sendable, Equatable, Codable {
    /// The schema this version writes and the newest it reads.
    public static let schema = 1
    /// The deepest node nesting the reader follows before it refuses with `SDFError.tooDeep`.
    static let maxReadDepth = 64

    /// The stored description.
    public let shape: SDFShape

    /// A document holding `shape`.
    public init(shape: SDFShape) { self.shape = shape }

    /// The JSON form with sorted keys (identical bytes for equal shapes).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Reads a document: `.malformed` for unreadable data or a missing or non-integer schema (or one below 1),
    /// `.newerSchema` for a schema above `schema`, `.unknownKind` for an unknown node kind, `.tooDeep` for nesting
    /// beyond 64 nodes, and otherwise the error the shape makers give for a stored value.
    public static func decode(_ data: Data) throws(SDFError) -> SDFDocument {
        do {
            return try JSONDecoder().decode(SDFDocument.self, from: data)
        } catch let error as DecodingError {
            throw sdfError(from: error)
        } catch let error as SDFError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }

    /// Encodes `{"schema":1,"shape":<node>}`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DocumentKey.self)
        try container.encode(Self.schema, forKey: .schema)
        try container.encode(StoredNode(shape.node), forKey: .shape)
    }

    /// Decodes and re-validates a document; a refusal is a `DecodingError.dataCorrupted` whose underlying error is
    /// the `SDFError` (`decode(_:)` unwraps it).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentKey.self)
        guard container.contains(.schema) else { throw Self.refusal(.malformed("missing schema"), container) }
        let schema: Int
        do {
            schema = try container.decode(Int.self, forKey: .schema)
        } catch {
            throw Self.refusal(.malformed("schema is not an integer"), container)
        }
        guard schema <= Self.schema else { throw Self.refusal(.newerSchema(schema), container) }
        guard schema >= 1 else { throw Self.refusal(.malformed("schema \(schema) is below 1"), container) }
        let stored = try container.decode(StoredNode.self, forKey: .shape)
        do {
            shape = try SDFShape.validated(stored.node)
        } catch {
            throw Self.refusal(error, container)
        }
    }

    // MARK: Private

    private enum DocumentKey: String, CodingKey { case schema, shape }

    fileprivate static func refusal<K>(_ error: SDFError, _ container: KeyedDecodingContainer<K>) -> DecodingError {
        .dataCorrupted(.init(codingPath: container.codingPath, debugDescription: error.reasonCode,
                             underlyingError: error))
    }

    private static func sdfError(from error: DecodingError) -> SDFError {
        let context: DecodingError.Context
        switch error {
        case let .dataCorrupted(c): context = c
        case let .keyNotFound(key, c):
            return .malformed("missing \(key.stringValue) at \(path(c.codingPath))")
        case let .typeMismatch(_, c): context = c
        case let .valueNotFound(_, c): context = c
        @unknown default: return .malformed(String(describing: error))
        }
        if let sdf = context.underlyingError as? SDFError { return sdf }
        return .malformed("\(context.debugDescription) at \(path(context.codingPath))")
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        codingPath.isEmpty ? "root" : codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
            .joined(separator: ".")
    }
}

/// The coded form of one `SDFShape.Node` (unvalidated until `SDFShape.validated(_:)`).
private struct StoredNode: Codable {
    let node: SDFShape.Node

    init(_ node: SDFShape.Node) { self.node = node }

    private enum Key: String, CodingKey {
        case kind, normal, offset, radius, halfExtents, a, b, major, minor, children, first, second, child, rotation,
             factor
    }

    private enum QuatKey: String, CodingKey { case x, y, z, w }

    /// How many nodes deep `codingPath` is (array indices and the `children` key do not add a level).
    private static func nodeDepth(_ codingPath: [CodingKey]) -> Int {
        codingPath.filter { $0.intValue == nil && $0.stringValue != Key.children.rawValue }.count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        let depth = Self.nodeDepth(decoder.codingPath)
        guard depth <= SDFDocument.maxReadDepth else { throw SDFDocument.refusal(.tooDeep(depth), c) }
        let kind = try c.decode(String.self, forKey: .kind)
        func sub(_ key: Key) throws -> SDFShape.Node { try c.decode(StoredNode.self, forKey: key).node }
        func vec(_ key: Key) throws -> Vec3 { try c.decode(Vec3.self, forKey: key) }
        func num(_ key: Key) throws -> Double { try c.decode(Double.self, forKey: key) }
        switch kind {
        case "plane": node = .plane(normal: try vec(.normal), offset: try num(.offset))
        case "sphere": node = .sphere(radius: try num(.radius))
        case "box": node = .box(halfExtents: try vec(.halfExtents))
        case "roundedBox": node = .roundedBox(halfExtents: try vec(.halfExtents), radius: try num(.radius))
        case "capsule": node = .capsule(a: try vec(.a), b: try vec(.b), radius: try num(.radius))
        case "torus": node = .torus(major: try num(.major), minor: try num(.minor))
        case "union": node = .union(try c.decode([StoredNode].self, forKey: .children).map(\.node))
        case "intersection": node = .intersection(try c.decode([StoredNode].self, forKey: .children).map(\.node))
        case "subtraction": node = .subtraction(try sub(.first), try sub(.second))
        case "smoothUnion": node = .smoothUnion(try sub(.first), try sub(.second), radius: try num(.radius))
        case "translated": node = .translated(try sub(.child), offset: try vec(.offset))
        case "rotated":
            let q = try c.nestedContainer(keyedBy: QuatKey.self, forKey: .rotation)
            let rotation = Quat(x: try q.decode(Double.self, forKey: .x), y: try q.decode(Double.self, forKey: .y),
                                z: try q.decode(Double.self, forKey: .z), w: try q.decode(Double.self, forKey: .w))
            node = .rotated(try sub(.child), rotation: rotation)
        case "scaled": node = .scaled(try sub(.child), factor: try num(.factor))
        default: throw SDFDocument.refusal(.unknownKind(kind), c)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        switch node {
        case let .plane(n, h):
            try c.encode("plane", forKey: .kind); try c.encode(n, forKey: .normal); try c.encode(h, forKey: .offset)
        case let .sphere(r):
            try c.encode("sphere", forKey: .kind); try c.encode(r, forKey: .radius)
        case let .box(b):
            try c.encode("box", forKey: .kind); try c.encode(b, forKey: .halfExtents)
        case let .roundedBox(b, r):
            try c.encode("roundedBox", forKey: .kind); try c.encode(b, forKey: .halfExtents)
            try c.encode(r, forKey: .radius)
        case let .capsule(a, b, r):
            try c.encode("capsule", forKey: .kind); try c.encode(a, forKey: .a); try c.encode(b, forKey: .b)
            try c.encode(r, forKey: .radius)
        case let .torus(major, minor):
            try c.encode("torus", forKey: .kind); try c.encode(major, forKey: .major)
            try c.encode(minor, forKey: .minor)
        case let .union(children):
            try c.encode("union", forKey: .kind); try c.encode(children.map(StoredNode.init), forKey: .children)
        case let .intersection(children):
            try c.encode("intersection", forKey: .kind)
            try c.encode(children.map(StoredNode.init), forKey: .children)
        case let .subtraction(a, b):
            try c.encode("subtraction", forKey: .kind); try c.encode(StoredNode(a), forKey: .first)
            try c.encode(StoredNode(b), forKey: .second)
        case let .smoothUnion(a, b, k):
            try c.encode("smoothUnion", forKey: .kind); try c.encode(StoredNode(a), forKey: .first)
            try c.encode(StoredNode(b), forKey: .second); try c.encode(k, forKey: .radius)
        case let .translated(child, t):
            try c.encode("translated", forKey: .kind); try c.encode(StoredNode(child), forKey: .child)
            try c.encode(t, forKey: .offset)
        case let .rotated(child, q):
            try c.encode("rotated", forKey: .kind); try c.encode(StoredNode(child), forKey: .child)
            var r = c.nestedContainer(keyedBy: QuatKey.self, forKey: .rotation)
            try r.encode(q.x, forKey: .x); try r.encode(q.y, forKey: .y)
            try r.encode(q.z, forKey: .z); try r.encode(q.w, forKey: .w)
        case let .scaled(child, s):
            try c.encode("scaled", forKey: .kind); try c.encode(StoredNode(child), forKey: .child)
            try c.encode(s, forKey: .factor)
        }
    }
}
