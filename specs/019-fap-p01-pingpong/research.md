# Research: Fluid Art Playground — Phase 01

All Technical Context items were resolved; none remain NEEDS CLARIFICATION.

## R1 Dissipation formula

- **Decision**: per step `x ← x / (1 + d·Δt)` for every channel, with `d ∈ [0, 10]` per second (spec clarification 1).
- **Rationale**: the form used by common artistic GPU fluid demos. It is stable for any `d ≥ 0` and `Δt > 0`, never
  negative, never NaN, and exactly the identity at `d = 0`.
- **Alternatives**:
  - `x·exp(−d·Δt)`: equivalent intent, but `exp` precision differs between GPU and CPU.
  - `x·(1 − d·Δt)`: goes negative for `d·Δt > 1`.

## R2 Precision-matched reference

- **Decision**: the CPU reference rounds to the storage format after every step:
  - `float32`: identity;
  - `float16`: Swift `Float16` round-to-nearest-even;
  - `unorm8`: `round(clamp(x, 0, 1)·255)/255`.

  Tolerances: 1e-3 for half-float values ≤ 1; 1.5/255 for unorm8.
- **Rationale**: an 8-bit decay stalls once the per-step change is below 1/510. For example, `d = 1`, `Δt = 1/60` and
  `x = 0.5` changes by 0.0082 per step, which is fine, but `d = 0.1` changes by 0.0008, which stalls. A float32
  reference would demand an impossible match. Matching the storage precision makes the fixture test the pass
  arithmetic, not the format.
- **Alternatives**: a looser fixed tolerance against float32 (hides real bugs); skipping the fallback (it would be
  untested).
- **Risk**: the GPU computes in `highp` float and then stores. A ties case could round differently from the CPU, so
  the tolerance allows one storage step.
- **Revision (T-A02-111, observed)**: half-float color writes truncate on the iOS 27.2 simulator. This is a
  systematic difference, not a ties case. `StoragePrecision.float16TowardZero` was added to VisualCore, and the
  fixture accepts the closer of the two half references (spec clarification 6). Assuming nearest-even only would
  have failed against real behavior; loosening the tolerance would have hidden real bugs.

## R3 Half-float support decision

- **Decision**: `FloatRenderSupport` reports three things:
  - `extensionReported` (`GL_EXT_color_buffer_half_float` or `GL_EXT_color_buffer_float` in the extension list);
  - `probeComplete` (a 4×4 RGBA16F target is framebuffer-complete, cleared, and its readback is finite);
  - `supported` (both are true).

  Storage selection returns `.rgba16f` when supported, otherwise `.rgba8`. A `forceFallback` flag lets tests exercise
  RGBA8. The result is cached per registry generation.
- **Rationale**: ES 3.0 does not guarantee color-renderable float formats; the extensions do. The probe guards
  against an extension that is reported but fails in practice. Both are cheap.
- **Alternatives**: the extension only (unsafe); the probe only (misses a semantic guarantee); RGBA32F (twice the
  memory, not needed).

## R4 Float readback and upload

- **Decision**:
  - `RenderTarget.readFloatPixels()` reads with `GL_RGBA`/`GL_FLOAT`, which is allowed for float color buffers under
    `EXT_color_buffer_float`. An RGBA8 target is read with `UNSIGNED_BYTE` and normalized.
  - `RenderTarget.upload(rgbaFloats:)` writes with `GL_RGBA`/`GL_FLOAT`, a valid upload combination for RGBA16F in
    ES 3.0. For RGBA8 the values are quantized on the CPU to unorm8 first.
- **Rationale**: the fixture needs exact seeding and comparison in both storages, through VisualCore and not raw GL
  calls in the app (Principle I/II).
- **Alternatives**: seeding through a shader pass (the CPU cannot reproduce arbitrary seeds); RGBA8 readback of a
  half-float target (loses precision).
- **Verification**: a package test on both runtimes; a readback that fails returns `[]`, and the test fails.

## R5 FieldPass design

- **Decision**:
  - `FieldPass(registry:fragment:inputs:label:)` compiles `FullScreenShaderScene.vertexSource` plus the fragment
    through the registry program cache, and binds each named sampler to units 0…n−1.
  - `run(output:inputs:uniforms:)` rejects:
    - an input that is also the output (`.inputIsOutput`);
    - a missing or extra input (`.missingInput` / `.unknownInput`);
    - an unknown uniform name (`.unknownUniform`);
    - stale handles (`.stale`).
  - The output is a `RenderTarget` or a framebuffer (the screen).
  - `run(pair:input:...)` reads `pair.read`, writes `pair.write`, and swaps only on success.
- **Rationale**: the "never read and write the same texture" rule becomes an API guarantee (FR-A02-103, SC-A02-102).
  Typed uniforms are checked against the program's reflected `uniforms` table.
- **Alternatives**: extending `EffectRenderer` (an effect graph has a single input/output and a different purpose);
  raw `ShaderProgram` use in the app (puts the guard in the app).

## R6 Where generic CPU pieces live (reuse rule)

- **Decision**:
  - `FieldGrid` (a W×H×C Float grid), `StoragePrecision` and `SignedRangeEncoding` go into VisualCoreSimulation.
  - `TimeStepPolicy` (a variable-step clamp) goes into VisualCoreSimulation next to `FixedStepClock`.
  - The app keeps `FluidConfiguration`, `Dissipation` and `DyeSeed`.
- **Rationale**: the owner instruction maximizes reuse. A16 Simulation Lab, A09 Digital Aquarium and A22 Shader Studio
  all need CPU references for GPU grid passes and precision-matched comparison. These are additions not foreseen in
  the A02-P00 contract; they are recorded as gap `G-CPUFIELD` (closed in this phase) when the contract is updated.
- **Alternatives**: app-local (duplicated later); `FixedStepClock` (its semantics are fixed sub-steps, but the spec
  wants one clamped step per frame).

## R7 Context loss

- **Decision**: `RenderHost.recreateContext()` already calls the scene's `teardown` and `setup` on the new
  generation. The scene re-seeds from the configuration and resets `stepCount`. Tests assert that:
  - `resources.stats` has the same live counts as after the first setup;
  - the stale-use counter does not grow from scene code;
  - rendering continues (non-blank readback).
- **Rationale**: this matches FR-A02-107 and the A02 Bounded GPU rule (rebuild from versioned CPU state).

## R8 Canvas and spoken description

- **Decision**: `PlaygroundView` hosts `RenderSurface(host:accessibilityLabel:accessibilityHint:)` with the label
  "Fluid canvas" and a dynamic value from `FluidCanvasDescription` (Core), for example: "Dye pattern fading, 128 by
  128 grid, half-float storage". The view's identifier is `fap.canvas`.
- **Rationale**: this follows the A01 `CanvasDescription` pattern and the constitution's accessibility rule.

## R9 Fixture parameters

- **Decision**:
  - dissipations `{0, 1, 5}`;
  - `Δt = 1/60`;
  - 60 steps;
  - a 16×16 grid with uniform dye 0.8 (RGB) and alpha 1.0;
  - velocity 0.

  Each case runs in both storages (half-float when supported, plus forced RGBA8) on iOS 27.2 and 26.5. A 1,000-step
  CPU run at `d = 10` checks for no NaN and no negatives (SC-A02-103).
- **Rationale**: this covers identity, moderate and strong decay, and it is fast.

## R10 Local package directory name (found during T-A02-101)

- **Decision**: the app's domain package lives in `Apps/FluidArtPlayground/FluidArtPlaygroundCore`, not in
  `Apps/FluidArtPlayground/Core`. From now on, every app's domain package directory is named `<App>Core`.
- **Rationale**: SwiftPM and Xcode derive a local package's identity from the last path component. A second
  `…/Core` package collided with `Apps/GenerativeArtStudio/Core`: the xcodebuild log for
  `t101-app-build` shows "Core: (null)" and "Missing package product 'FluidArtPlaygroundCore'".
- **Alternatives**: renaming A01's sealed package (it would churn a sealed gate's paths for no benefit).
