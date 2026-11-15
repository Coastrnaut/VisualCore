// SurfaceRecipeTests — feature 105 (A14-P03) T-A14-302 (FR-A14-301; SC-A14-301; clarification Q1; research D1). The
// nine procedural surfaces on a 48 × 24 UV sphere whose vertices are laid out exactly as `Mesh.uvSphere` lays them
// out (MeshGenerators.swift: rings j = 0…24 from the north pole, columns i = 0…48, n = (sin θ sin φ, cos θ,
// sin θ cos φ)); the test target does not depend on VisualCoreScenes, so the layout is replicated here. Checked:
// recipes in catalog order with seeds 0xA14_0000 + index; digests stable and pairwise distinct; seam columns and pole
// rows identical; no colour step across the date line larger than the largest neighbour step elsewhere; every channel
// 0…1; Earth has ocean, land and polar white; the Sun is bright.
import Foundation
import SolarSystemExplorerCore
import Testing
import VisualCoreMath

@Suite struct SurfaceRecipeTests {
    static let segments: Int = 48
    static let rings: Int = 24

    /// The positions of `Mesh.uvSphere(segments: 48, rings: 24, radius:)`, row-major from the north pole.
    static func spherePositions(radius: Double = 1) -> [Vec3] {
        var positions: [Vec3] = []
        for j in 0...rings {
            let v = Double(j) / Double(rings), theta = v * Double.pi
            for i in 0...segments {
                let u = Double(i) / Double(segments), phi = u * 2 * Double.pi
                let n = Vec3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                positions.append(n * radius)
            }
        }
        return positions
    }

    static func index(ring j: Int, column i: Int) -> Int { j * (segments + 1) + i }

    @Test func recipesFollowTheCatalogWithTheirSeeds() throws {
        let bodies: [CelestialBody] = BodyCatalog.bundled.bodies
        #expect(SurfaceRecipe.bundled.count == bodies.count)
        for (index, body) in bodies.enumerated() {
            let recipe: SurfaceRecipe = SurfaceRecipe.bundled[index]
            #expect(recipe.bodyID == body.id)
            #expect(recipe.seed == 0xA14_0000 + UInt64(index))
            #expect(recipe.noise.seed == recipe.seed)
            #expect(SurfaceRecipe.recipe(bodyID: body.id) == recipe)
        }
        #expect(SurfaceRecipe.recipe(bodyID: "pluto") == nil)
        let sun: SurfaceRecipe = try #require(SurfaceRecipe.recipe(bodyID: "sun"))
        let earth: SurfaceRecipe = try #require(SurfaceRecipe.recipe(bodyID: "earth"))
        let jupiter: SurfaceRecipe = try #require(SurfaceRecipe.recipe(bodyID: "jupiter"))
        let saturn: SurfaceRecipe = try #require(SurfaceRecipe.recipe(bodyID: "saturn"))
        #expect(sun.style == .emissive && earth.style == .oceanWorld)
        #expect(jupiter.bands == 9 && saturn.bands == 7)
    }

    @Test func digestsAreStableAndPairwiseDistinct() {
        let positions: [Vec3] = SurfaceRecipeTests.spherePositions()
        let scaled: [Vec3] = SurfaceRecipeTests.spherePositions(radius: 4.2)
        var digests: [String] = []
        for recipe in SurfaceRecipe.bundled {
            let first: String = recipe.digest(for: positions)
            #expect(first.count == 64)
            #expect(recipe.digest(for: positions) == first, "\(recipe.bodyID) stable")
            #expect(recipe.digest(for: scaled) == first, "\(recipe.bodyID) independent of radius")
            digests.append(first)
        }
        #expect(Set(digests).count == digests.count)
    }

    @Test func seamColumnsAndPoleRowsAreIdentical() {
        let positions: [Vec3] = SurfaceRecipeTests.spherePositions(radius: 2.5)
        let s: Int = SurfaceRecipeTests.segments
        for recipe in SurfaceRecipe.bundled {
            let colors: [SurfaceColor] = recipe.colors(for: positions)
            #expect(colors.count == positions.count)
            for j in 0...SurfaceRecipeTests.rings {
                let first = colors[SurfaceRecipeTests.index(ring: j, column: 0)]
                let last = colors[SurfaceRecipeTests.index(ring: j, column: s)]
                #expect(first == last, "\(recipe.bodyID) seam ring \(j)")
            }
            for j in [0, SurfaceRecipeTests.rings] {
                let pole = colors[SurfaceRecipeTests.index(ring: j, column: 0)]
                for i in 0...s {
                    #expect(colors[SurfaceRecipeTests.index(ring: j, column: i)] == pole, "\(recipe.bodyID) pole \(j)")
                }
            }
        }
    }

    @Test func dateLineStepIsNoLargerThanStepsElsewhere() {
        let positions: [Vec3] = SurfaceRecipeTests.spherePositions()
        let s: Int = SurfaceRecipeTests.segments
        for recipe in SurfaceRecipe.bundled {
            let colors: [SurfaceColor] = recipe.colors(for: positions)
            var dateLine: Double = 0
            var elsewhere: Double = 0
            for j in 0...SurfaceRecipeTests.rings {
                for i in 0..<s {
                    let step: Double = colors[SurfaceRecipeTests.index(ring: j, column: i)]
                        .distance(to: colors[SurfaceRecipeTests.index(ring: j, column: i + 1)])
                    if i == 0 || i == s - 1 { dateLine = max(dateLine, step) } else { elsewhere = max(elsewhere, step) }
                }
            }
            for j in 0..<SurfaceRecipeTests.rings {
                for i in 0...s {
                    let step: Double = colors[SurfaceRecipeTests.index(ring: j, column: i)]
                        .distance(to: colors[SurfaceRecipeTests.index(ring: j + 1, column: i)])
                    elsewhere = max(elsewhere, step)
                }
            }
            #expect(dateLine <= elsewhere, "\(recipe.bodyID): date line \(dateLine), elsewhere \(elsewhere)")
        }
    }

    @Test func everyChannelStaysInTheUnitRange() {
        let positions: [Vec3] = SurfaceRecipeTests.spherePositions()
        for recipe in SurfaceRecipe.bundled {
            for color in recipe.colors(for: positions) {
                let channels: [Double] = [color.r, color.g, color.b, color.a]
                for channel in channels {
                    #expect(channel >= 0 && channel <= 1, "\(recipe.bodyID)")
                }
            }
            let fallback: SurfaceColor = recipe.color(at: Vec3(.nan, 0, 0))
            #expect(fallback == recipe.color(at: Vec3(0, 1, 0)))
        }
        let clamped = SurfaceColor(r: 2, g: -1, b: .nan, a: 0.5)
        #expect(clamped.r == 1 && clamped.g == 0 && clamped.b == 0 && clamped.a == 0.5)
    }

    @Test func earthHasOceanLandAndPolarWhite() throws {
        let earth: SurfaceRecipe = try #require(SurfaceRecipe.recipe(bodyID: "earth"))
        let positions: [Vec3] = SurfaceRecipeTests.spherePositions()
        let colors: [SurfaceColor] = earth.colors(for: positions)
        var ocean: Int = 0
        var land: Int = 0
        var polarWhite: Int = 0
        var polarCount: Int = 0
        for (index, color) in colors.enumerated() {
            let direction: Vec3 = positions[index]
            if abs(direction.y) > 0.88 {
                polarCount += 1
                if color.r > 0.9 && color.g > 0.9 && color.b > 0.9 { polarWhite += 1 }
            } else if color.b > color.r && color.b > color.g {
                ocean += 1
            } else {
                land += 1
            }
        }
        #expect(ocean > 50, "ocean \(ocean)")
        #expect(land > 50, "land \(land)")
        #expect(polarCount > 0 && polarWhite == polarCount)
    }

    @Test func theSunIsBright() throws {
        let sun: SurfaceRecipe = try #require(SurfaceRecipe.recipe(bodyID: "sun"))
        let colors: [SurfaceColor] = sun.colors(for: SurfaceRecipeTests.spherePositions())
        var total: Double = 0
        for color in colors { total += color.luminance }
        #expect(total / Double(colors.count) > 0.6)
    }
}
