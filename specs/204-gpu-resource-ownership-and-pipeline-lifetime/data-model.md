# Data Model: R02-F04

- **RenderState** (pure, value): `blend: BlendMode` (none | alpha | premultiplied | additive), `depthTest: Bool`,
  `depthWrite: Bool`, `cull: CullMode` (none | back | front), `colorMask: ColorMask` (red, green, blue, alpha Bools).
  Presets: `opaque` (none, no depth, no cull, all), `alphaBlended` (alpha), `additive` (additive, depthWrite false),
  `opaque3D` (none, depthTest true, depthWrite true, cull back). Blend factors: alpha = SRC_ALPHA/ONE_MINUS_SRC_ALPHA,
  premultiplied = ONE/ONE_MINUS_SRC_ALPHA, additive = ONE/ONE (or SRC_ALPHA/ONE).
- **Pipeline** (rendering): program (identity) + RenderState; Hashable.
- **RenderTarget** gains `depthRenderbuffer` (0 = none). Pool key: width, height, format, depth.
- **Registry statistics**: `evictionCount`, `retiredProgramCount`.
