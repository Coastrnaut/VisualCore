// DetailTierTests — feature 093 (A12-P05) T-A12-502 (FR-A12-501; SC-A12-501). The tier table, host-free and short:
// terrain cells per preset and tier (64, 32, 16 and 48, 24, 12), vertices strictly falling, the draws the same at every
// tier (terrain plus sea for the island and the city, terrain alone for the asteroid garden, plus every prop), the
// thumbnail 160 × 120 at every tier, and indices outside 0…2 refused.
import Foundation
import Testing
import TinyWorldsCore

@Suite struct DetailTierTests {
    @Test func theTerrainCellsFollowTheDetailLevels() throws {
        for preset in WorldPreset.all {
            let table = DetailTier.table(preset)
            #expect(table.map(\.index) == [0, 1, 2])
            for tier in table {
                #expect(tier.terrainLevel == tier.index)
                #expect(tier.terrainColumns == TerrainDetail.columns(preset: preset, level: tier.index))
                #expect(tier.terrainRows == TerrainDetail.rows(preset: preset, level: tier.index))
            }
        }
        #expect(DetailTier.table(.island).map(\.terrainColumns) == [64, 32, 16])
        #expect(DetailTier.table(.asteroidGarden).map(\.terrainColumns) == [64, 32, 16])
        #expect(DetailTier.table(.miniatureCity).map(\.terrainColumns) == [48, 24, 12])
    }

    @Test func lowerTiersNeverRaiseACount() {
        for preset in WorldPreset.all {
            let table = DetailTier.table(preset)
            for k in 1..<table.count {
                #expect(table[k].terrainVertices < table[k - 1].terrainVertices)
                #expect(table[k].terrainColumns < table[k - 1].terrainColumns)
                for props in [0, 1, 12, 24] {
                    #expect(table[k].draws(props: props) <= table[k - 1].draws(props: props))
                }
            }
        }
        #expect(DetailTier.table(.island).map(\.terrainVertices) == [4_225, 1_089, 289])
        #expect(DetailTier.table(.miniatureCity).map(\.terrainVertices) == [2_401, 625, 169])
    }

    @Test func everyWorldPartAndPropIsDrawnAtEveryTier() {
        for tier in DetailTier.table(.island) {
            #expect(tier.worldParts == 2)
            #expect(tier.draws(props: 5) == 7)
        }
        for tier in DetailTier.table(.asteroidGarden) {
            #expect(tier.worldParts == 1)
            #expect(tier.draws(props: 24) == 25)
        }
        for tier in DetailTier.table(.miniatureCity) { #expect(tier.draws(props: 0) == 2) }
        #expect(DetailTier(index: 0, preset: .island)?.draws(props: -3) == 2)
    }

    @Test func theThumbnailSizeIsFixedAndIndicesOutsideAreRefused() {
        #expect(DetailTier.thumbnailWidth == 160 && DetailTier.thumbnailHeight == 120)
        #expect(DetailTier.lightest == 2)
        #expect(DetailTier(index: -1, preset: .island) == nil)
        #expect(DetailTier(index: 3, preset: .island) == nil)
    }
}
