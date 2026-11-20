// SDFError — feature 211 (R02-F11) T-R02F11-002 (FR-R02F11-006, FR-R02F11-007; clarification Q4; research R8). Why a
// signed-distance description, its stored form or a march or volume request was refused. Every case carries the
// offending field and has a stable `reasonCode` that names the feature (`r2-f11.*`); the experience that reports it adds
// its own id, seed and tick.

/// A refused signed-distance description or request (see the file header).
public enum SDFError: Error, Equatable, Sendable {
    /// The named value is not finite.
    case nonFinite(String)
    /// The named value must be greater than zero (or, for a smoothing radius, at least zero), or is out of its range.
    case nonPositive(String)
    /// The named direction or segment has zero length.
    case zeroDirection(String)
    /// A rotation quaternion is not of unit length (within 1e-9).
    case notUnitRotation
    /// The description has this many nodes, more than `SDFShape.maxNodes`.
    case tooManyNodes(Int)
    /// The description is this deep, more than `SDFShape.maxDepth`.
    case tooDeep(Int)
    /// A stored node has this unknown kind.
    case unknownKind(String)
    /// The stored form has this schema, newer than `SDFDocument.schema`.
    case newerSchema(Int)
    /// The stored form cannot be read; the text says why.
    case malformed(String)

    /// The stable reason code: `r2-f11.non-finite`, `r2-f11.non-positive`, `r2-f11.zero-direction`,
    /// `r2-f11.not-unit-rotation`, `r2-f11.too-many-nodes`, `r2-f11.too-deep`, `r2-f11.unknown-kind`,
    /// `r2-f11.newer-schema` or `r2-f11.malformed`.
    public var reasonCode: String {
        switch self {
        case .nonFinite: "r2-f11.non-finite"
        case .nonPositive: "r2-f11.non-positive"
        case .zeroDirection: "r2-f11.zero-direction"
        case .notUnitRotation: "r2-f11.not-unit-rotation"
        case .tooManyNodes: "r2-f11.too-many-nodes"
        case .tooDeep: "r2-f11.too-deep"
        case .unknownKind: "r2-f11.unknown-kind"
        case .newerSchema: "r2-f11.newer-schema"
        case .malformed: "r2-f11.malformed"
        }
    }
}
