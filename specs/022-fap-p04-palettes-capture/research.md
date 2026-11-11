# Research: Fluid Art Playground — Phase 04

## R1 Palettes as display modes

- **Decision**: one display shader with `uMode` (0 ink, 1 smoke, 2 glow) and `uBackground`, using the formulas of
  spec clarification 1. Splat colors come from the palette.
- **Rationale**: the fields are unchanged, so switching is instant with no rebuild, and probe tests are exact on the
  same renderer.
- **Alternatives**: separate scenes per palette (needs rebuilds); `vc/palette.glsl` gradient lookups (the gradient
  palettes don't model subtractive ink).

## R2 Glow through EffectScene

- **Decision**: the PlaygroundModel host scene is `EffectScene(content: FluidFieldsScene, graph: bloom)`, with the
  bloom input from `scene`. It is bypassed unless the palette is Glowing dye. `reduceFlashing` follows
  `SystemAccessibilityObserver`.
- **Rationale**: this reuses the effect graph, the bloom and the flash limiter (constitution II).

## R3 Pinch

- **Decision**: `PlaygroundModel` feeds every event to a `PointerTracker` and a `PinchRecognizer`. When the tracker
  count reaches 2, the model sends `cancelled` to the `PointerVelocityTracker` for both ids, forgets their colors and
  enters pinch mode, which ignores splat input until the count returns to 0. The brush radius is the radius at the
  start times `pinch.scale`, clamped.

## R4 Capture

- **Decision**: `CaptureModel.capture(host:scene:viewSize:)` computes `ExportGeometry(maxEdge: host.maxRenderSize)` at
  2048 on the long edge in the view aspect, pauses the scene, calls `renderOffscreen`, restores the pause state, and
  encodes the PNG. It writes `capture-<uuid>.png` to the temporary directory, deleting the previous file.
- **Rationale**: this is A01's proven pattern; pausing guarantees that no step runs.

## R5 Pass run observer

- **Decision**: `FieldPass.Run { label, output: UInt32, inputs: [String: UInt32] }` and
  `@MainActor public static var runObserver: ((Run) -> Void)?`, called after validation and just before the draw.
- **Rationale**: frame-wide auditing needs no per-pass wiring and costs nothing in production when nil.
