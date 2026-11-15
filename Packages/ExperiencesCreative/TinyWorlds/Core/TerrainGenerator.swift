// TerrainGenerator — feature 089 (A12-P01) T-A12-103 (FR-A12-110, FR-A12-111, FR-A12-112; clarification 3; research
// D3; SC-A12-101, SC-A12-104). Builds a world's drawable parts from a preset and a seed: the terrain (a VisualCore
// `HeightField` of the preset's grid over −6…6 m, its mesh within `MeshBudget.default`) in the palette's low-land
// colour, and — for the island and the miniature city — a flat sea plane (12 × 12 m at y = 0, normal +y, two triangles
// counter-clockwise seen from +y) in the palette's sea colour. The asteroid garden has no sea plane; its void colour is
// the background. A world therefore has at most 3 parts (here 1 or 2), one draw each.
//
// The world digest (`digest(preset:seed:)`) is the SHA-256 (64 lower-case hexadecimal digits) of the UTF-8 text
// "<name>:<mesh digest>" of every part in order, joined by line feeds ("terrain:…\nsea:…" or "terrain:…"); it pins the
// geometry, not the colours. Generation is pure: the same preset and seed always give the same parts and digest.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// One drawable part of a world: a name, a mesh and its colour.
public struct WorldPart: Equatable, Sendable {
    /// The terrain part's name.
    public static let terrainName = "terrain"
    /// The sea plane part's name.
    public static let seaName = "sea"

    /// The part's name (``terrainName`` or ``seaName``).
    public var name: String
    /// The part's mesh in world space (metres, y up).
    public var mesh: Mesh
    /// The colour the part is drawn in.
    public var color: RGBA

    /// Creates a part.
    public init(name: String, mesh: Mesh, color: RGBA) {
        self.name = name; self.mesh = mesh; self.color = color
    }
}

/// Generates the terrain and parts of a world.
public enum TerrainGenerator {
    /// The most parts a world has (one draw each).
    public static let maxParts = 3

    /// The preset's height field for `seed`: `preset.columns` × `preset.rows` cells of `preset.cellSize` from
    /// (−6, −6), heights from ``WorldShape/height(x:z:)``.
    ///
    /// - Throws: `.invalidInput` when the preset's noise settings or grid are refused.
    public static func heightField(preset: WorldPreset, seed: UInt32) throws(MeshError) -> HeightField {
        guard let shape = preset.shape(seed: seed) else {
            throw .invalidInput("noise settings of preset \(preset.id.contentId) are refused")
        }
        return try HeightField(columns: preset.columns, rows: preset.rows, cellSize: preset.cellSize,
                               originX: WorldPreset.worldOrigin, originZ: WorldPreset.worldOrigin) { x, z in
            shape.height(x: x, z: z)
        }
    }

    /// The flat sea plane: 12 × 12 m at y = `level`, 4 vertices (normal +y, texture coordinates 0…1 over x and z) and
    /// 2 triangles counter-clockwise seen from +y.
    public static func seaPlane(level: Double = WorldPreset.seaLevel) -> Mesh {
        let low = WorldPreset.worldOrigin, high = WorldPreset.worldOrigin + WorldPreset.worldSize
        var builder = MeshBuilder()
        let up = Vec3(0, 1, 0)
        // The four corners are distinct and the budget is far larger, so nothing here can throw.
        let a = (try? builder.vertex(Vec3(low, level, low), normal: up, uv: Vec2(0, 0))) ?? 0
        let b = (try? builder.vertex(Vec3(low, level, high), normal: up, uv: Vec2(0, 1))) ?? 0
        let c = (try? builder.vertex(Vec3(high, level, high), normal: up, uv: Vec2(1, 1))) ?? 0
        let d = (try? builder.vertex(Vec3(high, level, low), normal: up, uv: Vec2(1, 0))) ?? 0
        try? builder.triangle(a, b, c)
        try? builder.triangle(a, c, d)
        return builder.build()
    }

    /// The world's parts for `preset` and `seed`: the terrain in the palette's low-land colour, then (island and
    /// miniature city) the sea plane in the palette's sea colour. Colours come from `catalog`'s palette with the
    /// preset's id; a missing palette gives mid grey and transparent black.
    ///
    /// - Throws: `.invalidInput` for refused settings and `.budget` when the terrain exceeds `budget`.
    public static func parts(preset: WorldPreset, seed: UInt32, catalog: ContentCatalog = .bundled,
                             budget: MeshBudget = .default) throws(MeshError) -> [WorldPart] {
        let palette = catalog.palette(id: preset.paletteId)
        let terrain = try heightField(preset: preset, seed: seed).mesh(budget: budget)
        var parts = [WorldPart(name: WorldPart.terrainName, mesh: terrain,
                               color: palette?.lowLand ?? RGBA(0.5, 0.5, 0.5))]
        if preset.hasSea {
            parts.append(WorldPart(name: WorldPart.seaName, mesh: seaPlane(),
                                   color: palette?.sea ?? RGBA(0, 0, 0, 0)))
        }
        return parts
    }

    /// The world digest of `parts` (see the file header).
    public static func digest(of parts: [WorldPart]) -> String {
        let text = parts.map { "\($0.name):\($0.mesh.digest)" }.joined(separator: "\n")
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// The world digest of `preset` and `seed` (see the file header).
    ///
    /// - Throws: as ``parts(preset:seed:catalog:budget:)``.
    public static func digest(preset: WorldPreset, seed: UInt32) throws(MeshError) -> String {
        digest(of: try parts(preset: preset, seed: seed))
    }
}
