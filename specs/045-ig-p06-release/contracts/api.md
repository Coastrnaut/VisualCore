# Contract: A05-P06 (no public API change)

- `GeometryPresenter.failNextDraw: Bool` (internal) — the next `render` throws `GeometryDrawError.injected` and clears it.
- `enum GeometryDrawError: Error, Equatable { case injected }` (internal).
- Interface identifiers used by the UI tests: `experience.a05.infinite-geometry.<control>` (existing prefix) for preset,
  symmetry order, camera buttons, `library.name`, `library.save`, `library.open.<i>`, `export`, `export.share`.
