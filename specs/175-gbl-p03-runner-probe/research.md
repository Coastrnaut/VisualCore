# Research: A24-P03 (feature 175)

- **R1 Timer present on the simulator.** A throwaway probe on 2026-11-19 listed 95 extensions on the iOS 27.2
  simulator, including `GL_EXT_disjoint_timer_query` (ANGLE 2.1.1, 29d18232e803, Metal). Decision: build U-GPUTIMER.
- **R2 Where the entry points go.** Decision: a hand-written block in the loader; the generated header is regenerated
  from the core ES 3.0 list and must not be edited. Optional points do not count as missing (the floor check).
- **R3 Elapsed-time queries over timestamps.** Decision: `GL_TIME_ELAPSED_EXT` around the frame's draw calls.
  Rationale: one query per frame, no timestamp support assumed. Alternative: `glQueryCounterEXT` timestamps (rejected:
  more queries, `GL_TIMESTAMP_EXT` support varies).
- **R4 Ring of 4.** Decision: results are read up to 4 frames later; a frame without a result by the end has none.
- **R5 Capabilities on the registry.** Decision: a read-only property on `ResourceRegistry`. Rationale: every scene
  callback already has `context.resources`; no initializer change. Alternative: a field on `RenderContext` (rejected:
  its initializer is used by `redirected(to:)` and wrappers).
- **R6 Dropped rule.** Decision: interval > 1.5 × the 60 Hz frame period (25 ms). Rationale: the presenter's cap; simple
  and documented. Alternative: target timestamps (rejected: not comparable across refresh rates in this phase).
