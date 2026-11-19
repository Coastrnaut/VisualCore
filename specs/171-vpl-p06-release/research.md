# Research: A23-P06 (feature 171)

- **R1 Pattern.**
  - **Decision:** A22-P06 (feature 164): the same documents, the same release.json shape, the same two scans, a
    test-only failure seam, and stored samples generated once through the real encoders.
  - **Rationale:** the release checker and its tests already accept that shape.
  - **Alternatives considered:** a new release format (rejected: the checker would change for one experience).
- **R2 Claims words.**
  - **Decision:** refuse programming-language and typed-code words, other node tools, sharing and upload words, and
    speed words. Require "no code to type".
  - **Rationale:** these are the unsupported promises a node editor attracts; the lab has no text editor and no export.
- **R3 Samples.**
  - **Decision:** keep the A23-P04 `graph-sample.json` as the current saved graph and add newer and damaged graph
    files, three snapshots and three indexes in a new `ReleaseSampleTests`.
  - **Rationale:** the snapshot has had one schema since A23-P02 with no optional fields, so no older-shape sample
    exists; the committed graph sample already proves the current file byte for byte.
