// TerrainDetailTests — feature 090 (A12-P02) T-A12-204 (FR-A12-222; clarification 5; research D4; SC-A12-203). The
// three detail levels, host-free and short: the cell counts (64, 32, 16 and 48, 24, 12); all 27 meshes (3 presets ×
// seeds 1–3 × levels 0–2) validate with every index below the vertex count; level 0 is the P01 terrain exactly (same
// field, same mesh digest, and the world digests rebuilt from it equal the committed P01 fixtures); coarser grid points
// carry the level-0 heights; a level outside 0…2 is refused.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreScenes

@Suite struct TerrainDetailTests {
    @Test func theCellCountsHalveAndQuarterTheRecipe() {
        #expect([0, 1, 2].map { TerrainDetail.columns(preset: .island, level: $0) } == [64, 32, 16])
        #expect([0, 1, 2].map { TerrainDetail.columns(preset: .asteroidGarden, level: $0) } == [64, 32, 16])
        #expect([0, 1, 2].map { TerrainDetail.columns(preset: .miniatureCity, level: $0) } == [48, 24, 12])
        #expect([0, 1, 2].map { TerrainDetail.rows(preset: .miniatureCity, level: $0) } == [48, 24, 12])
        #expect(TerrainDetail.columns(preset: .island, level: 3) == nil)
        #expect(TerrainDetail.columns(preset: .island, level: -1) == nil)
    }

    @Test(arguments: WorldPreset.all)
    func allNineMeshesOfAPresetValidateWithIndicesInBounds(preset: WorldPreset) throws {
        for seed: UInt32 in [1, 2, 3] {
            for level in TerrainDetail.levels {
                let field = try TerrainDetail.field(preset: preset, seed: seed, level: level)
                let mesh = try TerrainDetail.mesh(preset: preset, seed: seed, level: level)
                let cells = preset.columns >> level
                #expect(field.columns == cells && field.rows == cells)
                #expect(abs(Double(field.columns) * field.cellSize - WorldPreset.worldSize) < 1e-12)
                #expect(field.originX == WorldPreset.worldOrigin && field.originZ == WorldPreset.worldOrigin)
                let report = mesh.validate()
                #expect(report.isValid, "\(preset.id.contentId) seed \(seed) level \(level): \(report)")
                #expect(mesh.positions.count == (cells + 1) * (cells + 1))
                #expect(mesh.indices.count == 6 * cells * cells)
                #expect(mesh.indices.allSatisfy { Int($0) < mesh.positions.count })
            }
        }
    }

    @Test(arguments: WorldPreset.all)
    func levelZeroIsTheP01TerrainAndKeepsTheFixtures(preset: WorldPreset) throws {
        let expected = try #require(TerrainFixtureTests.fixtures[preset.id.contentId])
        for seed: UInt32 in [1, 2, 3] {
            let field = try TerrainDetail.field(preset: preset, seed: seed, level: 0)
            #expect(field == (try TerrainGenerator.heightField(preset: preset, seed: seed)))
            var parts = try TerrainGenerator.parts(preset: preset, seed: seed)
            #expect(try TerrainDetail.mesh(preset: preset, seed: seed, level: 0).digest == parts[0].mesh.digest)
            parts[0].mesh = try TerrainDetail.mesh(preset: preset, seed: seed, level: 0)
            #expect(TerrainGenerator.digest(of: parts) == expected[seed], "\(preset.id.contentId) seed \(seed)")
        }
    }

    @Test(arguments: WorldPreset.all)
    func coarserGridPointsCarryTheLevelZeroHeights(preset: WorldPreset) throws {
        let full = try TerrainDetail.field(preset: preset, seed: 2, level: 0)
        for level in 1...2 {
            let coarse = try TerrainDetail.field(preset: preset, seed: 2, level: level)
            let factor = 1 << level
            for j in 0...coarse.rows {
                for i in 0...coarse.columns {
                    #expect(coarse.height(column: i, row: j) == full.height(column: i * factor, row: j * factor))
                }
            }
            #expect(try TerrainDetail.mesh(preset: preset, seed: 2, level: level).digest
                    != (try TerrainDetail.mesh(preset: preset, seed: 2, level: 0)).digest)
        }
    }

    @Test func aLevelOutsideZeroToTwoIsRefused() {
        for level in [-1, 3, 10] {
            #expect(throws: MeshError.self) { try TerrainDetail.field(preset: .island, seed: 1, level: level) }
            #expect(throws: MeshError.self) { try TerrainDetail.mesh(preset: .island, seed: 1, level: level) }
        }
    }
}
