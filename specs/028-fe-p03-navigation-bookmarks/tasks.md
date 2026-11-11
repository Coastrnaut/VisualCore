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
- [X] T-A03-302 [P] Write `NamedLibraryTests` first (`Packages/VisualCore/Tests/VisualCorePersistenceTests/NamedLibraryTests.swift`, ≥ 8 per the contract), then add `Packages/VisualCore/Sources/VisualCorePersistence/NamedLibrary.swift`: `Entry` (id UUID, name "trimmed, ≤ 60, 'Untitled' when empty", favorite, createdAt/modifiedAt "whole seconds", payload), ordering "favorite desc, modifiedAt desc, name", save/rename/setFavorite/duplicate/delete/reload with problems, caller `validate`. Docs, README, baseline. Run `swift test` (FR-A03-302). — Verified 2026-11-11: — Verified 2026-11-11: VisualCorePersistence.NamedLibrary<Payload> (Entry id/name/favorite/createdAt/modifiedAt whole seconds/payload; normalizedName trimmed <= 60, Untitled; ordering favorites, recent, name; save new or in place keeping createdAt, rename, setFavorite, duplicate ' copy', delete, reload reporting damaged/newer/invalid files and keeping them; caller validate on save and load; defaultDirectory(named:)), documented, README and baseline; NamedLibraryTests 8/8 in run-check A03-P03/t302-host-visualcore (persistence suite 20 tests passed); t302-checks 4/4
- [X] T-A03-303 After 301 and 302: run the ProjectM regression (`release_check.py` reference-a 3/3 and reference-b 4/4) and `build-for-testing` of A01 and A02; run `public-api dependencies docs compliance` (FR-A03-307, SC-A03-306). — Verified 2026-11-11: — Verified 2026-11-11: ProjectM regression after PlaneFraming and NamedLibrary: run-check A03-P03/t303-reference-a 3/3 (pin d93edd1 unchanged) and t303-reference-b 4/4; A01 t303-build-GenerativeArtStudio and A02 t303-build-FluidArtPlayground TEST BUILD SUCCEEDED from clean derived data; public-api/dependencies/docs/compliance 4/4 in t302-checks

**Checkpoint**: VisualCore additions reviewed; regression 7/7.

## Phase 2: User Story 1 and 2 — bookmarks save and return (P1) 🎯

- [X] T-A03-304 [US1] [US2] Write `BookmarkTests` first, then add `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/Bookmark.swift`: `Bookmark` (mode, framing with "|x|,|y| ≤ 4 for center; span finite > 0", juliaSeed finite, iterationCap "1…10,000", escapeRadius "≥ 2, finite", paletteID "one of sunset, ocean, forest, neon, ember", precision), `PrecisionMode` (format "gpu-float32", mantissaBits "1…64", level "reliable" | "nearLimit" | "beyondLimit"), `validated()`, `Bookmark(state:paletteID:precision:)` and `apply(to:)`; `BookmarkLibrary` wrapping `NamedLibrary<Bookmark>` (kind `dev.visualcore.fe.bookmark`, schema 1, `Application Support/Bookmarks`). Package depends on VisualCorePersistence. Tests: round trip over 100 random views × 5 sizes (bit-exact center, 1e-12 span), invalid fields reported as damaged, library save/reload in a `TemporaryFolder` (FR-A03-303, SC-A03-301). — Verified 2026-11-11: — Verified 2026-11-11: FractalExplorerCore Bookmark (mode, PlaneFraming, seed, cap, radius, paletteID in the 5 explorer palettes, PrecisionMode format gpu-float32/bits 1...64/level from PrecisionAdvisor), validated(), state(size:), summary; BookmarkLibrary = VisualCore NamedLibrary<Bookmark> (kind dev.visualcore.fe.bookmark, schema 1, Application Support/Bookmarks); package depends on VisualCorePersistence; FractalState.zoomText public. BookmarkTests 4 (100 random views saved, reloaded and opened at 5 sizes: center bit-exact, span within 1e-12, mode/seed/cap kept; 8 invalid-field rejections; damaged file reported and kept; precision levels and summary) — run-check A03-P03/t304-core-test 4 Swift Testing + 12 XCTest passed; t304-checks 5/5
- [X] T-A03-305 [US1] [US2] Model and UI in `Apps/FractalExplorer/App/ExplorerView.swift` and new `Apps/FractalExplorer/App/BookmarksView.swift`: `saveBookmark(name:)`, `open(_:)`, rename/favorite/delete; the `fe.bookmarks` button, sheet `fe.bookmarks.list` with rows (name, center, zoom, level when not reliable), empty-state text, `fe.bookmark.save` with the name alert (`fe.bookmark.name`), swipe actions, context menu and accessibility actions; a write failure alert. `project.yml`: app links VisualCorePersistence. Add `NavigationModelTests` (save → reload → open at another size returns the state; damaged file listed as a problem; write failure leaves state unchanged). Run on both runtimes (FR-A03-304, US1, US2). — Verified 2026-11-11: — Verified 2026-11-11: ExplorerModel bookmarks (VisualCore NamedLibrary via BookmarkLibrary, injectable folder, -uitestTemporaryBookmarks; saveBookmark with PrecisionMode from the advisor, open through apply so the clamp applies, rename/favorite/delete, error text on failure) and App/BookmarksView (fe.bookmarks toolbar button, sheet with fe.bookmarks.list rows fe.bookmark.row.N labelled name/coordinates/zoom/level/favorite, empty-state text fe.bookmarks.empty, fe.bookmark.save with name alert, swipe actions, context menu and accessibility actions, error alert); project.yml links VisualCorePersistence; palette ids from Bookmark.paletteIDs. NavigationModelTests 4 (save -> second model at 844x390 reload -> open: mode/seed/cap/palette, center exact, span within 1e-12; rename/favorite/delete/order/Untitled; damaged file reported and kept; write failure leaves list and view unchanged). First runs t305-app-ios27/26 failed to compile (typed-throws closure); run-check A03-P03/t305-app-ios27-2 and t305-app-ios26-2 TEST SUCCEEDED, enumeration 30/30 each

**Checkpoint**: MVP — save and return.

## Phase 3: Regression fixture — aspect changes (P1)

- [X] T-A03-306 [US2] Change `ExplorerModel.resize(to:)` to go through `PlaneFraming` (analyze D1), then add `Apps/FractalExplorer/Tests/Unit/AspectTests.swift`: 100 random resizes keep the center exactly and the span within 1e-12 with one scale for both axes; the GPU default Mandelbrot at 64×32 and 32×64 agrees with the CPU reference ≥ 99% (boundary-only). Run on both runtimes (FR-A03-306, SC-A03-302, SC-A03-303). — Verified 2026-11-11: — Verified 2026-11-11: ExplorerModel.resize(to:) through VisualCore PlaneFraming (analyze D1); AspectTests 3: 100 random resizes 200...1400 pt keep the center exactly, the span within 1e-12 and one scale for both axes, invalid size ignored; GPU default Mandelbrot after a shape change at 64x32 and 32x64 matches the CPU reference 100.0% with 0 unexplained on both runtimes — run-check A03-P03/t306-app-ios27 and t306-app-ios26 TEST SUCCEEDED, enumeration 33/33 each

## Phase 4: User Story 3 — precision mode travels (P2)

- [X] T-A03-307 [US3] Store the precision mode at save time (`PrecisionAdvisor.assess` with the model's bits); on open apply the clamp and set `bookmarkNote` ("Saved at higher precision (N bits); shown at this device's limit (M bits)") shown as `fe.bookmark.note` only when the clamp changed the span, cleared on the next apply. Unit tests: a 23-bit deep bookmark opened with a forced 10-bit model is clamped with the banner and the note; a fitting bookmark shows no note; the note clears on zoom out. Run on both runtimes (US3, SC-A03-304). — Verified 2026-11-11: — Verified 2026-11-11: precision mode saved from PrecisionMode.level (one rule shared with the banner: at the clamp = beyondLimit, within 16 steps = nearLimit); open applies the clamp and sets bookmarkNote ('Saved at higher precision (23 bits); shown at this device's limit (10 bits)', fe.bookmark.note) only when the clamp changed the span, cleared by the next apply. BookmarkPrecisionTests 3: a 23-bit bookmark at the limit opens on a 10-bit model clamped at the advisor minimum with the banner and the note, which clears on zoom out; a fitting bookmark opens unclamped without a note; the list label names 'At precision limit'. First run t307-app-ios27 failed (the clamp's margin 1 was saved as nearLimit while the banner said reached; the shared rule fixed it, and a test wrongly expected 10 bits to be reliable at 4x); run-check A03-P03/t307-core-test 12+4, t307-app-ios27-2 and t307-app-ios26-2 TEST SUCCEEDED, enumeration 36/36 each

## Phase 5: User Story 4 — Go to coordinates (P2)

- [X] T-A03-308 [P] [US4] Write `GoToInputTests` first, then add `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/GoToInput.swift` per research R4 ("." and locale separator, "−" minus, |x|, |y| ≤ 4, zoom in (0, 1e15], the three error texts). Run `swift test` (FR-A03-305). — Verified 2026-11-11: — Verified 2026-11-11: FractalExplorerCore GoToInput (trim, '.' or locale separator, U+2212 minus, finite only; |x|,|y| <= 4; zoom in (0, 1e15]; errors 'Enter a number', 'Use a value between −4 and 4', 'Zoom must be above 0 and at most 1e15' with the field), GoToTarget.framing(for:) span = default width / zoom. GoToInputTests 4 (−0.743643887 + 0.131825904i at 1000 reads 'zoom 1000×'; separators and minus; 9 rejections; boundaries) — run-check A03-P03/t308-core-test 8 Swift Testing + 12 XCTest passed
- [X] T-A03-309 [US4] Add `Apps/FractalExplorer/App/GoToView.swift` (sheet: `fe.goto.real`, `fe.goto.imaginary`, `fe.goto.zoom`, `fe.goto.go`, `fe.goto.error`) and the `fe.goto` button; `goTo(center:zoom:)` sets span = default width ÷ zoom through `apply`. Unit test: −0.743643887, 0.131825904, 1000 reads "zoom 1000×"; invalid input changes nothing. Run on both runtimes (US4). — Verified 2026-11-11: — Verified 2026-11-11: App/GoToView (sheet: fe.goto.real, fe.goto.imaginary, fe.goto.zoom labelled fields, fe.goto.go, inline fe.goto.error naming the field and announced, Cancel) and the fe.goto toolbar button; ExplorerModel.goTo(real:imaginary:zoom:) applies span = default width / zoom through apply (precision clamp applies), invalid input changes nothing. GoToModelTests 3 (−0.743643887, 0.131825904, 1000 reads 'Mandelbrot set, centered at −0.743644 + 0.131826i, zoom 1000×'; three invalid entries leave the state; 1e15 is clamped with the banner). First run t309-app-ios27 failed (project not regenerated for the new file); run-check A03-P03/t309-app-ios27-2 and t309-app-ios26-2 TEST SUCCEEDED, enumeration 39/39 each

## Phase 6: Polish

- [X] T-A03-310 Add `Apps/FractalExplorer/Tests/UI/BookmarkUITests.swift` (empty-state text before the first save (analyze G1), save with a name, list, open after changing the view, rename, favorite, delete; Go to with a valid and an invalid input) and extend the audit with the bookmarks sheet and the Go to sheet at default size and XXXL. Run on both runtimes. Then: contract (gate A03-P03, M07 and M02 evidence with PlaneFraming and NamedLibrary, gaps G-FRAMING and G-LIBRARY added as closed, G-COST moved to phase 4, A01 adoption follow-up in the notes), regression baseline section, simulator lessons, fast checks (FR-A03-307, SC-A03-305, SC-A03-306). — Verified 2026-11-11: — Verified 2026-11-11: BookmarkUITests 2 (empty-state text, save 'Valley' -> row 'Valley, −0.5 + 0i · zoom 4×', reset then open returns zoom 4×, rename to Seahorse and favorite through swipe actions, delete back to empty; Go to rejects real 9 with 'Real part: Use a value between −4 and 4' then −0.75, 0, 10 reads 'centered at −0.75 + 0i, zoom 10×') and the audit of the Go to sheet and the bookmark sheet (empty and listed) at default size and XXXL. Fixes found by these runs: row hit shape (whole row opens), Go to hint moved out of the gray footer, short prompts with wrapping fields (XXXL clipping); run-check A03-P03/t310-app-ios27-6 and t310-app-ios26-6 TEST SUCCEEDED, enumeration 41/41 each (earlier attempts -1...-5 failed and are kept). Contract gate A03-P03 (PlaneFraming in M02, M07 on NamedLibrary with the Bookmark example, G-FRAMING and G-LIBRARY closed, G-COST moved to phase 4, decision reason) check_app_contract PASS 10 rows/37 citations/7 gaps; regression baseline A03-P03; lessons feature 028; t310-fast-checks 11/11

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
