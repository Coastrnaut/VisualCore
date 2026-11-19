# Research: A24-P02 (feature 174)

- **R1 Determinism.** Decision: every picture is a function of the case and the workload frame number. Rationale:
  repeatable scenes (constitution A24); byte-identical tests across hosts. Alternative: the host's frame time
  (rejected: it varies with pacing).
- **R2 Textured quads.** Decision: a code-made texture in a render target and `layers` full-screen `FieldPass` draws
  sampling it. Rationale: `FieldPass` samples render targets only and disables blending, so each layer fills every
  pixel; a sprite helper does not exist (A24-P00 survey). Alternative: `Texture.upload` (rejected: `FieldPass` cannot
  sample a bare texture).
- **R3 ALU stress.** Decision: a constant loop bound of 1,024 with an early exit at the uniform. Rationale: GLSL ES 3.00
  allows it and the caps bound the work.
- **R4 Samples without a timer.** Decision: `gpuMs` absent on every sample; the summary flag says so. Rationale: the
  phase's regression fixture; constitution A24 provenance.
- **R5 No system menu.** Decision: inline buttons for the cases. Rationale: XCTest never saw the app idle with a
  menu open over a live drawing (A23-P05 lesson).
