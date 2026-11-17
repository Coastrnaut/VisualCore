# Tasks: Ambient Clock — Phase 03 Theme customization and persistence

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/crossfade.md](contracts/crossfade.md), [contracts/themes.md](contracts/themes.md),
[quickstart.md](quickstart.md). Gate A18-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A18-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only. No wall-clock
assert. Precedent: `specs/132-ac-p02-overlay-theme/tasks.md` and `specs/126-ia-p03-layers-search/tasks.md`.

## Phase 1: Setup

- [X] T-A18-301 Baseline: cite the A18-P02 evidence (`.autonomy/checks/A18-P02.{ac-ios27,app-unit,verify-27}.json`) on the tree recorded at A18-P02, whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A18-P02 evidence cited: .autonomy/checks/A18-P02.ac-ios27.json, A18-P02.app-unit.json and A18-P02.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A18-P02 record commit 9e504a90

## Phase 2: Foundational — the VisualCore crossfade (G-TRANSITION)

- [X] T-A18-302 Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/CrossfadeScene.swift` per data-model.md and contracts/crossfade.md ("two `RenderTarget`s of the drawable size; `from` and `to` drawn through `context.redirected(to:width:height:)`; one mix pass with `progress` clamped 0…1; rebuilt on resize and repeated setup; teardown releases everything"; `replaceIncoming(_:)` and restart from the current mix), every public symbol with `///`, and `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/CrossfadeSceneTests.swift` (progress 0 equals `from` byte for byte, 1 equals `to`, 0.5 within 2 of the average; no pixel darker than both inputs; resize and repeated setup give the same frame; teardown leaves no GPU object); the row in `Packages/VisualCoreRendering/README.md` and the API baseline (`check_public_api.py --update`, then `check_public_api.py`) (FR-A18-303, 307) — Verified 2026-11-16: 2026-11-16: VisualCoreRendering CrossfadeScene (two RGBA8 targets through context.redirected, one mix pass, exact end frames, rebuilt on resize and recreation, restart from the current mix) with CrossfadeSceneTests; .autonomy/checks/A18-P03.crossfade-ios27.json exit 0 (6 tests, 0 failures, iOS 27.2); README row; API baseline updated, A18-P03.public-api.json exit 0; written by an agent, retested

## Phase 3: Story 1 — four calm themes, all readable (P1) 🎯 MVP

- [ ] T-A18-303 [P] [US1] Create `Packages/ExperiencesCreative/AmbientClock/Core/{ThemePreset,ThemeCatalog}.swift` and `CoreTests/{ThemePresetTests,ThemeCatalogTests}.swift` per data-model.md: `ThemePreset` ("theme 0–3, palette 0–2, speed 0.25–2, motion"; kind `a18.theme-preset`, schema 1, ≤ 4,096 bytes; refusals damaged, newer-version, too-large, out-of-range with sentences); `ThemeCatalog` (four themes with three palettes of four sRGB colours each, budgets "noise octaves 5/3, particle cells 48/24, waves 6/3, shapes 8/4", `contrastProblems()` empty when white text reaches ≥ 4.5 : 1 on all 48 colours); the A18-P02 noise palette is palette 0 of theme 0 (FR-A18-301, 302, 304; SC-A18-301)
- [ ] T-A18-304 [US1] Create `Packages/ExperiencesCreative/AmbientClock/Experience/{ThemeShaders,ParticleDriftTheme,WaveFieldTheme,SDFShapesTheme}.swift` and update `NoiseGradientTheme.swift`, `Adapter/AmbientCore.swift` (schema 2 with `theme` and `palette`; controls `theme.select` [0…3], `theme.palette` [0…2]; a theme change resets the palette; migration 1 → 2 to theme 0, palette 0; outcome `theme-<id>` for themes other than the noise gradient), `AmbientPresenter.swift` (four lazily made theme scenes and one `CrossfadeScene`; 1.2 s smoothstep, `transitionDuration(_:reduceMotion:)` gives a cut; a failed theme compile keeps the previous theme) and `AmbientControls.swift` (theme and palette pickers); `Experience/AmbientSchemaExamples.swift` (schema-1 and schema-2 examples) registered with `examples:` in `Apps/VisualCore/App/ExperienceRegistry.swift` (lead) (FR-A18-301, 303, 306)

## Phase 4: Story 2 — changing theme without a jolt (P1)

- [ ] T-A18-305 [P] [US2] Write `Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{ThemeRenderTests,CrossfadeUseTests,SnapshotMigrationTests}.swift`: every theme at both levels non-blank with a dark centre; a theme change under Reduce Motion shows the new theme on the next frame; otherwise a frame 0.6 s into the fade differs from both themes and the frame at 1.2 s equals the new theme; a change during a fade restarts it; the schema-1 example migrates to theme 0 palette 0 and schema 2 round-trips; `theme.select` 4 and `theme.palette` 3 refused; a theme whose fragment fails to compile (a test-only seam) leaves the previous theme drawn and the time unchanged (SC-A18-302, 303; FR-A18-306; spec edge case)

## Phase 5: Story 3 — saving favourites (P2)

- [ ] T-A18-306 [US3] Create `Packages/ExperiencesCreative/AmbientClock/Experience/AmbientFavourites.swift` (`NamedLibrary<ThemePreset>` kind `a18.favourites` in the experience storage directory `favourites`; save with names "trimmed, ≤ 60 characters, empty becomes Favourite N", cap 12 (`over-cap`), `duplicate-name`; apply sends `theme.select`, `theme.palette`, `theme.speed`, `theme.motion`), the save and favourites list in `AmbientControls.swift`, and `ExperienceTests/FavouritesTests.swift` (save, reopen with a new library over the same storage, apply restores the preset; 13th refused; duplicate refused; empty name named; a damaged library file gives an empty list with a problem and no crash) (FR-A18-304, 305; SC-A18-304)

## Phase 6: Registration and verification

- [ ] T-A18-307 Extend `Packages/ExperiencesCreative/AmbientClock/Experience/Adapter/AmbientManifest.swift` with `fixture-theme-waves` (`theme.select [2]`) and `fixture-theme-shapes-palette` (`theme.select [3]`, `theme.palette [2]`), regenerate `scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) and update `ExperienceTests/AmbientManifestTests.swift`; `docs/apps/ambient-clock/licenses.md` lists the four shaders as original code (FR-A18-308)

## Phase 7: Records and evidence

- [ ] T-A18-308 Contract `docs/apps/ambient-clock/visualcore-contract.json`: G-THEMES, G-TRANSITION (promoted to VisualCoreRendering as `CrossfadeScene`) and G-FAVOURITES closed by "A18-P03"; rows whose gaps are all closed become available with evidence (`--name contract -- python3 scripts/check_app_contract.py --app ambient-clock --render`)
- [ ] T-A18-309 Tests: crossfade on sim-27.2 (`--name rendering-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests`), Ambient Clock on sim-27.2 (`--name ac-ios27 -- … --only-testing AmbientClockCoreTests AmbientClockExperienceTests`), public API and documented API (SC-A18-305)
- [ ] T-A18-310 Catalog, app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`), runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a18.ambient-clock --runtime 27`), packages and script tests (SC-A18-305)
- [ ] T-A18-311 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A18-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A18-301 → 302 → {303, 304} → 305 → 306 → 307 → 308 → 309 → 310 → 311. 303 (core) and 302 (VisualCore) touch different
files; 304 needs both.

## Parallel examples

Agent V: T-A18-302. Agent C: T-A18-303. Agent E, after V and C: T-A18-304 and 306 (sources). Agent T, with E:
T-A18-305 and the tests of 306. Lead: registry examples, manifest, licenses, README, API baseline, contract, runs,
commits.

## Implementation strategy

MVP: the four themes with the contrast rule (303, 304). The crossfade (302, 305) and the favourites (306) close the
phase. Review checkpoints after 302 (crossfade tests pass) and at 309.
