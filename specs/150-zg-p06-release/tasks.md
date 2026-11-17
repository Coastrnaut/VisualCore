# Tasks: Digital Zen Garden — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A20-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P06 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only; iOS 26 and the
reference regression wait for X-A20. Precedent: `specs/143-lw-p06-release/tasks.md`. Rollback: revert the commits (no
migration, no VisualCore change).

## Phase 1: Setup

- [X] T-A20-601 Baseline: cite the A20-P05 evidence (`.autonomy/checks/A20-P05.{zg-ios27,app-ui,verify-27}.json`) on — Verified 2026-11-17: 2026-11-17: A20-P05 evidence cited: .autonomy/checks/A20-P05.zg-ios27.json, A20-P05.app-ui.json and A20-P05.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A20-P05 record commit 1b4b6289
  the tree recorded at A20-P05 (`1b4b6289`), whose Packages, Apps and project.yml are unchanged since (owner ruling of
  2026-11-14)

## Phase 2: Story 1 — privacy and credits (P1) 🎯

- [X] T-A20-602 [P] [US1] Write `docs/apps/digital-zen-garden/privacy-and-credits.md`: the session snapshot (the open — Verified 2026-11-17: 2026-11-17: docs/apps/digital-zen-garden/privacy-and-credits.md: state.json (schema 1, the garden document), garden-<n>.json (at most 12) and library.json, calm.v1, the temporary DigitalZenGarden-Still folder (one PNG), nothing sent, the add-only Photos string asked only by Save Image, declined path in campaign row ZG-D7, licence inventory; facts checked in code; validate_docs exit 0; written by an agent, reviewed
  garden document, schema 1), the named-garden library (`garden-<n>.json`, at most 12, and `library.json`) and the calm
  switches (`calm.v1`) in the experience's storage, replaced on each change and removed when the app is deleted; the
  temporary still folder `DigitalZenGarden-Still` (at most one PNG, replaced by the next still, removed with the app's
  temporary data); nothing is sent; the add-only Photos usage string, asked by the system only when the person
  chooses Save Image in the share sheet; the license inventory (code only; link `licenses.md`) (FR-A20-601)
- [X] T-A20-603 [US1] Write `specs/150-zg-p06-release/scan-sources-release.sh` (after — Verified 2026-11-17: 2026-11-17: specs/150-zg-p06-release/scan-sources-release.sh (the APIs of clarification Q3); .autonomy/checks/A20-P06.zg-no-network.json exit 0
  `specs/143-lw-p06-release/scan-sources-release.sh`) refusing the APIs of Clarifications Q3 in
  `Packages/ExperiencesCreative/DigitalZenGarden` (Swift files); run it (`--name zg-no-network -- sh
  specs/150-zg-p06-release/scan-sources-release.sh`) (FR-A20-602; SC-A20-601)

## Phase 3: Story 2 — recovery and stored files (P1)

- [X] T-A20-604 [US2] Add the test-only seam `var failNextDraw = false` to — Verified 2026-11-17: 2026-11-17: GardenPresenter.failNextDraw (test-only; the next draw throws GardenDrawError.injected once and clears itself) and GardenRecoveryDrawTests (two gardens saved; the session fails with the injected message at the draw stage; library.json, garden-1.json and garden-2.json byte-identical; a new session lists both); .autonomy/checks/A20-P06.zg-ios27.json exit 0 (99 experience, 51 core tests); written by an agent, retested
  `Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenPresenter.swift` ("the next `draw` throws
  `GardenDrawError.injected` once and clears the flag") and `ExperienceTests/GardenRecoveryDrawTests.swift` (two
  gardens saved in a temporary storage; a failed draw fails the session with the injected message; `library.json` and
  both garden files byte-identical; a new session over the same storage lists both) (FR-A20-603; SC-A20-602)
- [X] T-A20-605 [P] [US2] Commit `ExperienceTests/Fixtures/{snapshot-v1,snapshot-newer,snapshot-damaged,garden-current, — Verified 2026-11-17: 2026-11-17: nine samples in ExperienceTests/Fixtures (snapshot v1, newer, damaged; garden current, newer, damaged; library current, newer, damaged), the Fixtures resource in Package.swift, StoredSampleTests (8: v1 restores with its digest, newer refused as newerSchema 2, damaged corrupt; current garden opens and re-encodes exactly; newer and damaged unreadable; index lists two; newer index read-only; damaged index not rewritten; every file byte-identical); .autonomy/checks/A20-P06.zg-ios27.json exit 0; written by an agent, retested
  garden-newer,garden-damaged,library-current,library-newer,library-damaged}.json`, declare the `Fixtures` resource of
  `DigitalZenGardenExperienceTests` in `Packages/ExperiencesCreative/Package.swift` (lead), and add
  `ExperienceTests/StoredSampleTests.swift`: snapshot v1 restores, newer (schema 2) and damaged refused; a current
  garden file is listed and opens, newer (version 2) and damaged are listed as unreadable with `newer-version` and
  `damaged`; a current index lists two gardens, a newer index makes the library read-only, a damaged one is not
  rewritten by reading; every file byte-identical afterwards; synthetic UUIDs only (FR-A20-604)

## Phase 4: Story 3 — copy and checklist (P1)

- [X] T-A20-606 [US3] Write the release documents in `docs/apps/digital-zen-garden/`: `store-listing.md` (claims each — Verified 2026-11-17: 2026-11-17: store-listing.md (sound, no physics, health or measured claim; claims table with 38 proving tests and the three ZG interface classes), release-checklist.md (36 rows: 25 verified, 8 pending-campaign-ii ZG-D1 to ZG-D8, 3 owner-action), release.json (copyCheck.allow share), known-limitations section Digital Zen Garden (A20; features 144-150), README table; check_experience_release exit 0, check_copy_claims exit 0, validate_docs exit 0; written by an agent, reviewed
  with a proving test or interface class; "sound", never "audio" or "music"; no physics, health or measured claim),
  `release-checklist.md` (rows verified, pending-campaign-ii ZG-D1–ZG-D8, owner-action: signing, archive, upload),
  `release.json` per data-model.md (`copyCheck.allow` `["share"]`), the section `### Digital Zen Garden (A20; features 144–150)` of
  `docs/release/known-limitations.md` (after the A19 section), and the README document table (FR-A20-605, 606)
- [X] T-A20-607 [US3] Write `specs/150-zg-p06-release/scan-claims-release.sh` (the words of Clarifications Q2, whole — Verified 2026-11-17: 2026-11-17: specs/150-zg-p06-release/scan-claims-release.sh (the words of clarification Q2 over the store text and four interface Swift files; every named test, suite and ZG interface class exists); .autonomy/checks/A20-P06.zg-claims.json exit 0 (38 proving tests found)
  words, case-insensitive, over the store text and the interface Swift of data-model.md; every named test exists; ZG
  interface classes exist) and run it (`--name zg-claims -- sh specs/150-zg-p06-release/scan-claims-release.sh`)
  (FR-A20-605; SC-A20-603)

## Phase 5: Story 4 — interface tests (P2)

- [ ] T-A20-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/DigitalZenGarden/ZGReleaseUITests.swift` per Clarifications
  Q5 (with `ZGSupport`; a fresh start shows `calm-sound`, `calm-drift`, `calm-haptics` off; Make picture; the message
  reads "The picture is ready to share: 1600 by 1200 pixels." and `still-share` exists; under 60 s), and add it to the
  serial chunk `b3` in `scripts/release_check.py` (lead) (FR-A20-607)

## Phase 6: Records and evidence

- [ ] T-A20-609 Digital Zen Garden tests on sim-27.2 (`--name zg-ios27`; each under 10 s) and the documented API
  (`--name documented-api`) (SC-A20-604)
- [ ] T-A20-610 App build, unit and interface chunk (`xcodegen generate --spec project.yml`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-b3`) and the runner (`--name
  verify-27`) (SC-A20-604)
- [ ] T-A20-611 Release build checks (review checkpoint; `--name release-checks -- python3 scripts/release_check.py
  --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
  experience-release-a20 copy-claims-a20`)
- [ ] T-A20-612 Contract: G-RELEASE closed by "A20-P06" (its iOS 26.x runner half is cited at X-A20); rows whose gaps are all closed become available with evidence
  (`--name contract`); packages, catalog and script tests
- [ ] T-A20-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A20-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A20-601 → {602, 603} → {604, 605} → {606, 607} → 608 → 609 → 610 → 611 → 612 → 613. 602, 605 and 608 touch
different files and may run in parallel; 606 follows 602 (its `requiredDocs` names 602's page), and 607 follows 606
(it scans 606's store text).

## Parallel examples

Agent D: T-A20-602 and 606 (documents). Agent K: T-A20-604 and 605 (code and samples). Agent U: T-A20-608 (interface
test). Lead: scans (603, 607), Package.swift, release_check.py, runs, contract, commits.

## Implementation strategy

MVP: privacy (602, 603) and recovery (604, 605). Copy and checklist (606, 607) and the interface chunk (608) close the
release. Review checkpoints after 605 and at 611. One commit per task.
