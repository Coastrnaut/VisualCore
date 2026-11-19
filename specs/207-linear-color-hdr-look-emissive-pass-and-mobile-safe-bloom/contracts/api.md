# Contract: public API (R02-F07)

VisualCoreEffectsGraph (pure):
- `PassSchemas.all["emissive"]` with the parameters of data-model.md; `composite.mode` range 0…2; `flashLimit.linear`.
- `public enum ToneMapOperator: Int, Sendable, CaseIterable { case none = 0, reinhard = 1, filmic = 2 }`
- `public enum EmissiveReference { static func srgbDecode(_:) -> Double; static func srgbEncode(_:) -> Double; static func luminance(_ rgb: SIMD3<Double>) -> Double; static func prefilter(_ rgb: SIMD3<Double>, threshold:knee:) -> SIMD3<Double>; static func toneMap(_ x: Double, _ op: ToneMapOperator) -> Double; static func composite(base:glow:intensity:exposure:op:) -> SIMD3<Double>; static func premultipliedOver(overlay: SIMD4<Double>, base: SIMD4<Double>, opacity: Double) -> SIMD4<Double> }`

VisualCoreShaderSource: `RenderState.premultipliedBlended`.

VisualCoreEffects: no new public type required; the pass is reached through graph descriptions (`EffectRenderer`),
plus an internal `forceStandardPrecision` switch for tests.
