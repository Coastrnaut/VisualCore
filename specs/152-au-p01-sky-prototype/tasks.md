# Tasks: Aurora — Phase 01 Noise and ribbon sky prototype

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A21-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A21-P01 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/145-zg-p01-document-strokes/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A21-101 Baseline: cite the A21-P00 evidence (`.autonomy/checks/A21-P00.{app-build,no-change,experience-packages}.json`) — Verified 2026-11-17: 2026-11-17: A21-P00 evidence cited: .autonomy/checks/A21-P00.app-build.json, A21-P00.no-change.json and A21-P00.experience-packages.json, all exit 0; no Packages, Apps or project.yml change since the A21-P00 record commit 417e6556
  on the tree recorded at A21-P00 (`417e6556`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A21-102 Add the targets `AuroraCore` (path `Aurora/Core`, dependencies `VisualCoreMath` and `VisualCoreSimulation`) and `AuroraCoreTests` (path `Aurora/CoreTests`, dependencies `AuroraCore` and — Verified 2026-11-17: 2026-11-17: AuroraCore (Aurora/Core; VisualCoreMath, VisualCoreSimulation) and AuroraCoreTests (Aurora/CoreTests; AuroraCore, VisualCoreSimulation, VisualCoreRendering) in Packages/ExperiencesCreative/Package.swift; .autonomy/checks/A21-P01.experience-packages.json exit 0 (a pending core)
  `VisualCoreRendering`) to `Packages/ExperiencesCreative/Package.swift` (lead); the package check still passes (a
  pending core)

## Phase 2: Story 1 — a bounded scene (P1) 🎯

- [X] T-A21-103 [P] [US1] Create `Packages/ExperiencesCreative/Aurora/Core/{SkyScene,SkyPresets}.swift` per — Verified 2026-11-17: 2026-11-17: SkyScene (schema 1, a21.sky-scene, at most 4,096 bytes, bounds of data-model.md, seven refusal codes, clamping setters) and SkyPresets (polar-night, violet-veil, dawn-haze; version 1; written for VisualCore); .autonomy/checks/A21-P01.au-core-ios27.json exit 0; written by an agent, retested
  data-model.md: "schema 1, kind `a21.sky-scene`, ≤ 4,096 bytes"; `preset`, `palette` "2…4 opaque sRGB colours",
  `ribbons` "1…4", `turbulence` "0…1", `cloudiness` "0…1", `stars` "0…400", `speed` "0…2"; refusal codes `damaged`,
  `newer-version`, `too-large`, `not-finite`, `out-of-range`, `unknown-preset`, `palette-size`; setters clamp and ignore
  non-finite values; presets `polar-night`, `violet-veil`, `dawn-haze` (version 1, attribution "written for
  VisualCore"); `///` on every public declaration (FR-A21-101–103)
- [X] T-A21-104 [P] [US1] Write `Packages/ExperiencesCreative/Aurora/CoreTests/{SceneTests,PresetTests}.swift`: each — Verified 2026-11-17: 2026-11-17: SceneTests (16) and PresetTests (6): exact round trips, one sample per refusal code, clamping at every bound, NaN and infinity ignored, unique valid presets; .autonomy/checks/A21-P01.au-core-ios27.json exit 0 (22 Swift Testing tests); written by an agent, retested
  preset round-trips exactly; one sample per refusal code; setters clamp each bound; NaN ignored; synthetic data only
  (SC-A21-101)

## Phase 3: Story 2 — layered light within bounds (P1)

- [ ] T-A21-105 [P] [US2] Create `Packages/ExperiencesCreative/Aurora/Core/{SkyNoise,SkyShader,SkyReference}.swift` per
  clarification Q2 and data-model.md: a Swift `Float` port of `vc_pcg`, `vc_hash21`, `vc_hash22`, `vc_gradientNoise`
  and `vc_fbm`; `aurora-sky.frag` source text (`#include "vc/noise.glsl"`, uniforms `u_phase`, `u_ribbons`,
  `u_turbulence`, `u_cloudiness`, `u_stars`, `u_octaves`, palette) compositing stars ("twinkle ±30 %", "size ≤ 1.5
  pixels"), fbm clouds and up to four advected ribbons; levels "0 → 5 octaves, 1 → 3"; `SkyReference` evaluates the
  same formulas per pixel (FR-A21-104, 105)
- [ ] T-A21-106 [P] [US2] Write `Packages/ExperiencesCreative/Aurora/CoreTests/{NoiseTests,SkyRenderTests}.swift`: the
  noise port matches the GPU noise drawn off screen; each preset at levels 0 and 1 drawn at 64 × 48 through
  `FullScreenShaderScene` matches `SkyReference` ("mean absolute channel difference ≤ 2/255, largest ≤ 8/255"); every
  pixel's luminance ≤ 0.75 and the mean ≥ 0.02; level 1 uses fewer octaves; after `recreateContext` and after a resize
  the drawing matches again; a broken shader reports its name (SC-A21-102)

## Phase 4: Story 3 — time and stillness (P1)

- [ ] T-A21-107 [P] [US3] Create `Packages/ExperiencesCreative/Aurora/Core/SkyClock.swift` per clarification Q4: a
  `SceneClock` of period 600 s, advanced by the frame delta (≤ 0.25 s per step) × speed, held under Reduce Motion or at
  speed 0; `phase = time / 600` (FR-A21-106)
- [ ] T-A21-108 [P] [US3] Write `Packages/ExperiencesCreative/Aurora/CoreTests/{ClockTests,ReducedMotionFrameTests}.swift`:
  a one-hour delta moves time by at most 0.25 s × speed; held under Reduce Motion and at speed 0; two drawings at
  different frame times are identical under Reduce Motion; phase 0 and phase 1 give the same picture (SC-A21-103)

## Phase 5: Records and evidence

- [X] T-A21-109 [P] Write `docs/apps/aurora/licenses.md` (presets, palettes and shader written in this repository; the — Verified 2026-11-17: 2026-11-17: docs/apps/aurora/licenses.md (presets, bounds, aurora-sky.frag, the noise port and reference written here; vc/ is VisualCore's; no third-party asset) listed in docs/apps/aurora/README.md; validate_docs exit 0
  `vc/` library is VisualCore's; no third-party asset) and list it in `docs/apps/aurora/README.md`
- [ ] T-A21-110 Core tests on sim-27.2 (`--name au-core-ios27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing
  AuroraCoreTests`; each test under 10 s), the purity scan (`--name core-purity`) and the documented API (`--name
  documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/Aurora`) (review
  checkpoint; SC-A21-104, FR-A21-107)
- [ ] T-A21-111 Contract `docs/apps/aurora/visualcore-contract.json`: G-SCENE, G-SKY and G-CLOCK closed by "A21-P01";
  rows whose gaps are all closed become available with evidence (`--name contract -- python3
  scripts/check_app_contract.py --app aurora --render`)
- [ ] T-A21-112 Packages, catalog, script tests and the app build (`--name experience-packages`, `--name catalog --
  python3 scripts/build_catalog.py --check`, `--name script-tests -- python3 scripts/test_scripts.py`, `--name app-build
  -- python3 scripts/release_check.py --only app-build-for-testing-ios27`)
- [ ] T-A21-113 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A21-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

101 → 102 → {103/104, 105/106, 107/108, 109} → 110 → 111 → 112 → 113. 105/106 use 107's clock only through the phase
uniform, so they stay separate files.

## Parallel examples

Agent S: T-A21-103, 104. Agent R: T-A21-105–108. Lead: Package.swift (102), licenses (109), runs, contract, commits.

## Implementation strategy

MVP: the scene and presets (103, 104). The sky and its reference (105, 106) prove the prototype; the clock (107, 108)
proves the regression fixture. Review checkpoint at 110. One commit per task.
