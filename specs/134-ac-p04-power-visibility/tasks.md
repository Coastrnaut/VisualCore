# Tasks: Ambient Clock — Phase 04 Power and visibility controls

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/power.md](contracts/power.md), [quickstart.md](quickstart.md). Gate A18-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A18-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only. No wall-clock
assert. Precedent: `specs/133-ac-p03-themes-favourites/tasks.md`.

## Phase 1: Setup

- [X] T-A18-401 Baseline: cite the A18-P03 evidence (`.autonomy/checks/A18-P03.{ac-ios27,app-unit,verify-27}.json`) on the tree recorded at A18-P03, whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A18-P03 evidence cited: .autonomy/checks/A18-P03.ac-ios27.json, A18-P03.app-unit.json and A18-P03.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A18-P03 record commit d6364788

## Phase 2: Foundational — the VisualCore frame cap (G-FRAMERATE)

- [X] T-A18-402 Add `var maxFramesPerSecond: Int { get }` with a default of 60 to `ExperiencePresenter` in `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperiencePresenter.swift` and pass it in `ExperienceSession.swift` to `RenderHost(scene:maxFramesPerSecond:budget:)`, documented; `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/FrameCapTests.swift` (a presenter declaring 30 gives `host.framePacing.maxFPS == 30`; one without a declaration gives 60; a declared 10 gives 30, the floor; `FramePacing` with Low Power Mode or serious heat lowers a requested 60 and keeps a declared 30 at the floor); the row in `Packages/VisualCoreRendering/README.md` and the API baseline (FR-A18-404, 409) — Verified 2026-11-16: 2026-11-16: ExperiencePresenter.maxFramesPerSecond and Experience.maxFramesPerSecond (default 60), forwarded by ExperienceShell and passed by ExperienceSession to RenderHost; FrameCapTests (a declared 30 reaches the host, no declaration keeps 60, a declared 10 is raised to 30, FramePacing rules); .autonomy/checks/A18-P04.host-ios27.json exit 0 (167 VisualCoreExperienceHostTests, iOS 27.2); README section; API baseline updated, A18-P04.public-api.json exit 0; written by an agent, retested

## Phase 3: Story 1 — a clock that is kind at night (P1) 🎯 MVP

- [X] T-A18-403 [P] [US1] Create `Packages/ExperiencesCreative/AmbientClock/Core/{NightPolicy,ScreenCare}.swift` with `CoreTests/{NightPolicyTests,ScreenCareTests}.swift` per data-model.md: `NightPolicy` ("mode off, on, scheduled; start and end 0…1439; dim 0.3…1"; `isNight(localMinute:)` with wrap and empty window; tint (1, 0.75, 0.55); text #FFB27A; `contrastProblems(palettes:)` over all 48 `ThemeCatalog` colours × dim × tint), `ScreenCare` (`drift(at:reduceMotion:)` = 8 × (sin 2πt/600, sin 2πt/840) points or zero; `dimFactor(now:lastAction:)` 1 before 600 s, 0.6 after); tests: the boundary table of contracts/power.md, contrast empty, drift bound and rate over 1,440 minute samples, determinism, reduced motion zero, dim at 599 and 600 s (FR-A18-401, 405, 406; SC-A18-401, 404) — Verified 2026-11-16: 2026-11-16: NightPolicy (off, on, scheduled with wrap and empty windows, tint and amber text, contrast over 48 colours at dim 0.3 and 1) and ScreenCare (drift within 8 points and 6 per minute, idle dim 0.6 after 600 s) with NightPolicyTests and ScreenCareTests; .autonomy/checks/A18-P04.ac-core-ios27.json exit 0 (90 core tests, iOS 27.2); written by an agent, retested
- [X] T-A18-404 [US1] Update the experience: `Adapter/AmbientCore.swift` schema 3 ("nightMode 0…2, nightStart and nightEnd 0…1439, nightDim 0.3…1, reduceMotion, keepAwake"; controls `night.mode`, `night.window`, `night.dim`, `motion.reduce`, `screen.keepAwake`; migration 2 → 3 with the defaults 0, 1,320, 420, 0.5, false, false; outcome `night-on`), `AmbientSchemaExamples.swift` (schema-1 and schema-2 examples, both registered with `examples:` in `Apps/VisualCore/App/ExperienceRegistry.swift`, lead), `ThemeShaders.swift` and the four themes (a `u_night` vec4 of dim and tint, a drift translation), `AmbientPresenter.swift` (`maxFramesPerSecond` 30; night from the display environment's local minute; reduced motion = system or in-app; drift and dim per frame; `lastActionInstant` from the clock on every sent action), `ClockOverlay.swift` (night text colour, drift offset, dim opacity), `AmbientControls.swift` (night mode, window, dim, reduce motion, keep-awake); the device brightness is never written (FR-A18-401–406, 409) — Verified 2026-11-16: 2026-11-16: AmbientCore schema 3 (night mode, window, dim, reduce motion, keep-awake; five controls; migration 2 to 3; outcome night-on), schema-1 and schema-2 examples registered in ExperienceRegistry.swift, shader night dim and tint after sRGB encode and the drift (float uniforms, the scene binds floats only), presenter cap 30, night from the local minute, reduced motion system or in-app, drift and idle dim, noteAction on control sends; overlay amber night text, drift offset and dim opacity; controls for night, dim, reduce motion and keep-awake; 2026-11-16: .autonomy/checks/A18-P04.ac-ios27.json exit 0 (97 experience tests in 16 suites and 90 core tests, iOS 27.2); A18-P04.documented-api.json exit 0; written by an agent, retested

## Phase 4: Story 2 — calm motion and a light load (P1)

- [X] T-A18-405 [P] [US2] Write `Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{NightRenderTests,PowerCoreTests}.swift`: a night frame is darker (mean luma) than the day frame and non-blank; `motion.reduce` on gives identical stills at two times and a theme change cuts; a session's `host.framePacing.maxFPS == 30`; every new control refused out of range; schema-1 and schema-2 examples migrate to schema 3 with the defaults; schema 3 round-trips (SC-A18-401, 403; FR-A18-403, 404, 409) — Verified 2026-11-16: 2026-11-16: NightRenderTests (4: night darker than day, schedule in New York, amber text, contrast) and PowerCoreTests (6: controls, migrations from schema 1 and 2, round trip, still frames and cuts under motion.reduce, the session cap 30) pass; 2026-11-16: .autonomy/checks/A18-P04.ac-ios27.json exit 0 (97 experience tests in 16 suites and 90 core tests, iOS 27.2); written by an agent, retested

## Phase 5: Story 3 — screen care and keeping the screen on (P2)

- [X] T-A18-406 [US3] Create `Packages/ExperiencesCreative/AmbientClock/Experience/KeepAwake.swift` (`IdleTimerPort`, `ApplicationIdleTimer` — the only file naming `isIdleTimerDisabled`; `KeepAwakeController.update(setting:visible:)`) wired in the presenter (on at setup or `didBecomeActive` when the setting is on; off at `willResignActive`, `didEnterBackground`, teardown and setting off), and `ExperienceTests/{KeepAwakeTests,ResumeTests,SourceScanTests}.swift` (a recording port through every transition; the resume fixture shows the new time before any draw; the presenter's dim factor is 0.6 after 600 s of the fixed clock without an action and 1 after a sent action; the source scan finds `isIdleTimerDisabled` only in `KeepAwake.swift` and `brightness =` nowhere in `Packages/ExperiencesCreative/AmbientClock`) (FR-A18-402, 407, 408; SC-A18-402) — Verified 2026-11-16: 2026-11-16: KeepAwake.swift (IdleTimerPort, ApplicationIdleTimer, KeepAwakeController) wired to setup, didBecomeActive, willResignActive, didEnterBackground and teardown; KeepAwakeTests (3), ResumeTests (3: 2:35 PM shown on foreground before any draw, dim 0.6 after 600 s and 1 after an action) and SourceScanTests (3: isIdleTimerDisabled only in KeepAwake.swift, no brightness write) pass; 2026-11-16: .autonomy/checks/A18-P04.ac-ios27.json exit 0 (97 experience tests in 16 suites and 90 core tests, iOS 27.2); written by agents, retested

## Phase 6: Registration and verification

- [X] T-A18-407 Extend `Adapter/AmbientManifest.swift` with `fixture-night-on` (`night.mode [1]`) and `fixture-motion-reduced` (`motion.reduce [1]`), regenerate `scenario-manifest.json` and update `AmbientManifestTests.swift` — Verified 2026-11-16: 2026-11-16: AmbientManifest adds fixture-night-on and fixture-motion-reduced; scenario-manifest.json regenerated; AmbientManifestTests pass in 2026-11-16: .autonomy/checks/A18-P04.ac-ios27.json exit 0 (97 experience tests in 16 suites and 90 core tests, iOS 27.2)

## Phase 7: Records and evidence

- [ ] T-A18-408 Contract: G-NIGHT, G-MOTION, G-FRAMERATE (promoted to VisualCoreExperienceHost as `ExperiencePresenter.maxFramesPerSecond`), G-SCREENCARE and G-AWAKE closed by "A18-P04"; rows whose gaps are all closed become available with evidence (`--name contract -- python3 scripts/check_app_contract.py --app ambient-clock --render`)
- [ ] T-A18-409 Tests: host on sim-27.2 (`--name host-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreExperienceHostTests`), Ambient Clock on sim-27.2 (`--name ac-ios27`), public API and documented API (SC-A18-405)
- [ ] T-A18-410 Catalog, app build and unit, runner (`--name verify-27`), packages and script tests (SC-A18-405)
- [ ] T-A18-411 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A18-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A18-401 → 402 → {403, 404} → 405 → 406 → 407 → 408 → 409 → 410 → 411. 402 (VisualCore) and 403 (core) touch different
files; 404 needs both.

## Parallel examples

Agent V: T-A18-402. Agent C: T-A18-403. Agent E, after V and C: T-A18-404 and the source of 406. Agent T, with E:
T-A18-405 and the tests of 406. Lead: registry, manifest, README, API baseline, contract, runs, commits.

## Implementation strategy

MVP: night mode with its contrast rule (403, 404). Motion and the frame cap (402, 405) and screen care with keep-awake
(406) close the phase. Review checkpoints after 402 and at 409.
