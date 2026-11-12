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

- **Decision:** `TrailDecay.factor(strength:delta:) = s^(max(delta,0)·60)`, with s clamped to 0…0.98 (non-finite
  becomes 0); `delta` 0 gives factor 1. The shader writes `max(prev·f − 1/255, 0)`. The GPU stores
  `round(255·out)`, so the predicted 8-bit step is `step8(k, f) = max(0, round(k·f − 1))`.
- **Rationale:** the extra −1/255 guarantees the fade reaches 0 in 8 bits (without it, 1/255 × 0.95 rounds back to
  1/255 forever). The exponent form makes the same elapsed time give the same fade at any frame rate (SC-A04-303);
  the subtraction is per frame, so the tolerance of 1/255 is checked per frame against `step8` of the observed
  previous value, and over time at 60 versus 30 Hz to within 2/255 per 30 frames.
- **Alternatives:** RGBA16F targets (not guaranteed renderable on every device path, larger); a time-based
  subtraction (fractional, rounds away).

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
- A new `ParticleSystem` query is needed to know whether a source still has live particles: add the generic
  `ParticleSystem.liveCount(source:)` (VisualCoreSimulation, documented and tested) rather than reading internals
  from the app.

## R5. Emitter placement

- **Decision:** the k-th added emitter (k ≥ 1) is placed at the family's position + (150·⌈k/2⌉·(−1)^(k+1), 0),
  clamped to ±450. Moving emitters is Phase 04.

## R6. UI test seams

- **Decision:** DEBUG `-uitestReduceFlashing YES` forces the system flag for the cap test. Trails in the CPU preview
  show "Trails need the GPU renderer" and the trail controls are disabled.
