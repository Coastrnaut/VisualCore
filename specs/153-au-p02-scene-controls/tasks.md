# Tasks: Aurora — Phase 02 Scene selection and controls

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A21-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A21-P02 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/146-zg-p02-sand-renderer/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A21-201 Baseline: cite the A21-P01 evidence (`.autonomy/checks/A21-P01.{au-core-ios27,app-build,experience-packages}.json`) — Verified 2026-11-17: 2026-11-17: A21-P01 evidence cited: .autonomy/checks/A21-P01.au-core-ios27.json, A21-P01.app-build.json and A21-P01.experience-packages.json, all exit 0; no Packages, Apps or project.yml change since the A21-P01 record commit f7154f4d
  on the tree recorded at A21-P01 (`f7154f4d`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A21-202 Add the targets `AuroraExperience` (path `Aurora/Experience`) and `AuroraExperienceTests` (path — Verified 2026-11-17: 2026-11-17: AuroraExperience and AuroraExperienceTests targets and the AuroraExperience product in Packages/ExperiencesCreative/Package.swift (dependencies as Digital Zen Garden's experience without audio); .autonomy/checks/A21-P02.au-ios27.json exit 0
  `Aurora/ExperienceTests`) and the product `AuroraExperience` to `Packages/ExperiencesCreative/Package.swift` (lead;
  dependencies as the Digital Zen Garden experience without the audio products)

## Phase 2: Story 1 — choose and tune a sky (P1) 🎯

- [X] T-A21-203 [US1] Create `Packages/ExperiencesCreative/Aurora/Experience/{Adapter/AuroraCore.swift,AuroraPresenter.swift, — Verified 2026-11-17: 2026-11-17: SkyCore (schema 1: scene, hue, limit; digest a21.aurora.v1; eight one-value actions with a21.not-whole for fractional integers; restore refusals; quality tiers level-0 and level-1), AuroraPresenter (one FullScreenShaderScene, fixedTime from SkyClock, 30 fps cap, rebuild from state), SkyBlend (1.5 s smoothstep, from the current blend, immediate under Reduce Motion), AuroraControls with spoken labels, AuroraExperience.make; .autonomy/checks/A21-P02.au-ios27.json exit 0; written by an agent, retested
  SkyBlend.swift,AuroraControls.swift,AuroraExperience.swift}` per data-model.md and contracts/experience.md:
  `AuroraCore` ("snapshot schema 1": the `SkyScene`, `hue` "−0.5…0.5 turns", `limit` "0.2…0.72, default 0.6"; digest
  of exactly these; actions `preset.select` "0…2 (integer)", `colour.hue`, `motion.speed` "0…2", `motion.turbulence`
  "0…1", `sky.ribbons` "1…4 (integer)", `sky.stars` "0…400 (integer)", `sky.clouds` "0…1", `light.limit`; a fractional
  integer value refused; refusals leave the state unchanged; a newer, damaged or refused snapshot refused on restore;
  quality tiers `level-0`, `level-1`); `AuroraPresenter` (one `FullScreenShaderScene` with the core's shader, `fixedTime`
  from `SkyClock` by frame deltas, `maxFramesPerSecond` 30, rebuild after context loss or resize); the hue shift applied to the palette before `SkyUniforms` (data-model "Hue"); `SkyBlend` ("1.5 s
  of frame time", smoothstep, from the current blend, immediate under Reduce Motion); native controls with spoken
  labels; the factory as Digital Zen Garden's (FR-A21-201, 202, 204, 207)
- [X] T-A21-204 [US1] Write `Packages/ExperiencesCreative/Aurora/ExperienceTests/{AuroraTestSupport,AuroraCoreTests, — Verified 2026-11-17: 2026-11-17: AuroraTestSupport, AuroraCoreTests, BlendTests and RebuildTests: actions in range accepted, out of range or fractional refused with the state unchanged, snapshot round trip and restore refusals, the blend's duration, interruption and Reduce Motion, the picture equal after recreateContext and a resize; .autonomy/checks/A21-P02.au-ios27.json exit 0; written by an agent, retested
  BlendTests,RebuildTests}.swift`: every action accepted in range and refused outside or fractional; snapshot round
  trip and restore refusals; the blend's duration, interruption and Reduce Motion; the picture equal after
  `recreateContext` and a resize (SC-A21-201)

## Phase 3: Story 2 — the brightness limit (P1)

- [X] T-A21-205 [US2] Add `u_limit` to `Packages/ExperiencesCreative/Aurora/Core/SkyShader.swift` and the limit to — Verified 2026-11-17: 2026-11-17: u_limit in SkyShader and SkyReference (knee from 5/6 x limit to the limit after compositing; the default 0.72 keeps the A21-P01 pictures byte for byte); LimitTests (reference under 0.2, 0.4, 0.6, 0.72) and LimitRenderTests (every preset and the start, middle and end of all six changes: largest luminance 0.1998 at 0.2, 0.3939 at 0.4, 0.6825 at 0.72); .autonomy/checks/A21-P02.au-ios27.json exit 0; written by an agent, retested
  `SkyReference.swift` ("knee from 0.83 × limit to the limit", after compositing; default 0.72 keeps the A21-P01
  tests) with `CoreTests/LimitTests.swift` (the reference under every limit), and write
  `ExperienceTests/LimitRenderTests.swift`: every preset at limits 0.2, 0.4 and 0.72 and the start, middle and end of
  every change between the presets have no pixel above the limit + 1/255; drawing matches the reference within the
  A21-P01 tolerances (FR-A21-203; SC-A21-202)

## Phase 4: Story 3 — controls step aside (P2)

- [X] T-A21-206 [US3] In `AuroraControls.swift` and the presenter: "Hide controls" hides them; a tap on the canvas or — Verified 2026-11-17: 2026-11-17: Hide controls hides them; a tap on the sky or the accessibility action Show controls restores them; the flag is presenter-only; ChromeTests; .autonomy/checks/A21-P02.au-ios27.json exit 0; written by an agent, retested
  the accessibility action "Show controls" restores them; the flag is not in the state; `ExperienceTests/ChromeTests.swift`
  (FR-A21-205; SC-A21-203)

## Phase 5: Registration and evidence

- [X] T-A21-207 Register the candidate: `Catalog/registrations.json` entry for a21 (capabilities ≤ 40 characters each, — Verified 2026-11-17: 2026-11-17: Catalog/registrations.json a21 candidate (5 capabilities of at most 40 characters, quality tiers level-0 and level-1, palette, manifest, permissions [], a 267-character summary); build_catalog.py (catalog and fixtures; 20 available, A21 not); ExperienceRegistry candidate aurora (no examples: schema 1) with its manifest; project.yml product AuroraExperience; AppModelTests synthetic candidate a22.shader-studio; RealCatalogTests and test_scripts.py lists; .autonomy/checks/A21-P02.catalog-tests.json, A21-P02.script-tests.json and A21-P02.app-unit-2.json exit 0 (the first app-unit attempt failed to compile because the registration had been placed in the wrong extension; moved and rebuilt)
  quality_tiers ["level-0", "level-1"], palette, manifest `Packages/ExperiencesCreative/Aurora/scenario-manifest.json`,
  permissions []); `python3 scripts/build_catalog.py`; `Apps/VisualCore/App/ExperienceRegistry.swift` candidate
  `aurora` (no examples: schema 1); `project.yml` product; the synthetic candidate id in
  `Apps/VisualCore/Tests/Unit/AppModelTests.swift` moves to `a22.shader-studio`; the candidate lists in app and script
  tests (FR-A21-206)
- [X] T-A21-208 Write `Packages/ExperiencesCreative/Aurora/Experience/Adapter/AuroraManifest.swift` (nine standard — Verified 2026-11-17: 2026-11-17: SkyCore.manifest(for:) in Adapter/AuroraManifest.swift (nine standard scenarios; fixtures for the three presets, a tuned sky and a lowered limit) and AuroraManifestTests (5); scenario-manifest.json generated with UPDATE_SCENARIO_MANIFEST=1 and matched on the plain run; .autonomy/checks/A21-P02.au-ios27.json exit 0; written by an agent, retested
  scenarios and fixtures for each preset, a tuned sky and a lowered limit) and `ExperienceTests/AuroraManifestTests.swift`;
  generate `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`
- [X] T-A21-209 Aurora tests on sim-27.2 (`--name au-ios27 -- python3 scripts/xcodebuild_package.py --package — Verified 2026-11-17: 2026-11-17: review checkpoint: .autonomy/checks/A21-P02.au-ios27.json (AuroraCoreTests and AuroraExperienceTests on sim-27.2), A21-P02.documented-api.json, A21-P02.isolation.json and A21-P02.core-purity.json, all exit 0
  Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing
  AuroraCoreTests AuroraExperienceTests`), the documented API, isolation and core purity (review checkpoint)
- [X] T-A21-210 Contract: G-CONTROLS, G-CAP and G-CHROME closed by "A21-P02"; rows whose gaps are all closed become — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P02.contract.json exit 0; G-CONTROLS, G-CAP and G-CHROME closed by A21-P02; M07, M11 and M18 available; M14 stays open for G-COMPOSITE and G-DEVICE
  available with evidence (`--name contract`)
- [X] T-A21-211 Catalog (`--name catalog`); app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P02.catalog.json, A21-P02.app-unit-2.json (xcodegen generate; app-build-for-testing-ios27 and app-unit-ios27), A21-P02.verify-27.json (the runner on iOS 27.2 for a21.aurora), A21-P02.experience-packages.json (21 experiences) and A21-P02.script-tests.json, all exit 0
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

## Phase 6: Convergence

- [ ] T-A21-213 Record the as-built design in `specs/153-au-p02-scene-controls/data-model.md` and `contracts/experience.md`: the knee starts at 5/6 × limit (so the default 0.72 is exactly the A21-P01 knee); only a preset change starts the 1.5 s blend, a control moved during a blend retargets it with its progress kept, re-selecting the current preset snaps, and opening or restoring shows the state at once; the palette expands to five stops (the sky and four ribbon slots) and a ribbon on one side only fades during a blend; `reset()` returns the limit to 0.6; restore refusals `SkyRestoreRefusal` (damaged, scene, out-of-range hue or limit); the rule `a21.not-whole`; the outcome `preset-<id>`; the tap is presentation only (no gesture action) per data-model and contract (unrequested)
