# Contract: Effects Composer core (A25-P01)

- `EffectLibrary.all` lists the five definitions in the order grade, blur, distort, vignette, posterize;
  `EffectLibrary.definition(_:)` returns one.
- `EffectDefinition.validate(values:) throws(ChainRefusal)` refuses unknown, missing, non-finite, fractional-whole and
  out-of-range values naming the parameter.
- `EffectReference.apply(_ node: EffectNode, to: RGBAImage) -> RGBAImage` computes the CPU picture.
- `EffectPrograms.source(for: EffectID) -> String` and `EffectPrograms.uniforms(for: EffectNode, width:height:) ->
  [String: [Float]]` (vec4-packed values and `u_texel`); the sampler input is named `u_source`.
- `EffectChain.validate() throws(ChainRefusal)`, `fingerprint() -> StateDigest`.
- `EditHistory.apply(_:to:) -> Result<EffectChain, ChainRefusal>`, `undo(_:)`, `redo(_:)`, `canUndo`, `canRedo`.
- `ChainDocument.encode(_:) -> Data`, `ChainDocument.decode(_:) -> Result<EffectChain, ChainRefusal>`.
- `TestImage.make() -> RGBAImage`.
