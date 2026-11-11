# Contract: Fluid Art Playground Phase 01 fields, scene and canvas

## FluidArtPlaygroundCore (GPU-free; imports only VisualCoreSimulation)

- `FluidConfiguration.validated(maxEdge: Int = 512)` → `(FluidConfiguration, [ConfigurationIssue])`. The bounds are
  in [data-model.md](../data-model.md). At least 8 out-of-range cases are covered by tests (SC-A02-103).
- `Dissipation.factor(d:dt:)` and `Dissipation.step(_:d:dt:precision:)`.
- `DyeSeed.uniform`, `DyeSeed.pattern(seed:)` (deterministic), `DyeSeed.zeroVelocity`.
- `FluidCanvasDescription.text(configuration:storage:paused:)`.

## FluidFieldsScene (app; `RenderScene`)

- `init(configuration: FluidConfiguration, forceFallback: Bool = false, seed: SeedKind = .pattern)`.
- Read-only state for tests: `storage: TextureFormat?`, `stepCount`, `lastStep: Double`, `rebuildCount`,
  `lastError: FieldPassError?`.
- `fixedDelta: Double?` is a test seam that replaces `frame.delta` before the clamp.
- `readDye() -> FieldGrid?` and `readVelocity() -> FieldGrid?` decode the RGBA8 velocity with
  `SignedRangeEncoding(range: velocityRange)`.
- Each frame:
  1. `dt = policy.clamp(fixedDelta ?? frame.delta)`;
  2. `dissipate.run(pair: velocity, input: "uField", uniforms: ["uFactor": factor(dV, dt), "uEncoded": rgba8 ? 1 : 0, "uRange": vmax])`;
  3. the same for dye with `factor(dD, dt)`;
  4. `display.run(output: .framebuffer(context.framebuffer, w, h), inputs: ["uDye": dye.read])`.
- Velocity dissipation on RGBA8: the shader decodes, scales and re-encodes (zero velocity stays at 0.5 and decodes to
  0).
- `setup` and `teardown` follow the plan's lifecycle contract. A context loss means teardown, then setup and
  `rebuildCount += 1`.

## PlaygroundView (app)

- Navigation: home `fap.home.open` → `PlaygroundView`.
- The canvas has the identifier `fap.canvas`, the label "Fluid canvas", and a value from `FluidCanvasDescription`.
- The title is "Playground", shown as a header.
- No permissions and no networking.

## Fixture acceptance (SC-A02-101)

For `d ∈ {0, 1, 5}`, 60 steps at `Δt = 1/60` on a 16×16 grid with uniform dye `(0.8, 0.8, 0.8, 1)`:
`max |GPU − CPU(precision of storage)| ≤ precision.tolerance` for every channel. This runs for half-float when
supported and for forced RGBA8, on iOS 27.2 and 26.5.
