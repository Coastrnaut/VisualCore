# Tasks: Aurora — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release.md](contracts/release.md), [quickstart.md](quickstart.md). Gate A21-P06 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A21-P06 --timeout 595 --name <check> -- <command>`.
- **Commits:** one per task, with no trailers.
- **Checks:** run each check and read its exit, then tick in a separate step.
- **Scope:** iOS 27 only. iOS 26 and the reference regression wait for X-A21.
- **Precedent:** `specs/150-zg-p06-release/tasks.md`.
- **Rollback:** revert the commits (no migration, no VisualCore change).

## Phase 1: Setup

- [X] T-A21-601 Baseline: cite the A21-P05 evidence (`.autonomy/checks/A21-P05.{au-ios27-2,app-ui,verify-27}.json`) on — Verified 2026-11-17: 2026-11-17: A21-P05 evidence cited: .autonomy/checks/A21-P05.au-ios27-2.json, A21-P05.app-ui.json and A21-P05.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A21-P05 record commit 40aa885c
  the tree recorded at A21-P05 (`40aa885c`), whose Packages, Apps and project.yml are unchanged since (owner ruling of
  2026-11-14)

## Phase 2: Story 1 — nothing leaves the device (P1) 🎯

- [X] T-A21-602 [P] [US1] Write `docs/apps/aurora/privacy-and-credits.md`: — Verified 2026-11-17: 2026-11-17: docs/apps/aurora/privacy-and-credits.md: state.json (schema 1, the open sky) and prefs.v1 (a21.preferences) in the experience's storage, replaced on each change, removed with the app; refused values open the defaults and are not rewritten by reading; no temporary file; nothing sent; no permission; screen never kept awake, brightness never changed; the ambient sound off by default; licence inventory; facts checked in code; A21-P06.docs.json exit 0; written by an agent, reviewed
  - the session snapshot (the open sky, schema 1) and the saved choices (`prefs.v1`: the sky, the brightness limit,
    the sound on/off and volume) in the experience's storage, replaced on each change and removed when the app is
    deleted;
  - no temporary file; nothing is sent; no permission is asked (no location, microphone or camera);
  - the screen is never kept awake and its brightness never changed;
  - the optional sound plays on the ambient session (silenced by the silent switch), off by default;
  - the licence inventory (code only; link `licenses.md`)
  (FR-A21-601)
- [X] T-A21-603 [US1] Write `specs/157-au-p06-release/scan-sources-release.sh` (after — Verified 2026-11-17: 2026-11-17: specs/157-au-p06-release/scan-sources-release.sh (the APIs of clarification Q3); .autonomy/checks/A21-P06.au-no-network.json exit 0
  `specs/150-zg-p06-release/scan-sources-release.sh`):
  - it refuses the APIs of clarification Q3 in the Swift files of `Packages/ExperiencesCreative/Aurora`;
  - run it: `--name au-no-network -- sh specs/157-au-p06-release/scan-sources-release.sh`
  (FR-A21-602; SC-A21-601)

## Phase 3: Story 2 — recovery and stored files (P1)

- [X] T-A21-604 [US2] Add the recovery seam and its test: — Verified 2026-11-17: 2026-11-17: AuroraPresenter.failNextDraw (test-only; the next draw throws SkyDrawError.injected once and clears itself) and SkyRecoveryDrawTests (Violet veil and the sound saved; the session fails at the draw stage with the injected message; prefs.v1 byte-identical; a new session opens on Violet veil with the sound on); .autonomy/checks/A21-P06.au-ios27.json exit 0 (71 experience, 32 core tests); written by an agent, retested
  - in `Packages/ExperiencesCreative/Aurora/Experience/AuroraPresenter.swift`, the test-only seam
    `var failNextDraw = false` ("the next `draw` throws `SkyDrawError.injected` once and clears the flag");
  - `ExperienceTests/SkyRecoveryDrawTests.swift`, in a temporary storage:
    - save Violet veil and turn the sound on;
    - a failed draw fails the session with the injected message;
    - `prefs.v1` is byte-identical;
    - a new session over the same storage opens on Violet veil with the sound on
  (FR-A21-603; SC-A21-602)
- [X] T-A21-605 [P] [US2] Commit the stored samples and test them: — Verified 2026-11-17: 2026-11-17: seven samples in ExperienceTests/Fixtures (snapshot v1, newer, damaged; prefs current, newer, damaged, out-of-range), generated once through the real encoders, no UUID or path; the Fixtures resource in Package.swift; StoredSampleTests (5: v1 restores with its digest, newer refused as snapshot.newer-schema, damaged as snapshot.corrupt; current prefs open on Violet veil, sound on, volume 0.4; newer, damaged and out-of-range open the defaults with their codes; every file byte-identical); .autonomy/checks/A21-P06.au-ios27.json exit 0; written by an agent, retested
  - commit `ExperienceTests/Fixtures/{snapshot-v1,snapshot-newer,snapshot-damaged,prefs-current,prefs-newer,
    prefs-damaged,prefs-out-of-range}.json`, generated once through the real encoders;
  - declare the `Fixtures` resource of `AuroraExperienceTests` in `Packages/ExperiencesCreative/Package.swift` (lead);
  - add `ExperienceTests/StoredSampleTests.swift`:
    - snapshot v1 restores; the newer one (schema 2) is refused as `newerSchema` and the damaged one as `corrupt`;
    - the current preferences open with their values;
    - the newer, damaged and out-of-range preferences open the defaults with `newer-version`, `damaged` and
      `out-of-range`;
    - every file is byte-identical afterwards;
    - synthetic UUIDs only
  (FR-A21-604)

## Phase 4: Story 3 — copy and checklist (P1)

- [X] T-A21-606 [US3] Write the release documents: — Verified 2026-11-17: 2026-11-17: store-listing.md (sound, never audio or music; no forecast, scientific, therapeutic, sleep, always-on or measured claim; 13-row claims table), release-checklist.md (36 rows: 25 verified, 8 pending-campaign-ii AU-D1 to AU-D8, 3 owner-action), release.json (copyCheck.allow []), known-limitations section Aurora (A21; features 151-157), README table; the catalog capability and summary say gentle, not smooth (build_catalog --check PASS); device-campaign.md default brightness limit corrected to 0.6 (range 0.2 to 0.72); A21-P06.experience-release, copy-claims and docs exit 0; written by an agent, reviewed
  - in `docs/apps/aurora/`, `store-listing.md`:
    - each claim names a proving test or interface class;
    - "sound", never "audio" or "music";
    - no forecast, scientific, therapeutic, sleep, always-on or measured claim;
  - `release-checklist.md`, with these rows:
    - verified;
    - pending-campaign-ii (AU-D1–AU-D8);
    - owner-action (signing, archive, upload);
  - `release.json` per data-model.md (`copyCheck.allow` `[]`);
  - the section `### Aurora (A21; features 151–157)` of `docs/release/known-limitations.md`, after the A20 section;
  - the README document table
  (FR-A21-605, 606)
- [X] T-A21-607 [US3] Write `specs/157-au-p06-release/scan-claims-release.sh`, then run it: — Verified 2026-11-17: 2026-11-17: specs/157-au-p06-release/scan-claims-release.sh (the words of clarification Q2 over the store text and four interface Swift files, comments included; every named test, suite and AU interface class exists); .autonomy/checks/A21-P06.au-claims.json exit 0 (40 proving tests found)
  - it matches the words of clarification Q2 as whole words, case-insensitive, over the store text and the
    interface Swift of data-model.md;
  - every named test exists, and the AU interface classes exist;
  - the scan reads comments too, so a comment that matches is reworded, never allowed;
  - run: `--name au-claims -- sh specs/157-au-p06-release/scan-claims-release.sh`
  (FR-A21-605; SC-A21-603)

## Phase 5: Story 4 — interface (P2)

- [X] T-A21-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/Aurora/AUReleaseUITests.swift` per clarification Q5, with — Verified 2026-11-17: 2026-11-17: AUReleaseUITests (a fresh start names Polar night on the canvas; sound, still and reduced-flash read off; no failure); added to serial chunk c3 in scripts/release_check.py; .autonomy/checks/A21-P06.app-ui.json exit 0 (chunk c3: 5 tests in 123.4 s on the iOS 27.2 phone, each under 60 s); A21-P06.script-tests.json exit 0; written by an agent, retested
  `AUSupport`:
  - a fresh start names "Polar night" on the canvas;
  - `sound`, `still` and `reduced-flash` read off;
  - under 60 s;
  - add it to the serial chunk `c3` in `scripts/release_check.py` (lead)
  (FR-A21-607)

## Phase 6: Records and evidence

- [ ] T-A21-609 Aurora tests on sim-27.2 (`--name au-ios27`; each under 10 s) and the documented API
  (`--name documented-api`) (SC-A21-604)
- [ ] T-A21-610 App build, unit tests and interface chunk:
  - `xcodegen generate --spec project.yml`;
  - `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-c3`;
  - the runner (`--name verify-27`)
  (SC-A21-604)
- [ ] T-A21-611 Release build checks, as a review checkpoint: `--name release-checks -- python3 scripts/release_check.py
  --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
  experience-release-a21 copy-claims-a21`
- [ ] T-A21-612 Contract:
  - G-RELEASE is closed by "A21-P06"; its iOS 26.x runner half is cited at X-A21;
  - rows whose gaps are all closed become available, with evidence;
  - run `--name contract`, then the packages, catalog and script tests
- [ ] T-A21-613 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A21-P06; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A21-601 → {602, 603} → {604, 605} → {606, 607} → 608 → 609 → 610 → 611 → 612 → 613.
- **Parallel:** 602, 605 and 608 touch different files and may run in parallel.
- **606 after 602:** its `requiredDocs` names 602's page.
- **607 after 606:** it scans 606's store text.

## Parallel examples

- **Agent D:** T-A21-602 and 606 (the documents).
- **Agent K:** T-A21-604 and 605 (the code and the samples).
- **Agent U:** T-A21-608 (the interface test).
- **Lead:** the scans (603, 607), Package.swift, release_check.py, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** privacy (602, 603) and recovery (604, 605).
- **Release:** the copy and checklist (606, 607) and the interface chunk (608) close the release.
- **Review checkpoints:** after 605 and at 611.
- **Commits:** one per task.
