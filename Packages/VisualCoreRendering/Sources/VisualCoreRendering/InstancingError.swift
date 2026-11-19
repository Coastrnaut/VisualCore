// InstancingError.swift — the refusals of the instanced renderers (feature 209, R02-F09, T-R02F09-003; clarification
// Q4). Every check runs before any GL call, so a refused list leaves the bound framebuffer untouched (no partial frame).

/// Why `InstancedMeshRenderer` or `BeamRenderer` refused a list; thrown before any GL call.
public enum InstancingError: Error, Equatable, Sendable {
    /// The list holds `count` entries, more than the renderer's `limit` per call.
    case tooMany(count: Int, limit: Int)
    /// Entry `index` holds a non-finite number (matrix, end point, width or colour component).
    case notFinite(index: Int)
    /// Beam `index` has a finite width of zero or less.
    case badWidth(index: Int)
}
