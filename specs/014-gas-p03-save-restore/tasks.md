---

description: "Task list for feature 014 — Generative Art Studio Phase 03 save and restore (ledger gate A01-P03)"
---

# Tasks: Generative Art Studio — Phase 03 Save and restore compositions

**Input**: `/specs/014-gas-p03-save-restore/`. **Tests** are required: host store and library tests, hosted app
pixel and leak tests, UI tests on both runtimes, and the reference regression. IDs are `T-A01-3##`, with one commit
and push per task (`scripts/tick_task.py`). **Checkpoints:** after Phase 1, the API baseline, R1–R5 and the reference
regression; after each phase, `validate_docs.py`.

## Phase 1: Foundational — VisualCorePersistence store (US5; blocks US1–US3)

- [X] T-A01-301 [US5] Implement `Packages/VisualCore/Sources/VisualCorePersistence/{Envelope,Migration,DocumentStore}.swift` per contracts/api.md: — Verified 2026-11-10: VisualCorePersistence: Envelope.swift (DocumentEnvelope, StoreProblem incl. invalidID), Migration.swift (MigrationChain over JSON objects, MigrationError), DocumentStore.swift (atomic temp+replace with test hook, id rule, size limit checked before reading, load report with per-file problems and temp cleanup, load(id:)/delete/exists, ISO 8601 dates, sorted keys) + VisualCorePersistenceTests; run-check A01-P03/t301-persistence-tests 6/6: round trip/update/delete, missing dir created, interrupted write keeps old file + temp cleanup, 5 bad of 10 files reported and byte-identical, v0 migrated on load without rewrite, invalid ids and oversize writes rejected; R1-R5 PASS; API baseline updated
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
  the old file; bad files are reported and left byte-identical; migration from a v0 fixture (the file stays byte-identical on load; rewritten only by a
  later save; analyze C3); newer version rejected;
  invalid ids; missing directory created.
- [X] T-A01-302 [US5] Update the API baseline, the VisualCore README section "Persistence", `docs/release/{support-matrix,known-limitations}.md` and the package-map row (Persistence built). Run the host tests and the reference regression (7 steps) (FR-A01-309). — Verified 2026-11-10: VisualCore README Persistence section + module row, support-matrix (DocumentStore host-verified A01-P03), known-limitations built note, getting-started module table, package-map row (built A01-P03); API baseline matches; validate_docs PASS; run-check A01-P03/t302-visualcore-host swift test green; t302-reference-regression 7/7 pass (FR-A01-309)

## Phase 2: US1 + US2 — Save, reopen and organize (P1) 🎯

- [X] T-A01-303 [US1] Implement `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CompositionLibrary.swift`: — Verified 2026-11-10: Core CompositionLibrary.swift (LibraryEntry schema 1; CompositionLibrary over VisualCore DocumentStore kind dev.visualcore.gas.composition; ordering favorites→modified desc→name; normalizedName; save/update-in-place/recreate-if-deleted, duplicate, rename, setFavorite, delete, reload with problems; whole-second times so reloads compare equal); Core + app depend on VisualCorePersistence; run-check A01-P03/t303-core-tests-a2 22/22: 32 round trips incl. seed 2^64-1/0 and 4 families (SC-A01-301), ordering + persistence, update in place, duplicate independence, rename rules, delete and recreate, 2 bad files reported and byte-identical (SC-A01-304), fractional-second reload equality
  - `LibraryEntry` (schema 1);
  - `CompositionLibrary` over `DocumentStore<LibraryEntry>`, kind `dev.visualcore.gas.composition`;
  - ordering: favorites, then modified descending, then name;
  - `normalizedName` (trim, ≤ 60, empty → "Untitled");
  - save or update in place, duplicate ("<name> copy", new id, not favorite), rename, setFavorite, delete, reload
    with problems.

  Add the VisualCorePersistence dependency to the Core package and the app (`project.yml`). Add tests in
  `CompositionLibraryTests.swift`: ≥ 30 generated round trips including seed 2^64−1 and all families
  (SC-A01-301); ordering; duplicate independence; rename rules; delete; update in place keeps the identity and
  advances `modifiedAt`; saving with the id of a deleted entry recreates it (the open composition survives deletion;
  analyze C1); bad files reported (SC-A01-304).
- [X] T-A01-304 [US1] Add `Apps/GenerativeArtStudio/App/LibraryView.swift` and `LibraryModel`: — Verified 2026-11-10: App: LibraryModel (CompositionLibrary in Application Support/Compositions; DEBUG -gasLibraryDir override; error surfacing), LibraryView (gas.library, rows gas.library.row.<uuid> with symbol/name/family/time/swatch, star gas.library.favorite.<uuid>, menu gas.library.more.<uuid> → duplicate/rename/delete, rename alert, delete confirmationDialog gas.library.confirmDelete, problems banner, empty state), gallery Route navigation + Library button gas.library.open, SceneScreen Save gas.save (name alert gas.save.name/confirm on first save, in place afterwards, recreate if deleted while open, gas.save.error alert); Core CompositionEditor(family:document:) (+ test). run-check A01-P03/t304-app-build BUILD SUCCEEDED; t304-core-tests 23/23; documented API PASS. UI behavior verified by T-A01-305
  - list `gas.library`, rows `gas.library.row.<uuid>` with name, family symbol, palette swatch, modified time and a
    favorite star;
  - row actions `gas.library.favorite`, `gas.library.duplicate`, `gas.library.rename` and `gas.library.delete` with a
    `gas.library.confirmDelete` confirmation;
  - a problems banner `gas.library.problems` and an empty state `gas.library.empty`.

  Add the gallery toolbar button `gas.library.open`. Save from the scene: toolbar `gas.save`, a name alert
  (`gas.save.name`, `gas.save.confirm`) on first save, and update in place afterwards. A failed save shows an alert `gas.save.error`, and the previous version
  stays (analyze C2). Deleting the open composition leaves the scene open as unsaved (analyze C1). Opening an entry shows its
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
