// TerrainGeneratorTests — feature 089 (A12-P01) T-A12-103 (FR-A12-110, FR-A12-111; clarification 3; research D3;
// SC-A12-101, SC-A12-104). The three preset recipes and the world parts, host-free and short: the presets' grids, noise
// settings and palettes; each preset's terrain is deterministic, stays within −1…1.6 m and within the mesh budget; the
// parts are the terrain in the low-land colour and (island, city) the sea plane in the sea colour; the asteroid garden
// places 6 craters and 8 mounds from its seed; a budget too small is refused before building; the digest is the
// documented hash of the parts.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct TerrainGeneratorTests {
    @Test func thePresetsHaveTheirRecipes() {
        #expect(WorldPreset.all.map(\.id) == [.island, .asteroidGarden, .miniatureCity])
        #expect(WorldPreset.all.map(\.id.contentId) == ["island", "asteroid-garden", "miniature-city"])
        #expect(WorldPreset.all.map(\.columns) == [64, 64, 48] && WorldPreset.all.map(\.rows) == [64, 64, 48])
        #expect(WorldPreset.all.map(\.octaves) == [4, 5, 2])
        #expect(WorldPreset.all.map(\.frequency) == [0.18, 0.3, 0.12])
        #expect(WorldPreset.all.map(\.hasSea) == [true, false, true])
        #expect(WorldPreset.all.map(\.cellSize) == [0.1875, 0.1875, 0.25])
        #expect(WorldPreset.all.allSatisfy { Double($0.columns) * $0.cellSize == WorldPreset.worldSize })
        #expect(WorldPreset.all.allSatisfy { ContentCatalog.bundled.palette(id: $0.paletteId) != nil })
        #expect(WorldPreset.all.allSatisfy { ContentCatalog.bundled.preset(id: $0.id.contentId)?.name == $0.name })
        #expect(WorldPreset.preset(index: 1) == .asteroidGarden)
        #expect(WorldPreset.preset(index: -1) == nil && WorldPreset.preset(index: 3) == nil)
        #expect(WorldPreset.preset(.miniatureCity) == .miniatureCity)
    }

    @Test(arguments: WorldPreset.all)
    func eachTerrainIsDeterministicWithinRangeAndBudget(preset: WorldPreset) throws {
        for seed: UInt32 in [0, 1, 7, 0xFFFF_FFFF] {
            let parts = try TerrainGenerator.parts(preset: preset, seed: seed)
            #expect(try TerrainGenerator.parts(preset: preset, seed: seed) == parts)
            let terrain = parts[0].mesh
            let vertices = (preset.columns + 1) * (preset.rows + 1)
            #expect(terrain.positions.count == vertices && terrain.indices.count == 6 * preset.columns * preset.rows)
            #expect(vertices <= MeshBudget.default.maxVertices
                    && terrain.indices.count <= MeshBudget.default.maxIndices)
            #expect(terrain.positions.allSatisfy { WorldPreset.heightRange.contains($0.y) })
            #expect(terrain.positions.allSatisfy { abs($0.x) <= 6 && abs($0.z) <= 6 })
            #expect(terrain.normals.allSatisfy { $0.y > 0 && abs($0.length - 1) < 1e-12 })
            #expect(terrain.validate(budget: .default).summary.vertices == vertices)
            let heights = terrain.positions.map(\.y)
            #expect(heights.max()! - heights.min()! > 0.5, "the terrain has relief")
            if preset.hasSea { #expect(heights.contains { $0 < 0 } && heights.contains { $0 > 0 }) }
        }
    }

    @Test func thePartsCarryThePaletteColours() throws {
        let catalog = ContentCatalog.bundled
        for preset in WorldPreset.all {
            let parts = try TerrainGenerator.parts(preset: preset, seed: 5)
            let palette = try #require(catalog.palette(id: preset.paletteId))
            #expect(parts.count <= TerrainGenerator.maxParts)
            #expect(parts.map(\.name) == (preset.hasSea ? ["terrain", "sea"] : ["terrain"]))
            #expect(parts[0].color == palette.lowLand)
            if preset.hasSea { #expect(parts[1].color == palette.sea && parts[1].mesh == TerrainGenerator.seaPlane()) }
        }
    }

    @Test func theSeaPlaneIsAFlatSquareFacingUp() {
        let sea = TerrainGenerator.seaPlane()
        #expect(sea.positions == [Vec3(-6, 0, -6), Vec3(-6, 0, 6), Vec3(6, 0, 6), Vec3(6, 0, -6)])
        #expect(sea.normals.allSatisfy { $0 == Vec3(0, 1, 0) })
        #expect(sea.uvs == [Vec2(0, 0), Vec2(0, 1), Vec2(1, 1), Vec2(1, 0)])
        #expect(sea.indices == [0, 1, 2, 0, 2, 3])
        for t in 0..<sea.triangleCount {
            let a = sea.positions[Int(sea.indices[3 * t])], b = sea.positions[Int(sea.indices[3 * t + 1])]
            let c = sea.positions[Int(sea.indices[3 * t + 2])]
            #expect((b - a).cross(c - a).y > 0, "counter-clockwise seen from +y")
        }
        #expect(TerrainGenerator.seaPlane(level: 0.5).positions.allSatisfy { $0.y == 0.5 })
    }

    @Test func theAsteroidGardenPlacesItsCratersAndMoundsFromTheSeed() throws {
        let shape = try #require(WorldPreset.asteroidGarden.shape(seed: 9))
        #expect(shape.craters.count == 6 && shape.mounds.count == 8)
        let r = WorldShape.featureRadius
        #expect((shape.craters + shape.mounds).allSatisfy { $0.x * $0.x + $0.z * $0.z <= r * r })
        #expect(shape.craters.allSatisfy { (0.6...1.4).contains($0.radius) && $0.amplitude == 0.35 * $0.radius })
        #expect(shape.mounds.allSatisfy { (0.4...0.9).contains($0.radius) && (0.25...0.55).contains($0.amplitude) })
        let again = try #require(WorldPreset.asteroidGarden.shape(seed: 9))
        #expect(again.craters == shape.craters && again.mounds == shape.mounds)
        let other = try #require(WorldPreset.asteroidGarden.shape(seed: 10))
        #expect(other.craters != shape.craters)
        #expect(shape.height(x: 6, z: 6) == -1 && shape.height(x: -5, z: -5) == -1, "the void outside the disc")
        let island = try #require(WorldPreset.island.shape(seed: 9))
        #expect(island.craters.isEmpty && island.mounds.isEmpty)
        #expect(island.height(x: 6, z: 6) < 0, "the island's corners are under the sea")
        let city = try #require(WorldPreset.miniatureCity.shape(seed: 9))
        #expect(city.height(x: 6, z: 6) == -0.6)
    }

    @Test func theCityIsTerraced() throws {
        let shape = try #require(WorldPreset.miniatureCity.shape(seed: 4))
        for i in -16...16 {
            for j in -16...16 {
                let h = shape.height(x: Double(i) * 0.25, z: Double(j) * 0.25)
                let steps = (h - 0.1) / WorldShape.terraceStep
                #expect(abs(steps - steps.rounded()) < 1e-9, "plateau heights are 0.1 + k × 0.35 m")
            }
        }
    }

    @Test func aBudgetTooSmallIsRefusedBeforeBuilding() {
        let tiny = MeshBudget(maxVertices: 100, maxIndices: 100)
        #expect(throws: MeshError.self) { try TerrainGenerator.parts(preset: .island, seed: 1, budget: tiny) }
    }

    @Test func theDigestIsTheHashOfThePartDigests() throws {
        let parts = try TerrainGenerator.parts(preset: .island, seed: 2)
        let text = "terrain:\(parts[0].mesh.digest)\nsea:\(parts[1].mesh.digest)"
        #expect(TerrainGenerator.digest(of: parts) == StableHash.sha256Hex(Array(text.utf8)))
        #expect(try TerrainGenerator.digest(preset: .island, seed: 2) == TerrainGenerator.digest(of: parts))
        var recoloured = parts
        recoloured[0].color = RGBA(1, 0, 0)
        #expect(TerrainGenerator.digest(of: recoloured) == TerrainGenerator.digest(of: parts), "colours not pinned")
        let field = try TerrainGenerator.heightField(preset: .island, seed: 2)
        #expect(field.columns == 64 && field.originX == -6 && field.originZ == -6 && field.cellSize == 0.1875)
    }
}
