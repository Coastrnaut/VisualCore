# Tasks: Aurora — Phase 02 Scene selection and controls

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A21-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A21-P02 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/146-zg-p02-sand-renderer/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [ ] T-A21-201 Baseline: cite the A21-P01 evidence (`.autonomy/checks/A21-P01.{au-core-ios27,app-build,experience-packages}.json`)
  on the tree recorded at A21-P01 (`f7154f4d`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [ ] T-A21-202 Add the targets `AuroraExperience` (path `Aurora/Experience`) and `AuroraExperienceTests` (path
  `Aurora/ExperienceTests`) and the product `AuroraExperience` to `Packages/ExperiencesCreative/Package.swift` (lead;
  dependencies as the Digital Zen Garden experience without the audio products)

## Phase 2: Story 1 — choose and tune a sky (P1) 🎯

- [ ] T-A21-203 [US1] Create `Packages/ExperiencesCreative/Aurora/Experience/{Adapter/AuroraCore.swift,AuroraPresenter.swift,
  SkyBlend.swift,AuroraControls.swift,AuroraExperience.swift}` per data-model.md and contracts/experience.md:
  `AuroraCore` ("snapshot schema 1": the `SkyScene`, `hue` "−0.5…0.5 turns", `limit` "0.2…0.72, default 0.6"; digest
  of exactly these; actions `preset.select` "0…2 (integer)", `colour.hue`, `motion.speed` "0…2", `motion.turbulence`
  "0…1", `sky.ribbons` "1…4 (integer)", `sky.stars` "0…400 (integer)", `sky.clouds` "0…1", `light.limit`; a fractional
  integer value refused; refusals leave the state unchanged; a newer, damaged or refused snapshot refused on restore;
  quality tiers `level-0`, `level-1`); `AuroraPresenter` (one `FullScreenShaderScene` with the core's shader, `fixedTime`
  from `SkyClock` by frame deltas, `maxFramesPerSecond` 30, rebuild after context loss or resize); the hue shift applied to the palette before `SkyUniforms` (data-model "Hue"); `SkyBlend` ("1.5 s
  of frame time", smoothstep, from the current blend, immediate under Reduce Motion); native controls with spoken
  labels; the factory as Digital Zen Garden's (FR-A21-201, 202, 204, 207)
- [ ] T-A21-204 [US1] Write `Packages/ExperiencesCreative/Aurora/ExperienceTests/{AuroraTestSupport,AuroraCoreTests,
  BlendTests,RebuildTests}.swift`: every action accepted in range and refused outside or fractional; snapshot round
  trip and restore refusals; the blend's duration, interruption and Reduce Motion; the picture equal after
  `recreateContext` and a resize (SC-A21-201)

## Phase 3: Story 2 — the brightness limit (P1)

- [ ] T-A21-205 [US2] Add `u_limit` to `Packages/ExperiencesCreative/Aurora/Core/SkyShader.swift` and the limit to
  `SkyReference.swift` ("knee from 0.83 × limit to the limit", after compositing; default 0.72 keeps the A21-P01
  tests) with `CoreTests/LimitTests.swift` (the reference under every limit), and write
  `ExperienceTests/LimitRenderTests.swift`: every preset at limits 0.2, 0.4 and 0.72 and the start, middle and end of
  every change between the presets have no pixel above the limit + 1/255; drawing matches the reference within the
  A21-P01 tolerances (FR-A21-203; SC-A21-202)

## Phase 4: Story 3 — controls step aside (P2)

- [ ] T-A21-206 [US3] In `AuroraControls.swift` and the presenter: "Hide controls" hides them; a tap on the canvas or
  the accessibility action "Show controls" restores them; the flag is not in the state; `ExperienceTests/ChromeTests.swift`
  (FR-A21-205; SC-A21-203)

## Phase 5: Registration and evidence

- [ ] T-A21-207 Register the candidate: `Catalog/registrations.json` entry for a21 (capabilities ≤ 40 characters each,
  quality_tiers ["level-0", "level-1"], palette, manifest `Packages/ExperiencesCreative/Aurora/scenario-manifest.json`,
  permissions []); `python3 scripts/build_catalog.py`; `Apps/VisualCore/App/ExperienceRegistry.swift` candidate
  `aurora` (no examples: schema 1); `project.yml` product; the synthetic candidate id in
  `Apps/VisualCore/Tests/Unit/AppModelTests.swift` moves to `a22.shader-studio`; the candidate lists in app and script
  tests (FR-A21-206)
- [ ] T-A21-208 Write `Packages/ExperiencesCreative/Aurora/Experience/Adapter/AuroraManifest.swift` (nine standard
  scenarios and fixtures for each preset, a tuned sky and a lowered limit) and `ExperienceTests/AuroraManifestTests.swift`;
  generate `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`
- [ ] T-A21-209 Aurora tests on sim-27.2 (`--name au-ios27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing
  AuroraCoreTests AuroraExperienceTests`), the documented API, isolation and core purity (review checkpoint)
- [ ] T-A21-210 Contract: G-CONTROLS, G-CAP and G-CHROME closed by "A21-P02"; rows whose gaps are all closed become
  available with evidence (`--name contract`)
- [ ] T-A21-211 Catalog (`--name catalog`); app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit
  -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`); runner (`--name verify-27 --
  python3 scripts/verify_experiences.py --only a21.aurora --runtime 27`); packages and script tests
- [ ] T-A21-212 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A21-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

201 → 202 → 203 → {204, 205, 206} → 207 → 208 → 209 → 210 → 211 → 212. 205 touches the core shader and reference;
203 and 206 share the controls file and run in one agent.

## Parallel examples

Agent E: T-A21-203–206. Agent M: T-A21-208 after 203. Lead: Package.swift (202), registration (207), runs, contract,
commits.

## Implementation strategy

MVP: the adapter, presenter and controls (203, 204). The limit (205) proves the regression fixture; the chrome (206)
the feature 06 slice. Review checkpoint at 209. One commit per task.
