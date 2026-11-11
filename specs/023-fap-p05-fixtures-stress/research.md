# Research: Fluid Art Playground — Phase 05

## R1. Where the synthetic gesture script lives

- **Decision**: `VisualCoreScenes.SyntheticGestureScript`, using `SeededRandom` from VisualCoreSimulation. This adds
  the pure dependency edge VisualCoreScenes → VisualCoreSimulation.
- **Rationale**:
  - It produces `PointerEvent`s, which VisualCoreScenes owns.
  - Every interactive app (particles, physics, zen garden) needs repeatable touch input for fixtures and device runs.
  - ADR-0003 allows pure-to-pure edges if the graph stays acyclic (R2, R3); VisualCoreSimulation depends only on
    VisualCoreMath.
- **Alternatives**:
  - A private PRNG in VisualCoreScenes: duplicates `SeededRandom`.
  - The script in VisualCoreSimulation: that module would depend on Scenes' event type.
  - App-local: violates the reuse rule.

## R2. Detecting numerical blow-up in device runs

- **Decision**: a generic `postRunCheck: (@MainActor () -> String?)?` on `AutomationRunner` and `AutomationView`. It
  is called after the mode's frames. A non-nil result sets the result to "fail", and the message is the returned text.
- **Rationale**: the runner stays app-neutral, and every app can verify domain invariants on device.
- **Alternatives**:
  - An app-specific "stress" mode in the runner: not generic.
  - Checking only in simulator tests: misses device GPU behavior.

## R3. Seed passing

- **Decision**: `AutomationRunner.seedKey = "VISUALCORE_AUTORUN_SEED"` and `requestedSeed(environment:) -> UInt64`.
  Missing, 0 or unparsable values give 1.
- **Rationale**: it matches the existing frames key; it is generic, compiled only in automation builds, and the
  symbol and string check already covers the `VISUALCORE_AUTORUN` prefix.

## R4. Simulation detail grids

- **Decision**: square grids 64², 128² and 256², with the default Medium = today's 128×128. Each is capped by
  `ResourceRegistry.maxTextureSize` through the existing validation.
- **Rationale**:
  - Aspect-following grids would change the default picture.
  - They would need a rebuild after the first layout, because setup runs in `RenderHost.init` before layout.
  - Existing fixtures assume the configured size.
- **Alternatives**: grids that follow the aspect ratio (deferred; it can be revisited with device data).

## R5. Byte-identical determinism

- **Decision**: compare two fresh `PlaygroundModel`s, each with its own host, in one test process. Fixed 1/60 s, the
  same seed, 120 frames, quality tier pinned to Full through the `deviceState` seam. Digest the on-screen readback
  with SHA-256.
- **Rationale**: same GPU, driver and shader binaries, and no wall-clock inputs. The tier policy uses `clock`, which
  is pinned.
- **Risk**: if the simulator GPU is nondeterministic, the test reports it. The spec would then be revisited, not the
  tolerance silently loosened.

## R6. Fixture 5 without real suspension

- **Decision**: drive `RenderHost.pause()` and `resume()` with `renderOneFrame`. While paused, `renderOneFrame`
  returns false and the step count does not change. Then feed the scene frames with deltas of 600, 0, −1 and NaN
  through `fixedDelta = nil` and a direct `render` with a synthetic `FrameInfo`. Assert one step each, with `lastStep`
  in 1/240…1/30.
- **Rationale**: this checks the exact code path a suspension takes (no frames while inactive; one clamped step on
  return) without wall-clock waits.

## R7. Release symbols

- **Decision**: build `FluidArtPlayground` Release for generic iOS unsigned, and run `check_release_symbols.py --app`.
  The automation product is linked only for the test configurations, as A01 does in `project.yml`.
- **Rationale**: this reuses the A01 and Showcase gate. The per-app `release.json` steps arrive in Phase 06.
