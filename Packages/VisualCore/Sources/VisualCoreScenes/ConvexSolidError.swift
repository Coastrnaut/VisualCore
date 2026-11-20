// ConvexSolidError — feature 212 (R02-F12) T-R02F12-002 (FR-R02F12-001, FR-R02F12-007, FR-R02F12-010; clarification
// Q5). Why a convex solid, a cut plane, a polygon, a ledger or a stored form was refused. Every case has a stable
// `reasonCode` naming the feature (`r2-f12.*`); the experience that reports it adds its own id, seed and tick.

/// A refused convex-solid operation (see the file header).
public enum ConvexSolidError: Error, Equatable, Sendable {
    /// The named value is not finite.
    case nonFinite(String)
    /// A plane normal has zero length.
    case zeroNormal
    /// The solid would have no volume (empty bounds, or nothing left).
    case empty
    /// A mesh or stored solid is not closed (an edge is not shared by exactly two faces).
    case notClosed
    /// A mesh or stored solid is not convex (a vertex lies above a face plane by more than the tolerance).
    case notConvex
    /// A limit would be exceeded; the text names it (vertices, faces, corners, ledger entries).
    case tooComplex(String)
    /// A polygon has fewer than three distinct, non-collinear corners.
    case degeneratePolygon
    /// The stored form has this schema, newer than `ConvexSolidDocument.schema`.
    case newerSchema(Int)
    /// The stored form cannot be read; the text says why.
    case malformed(String)

    /// The stable reason code: `r2-f12.non-finite`, `r2-f12.zero-normal`, `r2-f12.empty`, `r2-f12.not-closed`,
    /// `r2-f12.not-convex`, `r2-f12.too-complex`, `r2-f12.degenerate-polygon`, `r2-f12.newer-schema` or
    /// `r2-f12.malformed`.
    public var reasonCode: String {
        switch self {
        case .nonFinite: "r2-f12.non-finite"
        case .zeroNormal: "r2-f12.zero-normal"
        case .empty: "r2-f12.empty"
        case .notClosed: "r2-f12.not-closed"
        case .notConvex: "r2-f12.not-convex"
        case .tooComplex: "r2-f12.too-complex"
        case .degeneratePolygon: "r2-f12.degenerate-polygon"
        case .newerSchema: "r2-f12.newer-schema"
        case .malformed: "r2-f12.malformed"
        }
    }
}
