// CatalogError — feature 187 T-U01-006 (FR-U01-030 to FR-U01-035; data-model section 8).
import Foundation

/// Why a catalog file was refused. Every refusal is exactly one of these values; nothing is loaded in part.
/// `entry` is the id of the entry when it could be read, otherwise `#<index>`, or `manifest` for the top level.
public enum CatalogError: Error, Equatable, Sendable {
    /// The data is larger than the size cap; it was not parsed.
    case tooLarge(bytes: Int, limit: Int)
    /// The data is not JSON or not an object of the expected shape.
    case unreadable(reason: String)
    /// The file has another schema version than this build reads.
    case unsupportedSchema(found: Int, supported: Int)
    /// More entries than the catalog accepts.
    case tooManyEntries(count: Int, limit: Int)
    /// A key the schema requires is absent.
    case missingField(entry: String, field: String)
    /// A key the schema does not define is present.
    case unknownField(entry: String, field: String)
    /// A value has the wrong JSON type.
    case wrongType(entry: String, field: String)
    /// A value is of the right type but not allowed: an unknown tier, a text or list over its limit, a malformed id.
    case invalidValue(entry: String, field: String, reason: String)
    /// A number is not finite, not whole or outside its range.
    case invalidNumber(entry: String, field: String, reason: String)
    /// An id, a code or an order number occurs twice.
    case duplicate(field: String, value: String)
    /// The entries are not in ascending catalog order.
    case outOfOrder(entry: String)
    /// The launch allocation rule is broken for this code (ADR-0009 D-02).
    case allocation(code: String, reason: String)
}
