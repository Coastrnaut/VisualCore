# Contract: Fluid Art Playground Phase 02 splats, advection and controls

## Core (GPU-free)

`Splat`, `SplatQueue` and `Advection` are as in [data-model.md](../data-model.md). The CPU references are the
acceptance oracle for the GPU passes.

## Shaders (app; `#include "vc/field.glsl"`)

- **splat**:
  - inputs `uField`;
  - uniforms `uPoint` (cells), `uRadius` (cells), `uValue` (vec4), `uEncoded` (int), `uRange` (float),
    `uVelocity` (int: 1 = add `uValue.xy` to RG with encoding, 0 = add `uValue.rgb` to RGB);
  - output field + value·exp(−d²/r²).
- **advect**:
  - inputs `uVelocity`, `uSource`;
  - uniforms `uDt`, `uFactor`, `uEncodedVelocity` (int), `uEncodedSource` (int), `uRange`;
  - `src = gl_FragCoord.xy − uDt·v`;
  - output `vc_fieldBilinear(uSource, src) × uFactor` (re-encoded when the source is encoded velocity).

  Velocity self-advection binds the same `velocity.read` as both `uVelocity` and `uSource`. Sampling one target
  twice is allowed; the FieldPass guard only forbids input == output.

## FluidFieldsScene (app)

- `enqueue(_ splats: [Splat])` and the frame order in the plan.
- Counters: `appliedSplats`, `lastDrained`.
- The test seam `fixedDelta` remains.

## PlaygroundView (app)

- The canvas forwards `host.pointerHandler` events → tracker (spacing = brushRadius × shorter view edge / 2) →
  `queue.add`.
- The **"Add splash"** button (`fap.splash`, label "Add splash", hint "Adds a burst of dye and motion at the center")
  sits over the canvas bottom with a material background. It calls `queue.addSplash()` and posts the announcement
  "Splash added".
- The canvas description reports the number of splashes added (for example "…, 2 splashes added").

## Acceptance

SC-A02-201…206 from the spec. UI test: tap `fap.splash` → the canvas label contains "1 splash added"; a drag across
the canvas raises `appliedSplats` (verified in unit tests through the scene; the UI test only checks that the drag
leaves the app responsive).
