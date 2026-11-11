---

description: "Task list for feature 014 — Generative Art Studio Phase 03 save and restore (ledger gate A01-P03)"
---

# Tasks: Generative Art Studio — Phase 03 Save and restore compositions

**Input**: `/specs/014-gas-p03-save-restore/`. **Tests** are required: host store and library tests, hosted app
pixel and leak tests, UI tests on both runtimes, and the reference regression. IDs are `T-A01-3##`, with one commit
and push per task (`scripts/tick_task.py`). **Checkpoints:** after Phase 1, the API baseline, R1–R5 and the reference
regression; after each phase, `validate_docs.py`.

## Phase 1: Foundational — VisualCorePersistence store (US5; blocks US1–US3)

- [ ] T-A01-301 [US5] Implement `Packages/VisualCore/Sources/VisualCorePersistence/{Envelope,Migration,DocumentStore}.swift` per contracts/api.md:
  - envelope with sorted keys and ISO 8601 `savedAt`;
  - `MigrationChain` over JSON objects;
  - `DocumentStore<Value>`:
    - id `^[A-Za-z0-9._-]{1,128}$`;
    - atomic save (temporary file in the same directory, then replace);
    - an injectable write-failure hook for tests;
    - `load()` lists `*.json` only, reporting `.tooLarge` (checked before reading; default 256 KiB), `.corrupt`,
      `.wrongKind` and `.newerVersion`, and never modifies files;
    - leftover temporary files cleaned on load;
    - `load(id:)`, `delete(id:)`, `exists(id:)`.

  Add a `VisualCorePersistenceTests` target with tests for: round trip; update in place; an interrupted write keeps
  the old file; bad files are reported and left byte-identical; migration from a v0 fixture; newer version rejected;
  invalid ids; missing directory created.
- [ ] T-A01-302 [US5] Update the API baseline, the VisualCore README section "Persistence", `docs/release/{support-matrix,known-limitations}.md` and the package-map row (Persistence built). Run the host tests and the reference regression (7 steps) (FR-A01-309).

## Phase 2: US1 + US2 — Save, reopen and organize (P1) 🎯

- [ ] T-A01-303 [US1] Implement `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CompositionLibrary.swift`:
  - `LibraryEntry` (schema 1);
  - `CompositionLibrary` over `DocumentStore<LibraryEntry>`, kind `dev.visualcore.gas.composition`;
  - ordering: favorites, then modified descending, then name;
  - `normalizedName` (trim, ≤ 60, empty → "Untitled");
  - save or update in place, duplicate ("<name> copy", new id, not favorite), rename, setFavorite, delete, reload
    with problems.

  Add the VisualCorePersistence dependency to the Core package and the app (`project.yml`). Add tests in
  `CompositionLibraryTests.swift`: ≥ 30 generated round trips including seed 2^64−1 and all families
  (SC-A01-301); ordering; duplicate independence; rename rules; delete; update in place keeps the identity and
  advances `modifiedAt`; bad files reported (SC-A01-304).
- [ ] T-A01-304 [US1] Add `Apps/GenerativeArtStudio/App/LibraryView.swift` and `LibraryModel`:
  - list `gas.library`, rows `gas.library.row.<uuid>` with name, family symbol, palette swatch, modified time and a
    favorite star;
  - row actions `gas.library.favorite`, `gas.library.duplicate`, `gas.library.rename` and `gas.library.delete` with a
    `gas.library.confirmDelete` confirmation;
  - a problems banner `gas.library.problems` and an empty state `gas.library.empty`.

  Add the gallery toolbar button `gas.library.open`. Save from the scene: toolbar `gas.save`, a name alert
  (`gas.save.name`, `gas.save.confirm`) on first save, and update in place afterwards. Opening an entry shows its
  scene bound to the entry id. The store lives in `Application Support/Compositions`; UI tests use an isolated
  directory from the launch argument `-gasLibraryDir` (DEBUG only).
- [ ] T-A01-305 [US1] Add `Apps/GenerativeArtStudio/Tests/Unit/LibraryRenderTests.swift` (save → new store instance → reload → render at a fixed time matches the pre-save image, ≥ 99% within 2/255, for 4 families) (SC-A01-302). Add `Apps/GenerativeArtStudio/Tests/UI/LibraryUITests.swift` covering: save with a name, the library lists it, relaunch, it is still there; favorite moves it first; duplicate adds "<name> copy"; rename; delete with confirmation, where cancel keeps it (SC-A01-303). Run on iOS 27.2 and 26.5.

## Phase 3: US4 — Rapid edits never leak (P1)

- [ ] T-A01-306 [US4] Add a rapid-edit leak test to `LibraryRenderTests.swift` or a new `RapidEditLeakTests.swift`: for each of the 4 families, 200 palette, seed and preset edits applied with a frame between them; live program, texture and render-target counts equal the starting counts; 0 leaked after destroy (FR-A01-308, SC-A01-305). Run on both runtimes.

## Phase 4: Polish

- [ ] T-A01-307 Update `docs/apps/generative-art-studio/visualcore-contract.json` (G-PERSIST closed A01-P03; M08 available with DocumentStore evidence and a CompositionLibrary example) and render it. Run `check_app_contract`, the documented API for the app, and the release-check fast steps (FR-A01-311, SC-A01-306).

## Dependencies

T-A01-301 → T-A01-302 → T-A01-303 → T-A01-304 → T-A01-305. T-A01-306 is independent of the library (it needs only the
P02 scene). T-A01-307 runs last.

## Implementation strategy

The VisualCore store first, then the domain library, then the UI, then the leak gate and the contract.
