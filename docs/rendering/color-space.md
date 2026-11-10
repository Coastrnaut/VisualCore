# Color-space policy (FR-F315)

* Window surfaces and 8-bit render targets store **sRGB-encoded** values (BGRA8/RGBA8 UNORM, no
  automatic sRGB conversion, matching the reference's BGRA8 `CAMetalLayer`).
* Shaders that blend or filter in linear light convert explicitly: `pow(c, 2.2)` in, `pow(c, 1/2.2)` out
  (or the exact sRGB transfer function where accuracy matters).
* 16-bit float targets (`rgba16f`) hold **linear** values; the final pass encodes to sRGB.
* Colors passed from SwiftUI are converted to sRGB components before reaching uniforms.
