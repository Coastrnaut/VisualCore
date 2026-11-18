// TextureRecipeTests — feature 161 (A22-P03) T-A22-303 (FR-A22-304; SC-A22-304; clarification Q4; P00 contract
// G-TEXTURES). The three recipes (`checker`, `ramp`, `noise`, choices 0, 1, 2) each give 64 × 64 RGBA values, all
// finite in 0…1 with alpha 1, the same on every call and pairwise different; the checker has exact 0.85 and 0.25
// cells with a boundary at x = 8; the ramp runs from deep blue to warm orange with red rising; the noise spreads and
// tiles seamlessly; and each recipe's checksum (FNV-1a 64 over the uploaded bytes) is pinned so a change is caught.
import ShaderStudioCore
import Testing

@Suite struct TextureRecipeTests {
    /// The value at channel `c` of pixel (x, y) (row 0 at the bottom).
    private func value(_ pixels: [Float], x: Int, y: Int, c: Int) -> Float {
        pixels[(y * TextureRecipes.size + x) * 4 + c]
    }

    @Test func recipesAreInChoiceOrderWithTitles() {
        #expect(TextureRecipes.all == [.checker, .ramp, .noise])
        #expect(TextureRecipes.all.map(\.rawValue) == [0, 1, 2])
        #expect(TextureRecipes.all.map(\.title) == ["Checker", "Ramp", "Noise"])
        #expect(TextureRecipes.recipe(at: 1) == .ramp)
        #expect(TextureRecipes.recipe(at: 3) == nil)
        #expect(TextureRecipes.recipe(at: -1) == nil)
    }

    @Test(arguments: TextureRecipe.allCases)
    func recipeHasSizeRangeAlphaAndIsDeterministic(_ recipe: TextureRecipe) {
        let pixels = recipe.pixels
        #expect(TextureRecipes.size == 64)
        #expect(pixels.count == 64 * 64 * 4)
        #expect(TextureRecipes.valueCount == pixels.count)
        #expect(pixels.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }, "\(recipe)")
        #expect(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 1 }, "\(recipe) alpha")
        #expect(pixels == TextureRecipes.pixels(recipe), "\(recipe) deterministic")
        #expect(TextureRecipes.bytes(recipe).count == pixels.count)
        #expect(TextureRecipes.checksum(recipe) == TextureRecipes.checksum(recipe))
    }

    @Test func recipesDifferPairwise() {
        let all = TextureRecipes.all
        for i in all.indices {
            for j in all.indices where j > i {
                #expect(all[i].pixels != all[j].pixels, "\(all[i]) vs \(all[j])")
                #expect(TextureRecipes.checksum(all[i]) != TextureRecipes.checksum(all[j]))
            }
        }
    }

    @Test func checksumsArePinned() {
        #expect(TextureRecipes.checksum(.checker) == 0x0998_7C12_CC16_2325)
        #expect(TextureRecipes.checksum(.ramp) == 0xC983_0D4E_D593_2925)
        #expect(TextureRecipes.checksum(.noise) == 0xF86F_7F29_7C72_13E2)
    }

    @Test func checkerCellsAreExact() {
        let pixels = TextureRecipe.checker.pixels
        for c in 0..<3 {
            #expect(value(pixels, x: 0, y: 0, c: c) == 0.85)
            #expect(value(pixels, x: 7, y: 7, c: c) == 0.85)
            #expect(value(pixels, x: 8, y: 0, c: c) == 0.25)
            #expect(value(pixels, x: 0, y: 8, c: c) == 0.25)
            #expect(value(pixels, x: 8, y: 8, c: c) == 0.85)
            #expect(value(pixels, x: 63, y: 0, c: c) == 0.25)
            #expect(value(pixels, x: 63, y: 63, c: c) == 0.85)
        }
        let greys = Set(stride(from: 0, to: pixels.count, by: 4).map { pixels[$0] })
        #expect(greys == [0.85, 0.25])
    }

    @Test func rampRunsFromBlueToOrangeWithRedRising() {
        let pixels = TextureRecipe.ramp.pixels
        let left: [Float] = [0.05, 0.10, 0.40]
        let right: [Float] = [0.95, 0.55, 0.20]
        for c in 0..<3 {
            #expect(abs(value(pixels, x: 0, y: 0, c: c) - left[c]) < 0.02, "left channel \(c)")
            #expect(abs(value(pixels, x: 63, y: 63, c: c) - right[c]) < 0.02, "right channel \(c)")
        }
        for x in 1..<TextureRecipes.size {
            #expect(value(pixels, x: x, y: 10, c: 0) > value(pixels, x: x - 1, y: 10, c: 0), "red rises at \(x)")
        }
        for y in 1..<TextureRecipes.size {
            #expect(value(pixels, x: 20, y: y, c: 0) == value(pixels, x: 20, y: 0, c: 0), "constant in y at \(y)")
        }
    }

    @Test func noiseSpreadsIsGreyAndTiles() {
        let pixels = TextureRecipe.noise.pixels
        let size = TextureRecipes.size
        var greys: [Float] = []
        for i in stride(from: 0, to: pixels.count, by: 4) {
            #expect(pixels[i] == pixels[i + 1] && pixels[i] == pixels[i + 2])
            greys.append(pixels[i])
        }
        let low = greys.min() ?? 0
        let high = greys.max() ?? 0
        #expect(high - low > 0.5, "spread \(low)…\(high)")
        // Seamless: the step across the wrap (column 63 to column 0, row 63 to row 0) is no larger than the largest
        // step between neighbours inside the tile.
        var inside: Float = 0
        var across: Float = 0
        for a in 0..<size {
            for b in 1..<size {
                inside = max(inside, abs(value(pixels, x: b, y: a, c: 0) - value(pixels, x: b - 1, y: a, c: 0)))
                inside = max(inside, abs(value(pixels, x: a, y: b, c: 0) - value(pixels, x: a, y: b - 1, c: 0)))
            }
            across = max(across, abs(value(pixels, x: 0, y: a, c: 0) - value(pixels, x: size - 1, y: a, c: 0)))
            across = max(across, abs(value(pixels, x: a, y: 0, c: 0) - value(pixels, x: a, y: size - 1, c: 0)))
        }
        #expect(inside > 0)
        #expect(across <= inside, "wrap step \(across), largest inside step \(inside)")
    }
}
