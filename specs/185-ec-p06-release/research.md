# Research: Effects Composer — Phase 06

- **R1 Precedent.** Decision: follow `specs/178-gbl-p06-release` document for document, with the A25 facts of the
  clarifications. Rationale: the release checker and the copy check expect that shape.
- **R2 Picker and share sheet in one file.** Decision: the source scan allows `PhotosUI`, `PhotosPicker` and
  `ShareLink` only in `Experience/ECControls.swift` and requires each there. Rationale: one place to review the only
  two system surfaces through which a picture enters or leaves.
- **R3 Samples through the real encoders.** Decision: a throwaway test writes the current samples with
  `ChainDocument`, `LookLibrary` and the core's snapshot encoder; newer samples raise the version; damaged ones cut the
  JSON. Rationale: committed bytes equal what the code writes (A21-P06 lesson).
- **R4 Catalog text.** Decision: rewrite the registration's summary and capabilities to the built features (import,
  linear-light effects, export through the share sheet), keep "shader", stay within 300 characters; run
  `CatalogSearchTests` after the change. Rationale: the copy gate covers the catalog entry, and stale text would
  under-describe the experience.
- **R5 Interface chunk.** Decision: `h3`, serial, like `f3`. Rationale: the live canvas keeps XCTest from idling under
  parallel clones (A08-P06 lesson).
