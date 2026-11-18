# Research: A22-P06 (feature 164)

- **R1 Pattern.**
  - **Decision:** A21-P06 (feature 157): the same documents, the same release.json shape, the same two scans, a
    test-only failure seam, and stored samples generated once through the real encoders.
  - **Rationale:** the release checker and its tests already accept that shape.
- **R2 Claims words.**
  - **Decision:** refuse sandbox and safety words, other shader platforms and languages, sharing and upload words, and
    speed words. Require "not a sandbox".
  - **Rationale:** these are the unsupported promises a shader editor attracts. The constitution's A22 section forbids
    a sandbox claim.
- **R3 Samples.**
  - **Decision:** add a P02-shape snapshot (no optional fields) beside the current one.
  - **Rationale:** it proves the chain of optional fields added in A22-P03 to P05.
