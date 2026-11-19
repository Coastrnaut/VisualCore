# Research: A23-P04 (feature 169)

- **D1 Library (clarification Q1):** the Shader Studio and Zen Garden library pattern (one file per item, an index for
  the counter and names, files as the truth, unreadable files listed and kept) is proven twice in this repository;
  VisualCore's `NamedLibrary` works on a raw directory, not on the experience's quota-bound storage.
- **D2 Open by restore (Q2):** the graph is core state, so opening must go through the engine; `shell.restore(_:)`
  validates the snapshot as any restore does, so a bad file can never put the core in a state a person could not
  reach.
- **D3 Migration (Q3):** there is one format; the reader is written against `MigrationChain` and exercised with a
  synthetic version-0 step in a test, so the first real schema change adds one step.
- **D4 Examples (Q4):** three graphs that each use a different operator mix, written in code; no data files.
- **D5 Diagnostics (Q5):** the checker's issues already name nodes and ports; mapping them is pure, and marks use a
  shape (dashed outline and badge) besides colour.
