# Tasks: Tiny Worlds — Phase 04 Three environment packs

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/actions.md](contracts/actions.md), [quickstart.md](quickstart.md). Gate A12-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A12-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only; no VisualCore change in this phase.
Precedent: `specs/091-tw-p03-customize/tasks.md`.

## Phase 1: Setup

- [X] T-A12-401 Baseline: cite the last evidence on an unchanged `Packages` tree (`.autonomy/checks/A12-P03.{worlds-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A12-P03.{worlds-ios27,app-unit,verify-27}.json on the unchanged Packages tree (no rerun)

## Phase 2: Foundational — pack data, limits and clearance (stories 1–3)

- [X] T-A12-402 [US1] Core: new `Packages/ExperiencesCreative/TinyWorlds/Core/WorldPack.swift` and changes to `Core/{CameraPolicy,WorldView,ContentCatalog,LicenseAudit}.swift` per data-model.md and Clarifications Q1–Q5: three packs (island "seed 11, 3 trees, 2 rocks, 1 house, 1 lantern, light 120°/45°/0.35, pitch 15°…70°, distance 12…28 m, default view 45°, 35°, 18 m"; asteroid garden "seed 7, 5 rocks, 3 lanterns, light 300°/30°/0.25, pitch 20°…75°, distance 12…30 m, default view 135°, 40°, 20 m"; miniature city "seed 5, 6 houses, 4 lanterns, 2 trees, light 210°/60°/0.40, pitch 25°…75°, distance 10…24 m, default view 315°, 45°, 16 m"), prop positions and turns as fixed numbers that satisfy the rules on that terrain, author "VisualCore project", license "MIT"; `WorldPack.apply(to:)` placing through `WorldEditing.place` (which selects each new prop), refusing on the first refusal, then clearing the selection so a pack opens with none; per-preset camera limits used by `CameraPolicy.clamp` and `WorldView` clamps; prop-aware clearance ("highest of 9 terrain samples and of the top y + model height of every prop whose centre lies within 1 m plus its picking radius"); packs in the catalog and license audit. Tests in `Packages/ExperiencesCreative/TinyWorlds/CoreTests/{WorldPackTests.swift (new),CameraPolicyTests,WorldViewTests,ContentCatalogTests,LicenseAuditTests}.swift`: each pack applies without refusal, deterministic, prop counts as specified, budgets ("≤ 16 props, ≤ 30,000 vertices, ≤ 18 draws"); a broken pack (a prop under water) refused with `a12.under-water`; 24 × 8 × 4 sweep per pack keeps the pack's limits and the clearance over terrain and props; pack limits inside the global ones; restored out-of-range views clamped (FR-A12-401, 403–406; SC-A12-402–404) — Verified 2026-11-15: 2026-11-15: WorldPack (island seed 11, asteroid garden seed 7, miniature city seed 5; props placed through WorldEditing, selection cleared; budgets 5,507 / 6,683 / 4,085 vertices and 9 / 9 / 14 draws), per-preset CameraLimits inside the global ones, prop-aware clearance, packs in the catalog and license audit; 87 of 88 core tests pass on the host (swift test over the scratch package; the committed-document test runs on the simulator in T-A12-406): broken pack refused with a12.under-water, 24×8×4 sweep per pack keeps limits and clearance over terrain and props

## Phase 3: Stories 1–3 in the experience

- [X] T-A12-403 [US1] Experience: `Packages/ExperiencesCreative/TinyWorlds/Experience/Adapter/WorldsCore.swift` (`world.pack [0…2]` replacing the world with the pack, also used as reset; refusal codes; camera policy with the preset's limits), `WorldsControls.swift` (pack picker "Open pack" and "Reset to pack"), `WorldsPresenter.swift` (spoken "Opened the … pack."; direct camera move under Reduce Motion), `Adapter/WorldsManifest.swift` (fixtures `fixture-pack-island`, `fixture-pack-asteroid-garden`, `fixture-pack-miniature-city` pinning the state digest after `world.pack` from the default state, and `fixture-pack-reset` editing then resetting); tests in `Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/{WorldsPackTests.swift (new),WorldsCoreTests.swift,WorldsManifestTests.swift}`: pack digests equal committed values, reset after edits restores the digest exactly, every action has a control, a drawn frame of each pack is non-blank (FR-A12-402, 404, 407; SC-A12-401, 405) — Verified 2026-11-15: 2026-11-15: world.pack [0…2] (opens and resets packs; refusals a12.invalid-choice and placement codes), camera policy with the preset's limits and props after every action and on restore, Open pack and Reset to pack controls, spoken opening, direct move under Reduce Motion; manifest fixtures fixture-pack-island/asteroid-garden/miniature-city and fixture-pack-reset; .autonomy/checks/A12-P04.worlds-ios27.json exit 0 (88 core, 61 experience XCTest, 6 manifest tests on sim-27.2)

## Phase 4: Records

- [X] T-A12-404 Registration and regeneration: `Catalog/registrations.json` (capabilities: three environment packs); `python3 scripts/build_catalog.py`; regenerate `Packages/ExperiencesCreative/TinyWorlds/scenario-manifest.json` and `docs/apps/tiny-worlds/content-licenses.md` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) — Verified 2026-11-15: 2026-11-15: registrations.json a12 capability 'three ready-made world packs'; build_catalog (11 available); scenario-manifest.json (4 pack fixtures, 2 refusals) and content-licenses.md (3 packs) regenerated — both match in .autonomy/checks/A12-P04.worlds-ios27.json
- [X] T-A12-405 Contract `docs/apps/tiny-worlds/visualcore-contract.json`: G-PACKS closed by "A12-P04"; row M06 available with the pack evidence — Verified 2026-11-15: 2026-11-15: contract G-PACKS closed by A12-P04, M06 available (only G-DETAIL open); .autonomy/checks/A12-P04.contract.json exit 0

## Phase 5: Polish & evidence

- [X] T-A12-406 Tiny Worlds tests on sim-27.2 (`--name worlds-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing TinyWorldsCoreTests TinyWorldsExperienceTests`; each test < 10 s) (SC-A12-401–405) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P04.worlds-ios27.json exit 0 (88 core, 61 experience XCTest, 6 manifest tests on sim-27.2)
- [X] T-A12-407 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a12.tiny-worlds --runtime 27`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P04.{app-unit,verify-27}.json exit 0 (app build and unit; runner 9/9 on iOS 27.2)
- [X] T-A12-408 Experience package check, contract, catalog host tests and script tests (`--name experience-packages`, `--name contract`, `--name catalog-host`, `--name script-tests` as in A12-P03) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P04.{experience-packages,contract,catalog-host,script-tests}.json exit 0
- [ ] T-A12-409 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A12-P04; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A12-401 → 402 → 403 → 404 → 405 → Polish.

## Parallel examples

Agent A: T-A12-402. Agent B: T-A12-403 after A. Lead: 404, 405, runs, commits.

## Implementation strategy

MVP: the island pack opened and swept without clipping; then the other packs, reset, budgets and records.

## Phase 6: Convergence

- [ ] T-A12-410 Record in `specs/092-tw-p04-packs/research.md` (as built): `WorldPack.apply` resets the seed generator to `WorldState.generatorSeed`, so an opened pack depends only on the pack and "reset to pack" returns the exact digest after any edits, including a new seed; `world.pack` is the last control so earlier control ids keep their order; `view.reset` returns to the global default view (45°, 35°, 18 m) clamped to the preset's limits, while "Reset to pack" restores the pack's default view; the camera policy now also runs after prop and light actions because its clearance includes props, per research D1–D2 (unrequested)
