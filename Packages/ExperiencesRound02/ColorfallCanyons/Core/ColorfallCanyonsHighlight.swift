// ColorfallCanyonsHighlight — feature 344 (R02-G05-04) T-R02G0504-005 (FR-R02G0504-005; research R5). The outline of
// the cell a drag would carve: a thin square pearl ring on the cell's block top (inset 0.08·u from the cell's edge,
// 0.06·u wide, lifted 0.01·u), material code 2 like the basin rims, so the existing terrain program draws it (no new
// GLSL). The scene draws it last, opaque, so it stays visible over the fluid (depth testing is off on this path). The
// fallback draws the same ring with its per-vertex pearl colour. Presentation only: built from the drawn snapshot.
import VisualCoreMath
import VisualCoreScenes

extension ColorfallCanyonsSceneGeometry {
    /// The inset of the highlight ring's outer edge from the cell's edge, 0.08 · u.
    public static let highlightInset = 0.08
    /// The width of the highlight ring, 0.06 · u.
    public static let highlightWidth = 0.06
    /// The lift of the highlight ring above the block top, 0.01 · u.
    public static let highlightLift = 0.01

    /// The highlight ring of `cell` (terrain program, material code 2, normal +y): four flat quads framing the block
    /// top. Empty for a cell outside the grid.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func highlightPart(_ cell: Int,
                                     _ snapshot: ColorfallCanyonsSceneSnapshot) throws(MeshError)
        -> ColorfallCanyonsColouredMesh {
        var parts: Parts = Parts()
        guard (0..<snapshot.cellCount).contains(cell) else { return parts.built() }
        let u: Double = cellSize(snapshot)
        let top: SIMD3<Double> = cellTop(cell, snapshot) + SIMD3(0, highlightLift * u, 0)
        let outer: Double = (0.5 - highlightInset) * u
        let inner: Double = outer - highlightWidth * u
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        let pearl: ColorfallCanyonsShaders.TerrainMaterial = .pearl
        let uv: Vec2 = Vec2(pearl.code, 1)
        // Four strips: near (+z), far (−z), and the left and right strips between them.
        let strips: [(x0: Double, x1: Double, z0: Double, z1: Double)] = [
            (x0: -outer, x1: outer, z0: inner, z1: outer),
            (x0: -outer, x1: outer, z0: -outer, z1: -inner),
            (x0: -outer, x1: -inner, z0: -inner, z1: inner),
            (x0: inner, x1: outer, z0: -inner, z1: inner),
        ]
        for s in strips {
            let p: [SIMD3<Double>] = [top + SIMD3(s.x0, 0, s.z0), top + SIMD3(s.x1, 0, s.z0),
                                      top + SIMD3(s.x1, 0, s.z1), top + SIMD3(s.x0, 0, s.z1)]
            try parts.quad(p, slot: up, front: up, uv: uv, colour: pearl.colour)
        }
        return parts.built()
    }
}
