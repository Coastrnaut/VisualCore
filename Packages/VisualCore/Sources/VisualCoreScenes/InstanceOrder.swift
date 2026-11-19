// InstanceOrder — feature 209 (R02-F09) T-R02F09-002 (FR-R02F09-003, FR-R02F09-004; clarification Q3; research R4). The
// back-to-front order of translucent instances: indices sorted by view-space z ascending (the camera looks down −z,
// so the most negative z is the farthest), ties kept in submission order, a non-finite depth refused. The same rule as
// `DepthMeshPass.backToFront` in VisualCoreRendering, as a pure function the instanced renderers and tests share.
import VisualCoreMath

/// Back-to-front ordering of translucent instances by view-space depth.
public enum InstanceOrder {
    /// The indices of `depths` (view-space z of each instance) from farthest to nearest: ascending z, ties by index.
    /// Throws `MeshError.invalidInput` naming the first non-finite depth.
    public static func backToFront(depths: [Double]) throws(MeshError) -> [Int] {
        if let bad = depths.firstIndex(where: { !$0.isFinite }) {
            throw .invalidInput("depth \(bad) is not finite")
        }
        return depths.indices.sorted { depths[$0] != depths[$1] ? depths[$0] < depths[$1] : $0 < $1 }
    }
}
