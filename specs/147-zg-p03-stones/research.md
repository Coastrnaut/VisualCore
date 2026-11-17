# Research: A20-P03 (feature 147)

- **D1 Stones (clarification Q1):** superellipse domes rasterized on the CPU into a second layer. Alternatives:
  procedural meshes through `MeshRenderer` and `DepthMeshPass` (rejected for 0.1: a second, depth-tested pass and no
  CPU reference to compare a picture with); SDF stones evaluated in the shader per pixel (rejected: up to 24 stones as
  uniforms, and `FieldUniform` has no arrays).
- **D2 Shadows:** five taps toward the light in the relief pass, offset by stone height; soft and cheap.
- **D3 Selection (Q2, Q4):** the same `StoneShape.contains` as drawing, so what is seen is what is picked.
- **D4 Gestures (Q3):** one command per lift or rotation end keeps the history short and undo meaningful.
- **D5 Orientation (Q5):** both layers depend only on the document, so views differ only in the tray fit.
