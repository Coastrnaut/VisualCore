# Data Model: Fractal Explorer — Phase 02

- **ShaderPrecision** (VisualCoreRendering): `rangeMin`, `rangeMax` and `precisionBits` (Int32), all Codable.
- **RenderCapabilities**: adds `fragmentHighp: ShaderPrecision?` and `fragmentMediump: ShaderPrecision?`.
- **PrecisionAdvisor.Status** (VisualCoreMath):
  - `level`: reliable, nearLimit or beyondLimit;
  - `margin` (steps);
  - `minimumPixelStep`.
- **FractalScene snapshot** (app): `state` (FractalState), `paletteID`, `animate`, `pixelScale` (pixels per point).
- **Gesture mapping** (app): `PointerTracker`, `PinchRecognizer` and `DragRecognizer`, plus the previous scale,
  center and translation.
