// TerrainDetail — feature 090 (A12-P02) T-A12-204 (FR-A12-222; clarification 5; research D4; SC-A12-203). The three
// detail levels of a world's terrain: level 0 is the recipe's resolution, level 1 half and level 2 a quarter (cells
// along each side = recipe columns ÷ 1, 2, 4: island and asteroid garden 64, 32, 16; miniature city 48, 24, 12), over
// the same 12 m from (−6, −6) and from the same height function (`WorldShape.height(x:z:)`). Level 0 is exactly
// `TerrainGenerator.heightField(preset:seed:)`, so its mesh digest and the world digests of the P01 fixtures do not
// change. Because every cell size here is a power-of-two multiple of the recipe's, grid point (i, j) of level L lies
// exactly on grid point (2^L · i, 2^L · j) of level 0 and has the same height.
//
// The level is chosen by the host (quality tier `level-0` … `level-2`) and never saved.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Builds a world's terrain at one of three detail levels.
public enum TerrainDetail {
    /// The detail levels: 0 (full), 1 (half) and 2 (quarter resolution).
    public static let levels: ClosedRange<Int> = 0...2

    /// The cells along x of `preset` at `level` (recipe columns ÷ 2^level), or nil for a level outside ``levels``.
    public static func columns(preset: WorldPreset, level: Int) -> Int? {
        levels.contains(level) ? preset.columns >> level : nil
    }

    /// The cells along z of `preset` at `level` (recipe rows ÷ 2^level), or nil for a level outside ``levels``.
    public static func rows(preset: WorldPreset, level: Int) -> Int? {
        levels.contains(level) ? preset.rows >> level : nil
    }

    /// The height field of `preset` and `seed` at `level`; level 0 equals
    /// `TerrainGenerator.heightField(preset:seed:)`.
    ///
    /// - Throws: `.invalidInput` for a level outside ``levels`` or refused noise settings or grid.
    public static func field(preset: WorldPreset, seed: UInt32, level: Int) throws(MeshError) -> HeightField {
        guard let columns = columns(preset: preset, level: level), let rows = rows(preset: preset, level: level) else {
            throw .invalidInput("detail level \(level) is outside \(levels.lowerBound)…\(levels.upperBound)")
        }
        if level == 0 { return try TerrainGenerator.heightField(preset: preset, seed: seed) }
        guard let shape = preset.shape(seed: seed) else {
            throw .invalidInput("noise settings of preset \(preset.id.contentId) are refused")
        }
        return try HeightField(columns: columns, rows: rows, cellSize: WorldPreset.worldSize / Double(columns),
                               originX: WorldPreset.worldOrigin, originZ: WorldPreset.worldOrigin) { x, z in
            shape.height(x: x, z: z)
        }
    }

    /// The terrain mesh of `preset` and `seed` at `level` (see `HeightField.mesh(budget:)`).
    ///
    /// - Throws: as ``field(preset:seed:level:)``, and `.budget` when the mesh exceeds `budget`.
    public static func mesh(preset: WorldPreset, seed: UInt32, level: Int,
                            budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        try field(preset: preset, seed: seed, level: level).mesh(budget: budget)
    }
}
