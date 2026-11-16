# Tasks: Molecular Explorer — Phase 04 Curated molecule content and persistence

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/library.md](contracts/library.md), [quickstart.md](quickstart.md). Gate A15-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A15-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may raise a system prompt (the feature needs no permission). Precedent: `specs/112-me-p03-selection/tasks.md`.

## Phase 1: Setup

- [X] T-A15-401 Baseline: cite the A15-P03 evidence on the unchanged tree (`.autonomy/checks/A15-P03.{me-ios27-2,app-unit-2,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A15-P03 evidence cited on unchanged sources (no Packages change since): .autonomy/checks/A15-P03.me-ios27-2.json, A15-P03.app-unit-2.json, A15-P03.verify-27.json, all exit 0

## Phase 2: Foundational — the core (stories 2–4)

- [ ] T-A15-402 [US2] Create `Packages/ExperiencesCreative/MolecularExplorer/Core/{RecentMolecules,MoleculeSettings}.swift` per contracts/library.md (recent: "at most 8; unique; ids not in the library dropped on read; ≤ 2,048 bytes; refusals damaged, oversized, newer-version, out-of-range (more than 8 ids, a duplicate, a malformed id — empty, longer than 32 characters or not lowercase letters, digits and hyphens — or a schema version below 1)"; settings: label mode all / selected / none, default all, "≤ 1,024 bytes; same refusals (out-of-range: an unknown label mode or a schema version below 1)"; sorted-key schema-1 codecs; `DocumentRefusal`) with `CoreTests/{RecentMoleculesTests,MoleculeSettingsTests}.swift` (record order, uniqueness, cap of 8 after opening ten; unknown ids dropped; round trips; one fixture per refusal) (FR-A15-410, 411, 420; SC-A15-402, 403)
- [ ] T-A15-403 [P] [US4] Create `CoreTests/InferenceDeterminismTests.swift` (for each library molecule five seeded shuffles, seeds 1 to 5: inferred pairs mapped back equal the unshuffled inferred pairs and the recorded connections; every bond inferred and single; two runs identical) (FR-A15-430; SC-A15-404)

## Phase 3: Stories 1–3 — the experience

- [ ] T-A15-404 [US2] Create `Experience/{RecentStore,SettingsStore}.swift` over `ExperienceStorage?` following `ViewStore` (missing / refused / unreadable; load never writes; atomic write; in-memory without storage; failed write keeps the previous file and reports "… could not be saved (<code>).") and wire them into `MoleculePresenter.swift` and `MolecularExplorerExperience.swift` (load at creation; record the molecule on every molecule change including the first; settings drive the overlay's labels: all, only the selected atom (none when nothing is selected), none) with `ExperienceTests/{RecentStoreTests,SettingsStoreTests}.swift` (temporary storage: refused fixtures byte-identical with their messages; the list survives a new session over the same storage; settings survive; the app's data reset — removing the folder — gives an empty list and default labels; no engine digest changes) (FR-A15-410, 411, 420, 440; SC-A15-402, 403)
- [ ] T-A15-405 [US1] Extend `Experience/MoleculeControls.swift` with the Library section (`library-<id>` buttons with name, formula, counts and the source line; choosing sends `molecule.select`), the Recent menu (`recent`; "No recent molecules" when empty) and the Labels picker (`labels`: All, Selected, None), with `ExperienceTests/MoleculeLibraryUITests.swift` (the words of every library entry; the recent menu lists newest first; the labels picker changes the overlay's label count; controls hold only references) (FR-A15-401, 420, 440; SC-A15-401)

## Phase 4: Records and evidence

- [ ] T-A15-406 Contract `docs/apps/molecular-explorer/visualcore-contract.json`: G-LIBRARY closed by "A15-P04"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app molecular-explorer --render`)
- [ ] T-A15-407 Molecular Explorer tests on sim-27.2 (`--name me-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`) and the documented-API check (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/MolecularExplorer`) (SC-A15-401–405)
- [ ] T-A15-408 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`) (SC-A15-405)
- [ ] T-A15-409 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A15-410 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A15-P04; update README.md in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A15-401 → {402, 403 (independent: bond inference exists since A15-P02)}; 402 → 404 → 405 → 406; {403, 405} → 407 → 408 → 409 → 410.

## Parallel examples

Agent A: T-A15-402–403 (core). Agent B: T-A15-404–405 (experience) after A. Lead: contract, runs, commits.

## Implementation strategy

MVP: the documents and stores (402, 404) with the determinism fixture (403); the controls complete the phase (405).
Review checkpoints after 403 (core tests) and at 407.
