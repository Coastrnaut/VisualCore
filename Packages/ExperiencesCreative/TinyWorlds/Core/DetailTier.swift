// DetailTier — feature 093 (A12-P05) T-A12-502 (FR-A12-501; SC-A12-501; clarification 2; research D1). The table of
// the three detail tiers of a world: tier i draws the terrain at detail level i (`TerrainDetail`: island and asteroid
// garden 64, 32, 16 cells along each side; miniature city 48, 24, 12), so the terrain's vertex count
// (columns + 1) × (rows + 1) falls with every tier. Everything else is part of the world and is drawn at every tier:
// the world parts (the terrain, plus the sea plane for the island and the miniature city) and every placed prop, once
// each, so the draw count is the same at every tier; a saved world's thumbnail is 160 × 120 pixels at every tier.
// Lower tiers never raise a count. Derived from the preset; never saved.
import Foundation

/// One of the three detail tiers of a world, with its counts.
public struct DetailTier: Equatable, Sendable {
    /// The tiers: 0 (full detail), 1 and 2 (the lightest).
    public static let tiers: ClosedRange<Int> = TerrainDetail.levels
    /// The lightest tier, used under Low Power Mode and after a memory warning.
    public static let lightest: Int = tiers.upperBound
    /// The thumbnail width of a saved world in pixels, at every tier.
    public static let thumbnailWidth = 160
    /// The thumbnail height of a saved world in pixels, at every tier.
    public static let thumbnailHeight = 120

    /// The tier's index (0…2).
    public let index: Int
    /// The preset the counts are for.
    public let preset: WorldPreset

    /// The tier `index` of `preset`, or nil for an index outside ``tiers``.
    public init?(index: Int, preset: WorldPreset) {
        guard Self.tiers.contains(index) else { return nil }
        self.index = index
        self.preset = preset
    }

    /// The terrain detail level drawn at this tier (equal to the index).
    public var terrainLevel: Int { index }
    /// The terrain's cells along x.
    public var terrainColumns: Int { preset.columns >> index }
    /// The terrain's cells along z.
    public var terrainRows: Int { preset.rows >> index }
    /// The terrain mesh's vertex count: (columns + 1) × (rows + 1).
    public var terrainVertices: Int { (terrainColumns + 1) * (terrainRows + 1) }
    /// The world parts drawn: the terrain, plus the sea plane where the preset has one.
    public var worldParts: Int { preset.hasSea ? 2 : 1 }

    /// The draws of one frame with `props` placed props: every world part and every prop once (negative counts as 0).
    public func draws(props: Int) -> Int { worldParts + max(0, props) }

    /// The three tiers of `preset`, fullest first.
    public static func table(_ preset: WorldPreset) -> [DetailTier] {
        tiers.compactMap { DetailTier(index: $0, preset: preset) }
    }
}
