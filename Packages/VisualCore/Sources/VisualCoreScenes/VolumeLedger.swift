// VolumeLedger — feature 212 (R02-F12) T-R02F12-004 (FR-R02F12-005; SC-R02F12-002; clarification Q4). A record of
// sequential cuts of one convex solid: per cut the plane, the volume removed and the volume remaining, at most 65,536
// entries. The next cut past the limit is refused with `tooComplex("ledger")` and the ledger stays unchanged. The
// ledger balances when |original − remaining − Σ removed| / original ≤ 1e-9. Once nothing is left a cut removes 0 and
// records remaining 0. The stored form is `{"current":…,"entries":[…],"original":…}` plus `"maxEntries"` only when the
// limit is not the public 65,536 (the internal test limit survives a round trip); decoding re-validates the original
// volume (finite, > 0), every entry volume (finite, ≥ 0), the limit (1…65,536) and the entry count (≤ the limit).
import Foundation
import VisualCoreMath

/// A balanced record of sequential cuts of one convex solid (see the file header).
public struct VolumeLedger: Sendable, Equatable, Codable {
    /// One recorded cut.
    public struct Entry: Sendable, Equatable, Codable {
        /// The cut plane.
        public let plane: ClipPlane
        /// The volume this cut removed (0 when the plane missed or nothing was left).
        public let removed: Double
        /// The volume left after this cut (0 when nothing is left).
        public let remaining: Double

        /// An entry from its plane and volumes.
        public init(plane: ClipPlane, removed: Double, remaining: Double) {
            self.plane = plane; self.removed = removed; self.remaining = remaining
        }
    }

    /// The largest number of entries a ledger holds.
    public static let maxEntries = 65_536
    /// The largest relative imbalance for which `isBalanced` is true.
    public static let balanceTolerance = 1e-9

    /// The volume of the solid the ledger started from.
    public let original: Double
    /// The recorded cuts, in order.
    public private(set) var entries: [Entry]
    /// What is left of the solid, or nil when nothing is left.
    public private(set) var current: ConvexSolid?
    /// This ledger's entry limit (`maxEntries` unless a test chose a smaller one).
    let limit: Int

    /// A ledger for `solid` with no cuts yet.
    public init(solid: ConvexSolid) { self.init(solid: solid, maxEntries: Self.maxEntries) }

    /// A ledger with a smaller entry limit, for tests of the limit (clamped to 1…`maxEntries`).
    init(solid: ConvexSolid, maxEntries: Int) {
        original = solid.volume
        entries = []
        current = solid
        limit = Swift.min(Swift.max(maxEntries, 1), Self.maxEntries)
    }

    /// Cuts what is left by `plane`, keeps the part below it and records the entry. Throws `.tooComplex("ledger")`
    /// (the ledger unchanged) when the limit is reached, and any error of `ConvexSolid.cut(by:)` (also unchanged).
    public mutating func cut(by plane: ClipPlane) throws(ConvexSolidError) -> ConvexCutResult {
        guard entries.count < limit else { throw .tooComplex("ledger") }
        guard let solid = current else {
            entries.append(Entry(plane: plane, removed: 0, remaining: 0))
            return ConvexCutResult(kept: nil, removed: nil, cap: [], keptVolume: 0, removedVolume: 0)
        }
        let result = try solid.cut(by: plane)
        current = result.kept
        entries.append(Entry(plane: plane, removed: result.removedVolume,
                             remaining: result.kept == nil ? 0 : result.keptVolume))
        return result
    }

    /// |original − remaining − Σ removed| / original, with remaining the last entry's (the original before any cut).
    public var imbalance: Double {
        let remaining = entries.last?.remaining ?? original
        var removed = 0.0
        for entry in entries { removed += entry.removed }
        return abs(original - remaining - removed) / original
    }

    /// True when `imbalance` ≤ `balanceTolerance`.
    public var isBalanced: Bool { imbalance <= Self.balanceTolerance }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case original, entries, current, maxEntries }

    /// Decodes and re-validates a stored ledger; a refusal is `DecodingError.dataCorrupted` whose underlying error is
    /// the `ConvexSolidError` (`nonFinite("ledger")`, `malformed("ledger …")` or `tooComplex("ledger")`).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let original = try c.decode(Double.self, forKey: .original)
        let entries = try c.decode([Entry].self, forKey: .entries)
        let current = try c.decodeIfPresent(ConvexSolid.self, forKey: .current)
        let limit = try c.decodeIfPresent(Int.self, forKey: .maxEntries) ?? Self.maxEntries
        func refuse(_ error: ConvexSolidError) -> DecodingError {
            .dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode, underlyingError: error))
        }
        guard original.isFinite else { throw refuse(.nonFinite("ledger")) }
        guard original > 0 else { throw refuse(.malformed("ledger original")) }
        for entry in entries {
            guard entry.removed.isFinite, entry.remaining.isFinite else { throw refuse(.nonFinite("ledger")) }
            guard entry.removed >= 0, entry.remaining >= 0 else { throw refuse(.malformed("ledger volume")) }
        }
        guard limit >= 1, limit <= Self.maxEntries else { throw refuse(.malformed("ledger limit")) }
        guard entries.count <= limit else { throw refuse(.tooComplex("ledger")) }
        self.original = original
        self.entries = entries
        self.current = current
        self.limit = limit
    }

    /// Encodes the original volume, the entries, what is left (omitted when nothing is) and a non-default limit.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(original, forKey: .original)
        try c.encode(entries, forKey: .entries)
        try c.encodeIfPresent(current, forKey: .current)
        if limit != Self.maxEntries { try c.encode(limit, forKey: .maxEntries) }
    }
}
