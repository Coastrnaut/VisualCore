// TerrainColoringTests — feature 090 (A12-P02) T-A12-204 (FR-A12-220; clarification 4; research D4). The height bands
// of the terrain colours, host-free and short: below sea level the low land darkened by 25 % (island, miniature city);
// 0…0.1 m low land; 0.1…1.2 m a linear blend to high land, clamped above; the asteroid garden's edge from −0.5 m to
// −1 m blends to the void colour and has no underwater shade; every colour is in 0…1 with alpha 1, one per vertex,
// and the colouring of a terrain mesh is deterministic.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath

@Suite struct TerrainColoringTests {
    /// A palette with easily told colours: void/sea, low land, high land.
    private let palette = Palette(id: "test", name: "Test",
                                  colors: [RGBA(0.0, 0.2, 0.6), RGBA(0.4, 0.6, 0.2), RGBA(0.8, 0.8, 0.8)],
                                  author: "VisualCore project", license: "MIT")

    private func near(_ a: Vec4, _ b: Vec4, _ tolerance: Double = 1e-12) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
            && abs(a.w - b.w) <= tolerance
    }

    @Test(arguments: [WorldPreset.island, WorldPreset.miniatureCity])
    func seaWorldsShadeTheLowLandUnderwaterAndBlendUpwards(preset: WorldPreset) {
        func c(_ h: Double) -> Vec4 { TerrainColoring.color(height: h, palette: palette, preset: preset) }
        let low = Vec4(0.4, 0.6, 0.2, 1), high = Vec4(0.8, 0.8, 0.8, 1), shaded = Vec4(0.3, 0.45, 0.15, 1)
        #expect(near(c(-0.6), shaded) && near(c(-1), shaded) && near(c(-1e-9), shaded))
        #expect(near(c(0), low) && near(c(0.05), low) && near(c(0.1), low))
        #expect(near(c(0.65), Vec4(0.6, 0.7, 0.5, 1)), "half way between 0.1 m and 1.2 m")
        #expect(near(c(1.2), high) && near(c(1.6), high) && near(c(5), high))
    }

    @Test func theAsteroidEdgeFadesIntoTheVoid() {
        func c(_ h: Double) -> Vec4 { TerrainColoring.color(height: h, palette: palette, preset: .asteroidGarden) }
        let low = Vec4(0.4, 0.6, 0.2, 1), void = Vec4(0.0, 0.2, 0.6, 1)
        #expect(near(c(-0.3), low) && near(c(-0.5), low), "no underwater shade without a sea")
        #expect(near(c(-0.75), Vec4(0.2, 0.4, 0.4, 1)), "half way between −0.5 m and −1 m")
        #expect(near(c(-1), void) && near(c(-3), void))
        #expect(near(c(0.65), Vec4(0.6, 0.7, 0.5, 1)))
    }

    @Test func nonFiniteHeightsAndOutOfRangePalettesStayValid() {
        #expect(near(TerrainColoring.color(height: .nan, palette: palette, preset: .island), Vec4(0.4, 0.6, 0.2, 1)))
        let wild = Palette(id: "wild", name: "Wild", colors: [RGBA(-1, 2, .nan), RGBA(3, -2, 0.5), RGBA(9, 9, 9)],
                           author: "VisualCore project", license: "MIT")
        for h in stride(from: -1.5, through: 2.0, by: 0.05) {
            for preset in WorldPreset.all {
                let c = TerrainColoring.color(height: h, palette: wild, preset: preset)
                #expect([c.x, c.y, c.z].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } && c.w == 1)
            }
        }
    }

    @Test(arguments: WorldPreset.all)
    func terrainColoursAreOnePerVertexInRangeAndDeterministic(preset: WorldPreset) throws {
        let palette = try #require(ContentCatalog.bundled.palette(id: preset.paletteId))
        let mesh = try TerrainDetail.mesh(preset: preset, seed: 1, level: 0)
        let colors = TerrainColoring.colors(mesh: mesh, palette: palette, preset: preset)
        #expect(colors.count == mesh.positions.count)
        #expect(colors.allSatisfy { [$0.x, $0.y, $0.z, $0.w].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } })
        #expect(colors.allSatisfy { $0.w == 1 })
        #expect(colors == TerrainColoring.colors(mesh: mesh, palette: palette, preset: preset))
        #expect(colors == TerrainColoring.colors(heights: mesh.positions.map(\.y), palette: palette, preset: preset))
        #expect(Set(colors).count > 1, "a world has more than one colour")
    }
}
