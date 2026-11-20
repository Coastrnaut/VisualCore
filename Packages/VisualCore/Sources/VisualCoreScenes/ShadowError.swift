// ShadowError — feature 213 (R02-F13) T-R02F13-002 (FR-R02F13-001, FR-R02F13-002, FR-R02F13-006, FR-R02F13-008). The
// typed refusals of the shadow projector, the coverage masks and their stored form; every case has a stable reason code.

/// A refusal by the shadow-projection and coverage-mask APIs (see the file header).
public enum ShadowError: Error, Equatable, Sendable {
    /// An input value (named by the payload) is NaN or infinite.
    case nonFinite(String)
    /// A light direction has zero length.
    case zeroDirection
    /// A directional light is parallel to the projection plane, so its shadow is unbounded.
    case parallelLight
    /// A point light lies on the projection plane.
    case lightOnPlane
    /// The light is below the plane (a point light) or points away from it (a directional light).
    case lightBelowPlane
    /// A coverage mask size is outside the accepted range.
    case maskSize(width: Int, height: Int)
    /// Two coverage masks that must share a size and frame do not.
    case mismatchedMasks
    /// A mesh has more triangles than the projector accepts (the payload is the count).
    case tooManyTriangles(Int)
    /// A stored value carries a schema version newer than this build reads (the payload is that version).
    case newerSchema(Int)
    /// A stored value is malformed (the payload names what is wrong).
    case malformed(String)

    /// The stable reason code reported to the shell and the ledger.
    public var reasonCode: String {
        switch self {
        case .nonFinite: "r2-f13.non-finite"
        case .zeroDirection: "r2-f13.zero-direction"
        case .parallelLight: "r2-f13.parallel-light"
        case .lightOnPlane: "r2-f13.light-on-plane"
        case .lightBelowPlane: "r2-f13.light-below-plane"
        case .maskSize: "r2-f13.mask-size"
        case .mismatchedMasks: "r2-f13.mismatched-masks"
        case .tooManyTriangles: "r2-f13.too-many-triangles"
        case .newerSchema: "r2-f13.newer-schema"
        case .malformed: "r2-f13.malformed"
        }
    }
}
