# Tasks: Interactive Anatomy — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A17-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A17-P06 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only. Precedent:
`specs/122-sl-p06-release/tasks.md`.

## Phase 1: Setup

- [X] T-A17-601 Baseline: cite the A17-P05 evidence (`.autonomy/checks/A17-P05.{ia-ios27,app-unit,verify-27}.json`) on the tree recorded at A17-P05, whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A17-P05 evidence cited: .autonomy/checks/A17-P05.ia-ios27.json, A17-P05.app-unit.json and A17-P05.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A17-P05 record commit 45d9ab3d

## Phase 2: Story 1 — privacy and credits

- [ ] T-A17-602 [P] [US1] Write `docs/apps/interactive-anatomy/privacy-and-credits.md` (stored `view.json` in the experience's storage, replaced on every view change and removed when the app is deleted; nothing sent; no permission or usage string; license inventory of the pack's sources, the procedural geometry, the review record and the colours) (FR-A17-601)
- [X] T-A17-603 [US1] Write `specs/129-ia-p06-release/scan-sources-release.sh` refusing the APIs of Clarifications Q3 in `Packages/ExperiencesCreative/InteractiveAnatomy` and run it (`--name ia-no-network -- sh specs/129-ia-p06-release/scan-sources-release.sh`) (FR-A17-602; SC-A17-601) — Verified 2026-11-16: 2026-11-16: specs/129-ia-p06-release/scan-sources-release.sh; .autonomy/checks/A17-P06.ia-no-network.json exit 0 (no scanned use in 59 Swift files of Packages/ExperiencesCreative/InteractiveAnatomy)

## Phase 3: Story 2 — recovery and stored files

- [X] T-A17-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/InteractiveAnatomy/Experience/AnatomyPresenter.swift` (the next draw throws `AnatomyDrawError.injected` once and clears the flag) and `ExperienceTests/AnatomyRecoveryDrawTests.swift` (a saved view in a temporary storage; a failed draw fails the session; `view.json` byte-identical after the failure and after close; a new session opens with the view) (FR-A17-603; SC-A17-602) — Verified 2026-11-16: 2026-11-16: the test-only failNextDraw seam (AnatomyDrawError.injected once) and AnatomyRecoveryDrawTests (the failed draw fails the session, view.json byte-identical after the failure and after close, a new session opens with the view) pass in .autonomy/checks/A17-P06.ia-ios27.json exit 0 (101 core, 80 experience, 4 manifest tests, iOS 27); written by an agent, retested
- [X] T-A17-605 [P] [US2] Commit `ExperienceTests/Fixtures/view-{v2,v1,newer,damaged}.json`, declare the `Fixtures` resource of `InteractiveAnatomyExperienceTests` in `Packages/ExperiencesCreative/Package.swift` (lead), and add `ExperienceTests/StoredViewSampleTests.swift` (v2 opens; v1 opens migrated; newer and damaged leave the opening view and count a read refusal; every sample byte-identical afterwards) (FR-A17-604) — Verified 2026-11-16: 2026-11-16: Fixtures view-v2, view-v1, view-newer and view-damaged; the Fixtures resource of InteractiveAnatomyExperienceTests in Package.swift; StoredViewSampleTests (v2 opens, v1 opens migrated, newer and damaged leave the opening view, files byte-identical) pass in .autonomy/checks/A17-P06.ia-ios27.json exit 0 (101 core, 80 experience, 4 manifest tests, iOS 27)

## Phase 4: Story 3 — copy and checklist

- [X] T-A17-606 [P] [US3] Write the release documents in `docs/apps/interactive-anatomy/`: `store-listing.md` (claims each with a proving test or interface class; the educational, schematic and not-reviewed statements; labels may be skipped and the list names every part), `release-checklist.md` (rows verified, pending-campaign-ii IA-D1–IA-D7, owner-action: signing, archive, upload, clinical review), `release.json` per contracts/release.md, and the A17 section of `docs/release/known-limitations.md`; run `--name experience-release -- python3 scripts/release_check.py --only experience-release-a17 copy-claims-a17` (FR-A17-605, 606) — Verified 2026-11-16: 2026-11-16: privacy-and-credits.md, store-listing.md (claims with proving tests), release-checklist.md (40 rows: verified, pending-campaign-ii IA-D1 to IA-D7, owner-action signing, archive, upload, clinical review), release.json and the A17 section of docs/release/known-limitations.md; .autonomy/checks/A17-P06.experience-release.json exit 0 (experience-release-a17 and copy-claims-a17 with camera allowed); written by an agent, rechecked
- [X] T-A17-607 [US3] Write `specs/129-ia-p06-release/scan-claims-release.sh` (the words of Clarifications Q2 over the store text and the interface Swift; every named test exists) and run it (`--name ia-claims -- sh specs/129-ia-p06-release/scan-claims-release.sh`) (FR-A17-605; SC-A17-603) — Verified 2026-11-16: 2026-11-16: specs/129-ia-p06-release/scan-claims-release.sh; .autonomy/checks/A17-P06.ia-claims.json exit 0 (no refused word; every named proving test and interface class exists)

## Phase 5: Story 4 — interface tests

- [X] T-A17-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/InteractiveAnatomy/{IASupport,IAExploreUITests,IASearchUITests}.swift` per Clarifications Q4 (launched like `SLSupport`; identifiers `experience.a17.interactive-anatomy.<name>`), and add the serial chunk `"y2": ["IAExploreUITests", "IASearchUITests"]` to `scripts/release_check.py` (lead) and to `SERIAL_CHUNKS` (FR-A17-607) — Verified 2026-11-16: 2026-11-16: Apps/VisualCore/Tests/UI/InteractiveAnatomy/{IASupport,IAExploreUITests,IASearchUITests}.swift and the serial chunk y2 in scripts/release_check.py; .autonomy/checks/A17-P06.app-ui.json exit 0 (app-build-for-testing-ios27, app-unit-ios27, app-ui-ios27-y2: 5/5 interface tests, slowest 40.5 s); written by an agent, retested

## Phase 6: Records and evidence

- [ ] T-A17-609 Interactive Anatomy tests on sim-27.2 (`--name ia-ios27`; the slowest under 10 s) and the documented API
- [ ] T-A17-610 App build, unit and interface chunk (`xcodegen generate --spec project.yml`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-y2`) and the runner (`--name verify-27`) (SC-A17-604)
- [ ] T-A17-611 Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a17 copy-claims-a17`)
- [ ] T-A17-612 Contract: G-RELEASE closed by "A17-P06"; rows whose gaps are all closed become available (`--name contract`); packages, catalog and script tests
- [ ] T-A17-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A17-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A17-601 → {602, 603} → {604, 605} → {606, 607} → 608 → 609 → 610 → 611 → 612 → 613. 602, 605, 606 and 608 touch
different files and may run in parallel.

## Parallel examples

Agent D: T-A17-602 and 606 (documents). Agent K: T-A17-604 and 605 (code and samples). Agent U: T-A17-608 (interface
tests). Lead: scans (603, 607), Package.swift, release_check.py, runs, contract, commits.

## Implementation strategy

MVP: privacy (602, 603) and recovery (604, 605). Copy and checklist (606, 607) and the interface chunk (608) close the
release. Review checkpoints after 605 and at 611.
