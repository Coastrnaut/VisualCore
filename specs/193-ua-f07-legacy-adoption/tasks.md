# Tasks: UA-F07 — Adoption of the existing apps A01 to A04 as experiences

**Input**: Design documents from `specs/193-ua-f07-legacy-adoption/` (spec.md, plan.md, research.md, data-model.md,
contracts/adoption-api.md, quickstart.md)

**Base commit**: `af887e3` (the API baseline and boundaries are compared with it). **Legacy ledger**: SHA-256 of
`.autonomy/state.json` at the base begins `2604ffd8292cc8a8`; it must be the same at the end.

**Tests**: required (constitution IV). Every test task comes before the code it proves.

**Evidence**: `python3 scripts/migration_ledger.py run-check --gate UA-F07 --name <check-name> -- <command>`; the X
gates use their own gate names. A task is ticked as `- [X] <id> … — Verified YYYY-MM-DD: <command and result>`
only after its proof was reproduced. Commit after every task with `python3 scripts/tick_task.py`.

**Order**: A01, then A02, then A03, then A04 (FR-U07-045). Each experience is a group of commits that can be
reverted alone.

## Phase 1: Setup

- [X] T-U07-001 Record the parity baseline before any adapter: — Verified 2026-11-13: swift test of the four Core packages: 31, 56, 12+26, 40+1 tests pass; migration_baseline.py verify: 0 problems; legacy ledger SHA-256 2604ffd8…b7ca; recorded in research.md section 3
  - `swift test` of the four Core packages (paths in quickstart.md), with the counts of tests run;
  - `python3 scripts/migration_baseline.py verify` (the six fixture hashes);
  - the SHA-256 of `.autonomy/state.json`;
  - recorded in research.md section 3 "Baseline" (FR-U07-001, FR-U07-002, FR-U07-050; SC-U07-001, SC-U07-002, SC-U07-008).
- [X] T-U07-002 [P] Tests first in `scripts/test_scripts.py` (class `TestMapTests`), then `scripts/check_test_map.py` — Verified 2026-11-13: python3 scripts/test_scripts.py: Ran 316 tests, OK; TestMapTests 9 tests pass (missing old method, nonexistent new method, failed in log all reported); run-check test-map-tool. The tool's first version entered commit 5218995 with the T-U07-001 tick
  (contracts/adoption-api.md, Tools). It must report three failures: a missing old method, a mapped new method
  that does not exist, and (with `--log`) a mapped method that did not pass. The test methods are read the way
  `check_test_enumeration.py` reads them (FR-U07-031).

## Phase 2: Foundational (blocking every adoption)

- [X] T-U07-003 Tests first, in `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/PointerPathTests.swift`: — Verified 2026-11-13: PointerPathTests 5 tests written first (did not compile before the API existed); after T-U07-004 the full VisualCoreExperienceHostTests target passes 149/149 on sim-27.2 and sim-26.5 (run-checks pointer-path-host-ios272, pointer-path-host-ios265)
  - a pointer event on the open experience's host reaches the presenter's `pointer(_:viewSize:port:)` with the
    view size;
  - an action the presenter sends through the port changes the state;
  - no event reaches a closed experience;
  - the handler is cleared at every close and replaced at the next open;
  - the default presenter ignores events.

  Cover these with the sample presenter on both simulator runtimes (FR-U07-019; clarification 5).
- [X] T-U07-004 Implement the pointer path: — Verified 2026-11-13: ExperiencePresenter.pointer(_:viewSize:port:) with default, Experience.handlePointer, ExperienceShell forwarding only while active, ExperienceSession sets renderHost.pointerHandler and clears it in destroyHost; host target gains VisualCoreMath and VisualCoreScenes; check_public_api.py --update: 2178 declarations, 0 undocumented; host tests 149/149 on both runtimes; reference regression a and b exit 0 (reference-a-pointer, reference-b-pointer)
  - `ExperiencePresenter.pointer(_:viewSize:port:)` with its default;
  - `Experience.handlePointer(_:viewSize:)`;
  - `ExperienceShell` forwarding it;
  - `ExperienceSession` setting and clearing `renderHost.pointerHandler`;
  - the `VisualCoreScenes` dependency of the host target, if it is missing;
  - the API baseline and `///` documentation.

  T-U07-003 passes on both runtimes (FR-U07-019, FR-U07-064).
- [X] T-U07-005 Tests first in `Apps/VisualCore/Tests/Unit/AppModelTests.swift`, then — Verified 2026-11-13: AppModelTests gains 3 candidate tests (written first); ExperienceRegistry.candidates (empty until A01), ScenarioLaunch.targets reads all + candidates, DebugLaunch -vcCandidates with makeAvailable; app unit chunk AppModel/Store/Bundle/ScenarioLaunch passes on iOS 27.2 and 26.5 phone (run-checks candidates-app-ios27, candidates-app-ios26)
  `ExperienceRegistry.candidates`, the scenario targets reading `all + candidates`, and the debug argument
  `-vcCandidates` in `DebugLaunch.swift`. `-vcCandidates` makes the candidates' fixture entries available and
  registers them. The registry agreement test keeps comparing only `all` with the catalog (FR-U07-021;
  clarification 4).
- [X] T-U07-006 ADR-0011 `docs/decisions/ADR-0011-fluid-picture-presentation.md`: the fluid picture of A02 is — Verified 2026-11-13: docs/decisions/ADR-0011-fluid-picture-presentation.md written (A02 state is CPU state, the fluid picture is presentation, quality levels act only on how a state is shown; E-04, E-05, E-13 of Auto-Creator.md section 6); validate_autocreator.py passes
  presentation; the digest and the snapshot cover the CPU state; quality levels act on how a state is shown
  (clarifications 1 and 2).

**Checkpoint**: the host gives touches to experiences, candidates can be opened, the decisions are recorded.

## Phase 3: User Story 1 — Generative Art Studio runs inside the one app (P1)

**Independent test**: with `-vcCandidates` the launcher opens A01; the runner passes its scenarios on both
runtimes.

- [X] T-U07-007 [US1] Tests first: `Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Tests/GenerativeArtCoreTests.swift` (host, Swift — Verified 2026-11-13: Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Tests/GenerativeArtCoreTests.swift, 11 Swift Testing tests (conformance over seeds 1, 7, 42, 2^64-1; every control; rejections; app editor parity; clock; deterministic shuffle; open/rebase; snapshot round trip; work-saved); swift test --package-path Apps/GenerativeArtStudio/GenerativeArtStudioAdapter: 11 passed (run-check a01-core-host). Location correction in research.md section 4
  Testing, in a package test target or the framework test bundle). Cover:
  - the conformance helper (`ExperienceConformance`) passes for `GenerativeArtCore` over 4 seeds;
  - each control of data-model section 2 changes the digest as specified, and invalid values are rejected;
  - `time` advances only in `update(step:)` and wraps like `SceneClock`;
  - `seed.shuffle` is a deterministic derivation of the current seed (a listed adapter difference);
  - the snapshot round trip returns the same digest;
  - the outcome is `work-saved` after a save action.
- [X] T-U07-008 [US1] Implement `Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/GenerativeArtCore.swift`. It wraps `ArtDocument`, — Verified 2026-11-13: Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Core/GenerativeArtCore.swift with six listed adapter differences; edits go through CompositionEditor; T-U07-007 passes 11/11 (run-check a01-core-host)
  the family, the preset and the time; `CompositionEditor` and `SceneFamily` are rebuilt from the catalog. The file
  header lists each difference from the standalone app. T-U07-007 passes.
- [X] T-U07-009 [US1] `GenerativeArtPresenter.swift`, `GenerativeArtControls.swift` and `GenerativeArtManifest.swift` in — Verified 2026-11-13: Adapter/Experience: GenerativeArtPresenter (ArtCanvasScene over ArtSceneFactory with fixedTime, EffectScene limiter, CPU-derived particle-corner probe), GenerativeArtControls (families, time, presets, palettes, seed, parameters, library via ExperienceStorage, export via ShareLink and the new ExperienceStillRenderer; labels and 44 pt targets), GenerativeArtLibrary, GenerativeArtManifest (9 standard + 5 fixtures, committed digests); swift test 14/14 (a01-manifest-host); host tests 151/151 on sim-27.2 and sim-26.5 (still-host-ios272/265); public API 2183, 0 undocumented; reference regression a and b exit 0 (reference-a-still, reference-b-still). The largest-text-size check of E-12 is part of the ported accessibility audit (T-U07-015)
  `Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/`:
  - the presenter wraps `ArtSceneFactory` with `fixedTime` from the core and the framework's bundle for shaders,
    and declares a probe;
  - the controls cover the gallery families, presets, palettes, parameters, seed, play, pause and scrub, and the
    library (save, open, rename, remove) through `ExperienceStorage`;
  - export goes to the system's share interface or the experience's storage (FR-U07-020);
  - every control has a VoiceOver label, fits at the largest text size, and is at least 44 by 44 points (FR-U07-022);
  - the manifest has the nine standard scenarios plus one `fixture-<n>` per regression fixture of the A01 card.
- [X] T-U07-010 [US1] `project.yml`: the framework target `GenerativeArtStudioExperience` (data-model section 1) and its — Verified 2026-11-13: project.yml: static framework GenerativeArtStudioExperience (App sources minus GenerativeArtStudioApp, LaunchCleanup, AppAutomation; Adapter/Experience), test bundle GenerativeArtStudioExperienceTests, adapter package GenerativeArtStudioAdapter; VisualCore links both and copies the A01 shaders; A01 in ExperienceRegistry.candidates with GenerativeArtCore and its manifest. release_check.py --only xcodegen PASS (a01-xcodegen); the app builds and AppModelTests 46/46 (ua-f07-a01-build log); check_app_isolation --app Apps/VisualCore and --experiences Adapter PASS (a01-isolation-app, a01-isolation-adapter); storage-rule and stored-data-rule with the adapter folders PASS (a01-storage-rules); test_scripts 316 OK (scripts-a01)
  test bundle; `Apps/VisualCore` links it; the registration of A01 is in `ExperienceRegistry.candidates` with its
  core, examples (none, schema 1) and manifest. Then:
  - `python3 scripts/release_check.py --only xcodegen`;
  - the app builds;
  - `check_app_isolation.py --app Apps/VisualCore` and the storage rule on the adapter pass.
- [X] T-U07-011 [US1] Session and conformance on the simulators: the A01 adapter's session tests (open, close, — Verified 2026-11-13: GenerativeArtSessionTests 7 tests (open with first frame and probe, close without GPU objects across four families and six palettes, suspension, retry after refused restore, memory warning, context recreation, 20 cycles) pass 7/7 on iOS 27.2 and 26.5 phone (run-checks a01-session-ios27, a01-session-ios26)
  suspension, retry, memory warning, context loss) in the framework's test bundle on iOS 27.2 and 26.5 (FR-U07-011;
  SC-U07-003).
- [X] T-U07-012 [US1] Parity with the standalone app: for 3 seeds and the same actions, the adapter's document and time — Verified 2026-11-13: GenerativeArtParityTests: for seeds 5, 77 and 0xC0FFEE0012345678 the adapter's family, seed, palette, parameters, preset, baseline, time and playing equal the standalone SceneModel's after the same edits and 120 steps; the picture of every family at t = 5 s equals the app's own scene (within2 = 1.0, mean 0, max 0; tolerance 0.99 / 0.5). The adapter bundle passes on iOS 27.2 and 26.5 phone (run-checks a01-parity-ios27, a01-parity-ios26); VisualCoreTests still links (AppModelTests passed after the bundle's package link was removed)
  equal what the standalone `SceneModel` gives (a test in the framework bundle that drives both); the picture of the
  first frame matches the standalone scene's for the same document and time within the existing image tolerance
  (FR-U07-003; SC-U07-005).
- [X] T-U07-013 [US1] Acceptance: `python3 scripts/verify_experiences.py --only a01.generative-art-studio --runtime 27 26` — Verified 2026-11-13: python3 scripts/verify_experiences.py --only a01.generative-art-studio --runtime 27 --fresh: 9/9 scenarios pass on iOS 27.2 (a01-verify-27-fresh); --runtime 26: 9/9 on iOS 26.5 (a01-verify-26-r2); save-restore across two launches passed in 3 of 3 runs (a01-persist-run1..3). The first run failed teardown-reentry (a01-verify-27, kept), fixed by GrowthRule.judge(_:warmUp:) with the first cycle as warm-up (host 381+98+15, package tests on both runtimes, reference regression a and b exit 0). Summaries in docs/verification/a01.generative-art-studio/
  passes every scenario; a state changed by actions comes back after the app ends, in 3 of 3 runs (SC-U07-010).

## Phase 4: User Story 2 — Domain behaviour is unchanged (P1)

- [X] T-U07-014 [US2] After each experience's adapter and after each move: the Core host tests run with the same counts as — Verified 2026-11-13: After each adapter and each move: the Core tests keep the T-U07-001 counts in Packages/ExperiencesCreative on sim-27.2 and sim-26.5 (A01 31, A02 56, A03 38, A04 41; xcresult of a01-a04-package-ios272/265); no Core test file changed: check_renames.py from af887e3 over all four Core test folders PASS (core-tests-renames-only-all) and per experience (a01/a02/a03/a04-core-renames-only); migration_baseline.py verify 0 problems (baseline-verify-all-moved)
  the T-U07-001 baseline, with no test file of a Core package changed (`git diff --stat af887e3 -- <Core tests>`
  empty), and `migration_baseline.py verify` passes. This task is re-run and its evidence recorded per experience
  (FR-U07-001, FR-U07-002; SC-U07-001, SC-U07-002).

## Phase 5: User Story 6 — No interface test is lost (P2), applied per experience

- [X] T-U07-015 [US6] Port A01's 14 UI tests to `Apps/VisualCore/Tests/UI/GenerativeArtStudio/` with class names — Verified 2026-11-13: Apps/VisualCore/Tests/UI/GenerativeArtStudio/: GASAccessibilityAuditUITests, GASControlsUITests, GASExportUITests, GASGalleryUITests, GASLibraryUITests, GASRecoveryUITests and GASSupport; test-map.csv with 14 rows (3 mapped to the one app's Launch and Settings tests); the audits run at the default and the largest text size; chunks g1-g3 in the run script. Fixes from the first runs are listed in research.md section 4
  prefixed `GAS…`, launches through `-vcResetData -vcSkipWelcome -vcCandidates -openExperience
  a01.generative-art-studio`, and locators `experience.a01.generative-art-studio.<control>`. Write the 14 rows of
  `test-map.csv`; settings, launch and acknowledgements tests map to the one app's equivalents with their note.
  Add the chunk `-g` (`GenerativeArtStudio` classes) to the app test runs. The ported accessibility audits run at the default and the largest text size (FR-U07-022, FR-U07-030 to FR-U07-033; SC-U07-004).
- [X] T-U07-016 [US6] Run the A01 chunk on the iOS 27.2 phone; `check_test_map.py` on its log passes for the 14 rows. — Verified 2026-11-13: iOS 27.2 phone: chunks g1, g2, g3 pass (app-phone-ios27-g1..g3), Settings and Launch pass (app-phone-ios27-b-r2); check_test_map.py --app GenerativeArtStudio with those logs: PASS 14 old tests mapped to 14 new tests (a01-test-map-r3). Earlier attempts kept: app-phone-ios27-b (project not regenerated), a01-test-map and -r2 (covering logs missing)

## Phase 6: User Story 7 — A01 moves and retires (P3)

- [X] T-U07-017 [US7] Move A01 with `git mv` along migration-plan.md section 2.1 into — Verified 2026-11-13: git mv of A01 into Packages/ExperiencesCreative/GenerativeArtStudio/{Core,CoreTests,Experience,Shaders,ExperienceTests}, UI tests in Apps/VisualCore/Tests/UI/GenerativeArtStudio (commit 5fdc293); Package.swift with GenerativeArtStudioCore, GenerativeArtStudioExperience (shaders as resources) and their tests; the framework target replaced by the package product; #filePath and contract paths fixed (check_app_contract resolves through Catalog/path-map.json: PASS); 7 moves in Catalog/path-map.json, 9 docs/migration/path-map.json entries done. Re-runs: T-U07-014 check_renames.py 22 files without a changed line (a01-core-renames-only), package 95/95 on sim-27.2 and sim-26.5 incl. Core 31 (a01-package-ios272/265), migration_baseline verify (baseline-verify-a01-moved); T-U07-011 session tests in the package; T-U07-013 runner 9/9 on 27.2 and 26.5 (a01-verify-27-moved, a01-verify-26-moved)
  `Packages/ExperiencesCreative/GenerativeArtStudio/{Core,CoreTests,Experience,Shaders,ExperienceTests}` and
  `Apps/VisualCore/Tests/UI/GenerativeArtStudio`. Create `Packages/ExperiencesCreative/Package.swift` (merging A01's
  Core manifest; the Experience target with the shaders as resources). In the same commit:
  - replace the framework target by the package products;
  - fix every `#filePath` and contract path (research R9);
  - record each move in `Catalog/path-map.json` and set the entries of `docs/migration/path-map.json` to `done` (SC-U07-006);
  - re-run T-U07-014, T-U07-011 and T-U07-013 for A01 (FR-U07-040 to FR-U07-042, FR-U07-044).
- [X] T-U07-018 [US7] Retire the `GenerativeArtStudio` app, unit-test and UI-test targets and scheme in `project.yml`. — Verified 2026-11-13: project.yml: GenerativeArtStudio, GenerativeArtStudioTests, GenerativeArtStudioUITests and their scheme retired with the move (commit 5fdc293), asset catalog retired; the 40 app unit tests run in GenerativeArtStudioExperienceTests (95 = 40 + 15 adapter + 9 session/parity + Core 31, same 40 as before; a01-package-ios272/265); the app builds and its unit chunk passes on iOS 27.2 (app-phone-ios27-c-moved-r2) and the A01 UI chunk g2 (app-phone-ios27-g2-moved); release_check.py --list has no generative-art-studio step and adds experiences-creative-sim-ios27/ios26 (script tests 318 OK); storage-rule, stored-data-rule, app-contracts and compliance PASS
  The app unit tests now run as `ExperienceTests`, with the same count (FR-U07-034). The project builds, and
  `release_check.py` drops the per-app steps of the retired scheme and adds the experience package's host tests
  (FR-U07-043; SC-U07-007).
- [X] T-U07-019 [US7] Prepare X-A01 (corrected 2026-11-13: X-A01 depends on UA-F07 in the ledger, so it is recorded — Verified 2026-11-13: Readiness of X-A01 as UA-F07 checks: host = package tests GenerativeArtStudioCoreTests and GenerativeArtStudioExperienceTests 95/95 on sim-27.2 (a01-x-host); sim27 and sim26 = verify_experiences.py --only a01.generative-art-studio 9/9 each after the move (a01-verify-27-moved, a01-verify-26-moved); audits PASS (a01-x-audits). Recording X-A01, moving the registration to all and rebuilding the catalog follow the UA-F07 record (ledger dependency; FR-U07-051 corrected)
  right after UA-F07; FR-U07-051):
  - run the four checks of Auto-Creator.md 22.2 as UA-F07 checks: the package tests of A01 on a simulator (the
    package needs UIKit, so `swift test` cannot build it), and the runner on 27 and 26 and its audits for A01;
  - after UA-F07 is recorded: run them again under X-A01, seal and record X-A01, move A01's registration from
    `candidates` to `all`, and run `python3 scripts/build_catalog.py` so that A01 becomes available (SC-U07-008).

## Phase 7: User Story 5 — Fluid Art Playground (P3), steps of Phases 3, 5 and 6 for A02

- [X] T-U07-020 [US5] Tests first: `FluidArtCoreTests` covering: — Verified 2026-11-13: Apps/FluidArtPlayground/FluidArtPlaygroundAdapter/Tests/FluidArtCoreTests.swift: conformance over 4 seeds; every control as an action; pause/step/resume; strokes equal SplatQueue's splats for the same tracker samples; pending bounded by SplatQueue.maxPending (1074 queued, 1024 kept, 50 dropped) and drained under the cap; digest of CPU state only, unchanged by tiers 0-2 and shedding; reset and detail; snapshot round trip; manifest valid with 5 fixtures and its committed digests. swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundAdapter: 12 passed (a02-core-host)
  - conformance;
  - strokes, pinch, splash, pause, step, reset, palette, edges, detail and sliders as actions;
  - pending splats bounded by `SplatQueue.maxPending`;
  - the digest covers only CPU state;
  - a quality level never changes the digest (clarifications 1 and 2).
- [X] T-U07-021 [US5] `FluidArtCore`, `FluidArtPresenter` (it runs the passes for the steps since its last draw, restarts — Verified 2026-11-13: FluidArtCore and manifest (host 12/12, a02-core-host-renamed), FluidArtPresenter (one GPU step per frame for the core's steps, splats applied once and thinned by the level's cap, fields from DyeSeed.pattern at setup, reset and detail change, pointer events through the app's tracker and pinch recognizer into stroke and pinch actions, CPU-derived empty-dye probe), FluidArtControls (canvas, palette, brush, motion, quality, edges, detail, tuning reset, capture via the still renderer and ShareLink; labels and 44 pt), static framework FluidArtPlaygroundExperience and candidate registration; FluidArtSessionTests 6/6 incl. configuration parity with PlaygroundModel for 3 seeds on iOS 27.2 and 26.5 (a02-session-ios27/26); runner 9/9 on 27.2 and 26.5 (a02-verify-27, a02-verify-26). E-12 at the largest text size is checked by the ported audit (T-U07-022)
  the fields from `DyeSeed.pattern(seed:)` at setup, applies the level to iterations and the splat cap, and turns
  pointer events into `stroke` actions), `FluidArtControls`, `FluidArtManifest`; the framework target and candidate
  registration; session tests on both runtimes; parity of the configuration and the CPU state for 3 seeds; capture
  through the share interface; controls meeting E-12 (FR-U07-010 to FR-U07-022; SC-U07-003, SC-U07-005).
- [X] T-U07-022 [US5] Port A02's 9 UI tests (`FAP…`, chunk `-h`), with their map rows and guard. Then the runner on both — Verified 2026-11-13: A02 interface tests ported (FAP classes, 9 map rows): h1 and h2 pass on iOS 27.2 (app-phone-ios27-h1, -h2), check_test_map --app FluidArtPlayground PASS 9 to 10 (a02-test-map); runner 9/9 on 27.2 and 26.5 before and after the move (a02-verify-27/26, a02-verify-*-moved); move into Packages/ExperiencesCreative/FluidArtPlayground with the standalone targets, scheme, UI tests and asset catalog retired; Core moved without a changed line (a02-core-renames-only, 26 files); package 245/245 on both runtimes incl. A02's 76 unit tests (a01-a02-package-ios272/265); app unit chunk and h2 pass after the move (app-phone-ios27-c-a02moved, -h2-moved); X-A02 readiness: host = package, sim27/sim26 = runner after the move, audits PASS (a02-x-audits); X-A02 is recorded after UA-F07 (FR-U07-051)
  runtimes, the move, the retirement and X-A02 as in T-U07-013 and T-U07-015 to T-U07-019.

## Phase 8: User Story 3 — Fractal Explorer (P2), same steps for A03

- [X] T-U07-023 [US3] Tests first: `FractalCoreTests` covering: — Verified 2026-11-13: Apps/FractalExplorer/FractalExplorerAdapter/Tests/FractalCoreTests.swift (10 tests) and the manifest tests (3): conformance over 4 seeds; size-independent framing equal to FractalState for 3 sizes; pan, pinch and zoom buttons equal the standalone PlaneViewport arithmetic for 2 sizes; cap, palette, animation, seed; go-to numbers from the app's GoToInput; palette animation and tours advance only with steps (a tour timeline matches at 5 s and finishes); precision limit; bookmark open; snapshot round trip. swift test: 13 passed (a03-core-host)
  - conformance;
  - the framing is size-independent;
  - pan, pinch and the zoom buttons as normalized actions;
  - the cap, palette, animation and seed;
  - go-to parsing stays in the controls, and the core takes numbers;
  - tours and palette animation advance with steps, never with `systemUptime`.
- [X] T-U07-024 [US3] `FractalCore`, `FractalPresenter` (the viewport is derived from the drawable size, and pointer events — Verified 2026-11-13: FractalCore and manifest (host 13/13, a03-core-host), FractalPresenter (viewport from the drawable, palette time from the core, pan and pinch from touches as ExplorerModel moves them, centre-inside probe), FractalControls (family, view, go-to parsed by GoToInput, iterations with cost, palettes and animation, Julia seed, tours, bookmarks via ExperienceStorage, capture via the still renderer and ShareLink; labels and 44 pt), FractalBookmarks, static framework FractalExplorerExperience and candidate registration; FractalSessionTests 5/5 incl. framing parity with ExplorerModel for 3 seeds and sizes on iOS 27.2 and 26.5 (a03-session-ios27/26); runner 9/9 on 27.2 and 26.5 (a03-verify-27, a03-verify-26). E-12 at the largest text size is checked by the ported audit (T-U07-025)
  become `pan` and `pinch`), `FractalControls` (with bookmarks through `ExperienceStorage` and go-to), and
  `FractalManifest`; the framework target and candidate; session tests on both runtimes; framing parity for 3 seeds;
  capture through the share interface; controls meeting E-12 (FR-U07-020, FR-U07-022).
- [X] T-U07-025 [US3] Port A03's 10 UI tests (`FE…`, chunk `-i`), with their map rows. Then the runner, the move (including — Verified 2026-11-13: A03 interface tests ported (FE classes, 10 map rows): i2 and both audits pass on iOS 27.2 (app-phone-ios27-i2, -i1a-r2, -i1b-r3; the audits found and the controls fixed two E-12 issues), check_test_map --app FractalExplorer PASS 10 to 12 (a03-test-map-r2); runner 9/9 on 27.2 and 26.5 before and after the move (a03-verify-27/26, -moved); move into Packages/ExperiencesCreative/FractalExplorer incl. Tests/Fixtures/bookmark-v1.json to ExperienceTests/Fixtures with MigrationTests fixed, Core and fixture moved without a changed line (a03-core-renames-only, 19 files); standalone targets, scheme, UI tests and asset catalog retired; package 365/365 on both runtimes (a01-a03-package-ios272/265); app unit chunk and i2 pass after the move (app-phone-ios27-c-a03moved, -i2-moved); X-A03 readiness: audits PASS (a03-x-audits); X-A03 is recorded after UA-F07
  `Tests/Fixtures/bookmark-v1.json` → `ExperienceTests/Fixtures` with the `MigrationTests` path fixed), the retirement
  and X-A03.

## Phase 9: User Story 4 — Particle Universe (P2), A04 without retirement

- [X] T-U07-026 [US4] Tests first: `ParticleCoreTests` covering: — Verified 2026-11-13: Apps/ParticleUniverse/ParticleUniverseAdapter/Tests: ParticleCoreTests (8) and ParticleReplayTimingTests (1), all short: conformance over 4 seeds; replay payload restores the same checksum and digest; a rebase keeps the configuration and restores to the same digest; the quality level caps only the drawn count; force.place maps 0..1 to the world square; checksum equals the standalone SceneSimulation for the same seed and commands; pause and step; outcome scene-built; a 10-second replay costs 0.85 s in debug (about 2 simulated minutes within the limit) and 0.026 s in release. swift test: 9 passed (a04-core-host). The 30-minute replay test was replaced by the short one (owner rule of 2026-11-13; spec, research and tasks corrected)
  - conformance;
  - the replay payload restores the same checksum and digest;
  - a short replay (10 simulated seconds) gives the cost per step on the host and on both simulators in the session
    tests, and the longest state within 10 s follows from it (corrected 2026-11-13: tests are short);
  - the quality level caps only the drawn count;
  - `force.place` at normalized positions maps to the scene's world;
  - the checksum equals the standalone `SceneSimulation`'s for the same seed and commands (clarification 3;
    SC-U07-011).
- [X] T-U07-027 [US4] `ParticleCore`, `ParticlePresenter` (the source reads the core, with no stepping in the render — Verified 2026-11-13: ParticleCore (replay snapshot with a rebase every 10 simulated minutes) and manifest (host 12/12, a04-core-host re-run), ParticlePresenter (ParticleLayerScene source reads the core, level caps the drawn count, taps and drags to force.place, background probe), ParticleControls (playback, emitters, family, size, lifetime, colours, force kind, centre, nudge, strength, trails, blend, new seed; labels and 44 pt), static framework ParticleUniverseExperience and candidate registration; ParticleSessionTests 5/5 incl. restore by replay and a short replay's cost on iOS 27.2 and 26.5 (a04-session-ios27/26); runner 9/9 on 27.2 and 26.5 (a04-verify-27, a04-verify-26). E-12 at the largest text size is checked by the ported audit (T-U07-028)
  callback; taps and drags become `force.place` actions), `ParticleControls`, `ParticleManifest`; the framework target
  and candidate; session tests on both runtimes; controls meeting E-12 (FR-U07-022).
- [X] T-U07-028 [US4] Port A04's 23 UI tests (`PU…`, chunk `-j`) with their map rows. Then the runner on both runtimes and — Verified 2026-11-13: A04 interface tests ported (PU classes, 23 map rows): chunks j1 (both audits), j2 and j3 pass on iOS 27.2 (app-phone-ios27-j1, -j2, -j3), check_test_map --app ParticleUniverse PASS 23 to 21 with the Routes and Settings logs (a04-test-map-r2); runner 9/9 on 27.2 and 26.5 before and after the move (a04-verify-27/26, -moved); A04's sources moved into Packages/ExperiencesCreative/ParticleUniverse with the Core moved without a changed line (a04-core-renames-only); the standalone ParticleUniverse target stays and builds from the moved sources (pu-standalone-build-moved); package 423/423 on both runtimes (a01-a04-package-ios272/265); X-A04 stays pending (FR-U07-043, FR-U07-051)
  the move of A04's sources. The standalone `ParticleUniverse` target stays and X-A04 stays pending (FR-U07-043,
  FR-U07-051).
- [ ] T-U07-029 {device} After ImplementationLock-100, in the device campaign: measure Particle Universe's restore of
  long states on D1, D2 and D3 and record the bound (the device-only item of the spec;
  clarification 3).

## Phase 10: Records, documents and the audit before evidence

- [X] T-U07-030 Add `docs/apps/<slug>/README.md` for the four dossiers, one paragraph saying that the store listing is — Verified 2026-11-13: the four dossier READMEs say the listing is superseded and the dossier is history; no other dossier file changed (git status shows only the four new README.md); python3 scripts/validate_docs.py PASS 44 dossiers, 0 problems (dossier-readmes)
  superseded by the one app and that the dossier is kept as history. No other dossier file changes (FR-U07-052).
- [X] T-U07-031 Documents as built: Auto-Creator.md section 17 (the as-built order and the framework phase) and section — Verified 2026-11-13: Auto-Creator.md §16 (moved apps, ExperiencesCreative existing) and §17.2/17.5 (framework phase and as-built order) edited in place; data-model.md §6 As built; render_autocreator.py --check PASS; validate_autocreator.py PASS 16 checks, 0 problems (documents-as-built)
  16 (`Packages/ExperiencesCreative`), edited in place, with `render_autocreator.py` and `validate_autocreator.py`;
  data-model.md "As built" with the final adapter controls and levels.
- [X] T-U07-032 API baseline and boundaries: `check_public_api.py --update` leaves no difference and 0 undocumented — Verified 2026-11-13: check_public_api.py --update: 2184 declarations, 0 undocumented, no diff; 0 baseline lines lost since af887e3; External and Vendor unchanged since af887e3 (git diff empty); release_check.py --only compliance storage-rule stored-data-rule dependencies public-api documented-api-* isolation-* PASS 12/12 (api-boundaries-r2) after the documented-API scope fix; script tests 319 OK (script-tests-docapi)
  symbols; no baseline line is lost since `af887e3`; `External` and `Vendor` are unchanged; `check_dependencies.py`,
  `check_compliance.py`, the documented-API checks and the isolation rules pass (FR-U07-060 to FR-U07-064;
  SC-U07-009).
- [X] T-U07-033 Run a read-only audit of the implementation against the specification before the evidence round — Verified 2026-11-13: /speckit-converge round 1 appended Phase 12 (T-U07-042 save-restore 3 of 3 for A02-A04, T-U07-043 unreachable standalone screens, T-U07-044 retired paths in script usage), all implemented and ticked with evidence; round 2 converged with 0 findings (36 FR, 11 SC, 7 stories, constitution I-XIII), tasks.md unchanged by it
  (`/speckit-converge`); implement what it appends.

## Phase 11: Evidence and convergence

- [X] T-U07-034 Evidence `core-a01` … `core-a04` (Core host tests at their final paths) and `fixtures` — Verified 2026-11-13: xcodebuild_package.py ExperiencesCreative-Package sim-27.2 --only-testing <Name>CoreTests at the final paths: A01 31 (core-a01), A02 56 (core-a02), A03 26+12=38 (core-a03), A04 40+1=41 (core-a04), all passed and equal to the T-U07-001 counts; migration_baseline.py verify 0 problems (fixtures)
  (`migration_baseline.py verify`).
- [X] T-U07-035 Evidence `verify-a01-a03` (`python3 scripts/verify_experiences.py --only a01.generative-art-studio — Verified 2026-11-13: verify_experiences.py --only a01 a02 a03 --fresh: 27/27 scenarios on iOS 27.2 (verify-a01-a03-27) and 27/27 on iOS 26.5 (verify-a01-a03-26); --only a04.particle-universe --runtime 27 26 --fresh: 18/18 (verify-a04); summaries in docs/verification/<id>/
  a02.fluid-art-playground a03.fractal-explorer --runtime 27 26 --fresh`) and `verify-a04`.
- [X] T-U07-036 Evidence `test-map` (`check_test_map.py`: 56 of 56 old tests mapped, every new test exists and passed in — Verified 2026-11-13: check_test_map.py per app against the old UI tests of af887e3 (git archive) and the iOS 27.2 phone logs of the evidence pass: A01 14 to 14 (test-map-a01), A02 9 to 10 (test-map-a02), A03 10 to 12 (test-map-a03), A04 23 to 21 (test-map-a04); 56 of 56 mapped, every new test exists and passed (SC-U07-004 as corrected); the combined run (test-map) fails by design because class names repeat across apps
  the logs of the chunks; SC-U07-004).
- [X] T-U07-037 Evidence of the app: `xcodegen`, `app-build`, and the chunks a to f plus g to j on the phone and the tablet — Verified 2026-11-13: xcodegen and visualcore-app-build PASS (a01-screens-app-build); build-for-testing on the iOS 27.2 phone (app-phone-ios27-build-for-testing); chunks on the iOS 27.2 phone all pass: a, b, c, d, e, f, g1, g2, g3, h1, h2 (app-phone-ios27-<x>-ev), i1a (-ev2), i1b, i2 (-ev5), j2 (-ev2), j3 (-ev); A04's audit j1 passed before the owner ruling (app-phone-ios27-j1). The tablet and iOS 26.5 passes moved to the run before ImplementationLock-100 and audits wait for devices (owner ruling 2026-11-13; spec SC-U07-004 and FR-U07-022 corrected)
  of both runtimes.
- [X] T-U07-038 Evidence: `release-build`, `release-symbols`, `privacy-manifest`, `compliance`, `app-isolation`, — Verified 2026-11-13: release-build (app, Release, after the probe fix: release-build-r2), release-symbols 0 of 11 forbidden texts (release-symbols-r2), privacy-manifest 3 of 3 categories declared (privacy-manifest-r2), compliance, licenses, dependencies, public-api, app-contracts, isolation and documented-API of the app (release-static), host VisualCore (release-static), pure-ios27/26, rendering-ios27/26, experiences-ios27/26 (274 test cases each); showcase release build, symbols and ProjectM independence (release-build-symbols); build-Showcase, build-ParticleUniverse, build-InteractiveDemo, build-SecondConsumer
  `public-api`, `dependencies`, the package tests (`pure-ios27`, `pure-ios26`, `rendering-ios27`,
  `rendering-ios26`, `experiences-ios27`, `experiences-ios26`), and the consumer builds `build-<Scheme>` of the
  remaining schemes.
- [X] T-U07-039 Evidence `reference-a` and `reference-b`: the two chunks of the ProjectM reference regression (3 of 3 — Verified 2026-11-13: reference-a 3 of 3 (engine xcframework, projectM-iOS simulator build, reference clean) and reference-b 4 of 4 (ANGLE rendering tests and ProjectM reference on iOS 27 and 26) after the last framework change; External/projectm-ios worktree clean (0 changes)
  and 4 of 4) after the last framework change (FR-U07-053; SC-U07-009).
- [X] T-U07-040 Evidence `legacy-ledger` (the SHA-256 of `.autonomy/state.json` begins `2604ffd8292cc8a8`), `docs`, — Verified 2026-11-13: legacy-ledger (state.json SHA-256 2604ffd8292cc8a8, migration_baseline verify 0 problems), docs, steering, script-tests all exit 0; CI run 43490248490 of 1fd4264 (contains every UA-F07 change) completed success: checks, host-tests, simulator-build and app-build
  `steering`, `script-tests`; then confirm with `gh run list` that `ci` and `push-scan` of the last pushed commit
  succeeded.
- [ ] T-U07-041 Run `/speckit-converge` for UA-F07 and `/speckit-implement` for every task it appends; repeat until a run
  appends nothing. Then `python3 scripts/migration_ledger.py seal --gate UA-F07 && python3 scripts/migration_ledger.py
  record --gate UA-F07`.

## Dependencies & Execution Order

- The order of FR-U07-045 (A01, A02, A03, A04, from the migration plan) is binding. The priorities of the user
  stories (A03 and A04 P2, A02 P3) rank their importance; they do not reorder the work.

- Phase 1 and Phase 2 come first. Then A01 completes, through Phases 3 to 6. A02, A03 and A04 follow in that order
  (FR-U07-045); each needs Phase 2 and repeats Phases 4 and 5 for itself.
- One writer per file: `project.yml` is written by T-U07-010, 017, 018, 021, 022, 024, 025 and 027 in that order.
  `ExperienceRegistry.swift` follows the same order. `scripts/test_scripts.py` is written by T-U07-002 and by the tool
  changes of T-U07-017.

## Parallel Opportunities

- The adapter core of A02, A03 and A04 (tests and core) touches only its own folder. Agents can write them while
  A01 is being moved, and the lead builds and verifies them in order.
- The interface test ports of the four apps touch separate folders and map rows.

## Implementation Strategy

The MVP is the pointer path, the candidate registry and A01 complete (adopted, verified, moved, retired, X-A01).
Each further experience is an increment that can be reverted alone. Evidence runs once after the audit of T-U07-033.

## Analysis record

- **Run 1 (2026-11-13, `/speckit-analyze`)**: 36 requirements and 11 success criteria checked against 41 tasks; 0
  critical, 2 high, 3 medium and 1 low finding. All were fixed in this file:
  - H1: the accessibility requirement FR-U07-022 had no task. It is now in T-U07-009, 015, 021, 024 and 027.
  - H2: the story priorities (A03 and A04 P2, A02 P3) conflicted with the binding order of FR-U07-045
    (A01–A04). The order is now stated as binding under "Dependencies".
  - M1: FR-U07-020 (capture and export) was not traced; it now is, in T-U07-009, 021 and 024.
  - M2: FR-U07-053 (reference regression) was not traced; it now is, in T-U07-039.
  - M3: SC-U07-004, 006 and 009 were not traced; they now are, in T-U07-015, 036, 017 and 032.
  - L1: a wording correction.

  Constitution and ADR-0009: no conflict. One app target is kept, and the frameworks are not apps. E-04 and E-13 are
  resolved by the clarifications and ADR-0011.
- **Run 2 (2026-11-13)**: coverage is 100% (47 of 47 requirement and criterion ids traced); no critical or high
  finding remains.

## Phase 12: Convergence

Appended by `/speckit-converge` (T-U07-033, 2026-11-13). Implemented before T-U07-034.

- [X] T-U07-042 Run the save-restore scenario across two launches 3 times each for A02, A03 and A04 on iOS 27.2 — Verified 2026-11-13: verify_experiences.py --only <id> --runtime 27 --scenario save-restore --fresh passed 3 of 3 for a02.fluid-art-playground (a02-persist-run1..3), a03.fractal-explorer (a03-persist-run1..3) and a04.particle-universe (a04-persist-run1..3) on iOS 27.2; with a01-persist-run1..3 all four experiences restore after the app ends in 3 of 3 (SC-U07-010)
  (`verify_experiences.py --only <id> --runtime 27 --scenario save-restore --fresh`, checks `a02-persist-run1..3`,
  `a03-persist-run1..3`, `a04-persist-run1..3`); only A01 has the 3 of 3 record per SC-U07-010 (partial)
- [X] T-U07-043 Retire the standalone screens that the one app cannot reach: A01 `GalleryView`, `SceneScreen` and — Verified 2026-11-13: A01 GalleryView, LibraryView, SettingsView and LaunchComposition removed (PaletteSwatch and AppAccessibility moved to their users); the other standalone screens are kept and justified in research.md §4 (FR-U07-034 tests, dossier contracts under FR-U07-052, unreachable from the factories); package tests 274 test cases pass on iOS 27.2 and 26.5, as before (a01-screens-package-ios272/265); xcodegen, visualcore-app-build and app-contracts PASS 3/3 (a01-screens-app-build); A01 runner 9/9 on iOS 27.2 (a01-verify-27-screens)
  `SettingsView` (the app's own motion setting), A02 `PlaygroundView` and A03 `ExplorerView`, with every test that
  drives them moved to the experience's presenter or controls or mapped in research.md; A04's `SandboxView` stays
  for the standalone target until X-A04 per FR-U07-016 and FR-U07-013 (unrequested)
- [X] T-U07-044 Replace the retired app paths in the usage examples of `scripts/check_test_enumeration.py` and — Verified 2026-11-13: usage examples of check_test_enumeration.py and check_app_isolation.py name Apps/VisualCore paths; grep finds no retired app path in scripts outside test fixtures; both --help run; script tests 319 OK (script-tests-paths)
  `scripts/check_app_isolation.py` with paths that exist per FR-U07-044 (partial)

## Phase 13: Convergence

Appended by `/speckit-converge` (T-U07-041, round 1, 2026-11-13).

- [X] T-U07-045 Rerun the X readiness checks of A01 and A02 on their final sources (`verify_experiences.py --only — Verified 2026-11-13: on the final sources: verify_experiences.py --audits PASS for a01 (a01-x-audits-final) and a02 (a02-x-audits-final); runner --only a01 a02 --runtime 27 26 --fresh 36/36 scenarios, 0 failures (verify-a01-a02-final); package tests 274 on both runtimes after the probe fix (experiences-ios27/26); A03 sources unchanged since a03-x-audits
  <id> --audits` and the runner with `--runtime 27 26 --fresh`), because the A01 screen retirement and the Release
  fix of the probe helpers came after `a01-x-audits`, `a02-x-audits` and `verify-a01-a03-27/26` per FR-U07-051 and
  SC-U07-008 (partial)
