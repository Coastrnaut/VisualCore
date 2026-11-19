# Tasks: Effects Composer — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A25-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A25-P06 --timeout 595 --name <check> -- <command>`.
- **Commits:** one per task, no trailers. **Checks:** read every exit before ticking.
- **Precedent:** `specs/178-gbl-p06-release/tasks.md`. **Rollback:** revert the commits.

## Phase 1: Setup

- [ ] T-A25-601 Baseline: cite the A25-P05 evidence (`.autonomy/checks/A25-P05.{ec-ios27-3,app-unit-2,verify-27-2}.json`)

## Phase 2: Story 1 — nothing leaves without the person's choice (P1) 🎯

- [ ] T-A25-602 [P] [US1] Write `docs/apps/effects-composer/privacy-and-credits.md` (stored data, places and removal of
  clarification "Stored data"; the picker; the export and the add-only Photos prompt with its usage string word for
  word; "Nothing is sent automatically"; code-made visuals) and `docs/apps/effects-composer/licenses.md` (the licence
  inventory: VisualCore's own code and the system frameworks; no third-party asset)
- [ ] T-A25-603 [P] [US1] Write `specs/185-ec-p06-release/scan-sources-release.sh` per contracts/release.md (after
  `specs/178-gbl-p06-release/scan-sources-release.sh`; `PhotosUI`, `PhotosPicker`, `ShareLink` only in
  `Experience/ECControls.swift`, each required there); `--name scan-sources`

## Phase 3: Story 2 — recover without losing the looks (P1)

- [ ] T-A25-604 [US2] Add `failNextDraw` and `ComposerDrawError.injected` ("The picture could not be drawn.") to
  `Packages/ExperiencesCreative/EffectsComposer/Experience/ComposerPresenter.swift`; write
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ComposerRecoveryTests.swift` (two saved looks; the
  session fails with the message; every storage file byte-identical; a new session lists and opens both)
- [ ] T-A25-605 [US2] Generate the nine samples of data-model.md once through the real encoders into
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/Fixtures/` (declare the folder as a test resource in
  `Packages/ExperiencesCreative/Package.swift` if needed) and write
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ReleaseSampleTests.swift` (each outcome of
  data-model.md; every file byte-identical after reading); `--name ec-recovery-samples`

## Phase 4: Story 3 — honest copy and a complete checklist (P1)

- [ ] T-A25-606 [US3] Write `docs/apps/effects-composer/store-listing.md` (claims table naming proving tests; contains
  "Nothing is sent"), `docs/apps/effects-composer/release-checklist.md` (one table: `| Item | Status | Evidence |`,
  statuses `verified`, `pending-campaign-ii` for EC-D1 … EC-D7, `owner-action` with `docs/release/build-and-archive.md`),
  `docs/apps/effects-composer/release.json` (data-model.md), the A25 section of `docs/release/known-limitations.md`
  (FR-A25-606's four limits), and the a25 summary and capabilities in `Catalog/registrations.json` (built features,
  keeps "shader", ≤ 300 characters); `--name experience-release -- python3 scripts/release_check.py --only
  experience-release-a25 copy-claims-a25`; `python3 scripts/build_catalog.py`
- [ ] T-A25-607 [US3] Write `specs/185-ec-p06-release/scan-claims-release.sh` with the words of clarification Q2;
  `--name scan-claims`

## Phase 5: Story 4 — a first session (P2)

- [ ] T-A25-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/EffectsComposer/ECReleaseUITests.swift` per contracts/release.md
  and add chunk `"g3": ["ECReleaseUITests"]` to `scripts/release_check.py` (serial, in `SERIAL_CHUNKS`)

## Phase 6: Evidence and close

- [ ] T-A25-609 Effects Composer tests on sim-27.2 (`--name ec-ios27`, each under 10 s), the documented API and
  CatalogSearchTests through the app unit run
- [ ] T-A25-610 App: `xcodegen generate --spec project.yml`, then `--name app-ui -- python3 scripts/release_check.py
  --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-g3`; `--name verify-27`; `--name script-tests`
  (the new chunk); `--name catalog`
- [ ] T-A25-611 Release checks as a review checkpoint: `--name release-checks -- python3 scripts/release_check.py
  --only experience-release-a25 copy-claims-a25`, plus both scans
- [ ] T-A25-612 Contract: close G-RELEASE with "A25-P06" (all 14 gaps closed; the iOS 26.x runner half cited at
  X-A25), `--name contract`; experience README
- [ ] T-A25-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A25-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

601 → {602, 603, 604, 608}; 604 → 605; {602, 605} → 606 → 607; {603, 606, 607, 608} → 609 → 610 → 611 → 612 → 613.

## Parallel examples

- **Agent D:** 602, then 606's documents. **Agent S:** 603, 607. **Agent R:** 604, 605. **Agent U:** 608.
  **Lead:** 601, registration text, chunk wiring, 609–613.
