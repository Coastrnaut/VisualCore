# Research: A22-P05 (feature 163)

- **R1 Leak measure.**
  - **Decision:** the registry's `liveCount` per kind and `totalBytes`, compared after the warm-up cycle and after the
    last cycle; `leaked` must stay 0 across rebuilds.
  - **Rationale:** the first cycle legitimately creates the fallback and the stopped scene. After that, the level
    must be flat.
  - **Alternatives:** comparing with the level before any run was rejected, because the warm-up objects are intended.
- **R2 Shape in the core.**
  - **Decision:** an action, `document.shape`, sent by the presenter.
  - **Rationale:** the core stays pure and replayable and never parses source. An action is recorded and restored
    like every other change.
  - **Alternatives:** making the bounds the maximum (16 uniforms, 2 inputs) was rejected because it loses the
    `a22.no-uniform` guard. Computing the shape in the core from source was rejected because the core holds no source.
- **R3 Short runs.**
  - **Decision:** the counts are fixed by the spec (50, 20, 10, 10 × 5), and each run draws one 32 × 24 frame.
  - **Rationale:** they finish in seconds and are bounded by arithmetic (owner ruling of 2026-11-13).
- **R4 Device plan.**
  - **Decision:** Aurora's `device-campaign.md` layout.
  - **Rationale:** it is the established pattern, and every row stays pending until after `ImplementationLock-100`.
