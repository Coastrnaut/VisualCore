// ConvexSolidCoding — feature 212 (R02-F12) T-R02F12-005 (FR-R02F12-007; SC-R02F12-005; clarification Q5; research
// R6). The stored form of a convex solid and, optionally, its volume ledger: JSON `{"ledger":{…},"schema":1,
// "solid":{"faces":[…],"vertices":[…]}}` with sorted keys, so equal documents give identical bytes; `ledger` is
// omitted when there is none. Reading checks the schema first (missing, non-integer or below 1 is `malformed`, above 1
// is `newerSchema`) and re-validates the solid (indices, closedness, convexity, volume) and the ledger, so a stored
// value is refused with the same `ConvexSolidError` its maker gives. Nothing here traps.
import Foundation

/// A stored convex solid with an optional volume ledger (see the file header).
public struct ConvexSolidDocument: Sendable, Equatable {
    /// The schema this version writes and the newest it reads.
    public static let schema = 1

    /// The stored solid.
    public let solid: ConvexSolid
    /// The stored ledger, if any.
    public let ledger: VolumeLedger?

    /// A document holding `solid` and, optionally, `ledger`.
    public init(solid: ConvexSolid, ledger: VolumeLedger? = nil) {
        self.solid = solid
        self.ledger = ledger
    }

    /// The JSON form with sorted keys (identical bytes for equal documents).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Stored(self))
    }

    /// Reads a document: `.malformed` for unreadable data or a missing, non-integer or sub-1 schema, `.newerSchema`
    /// for a schema above `schema`, and otherwise the error the solid or the ledger validation gives.
    public static func decode(_ data: Data) throws(ConvexSolidError) -> ConvexSolidDocument {
        do {
            return try JSONDecoder().decode(Stored.self, from: data).document
        } catch let error as DecodingError {
            throw convexError(from: error)
        } catch let error as ConvexSolidError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }

    // MARK: Private

    private static func convexError(from error: DecodingError) -> ConvexSolidError {
        let context: DecodingError.Context
        switch error {
        case let .dataCorrupted(c): context = c
        case let .keyNotFound(key, c): return .malformed("missing \(key.stringValue) at \(path(c.codingPath))")
        case let .typeMismatch(_, c): context = c
        case let .valueNotFound(_, c): context = c
        @unknown default: return .malformed(String(describing: error))
        }
        if let convex = context.underlyingError as? ConvexSolidError { return convex }
        return .malformed("\(context.debugDescription) at \(path(context.codingPath))")
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        codingPath.isEmpty ? "root" : codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
            .joined(separator: ".")
    }
}

/// The coded form of a document (schema check before the solid and the ledger are read).
private struct Stored: Codable {
    let document: ConvexSolidDocument

    init(_ document: ConvexSolidDocument) { self.document = document }

    private enum Key: String, CodingKey { case schema, solid, ledger }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func refuse(_ error: ConvexSolidError) -> DecodingError {
            .dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode, underlyingError: error))
        }
        guard c.contains(.schema) else { throw refuse(.malformed("missing schema")) }
        let schema: Int
        do { schema = try c.decode(Int.self, forKey: .schema) } catch {
            throw refuse(.malformed("schema is not an integer"))
        }
        guard schema <= ConvexSolidDocument.schema else { throw refuse(.newerSchema(schema)) }
        guard schema >= 1 else { throw refuse(.malformed("schema \(schema) is below 1")) }
        let solid = try c.decode(ConvexSolid.self, forKey: .solid)
        let ledger = try c.decodeIfPresent(VolumeLedger.self, forKey: .ledger)
        document = ConvexSolidDocument(solid: solid, ledger: ledger)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(ConvexSolidDocument.schema, forKey: .schema)
        try c.encode(document.solid, forKey: .solid)
        try c.encodeIfPresent(document.ledger, forKey: .ledger)
    }
}
