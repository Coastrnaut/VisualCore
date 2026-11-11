---

description: "Task list for feature 026 — Fractal Explorer Phase 01 complex-plane math and fixtures (ledger gate A03-P01)"
---

# Tasks: Fractal Explorer — Phase 01 Complex-plane math and fixtures

**Input**: `/specs/026-fe-p01-complex-math/`: the spec with 5 clarifications and the checklist amendments, the plan,
research R1–R4, the data model, the contract and the quickstart.

**Tests are required**:
- host tests for VisualCore and FractalExplorerCore;
- app unit and UI tests on iOS 27.2 and 26.5, with the enumeration guard;
- the ProjectM regression;
- builds of A01 and A02.

**Conventions**:
- IDs are `T-A03-1##`, with one commit per task through `scripts/tick_task.py`.
- Commands run through `run-check --stage A03-P01`.

## Phase 1: Foundational — VisualCore PlaneViewport (blocks US3)

- [X] T-A03-101 Write `PlaneViewportTests` first (`Packages/VisualCore/Tests/VisualCoreMathTests/PlaneViewportTests.swift`, — Verified 2026-11-11: — Verified 2026-11-11: VisualCoreMath.PlaneViewport (center, unitsPerPoint clamped 1e-15...1e3 with wasClamped, size with last-valid fallback, plane(fromScreen:)/screen(fromPlane:) y-up plane, pinched(by:anchor:), panned(by:), resized(to:), framing(width:center:size:)), documented, README and baseline; PlaneViewportTests 8/8 (round trip < 1e-9 pt, anchored pinch drift < 1e-12 relative over 1e-6...1e6, clamps, pan, 100 random resizes keep center and square pixels, invalid inputs incl. zero/NaN size, framing) in run-check A03-P01/t101-host-visualcore; t101-checks 4/4; ProjectM regression t101-reference-a 3/3 + t101-reference-b 4/4; A01 and A02 build-for-testing succeeded
  at least 8 tests per the contract, including a zero or non-finite size keeping the last valid size; analyze G1). Then add `Packages/VisualCore/Sources/VisualCoreMath/PlaneViewport.swift` with:
  - center: `Vec2`, finite, otherwise (0, 0);
  - `unitsPerPoint`: clamped to 1e-15…1e3, with `wasClamped`;
  - size: a non-positive or non-finite size keeps the previous valid size, initially 1×1;
  - `plane(fromScreen:)` and `screen(fromPlane:)` (y down on screen, y up in the plane);
  - `pinched(by:anchor:)`, `panned(by:)`, `resized(to:)` and `framing(width:center:size:)`.

  Add docs, the README module note and the baseline. Run `swift test --package-path Packages/VisualCore`, then the
  ProjectM regression (3/3 + 4/4) and builds of A01 and A02 (FR-A03-104, SC-A03-102).

## Phase 2: User Story 2 — fractal math (P1)

- [X] T-A03-102 [US2] Write tests first, then add `Apps/FractalExplorer/FractalExplorerCore`: — Verified 2026-11-11: — Verified 2026-11-11: Apps/FractalExplorer/FractalExplorerCore (package on VisualCoreMath; in project.yml packages) with FractalMath.escape/mandelbrot/julia (escape when |z|^2 > R^2 after step n, smooth n + 1 - log2(log|z_n|), interior at cap, non-finite input escapes at 0 with smooth 0, cap 1...10,000, R >= 2); FractalMathTests 6: Mandelbrot interior 0, -1, -0.1+0.1i; exterior 2->2, 1+i->2, -2.1->1; Julia c=0 z=0.5 interior, z=1.5 count 1, c=-1 z=0 interior, c=-0.8+0.156i z=2 count 1; smooth bounds; NaN/Inf; validation. The first run (t102-core-test) failed on the spec's smooth bound [n-1, n+1], which is wrong for |z_n| just above 2; the spec now states the derived [n, n+1+log2(1/ln 2)] and run-check A03-P01/t102-core-test-2 passes 6/6
  - `Package.swift`, depending on VisualCoreMath;
  - `FractalMath.swift`:
    - `escape(z0:c:cap:radius:)`: escape when |z|² > R² after step n; count n; smooth value
      n + 1 − log₂(log|zₙ|);
    - interior when the cap is reached;
    - a non-finite input escapes at step 0 with a smooth value of 0;
    - `mandelbrot` and `julia` wrappers;
  - `FractalMathTests` with the FR-A03-103 fixtures:
    - Mandelbrot interior: 0, −1 and −0.1+0.1i;
    - Mandelbrot exterior: 2 → 2, 1+i → 2, −2.1 → 1;
    - Julia: c = 0 with z = 0.5 (interior) and z = 1.5 (count 1); c = −1 with z = 0 (interior);
      c = −0.8+0.156i with z = 2 (count 1);
    - the smooth value lies within [n−1, n+1];
    - NaN and Inf inputs.

  Add the package to `project.yml` and run `swift test` (FR-A03-102, FR-A03-103, SC-A03-101).
- [X] T-A03-103 [US1] [US2] Add `FractalState.swift`: — Verified 2026-11-11: — Verified 2026-11-11: FractalState (mode with reframing on change, PlaneViewport, seed keeping the last finite value, cap 1...10,000 default 200, radius >= 2, defaults per clarification 5, zoom, escape(at:), spokenDescription 'Mandelbrot set, centered at −0.5 + 0i, zoom 1×' with 6 significant digits and zoom 37× / 1e4× / 2.5e7×), FractalExplanations (z² + c, seed, connected, dust), Preview (<= 160 per side keeping aspect, black interior, gray ramp, deterministic, requestID); FractalStateTests 6 incl. validation edge cases (analyze G1); run-check A03-P01/t103-core-test-3 12/12 (earlier runs t103-core-test-2 failed on the zoom text format at 9999.99... and was fixed by rounding before the scientific threshold)
  - mode;
  - viewport;
  - seed;
  - cap 1…10,000 (default 200);
  - radius ≥ 2;
  - defaults per clarification 5;
  - `spokenDescription`, formatted per FR-A03-101.

  Add `FractalExplanations.swift` (one text per mode, including the Mandelbrot–Julia relation and the note about
  seeds outside |c| ≤ 2) and `FractalPreview.swift` (at most 160 samples per side, grayscale ramp, black interior,
  deterministic, with `requestID`). Write the tests first: validation (cap 0 → 1, cap 20,000 → 10,000, radius 1 → 2, a non-finite seed; analyze G1), description format, explanations, preview
  origin and c = 2 pixels, determinism (FR-A03-101, FR-A03-105, FR-A03-106, SC-A03-104).

## Phase 3: User Story 1 — explorer UI (P1) 🎯

- [X] T-A03-104 [US1] [US4] Add `Apps/FractalExplorer/App/ExplorerView.swift`: — Verified 2026-11-11: — Verified 2026-11-11: App/ExplorerView.swift (ExplorerModel @MainActor @Observable: preview in a detached task, request ids, stale results dropped and counted; segmented fe.mode picker, fe.mode.explanation, fe.canvas image labelled with the spoken description, fe.seed in Julia mode), home link fe.home.open, project.yml (app links FractalExplorerCore, VisualCoreMath, VisualCoreUI; FractalExplorerTests unit target; scheme runs unit + UI tests); Core type renamed Preview -> FractalPreview (collides with SwiftUI; spec/plan/data model updated; t104-app-ios27 first failed to compile on the ambiguity); ExplorerModelTests 3 (defaults + preview + image, mode switch changes explanation/description/picture, stale result dropped and newest of 5 requests shown); run-check A03-P01/t104-app-ios27-2 and t104-app-ios26-2 TEST SUCCEEDED, enumeration 4/4 each; t104-core-test 12/12; t104-isolation PASS
  - `ExplorerModel` (`@MainActor @Observable`), which computes the preview in a detached task and drops stale
    request identifiers;
  - a segmented `fe.mode` picker;
  - `fe.mode.explanation`;
  - the `fe.canvas` image, labelled with the spoken description;
  - the `fe.seed` text in Julia mode.

  Also:
  - the home link `fe.home.open`;
  - `project.yml`: the app links FractalExplorerCore, VisualCoreMath and VisualCoreUI, plus the `FractalExplorerTests`
    unit target and scheme updates;
  - `ExplorerModelTests` (mode switch, stale result dropped, default state).

  Run on 27.2 and 26.5 with the guard (FR-A03-101, FR-A03-106).
- [X] T-A03-105 [US1] Add `Apps/FractalExplorer/Tests/UI/ExplorerUITests.swift` (open, switch modes, explanation — Verified 2026-11-11: — Verified 2026-11-11: Tests/UI/ExplorerUITests (opens in Mandelbrot, explanation and canvas label 'Mandelbrot set, centered at −0.5 + 0i, zoom 1×', switch to Julia: explanation mentions the seed, label 'Julia set for seed −0.8 + 0.156i, centered at 0 + 0i, zoom 1×', fe.seed shown, back to Mandelbrot) and AccessibilityAuditUITests (home, explorer Mandelbrot and Julia at default size and XXXL with A02's documented exclusions) — run-check A03-P01/t105-app-ios27 and t105-app-ios26 TEST SUCCEEDED, no audit issues, enumeration 7/7 each
  and canvas label change) and `AccessibilityAuditUITests.swift` (home and explorer in both modes, at default size
  and XXXL, using A02's exclusions). Run on 27.2 and 26.5 (SC-A03-103).

## Phase 4: Polish

- [ ] T-A03-106 Update the contract: gate A03-P01, G-VIEWPORT and G-FRACTAL closed, PlaneViewport in the M02
  evidence, decision reason. Also update the regression baseline and the simulator lessons. Run the fast checks:
  docs, app-contracts, compliance, dependencies, public-api, licenses, script-tests, host-visualcore,
  documented-api-fractal-explorer, isolation-fractal-explorer and host-fractal-explorer-core (FR-A03-107,
  SC-A03-105).

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- G1: the edge-case tests are named.
- D1: the speculative edge 101 → 102 is dropped.
- 0 critical issues.

## Dependencies

- T-A03-101 and T-A03-102 are independent.
- Both block T-A03-103, then T-A03-104 → T-A03-105 (analyze D1).
- T-A03-106 runs last.
