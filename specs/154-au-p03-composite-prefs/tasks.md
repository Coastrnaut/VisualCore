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

- [X] T-A21-302 [US1] Create `Packages/ExperiencesCreative/Aurora/Experience/SkyTransition.swift` and change — Verified 2026-11-17: 2026-11-17: SkyTransition (CrossfadeScene of the shown moving sky and a new sky in a second shader slot; 2.0 s of frame time, smoothstep; replaceIncoming on a new choice; immediate under Reduce Motion; torn down at the end keeping the incoming sky) used by AuroraPresenter, SkyBlend kept for control changes; .autonomy/checks/A21-P03.au-ios27.json exit 0; written by an agent, retested
  `AuroraPresenter.swift` per data-model.md: a `CrossfadeScene` of the outgoing and incoming skies (two moving
  `FullScreenShaderScene`s, each under the limit), progress "over 2.0 s of frame time, smoothstep", a new choice
  mid-change through `replaceIncoming`, immediate under Reduce Motion; the A21-P02 input blend stays for control
  changes within one sky (FR-A21-301, 302)
- [X] T-A21-303 [US1] Write `Packages/ExperiencesCreative/Aurora/ExperienceTests/TransitionTests.swift`: at progress 0, — Verified 2026-11-17: 2026-11-17: TransitionTests (5): at steps 0 to 1 the largest luminance stays under the limit (0.5805 at 0.6, 0.1992 at 0.2, 0.6813 at 0.72) and the mean difference from the incoming sky falls monotonically to 0; context loss and resize mid-change keep the picture; a restart from the current mix; Reduce Motion immediate; BlendTests, LimitRenderTests and ChromeTests updated for the crossfade and the two sound controls; .autonomy/checks/A21-P03.au-ios27.json exit 0; written by an agent, retested
  0.1, …, 1 no pixel above the limit + 1/255 and the mean absolute difference from the incoming sky never increases;
  a context loss and a resize mid-change keep the picture; a new choice restarts from the current mix; immediate under
  Reduce Motion (SC-A21-301)

## Phase 3: Story 2 — choices kept (P1)

- [X] T-A21-304 [P] [US2] Create `Packages/ExperiencesCreative/Aurora/Core/SkyPreferences.swift` per data-model.md: — Verified 2026-11-17: 2026-11-17: SkyPreferences (schema 1, a21.preferences, prefs.v1, at most 4,096 bytes; ten fields with ranges and defaults; codes damaged, newer-version, out-of-range) and PreferencesTests (9: round trips, every code, size, defaults); .autonomy/checks/A21-P03.au-ios27.json exit 0; written by an agent, retested
  "schema 1, kind `a21.preferences`, experience value `prefs.v1`, ≤ 4,096 bytes"; fields and ranges as listed;
  defaults; codes `damaged`, `newer-version`, `out-of-range`; and `CoreTests/PreferencesTests.swift` (round trip, each
  code, defaults) (FR-A21-303, 304)
- [X] T-A21-305 [US2] Wire the preferences into the experience (`AuroraPresenter.swift`, `AuroraExperience.swift`): — Verified 2026-11-17: 2026-11-17: preferences read before the first draw and seeded through the port, written after every accepted change, the two messages, a restored snapshot (SkyCore.isRestored, outside the digest) winning for the sky and never for the sound; PreferencesStoreTests (4); .autonomy/checks/A21-P03.au-ios27.json exit 0; written by an agent, retested
  read before the first frame, written after every accepted change through `ExperienceStorage.setValue`, the two
  messages of data-model.md, a restored snapshot winning for the sky and never for the sound choice; and
  `ExperienceTests/PreferencesStoreTests.swift` (close and reopen keeps every field; damaged, newer and out-of-range
  open with defaults and their message; a failed save reported once) (SC-A21-302)

## Phase 4: Story 3 — the sound choice outlives the drawing (P1)

- [X] T-A21-306 [US3] Add the sound control (on/off and volume, spoken labels, plays nothing) to — Verified 2026-11-17: 2026-11-17: sound toggle and volume slider (identifiers sound, volume; spoken labels) writing the preferences only, no engine action, nothing plays; SoundChoiceTests (2): unchanged after recreateContext, resize, suspend, resume and teardown with a new session, port revision, snapshot and digest unchanged; manifest unchanged; .autonomy/checks/A21-P03.au-ios27.json exit 0; written by an agent, retested
  `AuroraControls.swift`, kept only in the preferences (no engine action: the snapshot, digest and manifest are unchanged); `ExperienceTests/SoundChoiceTests.swift`: unchanged after
  teardown, setup, `recreateContext`, resize, suspend and resume (FR-A21-305, 306; SC-A21-303)

## Phase 5: Records and evidence

- [X] T-A21-307 Aurora tests on sim-27.2 (`--name au-ios27`), documented API, isolation and core purity (review — Verified 2026-11-17: 2026-11-17: review checkpoint: .autonomy/checks/A21-P03.au-ios27.json, A21-P03.documented-api.json, A21-P03.isolation.json and A21-P03.core-purity.json, all exit 0; every test under 10 s (longest 5.6 s)
  checkpoint; SC-A21-304)
- [X] T-A21-308 Contract: G-COMPOSITE and G-PREFS closed by "A21-P03" (record that quality is the host's choice, not a — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P03.contract.json exit 0; G-COMPOSITE and G-PREFS closed by A21-P03 (quality recorded as the host's choice, not saved); M08, M12, M15 and M16 available; M14 stays open for G-DEVICE
  preference); rows whose gaps are all closed become available with evidence (`--name contract`)
- [X] T-A21-309 Manifest (regenerate `scenario-manifest.json` if the controls changed), catalog, app build and unit — Verified 2026-11-17: 2026-11-17: scenario-manifest.json unchanged (AuroraManifestTests in A21-P03.au-ios27.json pass; no engine action changed); .autonomy/checks/A21-P03.catalog.json, A21-P03.app-unit.json (build for testing and unit on iOS 27.2), A21-P03.verify-27.json, A21-P03.experience-packages.json and A21-P03.script-tests.json, all exit 0
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

## Phase 6: Convergence

- [ ] T-A21-311 Record the as-built design in `specs/154-au-p03-composite-prefs/data-model.md` and `contracts/experience.md`: the second sky is compiled with `#define AURORA_SKY_SLOT 1` so the two skies never share one cached program; a fade whose captured still was drawn under a higher limit ends at once when the limit is lowered; a fresh open seeds the saved preferences through the port at the first draw (a refused send is retried at the next draw); `SkyCore.isRestored` (presentation only, outside the digest, the snapshot and equality) tells a restore from a fresh open; a failed save is forced in tests by filling the 64-value quota; and the A21-P02 blend, limit and chrome tests now expect the crossfade and the two sound controls per data-model and contract (unrequested)
