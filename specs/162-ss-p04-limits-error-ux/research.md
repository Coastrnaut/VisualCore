# Research: A22-P04 (feature 162)

- **R1 Guidance matching.**
  - **Decision:** match the compiler's own words case-insensitively and prove the patterns by compiling broken
    shaders on the simulator's ANGLE in the core tests.
  - **Rationale:** the words differ between drivers, so a test against the real compiler catches drift.
  - **Alternatives:** parsing a grammar of messages was rejected as too much for three patterns.
- **R2 Watchdog input.**
  - **Decision:** `FrameInfo.delta` of each drawn frame.
  - **Rationale:** the session's `PacingMeter` is private. Delta is the presented interval, which grows when the GPU
    work blocks the frame.
  - **Alternatives:** timing the draw call on the CPU was rejected because GPU work is asynchronous and the core may
    not read a clock.
- **R3 Limit and window.**
  - **Decision:** 0.25 s and 8 frames.
  - **Rationale:** the preview targets 30 fps (0.033 s), so 0.25 s is over seven times slower. Eight frames, about
    2 s, avoid stopping on a single hitch.
  - **Alternatives:** a percentile over 60 frames was rejected because it reacts too slowly.
  - **Device check:** the device campaign (A22-P05) measures these values.
- **R4 Reset target.**
  - **Decision:** keep the previous live scene that was not stopped as a fallback, and swap it back without a
    compile.
  - **Rationale:** with a single "last good" slot, the slow shader would be the last good one. A fallback that is
    already built needs no compile from the control.
  - **Alternatives:** recompiling the template on Reset was kept only for when there is no fallback.
- **R5 Library.**
  - **Decision:** Digital Zen Garden's `GardenLibrary` design: one file per project, a counter, an index, caps, and
    unreadable files listed and never deleted.
  - **Rationale:** it is already proved in A20-P04. The types are app-local, so the design is followed, not imported.
  - **Alternatives:** VisualCore's `NamedLibrary` works on a raw directory, not `ExperienceStorage` (contract D6).
