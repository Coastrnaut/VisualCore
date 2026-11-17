# Tasks: Ambient Clock — Phase 02 Native clock overlay and one shader theme

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A18-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A18-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only. No test may
raise a system prompt; no wall-clock assert. Precedent: `specs/125-ia-p02-scene-selection/tasks.md`.

## Phase 1: Setup

- [X] T-A18-201 Baseline: cite the A18-P01 evidence (`.autonomy/checks/A18-P01.{ac-core-ios27-2,app-build,experience-packages}.json`) on the tree recorded at A18-P01, whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A18-P01 evidence cited: .autonomy/checks/A18-P01.ac-core-ios27-2.json, A18-P01.app-build.json and A18-P01.experience-packages.json, all exit 0; no Packages, Apps or project.yml change since the A18-P01 record commit 1d38f651

## Phase 2: Foundational — the experience target

- [X] T-A18-202 Add the targets `AmbientClockExperience` (path `AmbientClock/Experience`) and `AmbientClockExperienceTests` (path `AmbientClock/ExperienceTests`) and the product `AmbientClockExperience` to `Packages/ExperiencesCreative/Package.swift` (the lead writes this file; dependencies as the Interactive Anatomy experience plus `AmbientClockCore`) — Verified 2026-11-16: 2026-11-16: targets AmbientClockExperience and AmbientClockExperienceTests and the product AmbientClockExperience in Packages/ExperiencesCreative/Package.swift; 2026-11-16: .autonomy/checks/A18-P02.ac-ios27.json exit 0 (47 experience tests in 7 suites and 59 core tests, iOS 27.2); A18-P02.experience-packages.json exit 0 (18 experiences)

## Phase 3: Story 1 — a readable clock over a calm background (P1) 🎯 MVP

- [ ] T-A18-203 [P] [US1] Create `Packages/ExperiencesCreative/AmbientClock/Experience/{Adapter/AmbientCore.swift,NoiseGradientTheme.swift,ClockOverlay.swift,AmbientPresenter.swift,AmbientControls.swift,AmbientClockExperience.swift}` per data-model.md and contracts/experience.md: `AmbientCore` (numbers only: instant, hourCycle 0–2, showSeconds, showDate, motion, speed "0.25–2; default 1", revision; controls `time.set` [0…4.1e9], `time.changed` [0…4], `clock.format` [0…2, 0…1, 0…1], `theme.motion` [0…1], `theme.speed` [0.25…2]; `qualityTiers == 2` with `level-0` and `level-1` ("octaves 5 / 3, resolutionShare 1 / 0.5, iterationShare 1 / 0.6"); snapshot schema 1 of the format and theme fields, the instant not stored; outcomes `showing-time` and `motion-off`); `NoiseGradientTheme` (fragment over `vc/noise.glsl` and `vc/color.glsl`, `vc_fbm` lacunarity 2 gain 0.5, four dark palette colours, time uniform 0 when motion is off or Reduce Motion is on, white text and `minimumContrast()` with `AccessibleColors.contrastRatio`); `AmbientPresenter` (owns one `FullScreenShaderScene`; injected `ClockSource`, environment provider and `NotificationCenter`; `display: AmbientClockState`; `tick(port:) -> Date`; a `TimeChangeMonitor(names: .applicationNames)` started in setup and stopped in teardown, sending `time.changed`; `describe` is the spoken string; probe at the centre `dark`); `ClockOverlay` (time at 0.22 × the shorter side times the Dynamic Type factor, one line, minimumScaleFactor 0.3 within 90 % of the width, the date in the title style, white; a task calling `tick` and sleeping until the deadline); controls (24-hour menu, seconds, date, motion, speed); `AmbientClockExperience.make(id:storage:reduceMotion:…)` as Infinite Geometry; every public symbol documented (FR-A18-201–209)
- [ ] T-A18-204 [P] [US1] Write `Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{AmbientTestSupport,AmbientCoreTests,ThemeTests,OverlayTests,AmbientRenderTests}.swift`: every action accepted in range and refused outside; equal actions give equal digests; snapshot round trip; contrast ≥ 4.5 : 1 against every palette colour; overlay text equals the formatter's output for New York and Kolkata, system/h12/h24, seconds on and off, date on and off; `describe` equals the spoken string; the overlay layout at the largest Dynamic Type factor fits one line within 90 % of the width for a 320-point and a 1,024-point canvas; frames at both levels not blank (SC-A18-201, 203, 204)

## Phase 4: Story 2 — the time follows the world (P1)

- [ ] T-A18-205 [US2] Write `Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{PresenterClockTests,TimeZoneChangeTests}.swift`: `tick` sends the fixed clock's instant and returns a later deadline on a minute (or second) boundary; with the environment at New York the text shows New York time, then the provider switches to Kolkata and `NSSystemTimeZoneDidChange` is posted on the private centre: one `time.changed` (timeZone) is sent and the text shows Kolkata time for the same instant; `willEnterForegroundNotification` sends one `time.changed` (foreground); after teardown nothing is sent; with no frame drawn (rendering unavailable), `tick` still moves the text to the next minute (FR-A18-206; SC-A18-202; spec edge case)

## Phase 5: Story 3 — calm motion (P2)

- [ ] T-A18-206 [US3] Add to `Packages/ExperiencesCreative/AmbientClock/ExperienceTests/AmbientRenderTests.swift`: with motion off, and with Reduce Motion on, two frames at times 1 and 7 are identical; with motion on they differ; speed outside 0.25–2 is refused (FR-A18-207; SC-A18-204)

## Phase 6: Registration and verification

- [ ] T-A18-207 [US1] Register the candidate: `Catalog/registrations.json` entry for a18 (summary, capabilities ≤ 40 characters each, quality_tiers ["level-0", "level-1"], palette, manifest `Packages/ExperiencesCreative/AmbientClock/scenario-manifest.json`, permissions []), `python3 scripts/build_catalog.py` (catalog and fixture copies), candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, product in `project.yml`; update `RealCatalogTests`, `scripts/test_scripts.py` and the `AppModelTests` stand-in candidate (`a18.ambient-clock` → `a19.living-wallpapers`) (FR-A18-201)
- [ ] T-A18-208 [US1] Write `Packages/ExperiencesCreative/AmbientClock/Experience/Adapter/AmbientManifest.swift` (the nine standard scenarios and five fixtures, the planning catalog's count: `fixture-time-zone-changed`, `fixture-motion-off`, `fixture-twenty-four-hour`, `fixture-seconds-shown`, `fixture-slow-motion`; research D6) and generate `Packages/ExperiencesCreative/AmbientClock/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) with `ExperienceTests/AmbientManifestTests.swift` (FR-A18-210)

## Phase 7: Records and evidence

- [ ] T-A18-209 Contract `docs/apps/ambient-clock/visualcore-contract.json`: G-OVERLAY and G-BUDGETS closed by "A18-P02"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app ambient-clock --render`)
- [ ] T-A18-210 Ambient Clock tests on sim-27.2 (`--name ac-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AmbientClockCoreTests AmbientClockExperienceTests`) and the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/AmbientClock`) (SC-A18-205)
- [ ] T-A18-211 Catalog (`--name catalog -- python3 scripts/build_catalog.py --check`); app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`); runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a18.ambient-clock --runtime 27`); packages and script tests (SC-A18-205)
- [ ] T-A18-212 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A18-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A18-201 → 202 → {203, 204} → 205 → 206 → 207 → 208 → 209 → 210 → 211 → 212. 204–206 are written against
contracts/experience.md and compile once 203 exists.

## Parallel examples

Agent E: T-A18-203 (sources). Agent T: T-A18-204–206 (tests). Lead: Package.swift (202), registration (207), manifest
generation (208), contract, runs, commits.

## Implementation strategy

MVP: the presenter, theme and overlay (203) with their tests (204). The time-zone fixture (205), still frames (206)
and the registration (207, 208) close the phase. Review checkpoints after 204 and at 210.
