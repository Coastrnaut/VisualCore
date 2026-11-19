# Data Model: R02-F09

- **MeshInstance**: `model: Mat4`, `color: Vec4` (straight alpha, as in `MeshRenderer`: the shader multiplies rgb by alpha before premultiplied blending); all finite.
- **BeamInstance**: `a: Vec3`, `b: Vec3`, `width: Double` (> 0), `color: Vec4` (premultiplied); all finite.
- **BeamBlend**: `.premultiplied` (sorted back to front) or `.additive` (unsorted).
- **Limits**: `InstancedMeshRenderer.maxInstances = 16_384`; `BeamRenderer.maxBeams = 65_536`.
- **InstancingError**: `tooMany(count:limit:)`, `notFinite(index:)`, `badWidth(index:)`.
- **InstanceOrder.backToFront(depths: [Double]) throws -> [Int]**: ascending view-space z, ties by index.
- **BeamProfile**: `falloff(_ r: Double) -> Double` = exp(−4 r²) for r ≤ 1 else 0; `distanceToSegment(point:a:b:)`;
  `coverage(point:a:b:width:)` = falloff(distance / (width/2)).
- **GL state**: mesh instances cull back faces and leave depth testing to the caller, as `MeshRenderer`; translucent
  mesh instances and beams test depth without writing it; beams draw with face culling off (a view-facing strip can be
  wound either way) and restore the previous state afterwards.
