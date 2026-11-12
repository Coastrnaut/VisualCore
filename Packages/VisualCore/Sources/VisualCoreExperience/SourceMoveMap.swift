// SourceMoveMap — feature 187 T-U01-016 (FR-U01-046; data-model section 6).
import Foundation

/// The executed source moves of the migration (`Catalog/path-map.json`, schema 1). It is empty until the first move;
/// the plan of the moves is a different file, `docs/migration/path-map.json`.
public struct SourceMoveMap: Sendable, Equatable {
    /// One executed move of a source file or directory.
    public struct Move: Sendable, Equatable {
        /// The path before the move.
        public let from: String
        /// The path after the move.
        public let to: String
        /// The ledger gate under which the move was made.
        public let gate: String
        /// The short hash of the commit that made the move.
        public let commit: String

        /// Creates a move record.
        public init(from: String, to: String, gate: String, commit: String) {
            self.from = from
            self.to = to
            self.gate = gate
            self.commit = commit
        }
    }

    /// The largest number of moves the map accepts.
    public static let maxMoves = 5_000

    /// The moves in the order they were recorded.
    public let moves: [Move]

    /// Loads and validates the map: the size cap of the catalog, schema 1, at most `maxMoves` moves, each with
    /// exactly `from`, `to`, `gate` and `commit` as texts of 1 to 300 characters. Throws one `CatalogError`.
    public init(data: Data) throws(CatalogError) {
        guard data.count <= CatalogManifest.maxBytes else { throw .tooLarge(bytes: data.count, limit: CatalogManifest.maxBytes) }
        let top = try JSONFields.root(of: data, name: "path-map")
        let schema = try top.whole("schema", Int(Int32.min)...Int(Int32.max))
        guard schema == CatalogManifest.supportedSchema else {
            throw .unsupportedSchema(found: schema, supported: CatalogManifest.supportedSchema)
        }
        try top.requireOnly(["schema", "moves"])
        guard let list = top.object["moves"] as? [Any] else { throw .wrongType(entry: top.entry, field: "moves") }
        guard list.count <= Self.maxMoves else { throw .tooManyEntries(count: list.count, limit: Self.maxMoves) }
        var out: [Move] = []
        out.reserveCapacity(list.count)
        for (index, item) in list.enumerated() {
            guard let object = item as? [String: Any] else { throw .wrongType(entry: "#\(index)", field: "moves") }
            let fields = JSONFields(entry: "#\(index)", object: object)
            try fields.requireOnly(["from", "to", "gate", "commit"])
            out.append(Move(from: try fields.text("from", 1...300), to: try fields.text("to", 1...300),
                            gate: try fields.text("gate", 1...300), commit: try fields.text("commit", 1...300)))
        }
        moves = out
    }
}
