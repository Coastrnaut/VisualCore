# Tasks: Ambient Clock — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A18-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A18-P06 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only; iOS 26 and the
reference regression wait for X-A18. Precedent: `specs/129-ia-p06-release/tasks.md`. Rollback: revert the commits (no
migration, no VisualCore change).

## Phase 1: Setup

- [ ] T-A18-601 Baseline: cite the A18-P05 evidence (`.autonomy/checks/A18-P05.{ac-ios27,app-ui,verify-27}.json`) on the tree recorded at A18-P05 (495ae6b6), whose Packages, Apps and project.yml are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Story 1 — privacy and credits

- [ ] T-A18-602 [P] [US1] Write `docs/apps/ambient-clock/privacy-and-credits.md`: the stored snapshot (format, theme, night and motion settings) and `favourites.json` (at most 12) in the experience's storage, replaced on each change and removed when the app is deleted; nothing sent; no permission or usage string; keep-awake is off by default, turned on only by the person, applies only while the clock is open, and lives in `Experience/KeepAwake.swift`; brightness is never written; the license inventory (the themes, palettes, shaders and type are written in this repository; the system font) (FR-A18-601)
- [ ] T-A18-603 [US1] Write `specs/136-ac-p06-release/scan-sources-release.sh` refusing the APIs of Clarifications Q3 and any `brightness =` write in `Packages/ExperiencesCreative/AmbientClock`, and requiring `isIdleTimerDisabled` in exactly `Experience/KeepAwake.swift`; run it (`--name ac-no-network -- sh specs/136-ac-p06-release/scan-sources-release.sh`) (FR-A18-602; SC-A18-601)

## Phase 3: Story 2 — recovery and stored files

- [ ] T-A18-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/AmbientClock/Experience/AmbientPresenter.swift` (the next draw throws `AmbientDrawError.injected` once and clears the flag) and `ExperienceTests/AmbientRecoveryDrawTests.swift` (two favourites saved in a temporary storage; a failed draw fails the session; `favourites.json` byte-identical after the failure and after close; a new session over the same storage opens and lists both) (FR-A18-603; SC-A18-602)
- [ ] T-A18-605 [P] [US2] Commit `ExperienceTests/Fixtures/{snapshot-v1,snapshot-v2,snapshot-v3,snapshot-newer,snapshot-damaged,favourites-current,favourites-newer,favourites-damaged}.json`, declare the `Fixtures` resource of `AmbientClockExperienceTests` in `Packages/ExperiencesCreative/Package.swift` (lead), and add `ExperienceTests/StoredSampleTests.swift` (v1–v3 restore, v1 and v2 migrated; newer and damaged refused; favourites current loads, newer and damaged report their problem; every sample byte-identical afterwards) (FR-A18-604)

## Phase 4: Story 3 — copy and checklist

- [ ] T-A18-606 [P] [US3] Write the release documents in `docs/apps/ambient-clock/`: `store-listing.md` (claims each with a proving test or interface class; the clock shows the system time; keep-awake is the person's choice), `release-checklist.md` (rows verified, pending-campaign-ii AC-D1–AC-D10 including performance and heat AC-D1/AC-D3 and accessibility AC-D10, owner-action: signing, archive, upload), `release.json` per data-model.md, and the A18 section of `docs/release/known-limitations.md`; run `--name experience-release -- python3 scripts/release_check.py --only experience-release-a18 copy-claims-a18` (FR-A18-605, 606)
- [ ] T-A18-607 [US3] Write `specs/136-ac-p06-release/scan-claims-release.sh` (the words of Clarifications Q2, whole words, case-insensitive, over the store text and the interface Swift; every named test exists) and run it (`--name ac-claims -- sh specs/136-ac-p06-release/scan-claims-release.sh`) (FR-A18-605; SC-A18-603)

## Phase 5: Story 4 — interface tests

- [ ] T-A18-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/AmbientClock/ACThemeUITests.swift` per Clarifications Q5 (launched like `ACSupport`; Wave Field, save "Evening", switch, apply, Wave Field shown; under 60 s), and add it to the serial chunk `z2` in `scripts/release_check.py` (lead) (FR-A18-607)

## Phase 6: Records and evidence

- [ ] T-A18-609 Ambient Clock tests on sim-27.2 (`--name ac-ios27`; the slowest under 10 s) and the documented API (`--name documented-api`)
- [ ] T-A18-610 App build, unit and interface chunk (`xcodegen generate --spec project.yml`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-z2`) and the runner (`--name verify-27`) (SC-A18-604)
- [ ] T-A18-611 Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a18 copy-claims-a18`)
- [ ] T-A18-612 Contract: G-RELEASE closed by "A18-P06"; rows whose gaps are all closed become available with evidence (`--name contract`); packages, catalog and script tests
- [ ] T-A18-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A18-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A18-601 → {602, 603} → {604, 605} → {606, 607} → 608 → 609 → 610 → 611 → 612 → 613. 602, 605, 606 and 608 touch
different files and may run in parallel.

## Parallel examples

Agent D: T-A18-602 and 606 (documents). Agent K: T-A18-604 and 605 (code and samples). Agent U: T-A18-608 (interface
test). Lead: scans (603, 607), Package.swift, release_check.py, runs, contract, commits.

## Implementation strategy

MVP: privacy (602, 603) and recovery (604, 605). Copy and checklist (606, 607) and the interface chunk (608) close the
release. Review checkpoints after 605 and at 611.
