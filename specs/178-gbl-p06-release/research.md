# Research: A24-P06 (feature 178)

- **R1 Pattern.**
  - **Decision:** A23-P06 (feature 171): the same documents, the same release.json shape, the same two scans, a
    test-only failure seam, and stored samples generated once through the real encoders.
  - **Rationale:** the release checker and its tests already accept that shape.
  - **Alternatives considered:** a new release format (rejected: the checker would change for one experience).
- **R2 Claims words.**
  - **Decision:** refuse ranking and score words, precision and certification words, other benchmark tools and
    platforms, upload and account words, and speed words; require "does not rank devices". The explanation is left
    out of this scan because it states those limits as negations.
  - **Rationale:** these are the unsupported promises a benchmark attracts (constitution A24 "Truthful claims").
  - **Alternatives considered:** scanning the explanation with an exception list (rejected: negations would need
    per-line exceptions).
- **R3 Sharing.**
  - **Decision:** the share sheet is allowed in `Experience/ResultsView.swift` only, and the shared copy check allows
    "share".
  - **Rationale:** the export of A24-P04 is a real feature started only by the person's tap.
- **R4 Samples.**
  - **Decision:** a new `ExperienceTests/Fixtures/` folder (copied as a test resource) with three snapshots, three
    saved results and three indexes, read by `ReleaseSampleTests`.
  - **Rationale:** the snapshot has had one schema since A24-P02 and the saved result one version since A24-P04, so no
    older-shape sample exists; the run file's own migrations are covered by the A24-P04 core fixtures.
