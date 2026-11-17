# Tasks: Aurora — Phase 03 Multi-layer compositing and presets

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A21-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A21-P03 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/147-zg-p03-stones/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A21-301 Baseline: cite the A21-P02 evidence (`.autonomy/checks/A21-P02.{au-ios27,app-unit-2,verify-27}.json`) on — Verified 2026-11-17: 2026-11-17: A21-P02 evidence cited: .autonomy/checks/A21-P02.au-ios27.json, A21-P02.app-unit-2.json and A21-P02.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A21-P02 record commit a74f06f6
  the tree recorded at A21-P02 (`a74f06f6`), whose Packages are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Story 1 — one sky dissolves into the next (P1) 🎯

- [ ] T-A21-302 [US1] Create `Packages/ExperiencesCreative/Aurora/Experience/SkyTransition.swift` and change
  `AuroraPresenter.swift` per data-model.md: a `CrossfadeScene` of the outgoing and incoming skies (two moving
  `FullScreenShaderScene`s, each under the limit), progress "over 2.0 s of frame time, smoothstep", a new choice
  mid-change through `replaceIncoming`, immediate under Reduce Motion; the A21-P02 input blend stays for control
  changes within one sky (FR-A21-301, 302)
- [ ] T-A21-303 [US1] Write `Packages/ExperiencesCreative/Aurora/ExperienceTests/TransitionTests.swift`: at progress 0,
  0.1, …, 1 no pixel above the limit + 1/255 and the mean absolute difference from the incoming sky never increases;
  a context loss and a resize mid-change keep the picture; a new choice restarts from the current mix; immediate under
  Reduce Motion (SC-A21-301)

## Phase 3: Story 2 — choices kept (P1)

- [ ] T-A21-304 [P] [US2] Create `Packages/ExperiencesCreative/Aurora/Core/SkyPreferences.swift` per data-model.md:
  "schema 1, kind `a21.preferences`, experience value `prefs.v1`, ≤ 4,096 bytes"; fields and ranges as listed;
  defaults; codes `damaged`, `newer-version`, `out-of-range`; and `CoreTests/PreferencesTests.swift` (round trip, each
  code, defaults) (FR-A21-303, 304)
- [ ] T-A21-305 [US2] Wire the preferences into the experience (`AuroraPresenter.swift`, `AuroraExperience.swift`):
  read before the first frame, written after every accepted change through `ExperienceStorage.setValue`, the two
  messages of data-model.md, a restored snapshot winning for the sky and never for the sound choice; and
  `ExperienceTests/PreferencesStoreTests.swift` (close and reopen keeps every field; damaged, newer and out-of-range
  open with defaults and their message; a failed save reported once) (SC-A21-302)

## Phase 4: Story 3 — the sound choice outlives the drawing (P1)

- [ ] T-A21-306 [US3] Add the sound control (on/off and volume, spoken labels, plays nothing) to
  `AuroraControls.swift`, kept only in the preferences (no engine action: the snapshot, digest and manifest are unchanged); `ExperienceTests/SoundChoiceTests.swift`: unchanged after
  teardown, setup, `recreateContext`, resize, suspend and resume (FR-A21-305, 306; SC-A21-303)

## Phase 5: Records and evidence

- [ ] T-A21-307 Aurora tests on sim-27.2 (`--name au-ios27`), documented API, isolation and core purity (review
  checkpoint; SC-A21-304)
- [ ] T-A21-308 Contract: G-COMPOSITE and G-PREFS closed by "A21-P03" (record that quality is the host's choice, not a
  preference); rows whose gaps are all closed become available with evidence (`--name contract`)
- [ ] T-A21-309 Manifest (regenerate `scenario-manifest.json` if the controls changed), catalog, app build and unit
  (`--name app-unit`), runner (`--name verify-27`), packages and script tests
- [ ] T-A21-310 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A21-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

301 → {302 → 303, 304} → 305 → 306 → 307 → 308 → 309 → 310. 304 is a core file and runs beside 302; 305 and 306 touch
the presenter and controls after 302.

## Parallel examples

Agent C: T-A21-302, 303, then 305, 306. Agent P: T-A21-304. Lead: runs, contract, commits.

## Implementation strategy

MVP: the transition (302, 303). Preferences (304, 305) and the sound choice (306) close G-PREFS. Review checkpoint at
307. One commit per task.
