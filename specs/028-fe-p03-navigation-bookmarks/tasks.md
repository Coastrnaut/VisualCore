---

description: "Task list for feature 028 — Fractal Explorer Phase 03 navigation and bookmarks (ledger gate A03-P03)"
---

# Tasks: Fractal Explorer — Phase 03 Navigation and bookmarks

**Input**: `/specs/028-fe-p03-navigation-bookmarks/`: the spec (3 clarifications plus the checklist amendments), the
plan, research R1–R5, the data model, the contract and the quickstart.

**Tests are required**:
- host tests for VisualCore and FractalExplorerCore;
- app unit and UI tests on iOS 27.2 and 26.5, run under the enumeration guard;
- the ProjectM regression and the A01 and A02 builds after the VisualCore additions.

**Conventions**: IDs are `T-A03-3##`, with one commit per task through `scripts/tick_task.py`. Commands run through
`run-check --stage A03-P03`. Review checkpoint after each phase: the diff is read and the phase's tests rerun.

## Phase 1: Foundational — VisualCore G-FRAMING and G-LIBRARY (blocks all stories)

- [X] T-A03-301 [P] Write `PlaneFramingTests` first (`Packages/VisualCore/Tests/VisualCoreMathTests/PlaneFramingTests.swift`, ≥ 6 per the contract), then add `Packages/VisualCore/Sources/VisualCoreMath/PlaneFraming.swift`: center "finite, else (0, 0)"; span "finite and > 0, else 1; plane length across the shorter side"; `init(_ viewport:)`, `viewport(size:)`; Codable. Docs, README note, baseline (`check_public_api.py --update`). Run `swift test --package-path Packages/VisualCore` (FR-A03-301, SC-A03-302). — Verified 2026-11-11: — Verified 2026-11-11: VisualCoreMath.PlaneFraming (center finite else (0,0), span finite > 0 else 1, init(_ viewport:), viewport(size:), validating Codable), documented, README and baseline; PlaneFramingTests 6/6 (100 random views x 5 sizes: center bit-exact, span within 1e-12; portrait->landscape square pixels; fallbacks; Codable with validation on decode; clamped span; matches framing) in run-check A03-P03/t301-host-visualcore (full package) and t301-host-visualcore-2; t301-checks failed on 2 undocumented Codable members, fixed, t301-checks-2 4/4
- [ ] T-A03-302 [P] Write `NamedLibraryTests` first (`Packages/VisualCore/Tests/VisualCorePersistenceTests/NamedLibraryTests.swift`, ≥ 8 per the contract), then add `Packages/VisualCore/Sources/VisualCorePersistence/NamedLibrary.swift`: `Entry` (id UUID, name "trimmed, ≤ 60, 'Untitled' when empty", favorite, createdAt/modifiedAt "whole seconds", payload), ordering "favorite desc, modifiedAt desc, name", save/rename/setFavorite/duplicate/delete/reload with problems, caller `validate`. Docs, README, baseline. Run `swift test` (FR-A03-302).
- [ ] T-A03-303 After 301 and 302: run the ProjectM regression (`release_check.py` reference-a 3/3 and reference-b 4/4) and `build-for-testing` of A01 and A02; run `public-api dependencies docs compliance` (FR-A03-307, SC-A03-306).

**Checkpoint**: VisualCore additions reviewed; regression 7/7.

## Phase 2: User Story 1 and 2 — bookmarks save and return (P1) 🎯

- [ ] T-A03-304 [US1] [US2] Write `BookmarkTests` first, then add `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/Bookmark.swift`: `Bookmark` (mode, framing with "|x|,|y| ≤ 4 for center; span finite > 0", juliaSeed finite, iterationCap "1…10,000", escapeRadius "≥ 2, finite", paletteID "one of sunset, ocean, forest, neon, ember", precision), `PrecisionMode` (format "gpu-float32", mantissaBits "1…64", level "reliable" | "nearLimit" | "beyondLimit"), `validated()`, `Bookmark(state:paletteID:precision:)` and `apply(to:)`; `BookmarkLibrary` wrapping `NamedLibrary<Bookmark>` (kind `dev.visualcore.fe.bookmark`, schema 1, `Application Support/Bookmarks`). Package depends on VisualCorePersistence. Tests: round trip over 100 random views × 5 sizes (bit-exact center, 1e-12 span), invalid fields reported as damaged, library save/reload in a `TemporaryFolder` (FR-A03-303, SC-A03-301).
- [ ] T-A03-305 [US1] [US2] Model and UI in `Apps/FractalExplorer/App/ExplorerView.swift` and new `Apps/FractalExplorer/App/BookmarksView.swift`: `saveBookmark(name:)`, `open(_:)`, rename/favorite/delete; the `fe.bookmarks` button, sheet `fe.bookmarks.list` with rows (name, center, zoom, level when not reliable), empty-state text, `fe.bookmark.save` with the name alert (`fe.bookmark.name`), swipe actions, context menu and accessibility actions; a write failure alert. `project.yml`: app links VisualCorePersistence. Add `NavigationModelTests` (save → reload → open at another size returns the state; damaged file listed as a problem; write failure leaves state unchanged). Run on both runtimes (FR-A03-304, US1, US2).

**Checkpoint**: MVP — save and return.

## Phase 3: Regression fixture — aspect changes (P1)

- [ ] T-A03-306 [US2] Change `ExplorerModel.resize(to:)` to go through `PlaneFraming` (analyze D1), then add `Apps/FractalExplorer/Tests/Unit/AspectTests.swift`: 100 random resizes keep the center exactly and the span within 1e-12 with one scale for both axes; the GPU default Mandelbrot at 64×32 and 32×64 agrees with the CPU reference ≥ 99% (boundary-only). Run on both runtimes (FR-A03-306, SC-A03-302, SC-A03-303).

## Phase 4: User Story 3 — precision mode travels (P2)

- [ ] T-A03-307 [US3] Store the precision mode at save time (`PrecisionAdvisor.assess` with the model's bits); on open apply the clamp and set `bookmarkNote` ("Saved at higher precision (N bits); shown at this device's limit (M bits)") shown as `fe.bookmark.note` only when the clamp changed the span, cleared on the next apply. Unit tests: a 23-bit deep bookmark opened with a forced 10-bit model is clamped with the banner and the note; a fitting bookmark shows no note; the note clears on zoom out. Run on both runtimes (US3, SC-A03-304).

## Phase 5: User Story 4 — Go to coordinates (P2)

- [ ] T-A03-308 [P] [US4] Write `GoToInputTests` first, then add `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/GoToInput.swift` per research R4 ("." and locale separator, "−" minus, |x|, |y| ≤ 4, zoom in (0, 1e15], the three error texts). Run `swift test` (FR-A03-305).
- [ ] T-A03-309 [US4] Add `Apps/FractalExplorer/App/GoToView.swift` (sheet: `fe.goto.real`, `fe.goto.imaginary`, `fe.goto.zoom`, `fe.goto.go`, `fe.goto.error`) and the `fe.goto` button; `goTo(center:zoom:)` sets span = default width ÷ zoom through `apply`. Unit test: −0.743643887, 0.131825904, 1000 reads "zoom 1000×"; invalid input changes nothing. Run on both runtimes (US4).

## Phase 6: Polish

- [ ] T-A03-310 Add `Apps/FractalExplorer/Tests/UI/BookmarkUITests.swift` (empty-state text before the first save (analyze G1), save with a name, list, open after changing the view, rename, favorite, delete; Go to with a valid and an invalid input) and extend the audit with the bookmarks sheet and the Go to sheet at default size and XXXL. Run on both runtimes. Then: contract (gate A03-P03, M07 and M02 evidence with PlaneFraming and NamedLibrary, gaps G-FRAMING and G-LIBRARY added as closed, G-COST moved to phase 4, A01 adoption follow-up in the notes), regression baseline section, simulator lessons, fast checks (FR-A03-307, SC-A03-305, SC-A03-306).

## Dependencies

- T-A03-301 and T-A03-302 are independent; both precede T-A03-303 and every story.
- T-A03-304 → T-A03-305 → T-A03-307.
- T-A03-306 needs only T-A03-301 (analyze D1).
- T-A03-308 is independent of 304–307 (pure parsing); T-A03-309 needs 305 (the model) and 308.
- T-A03-310 runs last.

## Parallel examples

- 301 ∥ 302 (different VisualCore modules).
- 308 ∥ 304 (different Core files).

## Implementation strategy

MVP = Phases 1–2 (save and return, with the VisualCore pieces). Then the aspect fixture, precision mode and Go to,
then polish. Each task is committed on its own after its tests pass.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- D1: the span-keeping resize moved into T-A03-306, which now depends only on T-A03-301.
- G1: the empty-state text is covered by `BookmarkUITests`.
- C1: plan row VIII aligned with the spec (Phase 06 declares FileTimestamp C617.1).
- U1: `NamedLibrary.duplicate` is VisualCore API only; the app does not show it in this slice (recorded in the spec).
- 0 critical issues.
