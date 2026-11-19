// EffectReference — feature 180 (A25-P01) T-A25-107 (FR-A25-104, FR-A25-105; SC-A25-103, SC-A25-104; clarifications
// Q1, Q4; research R2). The CPU picture of each effect, computed with the formulas of clarification Q1 in `Float` on
// the stored values x = byte/255, so each effect's fragment program (`EffectPrograms`) can be checked against it:
//
//   grade      y = x·2^exposure; y = (y − 0.5)·contrast + 0.5; L = 0.2126 r + 0.7152 g + 0.0722 b of y;
//              y = L + (y − L)·saturation
//   blur       the mean of the (2·radius + 1)² texel centres around the pixel, each index clamped to the picture
//   distort    the bilinear sample at uv + amplitude·(sin(2π·frequency·uv.y), sin(2π·frequency·uv.x))
//   vignette   d = 2·‖uv − 0.5‖/√2; rgb·(1 − amount·smoothstep(radius − softness, radius, d))
//   posterize  y = floor(x·(levels − 1) + 0.5)/(levels − 1)
//
// Every result is clamped to 0…1 and stored as round(y·255); alpha is kept. A disabled node returns the picture
// unchanged; a chain applies its enabled nodes in order, storing 8-bit values between nodes as the GPU's `.rgba8`
// targets do.
// Choices recorded here: the texture coordinate uv is the GL one, origin at the bottom-left, at texel centres:
// uv = ((x + 0.5)/w, 1 − (y + 0.5)/h) for column x and top-down row y, which is `v_uv` of `FieldPass` when the
// picture is uploaded with its rows flipped to bottom-up. Bilinear sampling follows GL `LINEAR` with clamp to edge
// (texel centres at (i + 0.5)/w, indices clamped). A value missing from a node (an unvalidated node) falls back to the
// parameter's default of clarification Q1. Pure Swift; no UI, GPU or clock.
import Foundation

/// The CPU reference of every effect (clarification Q1).
public enum EffectReference {
    /// The picture `node` makes of `image`; `image` itself when the node is disabled.
    public static func apply(_ node: EffectNode, to image: RGBAImage) -> RGBAImage {
        guard node.enabled else { return image }
        let source = FloatPicture(image)
        let w = image.width, h = image.height
        var out = image
        for y in 0..<h {
            for x in 0..<w {
                let uv = SIMD2<Float>((Float(x) + 0.5) / Float(w), 1 - (Float(y) + 0.5) / Float(h))
                let input = source.texel(x, y)
                var rgb: SIMD3<Float>
                switch node.effect {
                case .grade: rgb = grade(input, node)
                case .blur: rgb = blur(source, x, y, node)
                case .distort: rgb = distort(source, uv, node)
                case .vignette: rgb = vignette(input, uv, node)
                case .posterize: rgb = posterize(input, node)
                }
                rgb = clamp01(rgb)
                let i = out.offset(x: x, y: y)
                out.bytes[i] = store(rgb.x)
                out.bytes[i + 1] = store(rgb.y)
                out.bytes[i + 2] = store(rgb.z)
            }
        }
        return out
    }

    /// The picture the enabled nodes of `chain` make of `image`, applied in order.
    public static func apply(_ chain: EffectChain, to image: RGBAImage) -> RGBAImage {
        var picture = image
        for node in chain.nodes where node.enabled { picture = apply(node, to: picture) }
        return picture
    }

    /// The 8-bit value stored for `value` in 0…1: round(value·255).
    static func store(_ value: Float) -> UInt8 { UInt8((min(max(value, 0), 1) * 255).rounded()) }

    /// Each component clamped to 0…1.
    static func clamp01(_ v: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(min(max(v.x, 0), 1), min(max(v.y, 0), 1), min(max(v.z, 0), 1))
    }

    /// `grade` of one pixel.
    static func grade(_ x: SIMD3<Float>, _ node: EffectNode) -> SIMD3<Float> {
        let exposure = NodeValues.value(node, "exposure")
        let contrast = NodeValues.value(node, "contrast")
        let saturation = NodeValues.value(node, "saturation")
        var y = x * exp2f(exposure)
        y = (y - SIMD3(repeating: 0.5)) * contrast + SIMD3(repeating: 0.5)
        let l = 0.2126 * y.x + 0.7152 * y.y + 0.0722 * y.z
        return SIMD3(repeating: l) + (y - SIMD3(repeating: l)) * saturation
    }

    /// `blur` of the pixel at column `x`, top-down row `y`.
    static func blur(_ source: FloatPicture, _ x: Int, _ y: Int, _ node: EffectNode) -> SIMD3<Float> {
        let r = min(max(Int(NodeValues.value(node, "radius").rounded()), 0), 8)
        var sum = SIMD3<Float>(repeating: 0)
        for j in -r...r {
            for i in -r...r { sum += source.texel(x + i, y + j) }
        }
        let count = Float((2 * r + 1) * (2 * r + 1))
        return sum / count
    }

    /// `distort` at texture coordinate `uv` (GL convention).
    static func distort(_ source: FloatPicture, _ uv: SIMD2<Float>, _ node: EffectNode) -> SIMD3<Float> {
        let amplitude = NodeValues.value(node, "amplitude")
        let frequency = NodeValues.value(node, "frequency")
        let twoPi = 2 * Float.pi
        let at = uv + amplitude * SIMD2(sinf(twoPi * frequency * uv.y), sinf(twoPi * frequency * uv.x))
        return source.bilinear(at)
    }

    /// `vignette` of one pixel at texture coordinate `uv`.
    static func vignette(_ x: SIMD3<Float>, _ uv: SIMD2<Float>, _ node: EffectNode) -> SIMD3<Float> {
        let amount = NodeValues.value(node, "amount")
        let radius = NodeValues.value(node, "radius")
        let softness = NodeValues.value(node, "softness")
        let c = uv - SIMD2(repeating: 0.5)
        let d = 2 * (c.x * c.x + c.y * c.y).squareRoot() / Float(2).squareRoot()
        let e0 = radius - softness
        let t = min(max((d - e0) / (radius - e0), 0), 1)
        let s = t * t * (3 - 2 * t)
        return x * (1 - amount * s)
    }

    /// `posterize` of one pixel.
    static func posterize(_ x: SIMD3<Float>, _ node: EffectNode) -> SIMD3<Float> {
        let steps = max(NodeValues.value(node, "levels").rounded() - 1, 1)
        let q = (x * steps + SIMD3(repeating: 0.5)).rounded(.down)
        return q / steps
    }
}

/// A picture as floats x = byte/255 in RGB, rows top-down, with clamped texel and bilinear reads.
struct FloatPicture {
    /// Width in pixels.
    let width: Int
    /// Height in pixels.
    let height: Int
    /// RGB values, row 0 (top) first.
    let values: [SIMD3<Float>]

    /// The RGB floats of `image`.
    init(_ image: RGBAImage) {
        width = image.width
        height = image.height
        var values: [SIMD3<Float>] = []
        values.reserveCapacity(width * height)
        for i in stride(from: 0, to: image.bytes.count, by: 4) {
            values.append(SIMD3(Float(image.bytes[i]), Float(image.bytes[i + 1]), Float(image.bytes[i + 2])) / 255)
        }
        self.values = values
    }

    /// The texel at column `x` and top-down row `y`, each index clamped to the picture (clamp to edge).
    func texel(_ x: Int, _ y: Int) -> SIMD3<Float> {
        values[min(max(y, 0), height - 1) * width + min(max(x, 0), width - 1)]
    }

    /// GL `LINEAR` sampling with clamp to edge at texture coordinate `uv` (origin bottom-left).
    func bilinear(_ uv: SIMD2<Float>) -> SIMD3<Float> {
        let tx = uv.x * Float(width) - 0.5
        let ty = uv.y * Float(height) - 0.5
        let x0 = tx.rounded(.down), y0 = ty.rounded(.down)
        let fx = tx - x0, fy = ty - y0
        let ix = Int(x0), iy = Int(y0)
        // Bottom-up texel row r is top-down row height − 1 − r.
        func at(_ i: Int, _ r: Int) -> SIMD3<Float> { texel(i, height - 1 - min(max(r, 0), height - 1)) }
        let bottom = at(ix, iy) * (1 - fx) + at(ix + 1, iy) * fx
        let top = at(ix, iy + 1) * (1 - fx) + at(ix + 1, iy + 1) * fx
        return bottom * (1 - fy) + top * fy
    }
}

/// Reads a node's parameter values as `Float`.
enum NodeValues {
    /// The value of parameter `name` of `node`, or the parameter's default (clarification Q1) when it is missing.
    static func value(_ node: EffectNode, _ name: String) -> Float {
        Float(node.values[name] ?? node.definition.parameter(named: name)?.defaultValue ?? 0)
    }
}
