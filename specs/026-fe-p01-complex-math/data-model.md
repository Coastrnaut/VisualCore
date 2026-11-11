# Data Model: Fractal Explorer — Phase 01

## PlaneViewport (VisualCoreMath)

| Field | Rule |
|---|---|
| center: Vec2 | finite; otherwise (0, 0) |
| unitsPerPoint: Double | clamped to 1e-15…1e3; `wasClamped` is set when clamping happened |
| size: Vec2 | points; a non-positive or non-finite size keeps the previous valid size (initially 1×1) |

Methods: `plane(fromScreen:)`, `screen(fromPlane:)`, `pinched(by:anchor:)`, `panned(by:)`, `resized(to:)` and
`framing(width:center:size:)`, which makes the plane width fit the shorter side.

## FractalMode (app)

`mandelbrot` or `julia`.

## FractalState (app)

- mode;
- viewport;
- juliaSeed: Vec2, finite;
- iterationCap: 1…10,000, default 200;
- escapeRadius: ≥ 2, default 2.

## EscapeResult (app)

- count: 0…cap;
- smooth: Double;
- interior: Bool.

## Preview (app)

- width, height: ≤ 160;
- rgba: [UInt8] (4 × width × height);
- requestID.
