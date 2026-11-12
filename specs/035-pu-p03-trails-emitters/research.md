# Research: Particle Universe — Phase 03 (A04-P03)

The spec's five clarifications (2026-11-11) resolve every open question. This file records the audit and the
remaining design decisions.

## R0. Read-only audit (2026-11-11)

| API | File | Fact used |
|---|---|---|
| `PingPongTarget` | `Packages/VisualCoreRendering/Sources/VisualCoreRendering/PingPongTarget.swift` | `init(registry:width:height:format:label:)` creates two targets and releases the first if the second fails; `swap()`, `release()`, `isValid` (false after recreation) |
| `FieldPass` | `.../FieldPass.swift` | `init(registry:fragment:inputs:label:)` with the full-screen vertex shader (`v_uv`); `run(output:inputs:uniforms:)` validates inputs ≠ output, disables blend and scissor, sets the viewport |
| `RenderTarget` | `.../GPUObjects.swift` | `bind()`, `readPixels()`, `width`, `height`, `format`; `TextureFormat.rgba8` |
| `ResourceRegistry.stats` | `.../ResourceRegistry.swift`, `VisualCoreDiagnostics/ResourceLedger.swift` | `liveCount[.texture]`, `.framebuffer`, `leaked` |
| `ParticleRenderer` | `.../ParticleRenderer.swift` | hard-coded `ONE, ONE_MINUS_SRC_ALPHA` blend |
| `ParticleLayerScene` | `.../ParticleLayerScene.swift` (feature 034) | binds the context framebuffer, clears, draws |
| `ParticleSystem.instances()` | `Packages/VisualCore/Sources/VisualCoreSimulation/ParticleSystem.swift` | size and color come from `emitters[source]` at draw time; lifetime is fixed at spawn |
| `Palette` | `Packages/VisualCore/Sources/VisualCoreParameters/Palette.swift` | 6 built-ins, `sample(t)` in sRGB stops |
| `AccessibilityPreferences`, `SystemAccessibilityObserver` | `VisualCoreSimulation/AccessibilityPreferences.swift`, `VisualCoreUI/SystemAccessibilityObserver.swift` | `resolve(_:)` gives `reduceFlashing`; system values from public APIs |

## R1. Fade model and 8-bit prediction

- **Decision:** `TrailDecay.factor(strength:delta:) = s^(max(delta,0)·60)` (s clamped to 0…0.98, non-finite → 0;
  delta 0 → 1) and `subtraction(delta:) = max(1, delta·60)` levels. The shader writes `max(prev·f − d/255, 0)`; the
  GPU stores `round(255·out)`, so the predicted step is `step8(k, f, d) = max(0, round(k·f − d))`.
- **Revision during T-A04-304:** the first model subtracted a fixed 1/255 per frame. Simulating all 255 start values
  showed that 60 and 30 Hz then differ by up to 20/255 after 1 s, because 60 Hz subtracts twice as often. Scaling the
  subtraction with time reduces the worst difference to 5/255 (strength 0.98) and 0 for strength ≤ 0.5; the
  minimum of one level per frame still guarantees every trail ends at high frame rates. SC-A04-303's cross-rate
  tolerance is therefore 6/255 (8-bit rounding), and the per-frame GPU-versus-model tolerance stays 1/255.
- **Alternatives:** RGBA16F targets (not guaranteed renderable on every device path, larger); no subtraction (8-bit
  values stall above 0 forever).

## R2. Additive blend and the cap

- **Decision:** `ParticleBlend.additive` uses `glBlendFunc(ONE, ONE)` on premultiplied colors. The cap is applied
  in the composite pass as `min(c, cap)` per channel (alpha set to 1), so it bounds both trails and additive
  overlap. Under Reduce Flashing the layer is used even with trails off.
- **Alternatives:** clamping in the particle fragment shader (does not bound sums); VisualCore's existing
  temporal flash limiter (bounds change over time, not peak brightness; it can be added in Phase 05 if measured
  flashes need it).

## R3. Overrides restyle live particles of that emitter

- **Decision:** keep `ParticleSystem` unchanged; overrides edit the emitter. Size and gradient therefore apply to
  that emitter's live particles at once; lifetime only to new ones. SC-A04-302 was clarified to match.
- **Rationale:** storing style per particle would change VisualCore's memory layout for every consumer to serve a
  cosmetic difference; live restyling gives immediate feedback while dragging a slider.
- **Alternatives:** a new emitter slot per change (exhausts the 8 slots during a slider drag); per-particle style.

## R4. Emitter slots

- **Decision:** `SceneSimulation` keeps `slots: [Slot]` (visible or retired) parallel to `system.emitters`.
  `visibleEmitters` lists the visible slots in order. Add reuses the first retired slot whose particles are gone
  (no live particle with that source), else appends while `system.emitters.count < 8`. Removal sets
  `isEmitting = false` and retires the slot. The last visible emitter cannot be removed. `rebuildScene()` builds a
  fresh `ParticleScene` from the visible emitters (for the family and seed rebuild paths).
- **Rationale:** no live particle ever changes source, so nothing recolors or vanishes (US1 AC2).
- **Family forces (T-A04-307):** the forces a family brings (Fountain gravity, Firework drag) are global, so with
  several emitters they are the deduplicated forces of the visible emitters' families, in order of first
  appearance, rebuilt after each add, remove or family change; the placed force and scene forces stay in front. Two
  Fountains therefore bring one gravity, not two. Initialization uses the same rule; the replay fixture's families
  (Fountain, Firework) are distinct, so it is unchanged.
- A new `ParticleSystem` query is needed to know whether a source still has live particles: add the generic
  `ParticleSystem.liveCount(source:)` (VisualCoreSimulation, documented and tested) rather than reading internals
  from the app.

## R5. Emitter placement

- **Decision:** the k-th added emitter (k ≥ 1) is placed at the family's position + (150·⌈k/2⌉·(−1)^(k+1), 0),
  clamped to ±450. Moving emitters is Phase 04.

## R6. UI test seams

- **Decision:** DEBUG `-uitestReduceFlashing YES` forces the system flag for the cap test. Trails in the CPU preview
  show "Trails need the GPU renderer" and the trail controls are disabled.
