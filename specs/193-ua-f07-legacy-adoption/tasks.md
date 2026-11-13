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

- [ ] T-U07-014 [US2] After each experience's adapter and after each move: the Core host tests run with the same counts as
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
- [ ] T-U07-018 [US7] Retire the `GenerativeArtStudio` app, unit-test and UI-test targets and scheme in `project.yml`.
  The app unit tests now run as `ExperienceTests`, with the same count (FR-U07-034). The project builds, and
  `release_check.py` drops the per-app steps of the retired scheme and adds the experience package's host tests
  (FR-U07-043; SC-U07-007).
- [ ] T-U07-019 [US7] Record X-A01:
  - move A01's registration from `candidates` to `all`;
  - run `python3 scripts/build_catalog.py`, so that A01 becomes available once X-A01 is pass;
  - run-check `host`, `sim27`, `sim26` and `audits` with the commands of Auto-Creator.md 22.2;
  - seal and record X-A01 (FR-U07-051; SC-U07-008).

## Phase 7: User Story 5 — Fluid Art Playground (P3), steps of Phases 3, 5 and 6 for A02

- [X] T-U07-020 [US5] Tests first: `FluidArtCoreTests` covering: — Verified 2026-11-13: Apps/FluidArtPlayground/FluidArtPlaygroundAdapter/Tests/FluidArtCoreTests.swift: conformance over 4 seeds; every control as an action; pause/step/resume; strokes equal SplatQueue's splats for the same tracker samples; pending bounded by SplatQueue.maxPending (1074 queued, 1024 kept, 50 dropped) and drained under the cap; digest of CPU state only, unchanged by tiers 0-2 and shedding; reset and detail; snapshot round trip; manifest valid with 5 fixtures and its committed digests. swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundAdapter: 12 passed (a02-core-host)
  - conformance;
  - strokes, pinch, splash, pause, step, reset, palette, edges, detail and sliders as actions;
  - pending splats bounded by `SplatQueue.maxPending`;
  - the digest covers only CPU state;
  - a quality level never changes the digest (clarifications 1 and 2).
- [ ] T-U07-021 [US5] `FluidArtCore`, `FluidArtPresenter` (it runs the passes for the steps since its last draw, restarts
  the fields from `DyeSeed.pattern(seed:)` at setup, applies the level to iterations and the splat cap, and turns
  pointer events into `stroke` actions), `FluidArtControls`, `FluidArtManifest`; the framework target and candidate
  registration; session tests on both runtimes; parity of the configuration and the CPU state for 3 seeds; capture
  through the share interface; controls meeting E-12 (FR-U07-010 to FR-U07-022; SC-U07-003, SC-U07-005).
- [ ] T-U07-022 [US5] Port A02's 9 UI tests (`FAP…`, chunk `-h`), with their map rows and guard. Then the runner on both
  runtimes, the move, the retirement and X-A02 as in T-U07-013 and T-U07-015 to T-U07-019.

## Phase 8: User Story 3 — Fractal Explorer (P2), same steps for A03

- [ ] T-U07-023 [US3] Tests first: `FractalCoreTests` covering:
  - conformance;
  - the framing is size-independent;
  - pan, pinch and the zoom buttons as normalized actions;
  - the cap, palette, animation and seed;
  - go-to parsing stays in the controls, and the core takes numbers;
  - tours and palette animation advance with steps, never with `systemUptime`.
- [ ] T-U07-024 [US3] `FractalCore`, `FractalPresenter` (the viewport is derived from the drawable size, and pointer events
  become `pan` and `pinch`), `FractalControls` (with bookmarks through `ExperienceStorage` and go-to), and
  `FractalManifest`; the framework target and candidate; session tests on both runtimes; framing parity for 3 seeds;
  capture through the share interface; controls meeting E-12 (FR-U07-020, FR-U07-022).
- [ ] T-U07-025 [US3] Port A03's 10 UI tests (`FE…`, chunk `-i`), with their map rows. Then the runner, the move (including
  `Tests/Fixtures/bookmark-v1.json` → `ExperienceTests/Fixtures` with the `MigrationTests` path fixed), the retirement
  and X-A03.

## Phase 9: User Story 4 — Particle Universe (P2), A04 without retirement

- [ ] T-U07-026 [US4] Tests first: `ParticleCoreTests` covering:
  - conformance;
  - the replay payload restores the same checksum and digest;
  - 30 simulated minutes replay within 10 s on the host, and on both simulators in the session tests;
  - the quality level caps only the drawn count;
  - `force.place` at normalized positions maps to the scene's world;
  - the checksum equals the standalone `SceneSimulation`'s for the same seed and commands (clarification 3;
    SC-U07-011).
- [ ] T-U07-027 [US4] `ParticleCore`, `ParticlePresenter` (the source reads the core, with no stepping in the render
  callback; taps and drags become `force.place` actions), `ParticleControls`, `ParticleManifest`; the framework target
  and candidate; session tests on both runtimes; controls meeting E-12 (FR-U07-022).
- [ ] T-U07-028 [US4] Port A04's 23 UI tests (`PU…`, chunk `-j`) with their map rows. Then the runner on both runtimes and
  the move of A04's sources. The standalone `ParticleUniverse` target stays and X-A04 stays pending (FR-U07-043,
  FR-U07-051).
- [ ] T-U07-029 {device} After ImplementationLock-100, in the device campaign: measure Particle Universe's restore of
  states longer than 30 simulated minutes on D1, D2 and D3 and record the bound (the device-only item of the spec;
  clarification 3).

## Phase 10: Records, documents and the audit before evidence

- [ ] T-U07-030 Add `docs/apps/<slug>/README.md` for the four dossiers, one paragraph saying that the store listing is
  superseded by the one app and that the dossier is kept as history. No other dossier file changes (FR-U07-052).
- [ ] T-U07-031 Documents as built: Auto-Creator.md section 17 (the as-built order and the framework phase) and section
  16 (`Packages/ExperiencesCreative`), edited in place, with `render_autocreator.py` and `validate_autocreator.py`;
  data-model.md "As built" with the final adapter controls and levels.
- [ ] T-U07-032 API baseline and boundaries: `check_public_api.py --update` leaves no difference and 0 undocumented
  symbols; no baseline line is lost since `af887e3`; `External` and `Vendor` are unchanged; `check_dependencies.py`,
  `check_compliance.py`, the documented-API checks and the isolation rules pass (FR-U07-060 to FR-U07-064;
  SC-U07-009).
- [ ] T-U07-033 Run a read-only audit of the implementation against the specification before the evidence round
  (`/speckit-converge`); implement what it appends.

## Phase 11: Evidence and convergence

- [ ] T-U07-034 Evidence `core-a01` … `core-a04` (Core host tests at their final paths) and `fixtures`
  (`migration_baseline.py verify`).
- [ ] T-U07-035 Evidence `verify-a01-a03` (`python3 scripts/verify_experiences.py --only a01.generative-art-studio
  a02.fluid-art-playground a03.fractal-explorer --runtime 27 26 --fresh`) and `verify-a04`.
- [ ] T-U07-036 Evidence `test-map` (`check_test_map.py`: 56 of 56 old tests mapped, every new test exists and passed in
  the logs of the chunks; SC-U07-004).
- [ ] T-U07-037 Evidence of the app: `xcodegen`, `app-build`, and the chunks a to f plus g to j on the phone and the tablet
  of both runtimes.
- [ ] T-U07-038 Evidence: `release-build`, `release-symbols`, `privacy-manifest`, `compliance`, `app-isolation`,
  `public-api`, `dependencies`, the package tests (`pure-ios27`, `pure-ios26`, `rendering-ios27`,
  `rendering-ios26`, `experiences-ios27`, `experiences-ios26`), and the consumer builds `build-<Scheme>` of the
  remaining schemes.
- [ ] T-U07-039 Evidence `reference-a` and `reference-b`: the two chunks of the ProjectM reference regression (3 of 3
  and 4 of 4) after the last framework change (FR-U07-053; SC-U07-009).
- [ ] T-U07-040 Evidence `legacy-ledger` (the SHA-256 of `.autonomy/state.json` begins `2604ffd8292cc8a8`), `docs`,
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
