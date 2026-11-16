# Tasks: Simulation Lab — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A16-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A16-P06 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may raise a system prompt.
Precedent: `specs/115-me-p06-release/tasks.md`.

## Phase 1: Setup

- [X] T-A16-601 Baseline: cite the A16-P05 evidence on the unchanged sources (`.autonomy/checks/A16-P05.{sl-ios27-2,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A16-P05 evidence cited on unchanged sources (no Packages, Apps or project.yml change since the A16-P05 record 60f21efc): .autonomy/checks/A16-P05.sl-ios27-2.json, A16-P05.app-unit.json, A16-P05.verify-27.json, all exit 0

## Phase 2: Story 1 — nothing leaves the device

- [X] T-A16-602 [P] [US1] Write `docs/apps/simulation-lab/privacy-and-credits.md` per research D1: — Verified 2026-11-16: 2026-11-16: docs/apps/simulation-lab/privacy-and-credits.md written (stored files and places, deletion, nothing sent, the share sheet; license inventory of six presets, three palettes and seven shader programs); validate_docs.py PASS
  - what is stored: `preset-<uuid>.json` in the experience's storage, the session state, and the latest capture in
    `tmp/a16-captures`, emptied on open;
  - that nothing is sent and no permission is asked, and how data is deleted;
  - the license inventory as a table (Item | Kind | Source | License): the six bundled presets, the palettes
    `SimulationPalette` (automaton, reaction-diffusion and wave; original) and the shader programs of
    `SimulationShaders.swift`, `GrayScottGPU.swift` and `WaveGPU.swift` (original code).

  (FR-A16-603)
- [X] T-A16-603 [US1] Write `specs/122-sl-p06-release/scan-sources-release.sh` refusing the uses of Clarifications Q3 in `Packages/ExperiencesCreative/SimulationLab` and run it (`--name sl-no-network -- sh specs/122-sl-p06-release/scan-sources-release.sh`) (FR-A16-601; SC-A16-601) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P06.sl-no-network.json exit 0 (no scanned use in 61 Swift files of Packages/ExperiencesCreative/SimulationLab)

## Phase 3: Story 2 — saved data and failures

- [X] T-A16-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift`: the next `draw` throws once and clears the flag. Add `ExperienceTests/SimulationRecoveryDrawTests.swift`: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P06.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 69 XCTest experience tests, 0 failures, slowest 6.6 s); SimulationRecoveryDrawTests: failNextDraw fails the session, the saved preset file is byte-identical, a new session lists it and sim.spec opens it at step 0
  - save an experiment into a temporary storage;
  - set the seam and draw, so the session fails;
  - the preset file is byte-identical;
  - a new session over the same storage lists it, and `sim.spec` opens it.

  (FR-A16-610)
- [X] T-A16-605 [P] [US2] Commit `ExperienceTests/Fixtures/preset-{valid,newer,damaged,invalid}.json` and `state-{valid,newer,damaged}.json`, declare the `Fixtures` resource of `SimulationLabExperienceTests` in `Packages/ExperiencesCreative/Package.swift`, and add `ExperienceTests/StoredFileSampleTests.swift`: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P06.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 69 XCTest experience tests, 0 failures, slowest 6.6 s); StoredFileSampleTests (seven samples bundled, regenerated from code with UPDATE_FIXTURES=1: preset valid listed, newer, damaged and invalid reported; state valid restores, newer and damaged refused; every file byte-identical afterwards); Fixtures resource in Package.swift
  - presets, answered by `SimulationPresetStore` over a temporary storage: valid listed; newer, damaged and invalid
    reported;
  - states, answered by `SimulationCore.restore`: valid restores; newer and damaged refused with their reasons;
  - every file byte-identical afterwards.

  (FR-A16-611; SC-A16-602)

## Phase 4: Story 3 — truthful release documents

- [X] T-A16-606 [P] [US3] Write the release documents in `docs/apps/simulation-lab/`: — Verified 2026-11-16: 2026-11-16: store-listing.md (20 claims with proving tests), release-checklist.md (37 rows; verified, pending-campaign-ii SL-D1–SL-D6, owner-action), device-campaign.md, release.json and the Simulation Lab section of known-limitations.md; check_experience_release.py PASS (7 documents, 37 rows); check_copy_claims.py --allow share PASS
  - `store-listing.md`: the text, plus a Claim | Proving test table, with no forbidden claim;
  - `release-checklist.md`: Item | Area | Status | Evidence. Statuses are `verified`, `pending-campaign-ii` for
    SL-D1–SL-D6, and `owner-action` for signing set-up, archive and upload, with the steps of
    `docs/release/build-and-archive.md`. It includes the artifact inventory, the accessibility facts proved, the audits
    pending, and the note that there are no schema examples;
  - `device-campaign.md`: SL-D1–SL-D6 per research D5;
  - `release.json`, per contracts/release.md.

  Add a Simulation Lab section to `docs/release/known-limitations.md`: the 64 × 64 grid, half-precision values, the
  stability limits, float targets required for two families, and the device-only items. (FR-A16-620, 622)
- [X] T-A16-607 [US3] Write `specs/122-sl-p06-release/scan-claims-release.sh`, scanning the words of Clarifications Q2 over the store text and the controls, presenter, legend and adapter Swift, and checking that every test named in the claims table exists. Run it (`--name sl-claims -- sh specs/122-sl-p06-release/scan-claims-release.sh`). (FR-A16-621; SC-A16-603) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P06.sl-claims.json exit 0 (no refused word in the store text and the four interface Swift files; 68 proving tests found); the phrase half-precision is removed before matching (clarification Q2, corrected at implement)

## Phase 5: Story 4 — the interface end to end

- [X] T-A16-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/SimulationLab/{SLSupport,SLExploreUITests,SLLibraryUITests}.swift` per Clarifications Q4 (launched like `MESupport`; identifiers `experience.a16.simulation-lab.<name>`). `SLExploreUITests` also reads the `approximation` element: after Spots, its value is the Euler-step sentence (FR-A16-622). Add the serial chunk `"x2": ["SLExploreUITests", "SLLibraryUITests"]` to `scripts/release_check.py`, with `x2` in `SERIAL_CHUNKS`. (FR-A16-630) — Verified 2026-11-16: 2026-11-16: Apps/VisualCore/Tests/UI/SimulationLab/{SLSupport,SLExploreUITests,SLLibraryUITests}.swift and the serial chunk x2 in scripts/release_check.py; .autonomy/checks/A16-P06.app-ui.json exit 0 (4 journeys passed: 23.2, 20.7, 20.1 and 41.0 s; the approximation element read after Spots)
- [X] T-A16-609 [US4] Simulation Lab suites on sim-27.2 (`--name sl-ios27`; the slowest test under 10 s) (FR-A16-632; SC-A16-605) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P06.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 69 XCTest experience tests, 0 failures, slowest 6.6 s)
- [X] T-A16-610 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml`, then `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-x2`) and the runner (`--name verify-27`) (SC-A16-604) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P06.app-ui.json exit 0 (app-build-for-testing-ios27, app-unit-ios27 and app-ui-ios27-x2 passed) and A16-P06.verify-27.json exit 0 (runner on iOS 27.2, 0 failures)
- [ ] T-A16-611 [US4] Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a16 copy-claims-a16`) (FR-A16-602, 631; SC-A16-603, 604)

## Phase 6: Records

- [ ] T-A16-612 Contract: G-RELEASE closed by "A16-P06"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app simulation-lab --render`); script tests (`--name script-tests -- python3 scripts/test_scripts.py`)

## Dependencies

- T-A16-601 runs first.
- T-A16-602, T-A16-605, T-A16-606 and T-A16-608 are independent (agents). T-A16-603 and T-A16-604 are the lead's.
- T-A16-607 needs T-A16-606.
- T-A16-609 through T-A16-612 run last.

**Review checkpoint:** after T-A16-611. **MVP:** Story 1.
