# Feature Specification: Particle Universe — Phase 03 Trails and multiple emitters

**Feature Branch**: `035-pu-p03-trails-emitters` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A04-P03 · ID namespace FR-A04-3##, SC-A04-3##, T-A04-3##

**Input**: User description: archived manual `apps/04-particle-universe.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: adjustable particle size, lifetime, color gradient and trail strength (v0.1 feature 03);
  - regression fixture 3: trail render targets resize and clear without texture leaks;
  - EGL and context ownership stays solely in the audited VisualCore host.
- **Gap closed (contract), in VisualCore (constitution Principle II, A04 reuse rule):**
  - G-BLENDTRAIL (VisualCoreRendering): an additive blend option for particle drawing, a trail-decay pass over a
    ping-pong target that fades by a set factor, trail targets that resize and clear without leaking textures, and a
    reduced-flash brightness cap.
- **Phase 02 stays:** the placed force, quality tiers and the CPU preview fallback keep working unchanged.
- **Out of scope here:** saving and loading scenes and the scene editor's library (Phase 04), profiling numbers
  (Phase 05), and more than the emitter count the scene format already allows.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §0 rule 1), choosing the recommended option
each time. Facts checked in code:
- `PingPongTarget(registry:width:height:format:label:)` and `FieldPass.run(output:inputs:uniforms:)` exist; field
  passes disable blending for their draw.
- `ResourceRegistry.stats.liveCount` counts live resources per kind.
- `ParticleRenderer` always blends premultiplied "over" (ONE, ONE_MINUS_SRC_ALPHA).
- `Palette.builtIns` has six palettes with `sample(t)`.
- `ParticleSystem.instances()` takes a particle's size and color from `emitters[source]`, so deleting an emitter
  from the middle of the list would recolor other emitters' live particles.

- Q: How is the trail layer built, and what exactly does "strength" mean? → A: `TrailLayer` in VisualCoreRendering:
  - an RGBA8 `PingPongTarget` at the drawable size, with the longer edge capped at 2,048 pixels;
  - each frame: (1) a decay pass writes `max(previous × f − 1/255, 0)` per channel into the write target, where
    f = s^(Δt·60) and s is the strength 0…0.98 (the fraction kept per 1/60 s), so the fade is frame-rate independent
    and always reaches background; (2) the particles are drawn into the write target; (3) a composite pass copies it
    to the screen; (4) swap.
  - Strength 0 means trails off: the layer is bypassed and the particles draw straight to the screen (no extra pass),
    except when the brightness cap must apply (Q3).
  - `clear()` zeroes both targets; a resize recreates them at the new size (cleared); teardown releases both.
- Q: How does additive blending work? → A: `ParticleRenderer` gains `blend: ParticleBlend` (`.normal`, the existing
  premultiplied over, default; `.additive`, ONE + ONE). Existing callers keep `.normal`, so A01's pixels are unchanged.
- Q: What is the reduced-flash brightness cap? → A: `TrailLayer.brightnessCap` (0…1, default 1). The composite pass
  writes `min(color, cap)` per channel. With Reduce Flashing on (VisualCore `AccessibilityPreferences` resolved with
  the system flags), the sandbox sets the cap to 0.6 (153/255) and routes drawing through the layer even with trails
  off, and shows "Brightness limited (Reduce Flashing)".
- Q: How do several emitters behave, including removal? → A:
  - The sandbox adds emitters up to `ParticleScene.maxEmitters` (8), placing emitter k at its family's position
    shifted 150 world units sideways (alternating right and left, clamped to the world square). The family picker
    changes the selected emitter's family; a picker selects "Emitter 1…N". The force placement from Phase 02 is
    unchanged; moving emitters is Phase 04's editor.
  - Removal retires the emitter's slot: it stops emitting and is hidden in the UI, but stays in the simulation until
    its last particle dies, so no live particle changes color or size. A retired slot whose particles are gone is
    reused by the next add. While all 8 slots are taken (retired ones still fading), Add stays disabled with the note
    "Waiting for removed emitters to fade".
  - `SceneSimulation` gains `addEmitter(_:)`, `removeEmitter(at:)`, `setEmitterOverrides(at:_:)` and the visible
    emitter list; a family or seed change rebuilds the scene from the visible emitters (Phase 01 rule).
- Q: What are the size, lifetime and gradient ranges, and how are they stored? → A: `SceneEmitter` gains optional
  fields (absent in old files, so schema 1 and `replay-v1.json` stay valid):
  - `size`: start diameter 1…48 world units; the end size keeps the family's end/start ratio;
  - `lifetime`: 0.2…8 s; particles live 0.8…1.2 × the value;
  - `gradient`: a built-in palette id (Sunset, Ocean, Forest, Neon, Monochrome, Ember) or nil for the family's colors;
    start color = `sample(1)` at alpha 1, end color = `sample(0.5)` at alpha 0.

  Invalid values are rejected on decode (`SceneError.invalidEmitter(i)`) and clamped when set from the UI.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Several emitters in one scene (Priority: P1) 🎯

A person adds a second (and third…) emitter of any family to the running scene, picks one to edit, and removes
emitters they no longer want. Each emitter keeps its own family and position.

**Why this priority**: Phase 03 deliverable ("multiple emitters"), v0.1 feature 01 (multiple emitter families) and
journey 2 ("change emitter type").

**Independent Test**: Host tests on the scene and simulation; UI tests add, select and remove emitters.

**Acceptance Scenarios**:

1. **Given** the sandbox with one emitter, **When** the person adds an emitter of a chosen family, **Then** the scene
   has two emitters, both emit, and the emitter count is shown in text.
2. **Given** several emitters, **When** the person selects one and removes it, **Then** only that emitter is gone and
   its particles fade out naturally (no live particle is deleted).
3. **Given** the scene's maximum number of emitters, **Then** the add control is disabled and says why.
4. **Given** one emitter left, **Then** it cannot be removed (a scene always has an emitter).

---

### User Story 2 - Adjust size, lifetime and color gradient (Priority: P1)

For the selected emitter, the person changes particle size, lifetime and color gradient with native controls, and
the change applies to new particles at once.

**Why this priority**: v0.1 feature 03 and journey 2 ("change … particle lifetime").

**Independent Test**: Host tests show new particles take the new size, lifetime and colors; UI tests drive the
controls and read the values back.

**Acceptance Scenarios**:

1. **Given** a selected emitter, **When** the person changes its size, **Then** particles emitted afterwards have the
   new size, and the value is shown with its unit.
2. **Given** a selected emitter, **When** the person changes its lifetime, **Then** particles emitted afterwards live
   for the new lifetime.
3. **Given** a selected emitter, **When** the person picks another color gradient, **Then** particles emitted
   afterwards start and end with the gradient's colors.
4. **Given** an out-of-range or non-finite value from any source, **Then** it is clamped or ignored, never applied
   raw.

---

### User Story 3 - Trails with adjustable strength (Priority: P1)

The person turns trails on and sets their strength. Moving particles then leave fading streaks; at zero strength
the picture is the same as without trails.

**Why this priority**: v0.1 feature 03 ("trail strength"), journey 2 ("toggle trails"), manual §6 algorithm
decision 4 (decaying ping-pong trail targets) and render stage 4.

**Independent Test**: Offscreen pixel tests of the trail pass; UI tests toggle trails and set the strength.

**Acceptance Scenarios**:

1. **Given** trails on with strength s, **When** frames are drawn without new particles, **Then** a previously lit
   pixel fades by the documented factor each frame, independent of the frame rate, until it reaches background.
2. **Given** trails off, **Then** each frame shows only the current particles.
3. **Given** additive blending, **When** particles overlap, **Then** their brightness adds up (capped by the display),
   while the default blend keeps the Phase 02 look.

---

### User Story 4 - Trails never leak or flash (Priority: P1)

Resizing the view, clearing trails, recreating the graphics context and turning trails on and off never leak
graphics memory. With Reduce Flashing on, trails and additive glow stay below a brightness cap.

**Why this priority**: Manual §11 fixture 3; risk 2 ("additive blending may be uncomfortable — offer flash and
brightness limits"); v0.1 feature 06 (reduced-flash mode).

**Independent Test**: Package tests count live textures across resizes, clears and recreations; pixel tests check
the brightness cap.

**Acceptance Scenarios**:

1. **Given** trails on, **When** the view is resized 20 times, trails are cleared 20 times and the context is
   recreated, **Then** the number of live textures returns to the same value as after the first setup.
2. **Given** Reduce Flashing on, **Then** no pixel of the trail layer exceeds the documented brightness cap, and the
   UI states that the cap is active.
3. **Given** the Phase 02 GPU fallback (CPU preview), **Then** trails are shown as unavailable there with a short
   note, and the rest of the sandbox keeps working.

### Edge Cases

- Adding an emitter when the particle budget is full: it is added, but its particles are dropped and counted until
  there is room (Phase 02 live limit).
- Removing the selected emitter selects the previous one.
- Removing an emitter retires it until its last particle dies; while all 8 slots are taken, Add is disabled with a
  note (clarification 4).
- Changing the family of the selected emitter keeps its position and its size, lifetime and gradient overrides.
- A trail strength outside its range is clamped; trails at strength 0 cost no extra pass.
- Resizing to a zero-size view or to the largest allowed size keeps trails valid (or clears them) without error.
- Backgrounding with trails on: trails are kept or cleared, never corrupted, when the app returns.
- Reduce Motion: trails start paused with the scene (Phase 01/02 rule).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A04-301**: VisualCore MUST offer an additive blend option for particle drawing, with the existing blend as
  the default so existing drawings stay identical (G-BLENDTRAIL).
- **FR-A04-302**: VisualCore MUST offer a reusable trail layer that keeps the previous image, fades it by a
  documented, frame-rate-independent factor, draws new content on top, and composites the result; it MUST clear on
  request and on resize, and MUST release every texture it created (G-BLENDTRAIL, fixture 3).
- **FR-A04-303**: VisualCore MUST offer a reduced-flash brightness cap for the trail layer (G-BLENDTRAIL).
- **FR-A04-304**: The sandbox MUST let a person add (up to the scene maximum), select and remove emitters of any
  family, show the emitter count, and keep at least one emitter.
- **FR-A04-305**: For the selected emitter the sandbox MUST offer particle size, lifetime and color gradient
  controls with clamped ranges, applied to new particles at once and shown in text.
- **FR-A04-306**: The sandbox MUST offer trails on/off, a trail strength control and a blend choice (normal or
  additive), honor Reduce Flashing with the brightness cap, and show trails as unavailable in the CPU preview.
- **FR-A04-307**: The contract MUST record G-BLENDTRAIL closed with tests. The API baseline, documented-API check,
  host suites, rendering package tests on both runtimes, the reference regression and the A01/A02 builds MUST pass,
  and the Phase 01 replay fixture MUST stay bit-identical.

### Negative requirements

- No new renderer, no app-owned GL/EGL context and no GL calls outside VisualCore.
- No persistence of the new settings yet (Phase 04).
- No measured performance claims; trails are bounded by size and the quality tier, not by invented FPS targets.
- No flashing content that bypasses Reduce Flashing.
- No networking or permissions.

### Key Entities

- **Emitter entry**: family, position and optional overrides (size, lifetime, color gradient).
- **Color gradient**: a named pair or list of colors a particle moves through over its life.
- **Trail settings**: on/off, strength (fade per second), blend mode.
- **Trail layer**: two images swapped each frame, faded, drawn into and composited; cleared on resize.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A04-301**: With 1…the maximum number of emitters, every emitter emits, the live count stays within the
  effective limit, and removing an emitter deletes 0 live particles.
- **SC-A04-302**: After a size, lifetime or gradient change, 100% of particles emitted afterwards carry the new
  values (host test). Lifetime is fixed at birth, so 0 earlier particles change lifetime; size and gradient restyle
  the emitter's live particles at once for immediate feedback (plan research R3), and never another emitter's.
- **SC-A04-303**: A lit trail pixel fades to within 1/255 of the predicted value after 1, 10 and 60 frames at two
  different frame rates for the same elapsed time.
- **SC-A04-304**: After 20 resizes, 20 clears and one context recreation, live trail textures equal the count after
  first setup (0 leaked).
- **SC-A04-305**: With Reduce Flashing on, 100% of sampled trail pixels are at or below the cap.
- **SC-A04-306**: UI tests (add/select/remove emitters, size/lifetime/gradient controls, trails toggle and strength,
  blend choice) and the accessibility audits pass on iOS 27.2 and 26.5.

## Assumptions

- VisualCore's `PingPongTarget`, `FieldPass`, `ResourceRegistry` live-count statistics, `ParticleRenderer` and the
  existing flash-limiting effect are the audited starting points (A04 contract M02–M04, M10).
- Reduce Flashing comes from the shared VisualCore accessibility preferences (system setting plus in-app choice).
- The scene format already allows several emitters (Phase 01); per-emitter overrides are additive optional fields,
  so existing scenes and the replay fixture stay valid.
- Exact ranges, gradient set and fade formula are fixed in clarification (decay `max(prev × s^(Δt·60) − 1/255, 0)`,
  cap 0.6 under Reduce Flashing, size 1…48, lifetime 0.2…8 s, six built-in palettes).

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 deliverable (trails and multiple emitters) | FR-A04-302, FR-A04-304, US1, US3 |
| v0.1 feature 01 (multiple emitter families) | FR-A04-304, US1 |
| v0.1 feature 03 (size, lifetime, color gradient, trail strength) | FR-A04-305, FR-A04-306, US2, US3 |
| Journey 2 (change emitter type and lifetime, toggle trails) | US1, US2, US3 |
| Manual §6 algorithm decision 4, render stage 4 (decay ping-pong trails) | FR-A04-302, US3 |
| Manual §11 fixture 3 (trail FBOs resize and clear without leaks) | FR-A04-302, US4, SC-A04-304 |
| Risk 2 (additive blending flash and brightness limits); v0.1 feature 06 | FR-A04-301, FR-A04-303, US4 |
| Gap register G-BLENDTRAIL | FR-A04-301–303, FR-A04-307 |
