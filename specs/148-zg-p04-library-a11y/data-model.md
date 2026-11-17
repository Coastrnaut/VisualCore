# Data Model: A20-P04 (feature 148)

- **`library.json`:** envelope kind `a20.garden-library`, schema 1, `{next: Int, entries: [{file, name, order}]}`.
- **`garden-<n>.json`:** envelope kind `a20.saved-garden`, schema 1, `{name, order, document}`; ≤ 262,144 bytes.
- **`GardenLibrary`:** `entries` (name, file, readable or its refusal code), `save(name:document:)` (replace on an
  existing name), `open(_:) -> GardenDocument`, `rename(_:to:)`, `delete(_:)`; caps 12 gardens, names 1…40
  characters after trimming; messages "The library holds 12 gardens." and "A garden is already called <name>.".
- **`GardenStill`:** 1600 × 1200 PNG, one file in `TemporaryFolder("DigitalZenGarden-Still")`; `export() ->
  Result<URL, StillFailure>`.
- **Bounded history:** `done.count ≤ 100`; encoded done + undone ≤ 2,457,600 bytes; document within its caps.
