// TextureRecipes — feature 161 (A22-P03) T-A22-302 (FR-A22-304; clarification Q4; data-model.md "TextureRecipes").
// The three textures Shader Studio's texture inputs sample, made in code: each recipe gives 64 × 64 RGBA float
// values in 0…1, rows bottom-up (row 0 is the bottom row, as `RenderTarget.upload(rgbaFloats:)` expects), alpha 1:
//
//   checker  8 × 8 pixel cells alternating 0.85 grey (the bottom-left cell) and 0.25 grey;
//   ramp     a horizontal ramp from (0.05, 0.10, 0.40) at the left to (0.95, 0.55, 0.20) at the right, linear in x
//            over the column centres;
//   noise    grey value noise: an integer hash gives one value per point of an 8 × 8 lattice (one point every
//            8 pixels, wrapping at the edges so the tile repeats seamlessly), smoothstep-interpolated between points.
//
// Each recipe also has a checksum (FNV-1a 64 over its values quantized to bytes as uploaded, `round(v * 255)`), which
// the tests pin so that any change of a recipe is caught (P00 contract, G-TEXTURES).
// Choices recorded here: the indices 0 checker, 1 ramp, 2 noise are the `texture.set` choices; the hash is a fixed
// 32-bit integer mix (no randomness API), so every call returns the same values. Pure Foundation; no UI, GPU or clock.
import Foundation

/// One texture made in code (clarification Q4); the raw value is the `texture.set` choice.
public enum TextureRecipe: Int, CaseIterable, Sendable, Equatable {
    /// 8 × 8 pixel cells alternating 0.85 and 0.25 grey.
    case checker = 0
    /// A horizontal ramp from deep blue at the left to warm orange at the right.
    case ramp = 1
    /// A seamless grey value-noise tile from an integer hash over an 8 × 8 lattice.
    case noise = 2

    /// Short user-facing title.
    public var title: String {
        switch self {
        case .checker: return "Checker"
        case .ramp: return "Ramp"
        case .noise: return "Noise"
        }
    }

    /// The recipe's ``TextureRecipes/size`` × ``TextureRecipes/size`` RGBA values (0…1, rows bottom-up, alpha 1).
    public var pixels: [Float] { TextureRecipes.pixels(self) }
}

/// The texture recipes and how their pixels are made (feature 161, clarification Q4).
public enum TextureRecipes {
    /// The width and height of every texture, in pixels.
    public static let size = 64

    /// The number of values of one texture: `size * size * 4`.
    public static let valueCount = size * size * 4

    /// The side of one checker cell, in pixels.
    public static let checkerCell = 8

    /// The checker's light grey (the bottom-left cell) and dark grey.
    public static let checkerLight: Float = 0.85
    /// The checker's dark grey.
    public static let checkerDark: Float = 0.25

    /// The ramp's colour at the left edge.
    public static let rampLeft: SIMD3<Float> = SIMD3(0.05, 0.10, 0.40)
    /// The ramp's colour at the right edge.
    public static let rampRight: SIMD3<Float> = SIMD3(0.95, 0.55, 0.20)

    /// The number of noise lattice points along each side (one every `size / noiseLattice` pixels).
    public static let noiseLattice = 8

    /// Every recipe, in choice order (checker, ramp, noise).
    public static let all: [TextureRecipe] = TextureRecipe.allCases

    /// The recipe for choice `index`, or nil outside 0…2.
    public static func recipe(at index: Int) -> TextureRecipe? { TextureRecipe(rawValue: index) }

    /// The ``valueCount`` RGBA values of `recipe`: pixel (x, y) starts at `(y * size + x) * 4`, row 0 at the bottom.
    public static func pixels(_ recipe: TextureRecipe) -> [Float] {
        var values = [Float](repeating: 1, count: valueCount)
        for y in 0..<size {
            for x in 0..<size {
                let rgb = colour(recipe, x: x, y: y)
                let base = (y * size + x) * 4
                values[base] = rgb.x
                values[base + 1] = rgb.y
                values[base + 2] = rgb.z
                values[base + 3] = 1
            }
        }
        return values
    }

    /// The ``valueCount`` bytes of `recipe` as they are uploaded to an `.rgba8` target: each value becomes
    /// `round(v * 255)`, clamped to 0…255.
    public static func bytes(_ recipe: TextureRecipe) -> [UInt8] {
        pixels(recipe).map { UInt8(min(max(($0 * 255).rounded(), 0), 255)) }
    }

    /// The checksum of `recipe`: FNV-1a 64 over ``bytes(_:)`` in order; a change of a recipe changes it.
    public static func checksum(_ recipe: TextureRecipe) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in bytes(recipe) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// The RGB colour of pixel (x, y) of `recipe`.
    static func colour(_ recipe: TextureRecipe, x: Int, y: Int) -> SIMD3<Float> {
        switch recipe {
        case .checker:
            let grey = (x / checkerCell + y / checkerCell) % 2 == 0 ? checkerLight : checkerDark
            return SIMD3(repeating: grey)
        case .ramp:
            let t = (Float(x) + 0.5) / Float(size)
            return rampLeft + (rampRight - rampLeft) * t
        case .noise:
            return SIMD3(repeating: noise(x: x, y: y))
        }
    }

    /// The value noise at the centre of pixel (x, y): the four surrounding lattice values (wrapping), blended with
    /// smoothstep weights; in 0…1.
    static func noise(x: Int, y: Int) -> Float {
        let step = Float(size / noiseLattice)
        let fx = (Float(x) + 0.5) / step
        let fy = (Float(y) + 0.5) / step
        let ix = Int(fx.rounded(.down))
        let iy = Int(fy.rounded(.down))
        let tx = smoothstep(fx - Float(ix))
        let ty = smoothstep(fy - Float(iy))
        let v00 = lattice(ix, iy)
        let v10 = lattice(ix + 1, iy)
        let v01 = lattice(ix, iy + 1)
        let v11 = lattice(ix + 1, iy + 1)
        let bottom = v00 + (v10 - v00) * tx
        let top = v01 + (v11 - v01) * tx
        return min(max(bottom + (top - bottom) * ty, 0), 1)
    }

    /// The hash value (0…1) of lattice point (i, j), wrapped into the 8 × 8 lattice so the tile repeats.
    static func lattice(_ i: Int, _ j: Int) -> Float {
        let n = noiseLattice
        let wi = UInt32(((i % n) + n) % n)
        let wj = UInt32(((j % n) + n) % n)
        return Float(hash(wi, wj) & 0xFFFF) / 65_535
    }

    /// A fixed 32-bit integer mix of (i, j); the same inputs always give the same output.
    static func hash(_ i: UInt32, _ j: UInt32) -> UInt32 {
        var h = i &* 374_761_393 &+ j &* 668_265_263 &+ 0x9E37_79B9
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return h
    }

    /// The smoothstep weight `t * t * (3 - 2t)` of `t` in 0…1.
    static func smoothstep(_ t: Float) -> Float { t * t * (3 - 2 * t) }
}
