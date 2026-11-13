# ADR-0011 — The fluid picture of A02 is presentation; quality levels act only on how a state is shown

**Date:** 2026-11-13 · **Status:** accepted (gate `UA-F07`, clarifications 1 and 2 of
[specs/193-ua-f07-legacy-adoption/spec.md](../../specs/193-ua-f07-legacy-adoption/spec.md), decided by the lead
under the owner's standing delegation)

This ADR records a design decision for the adoption of the existing apps A01 to A04 as experiences. It is not
evidence that any of them is adopted.

## Context

Auto-Creator.md section 6 sets the experience rules. E-04 says that the same seed gives the same state digest and
that outcomes are decided by CPU state, never by reading back pixels. E-05 says that a restore gives the same
digest. E-13 says that a quality level never changes the digest.

A02 Fluid Art Playground keeps its fluid (velocity, pressure and dye) in GPU textures and advances it with shader
passes (`FluidFieldsScene`). The textures cannot be part of a digest or a snapshot: reading them back would break
E-04, and their content depends on the GPU's arithmetic. A02 and A04 Particle Universe also lower work under a lower
quality level: A02 fewer solver iterations and a smaller splat cap, A04 a smaller particle count. If that work were
state, the level would change the digest and break E-13.

## Decision

1. **A02's state is CPU state.** `FluidArtCore` holds the `FluidConfiguration`, the control choices (palette,
   edges, detail, paused), the pending splats as actions (bounded by `SplatQueue.maxPending`), the step index and
   the seed. The digest and the snapshot cover these and nothing else.
2. **The fluid picture is presentation.** The presenter runs the GPU passes for the steps since its last draw and
   applies each splat once, at the step the core recorded it. After a restore or a context loss its fields start
   again from the seeded dye pattern (`DyeSeed.pattern(seed:)`) with the restored configuration. The picture is
   not an outcome: A02 declares no outcome, and nothing is decided from the GPU.
3. **Quality levels act only on how a state is shown.** A02's three levels (Full, Reduced, Minimal) set the
   solver iterations and the splat cap of the picture. A04's four levels from `SceneQuality` set a draw cap; the
   simulation keeps the requested particle count. A01 and A03 have one level. Each of these is listed as an
   adapter difference in the adapter's file header and in research.md (FR-U07-003).

## Consequences

- E-04, E-05 and E-13 hold for A02 and A04 and are tested with the digest before and after a level change and a
  save and restore.
- After a restore, A02's picture differs from the one before the save. This is accepted: what the person made (the
  configuration and the choices) comes back, and the fluid is a live effect.
- The verification runner's frame probes for A02 check the frame is not blank and not one colour; they never
  compare the fluid's pixels with a stored picture.
- A04 with many particles at a low level simulates more than it draws. Whether that fits the frame budget on
  devices is measured in the device campaign, not claimed from the simulator.

## Alternatives considered

- **The CPU `FluidSolver` as the authority.** It would make the fluid part of the digest, but change the app's
  behaviour and cost far more CPU time per frame.
- **Reading back the dye texture for the digest.** Forbidden by E-04.
- **Levels that lower simulated work.** They break E-13.
