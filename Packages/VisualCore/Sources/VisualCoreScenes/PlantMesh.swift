// PlantMesh — feature 219 (R02-F19) T-R02F19-006 (FR-R02F19-004; SC-R02F19-003; clarification Q3; research R4). One
// mesh for a grown plant: every branch is the existing `Mesh.tube` over its two end points (the branch radius,
// six sides, capped), every petal and cap marker carries a copy of the given petal or cap mesh and every leaf marker a
// petal of half the width, each placed in the marker's frame (the part's +y along the heading, its +x along −left as
// in the turtle's start frame, its +z along up) with its origin at the marker; the parts are joined in order (branches,
// then markers in word order) with `Mesh.merged`, which enforces the budget.
import VisualCoreMath

/// Builds a single mesh for a grown plant.
public enum PlantMesh {
    /// The mesh of `skeleton` with `petal` at petal markers, `cap` at cap markers and a half-width petal at leaf
    /// markers (see the file header).
    ///
    /// - Throws: the ``MeshError`` of a tube or part, `.budget` when the merged mesh exceeds `budget`, and
    ///   `.invalidInput` for a skeleton with neither branches nor markers.
    public static func build(_ skeleton: PlantSkeleton, petal: PetalShape, cap: CapShape,
                             budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        var parts: [Mesh] = []
        parts.reserveCapacity(skeleton.branches.count + skeleton.markers.count)
        for branch in skeleton.branches {
            let samples = try CurveSamples(positions: [branch.start, branch.end], closed: false)
            parts.append(try Mesh.tube(samples: samples, radius: branch.radius, sides: 6, caps: true,
                                              budget: budget))
        }
        if !skeleton.markers.isEmpty {
            let petalMesh = try petal.mesh()
            let capMesh = try cap.mesh()
            let leafShape: PetalShape
            do {
                leafShape = try PetalShape(length: petal.length, width: petal.width / 2, curl: petal.curl,
                                           segments: petal.segments)
            } catch {
                throw .invalidInput("leaf shape: \(error.reasonCode)")
            }
            let leafMesh = try leafShape.mesh()
            for marker in skeleton.markers {
                let local: Mesh
                switch marker.kind {
                case .petal: local = petalMesh
                case .cap: local = capMesh
                case .leaf: local = leafMesh
                }
                parts.append(placed(local, at: marker))
            }
        }
        return try Mesh.merged(parts, budget: budget)
    }

    /// `mesh` moved into the frame of `marker`: local (x, y, z) ↦ position − x · left + y · heading + z · up.
    static func placed(_ mesh: Mesh, at marker: PlantMarker) -> Mesh {
        var moved = mesh
        let right = Vec3(-marker.left.x, -marker.left.y, -marker.left.z)
        func rotate(_ v: Vec3) -> Vec3 { right * v.x + marker.heading * v.y + marker.up * v.z }
        for k in 0..<moved.positions.count {
            moved.positions[k] = marker.position + rotate(mesh.positions[k])
            moved.normals[k] = rotate(mesh.normals[k]).normalized
        }
        return moved
    }
}
