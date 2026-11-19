// EffectReference — feature 180 (A25-P01) T-A25-107 (FR-A25-104, FR-A25-105; SC-A25-103, SC-A25-104; clarifications
// Q1, Q4; research R2), changed by feature 184 (A25-P05) T-A25-502 (clarification Q1; research R1, R2, R4). The CPU
// picture of each effect, computed with the formulas of clarification Q1 in `Float`, so each effect's fragment program
// (`EffectPrograms`) can be checked against it. The stored values are x = byte/255 (sRGB-encoded). Since A25-P05 the
// linear effects (grade, blur, vignette; `EffectID.colorDomain`) decode every value they read with `SRGB.decode`,
// compute on linear light c and encode the result with `SRGB.encode`; distort and posterize work on x:
//
//   grade      y = c·2^exposure; y = (y − 0.18)·contrast + 0.18; L = 0.2126 r + 0.7152 g + 0.0722 b of y;
//              y = L + (y − L)·saturation  (A25-P05: linear light, pivot 0.18 instead of 0.5 on stored values)
//   blur       the mean of the linear values of the (2·radius + 1)² texel centres around the pixel, each index
//              clamped to the picture
//   distort    the bilinear sample of x at uv + amplitude·(sin(2π·frequency·uv.y), sin(2π·frequency·uv.x))
//   vignette   d = 2·‖uv − 0.5‖/√2; c·(1 − amount·smoothstep(radius − softness, radius, d))
//   posterize  y = floor(x·(levels − 1) + 0.5)/(levels − 1)
//
// Every result is clamped to 0…1 (encoding clamps as `vc_srgbEncode` does); alpha is kept. A disabled node returns
// the picture unchanged; a chain applies its enabled nodes in order, storing the picture between nodes as the GPU's
// intermediates do: 8-bit (`ReferenceStorage.byte`, `.rgba8`) or half-float (`.half`, `.rgba16f`), and the result
// as 8-bit (the result target is `.rgba8`).
// Choices recorded here: the texture coordinate uv is the GL one, origin at the bottom-left, at texel centres:
// uv = ((x + 0.5)/w, 1 − (y + 0.5)/h) for column x and top-down row y, which is `v_uv` of `FieldPass` when the
// picture is uploaded with its rows flipped to bottom-up. Bilinear sampling follows GL `LINEAR` with clamp to edge
// (texel centres at (i + 0.5)/w, indices clamped). A value missing from a node (an unvalidated node) falls back to the
// parameter's default of clarification Q1. Pure Swift; no UI, GPU or clock.
import Foundation

/// The CPU reference of every effect (clarification Q1), on linear light for the linear effects (A25-P05).
public enum EffectReference {
    /// The picture `node` makes of `image`; `image` itself when the node is disabled.
    public static func apply(_ node: EffectNode, to image: RGBAImage) -> RGBAImage {
        guard node.enabled else { return image }
        return FloatPicture(image).applying(node).image(alphaOf: image)
    }

    /// The picture the enabled nodes of `chain` make of `image`, applied in order, with 8-bit storage between nodes.
    public static func apply(_ chain: EffectChain, to image: RGBAImage) -> RGBAImage {
        applyChain(chain, to: image, storage: .byte)
    }

    /// The picture the enabled nodes of `chain` make of `image`, applied in order; between nodes the picture is
    /// stored with `storage` (8-bit or half-float, research R4) and the result as 8-bit.
    public static func applyChain(_ chain: EffectChain, to image: RGBAImage,
                                  storage: ReferenceStorage = .byte) -> RGBAImage {
        let nodes = chain.nodes.filter(\.enabled)
        guard !nodes.isEmpty else { return image }
        var picture = FloatPicture(image)
        for node in nodes { picture = picture.applying(node).quantised(storage) }
        return picture.image(alphaOf: image)
    }

    /// The RGB value `node` makes at column `x`, top-down row `y` of `source`, already clamped to 0…1. `source`
    /// holds linear values for a linear effect and stored values otherwise.
    static func value(_ node: EffectNode, _ source: FloatPicture, _ x: Int, _ y: Int) -> SIMD3<Float> {
        let w = source.width, h = source.height
        let uv = SIMD2<Float>((Float(x) + 0.5) / Float(w), 1 - (Float(y) + 0.5) / Float(h))
        let input = source.texel(x, y)
        switch node.effect {
        case .grade: return SRGB.encode(grade(input, node))
        case .blur: return SRGB.encode(blur(source, x, y, node))
        case .distort: return clamp01(distort(source, uv, node))
        case .vignette: return SRGB.encode(vignette(input, uv, node))
        case .posterize: return clamp01(posterize(input, node))
        }
    }

    /// The 8-bit value stored for `value` in 0…1: round(value·255).
    static func store(_ value: Float) -> UInt8 { UInt8((min(max(value, 0), 1) * 255).rounded()) }

    /// Each component clamped to 0…1.
    static func clamp01(_ v: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(min(max(v.x, 0), 1), min(max(v.y, 0), 1), min(max(v.z, 0), 1))
    }

    /// `grade` of one pixel of linear light `x` (pivot 0.18), unclamped.
    static func grade(_ x: SIMD3<Float>, _ node: EffectNode) -> SIMD3<Float> {
        let exposure = NodeValues.value(node, "exposure")
        let contrast = NodeValues.value(node, "contrast")
        let saturation = NodeValues.value(node, "saturation")
        var y = x * exp2f(exposure)
        y = (y - SIMD3(repeating: 0.18)) * contrast + SIMD3(repeating: 0.18)
        let l = 0.2126 * y.x + 0.7152 * y.y + 0.0722 * y.z
        return SIMD3(repeating: l) + (y - SIMD3(repeating: l)) * saturation
    }

    /// `blur` of the pixel at column `x`, top-down row `y` (the mean of `source`'s values; linear light).
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

    /// `vignette` of one pixel of linear light `x` at texture coordinate `uv`.
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

/// A picture as floats in RGB (x = byte/255, or their linear light), rows top-down, with clamped texel and bilinear
/// reads.
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

    /// A picture of `width × height` with `values`.
    init(width: Int, height: Int, values: [SIMD3<Float>]) {
        self.width = width
        self.height = height
        self.values = values
    }

    /// The picture `node` (enabled) makes of this stored-value picture: decoded first for a linear effect; every
    /// value clamped to 0…1 and encoded again.
    func applying(_ node: EffectNode) -> FloatPicture {
        let source = node.effect.colorDomain == .linear
            ? FloatPicture(width: width, height: height, values: values.map(SRGB.decode)) : self
        var out: [SIMD3<Float>] = []
        out.reserveCapacity(values.count)
        for y in 0..<height {
            for x in 0..<width { out.append(EffectReference.value(node, source, x, y)) }
        }
        return FloatPicture(width: width, height: height, values: out)
    }

    /// The picture as stored with `storage`: round(x·255)/255 (`.byte`) or rounded to `Float16` (`.half`).
    func quantised(_ storage: ReferenceStorage) -> FloatPicture {
        let q: (Float) -> Float = switch storage {
        case .byte: { Float(EffectReference.store($0)) / 255 }
        case .half: { Float(Float16($0)) }
        }
        return FloatPicture(width: width, height: height, values: values.map { SIMD3(q($0.x), q($0.y), q($0.z)) })
    }

    /// The 8-bit picture of these values with the alpha of `original` (round(x·255)).
    func image(alphaOf original: RGBAImage) -> RGBAImage {
        var out = original
        for (k, v) in values.enumerated() {
            let i = 4 * k
            out.bytes[i] = EffectReference.store(v.x)
            out.bytes[i + 1] = EffectReference.store(v.y)
            out.bytes[i + 2] = EffectReference.store(v.z)
        }
        return out
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
