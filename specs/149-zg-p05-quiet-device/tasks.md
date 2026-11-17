# Tasks: Digital Zen Garden — Phase 05 Responsiveness and idle-power QA

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/quiet.md](contracts/quiet.md), [quickstart.md](quickstart.md). Gate A20-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P05 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
device step. No VisualCore change. Precedent: `specs/142-lw-p05-device-tests/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A20-501 Baseline: cite the A20-P04 evidence (`.autonomy/checks/A20-P04.{zg-ios27,app-unit,verify-27}.json`) on — Verified 2026-11-17: 2026-11-17: A20-P04 evidence cited: .autonomy/checks/A20-P04.zg-ios27.json, A20-P04.app-unit.json and A20-P04.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A20-P04 record commit 1d8c1637
  the tree recorded at A20-P04 (`1d8c1637`), whose Packages, Apps and `project.yml` are unchanged since (owner ruling
  of 2026-11-14)
- [X] T-A20-502 Add `VisualCoreAudio` (package `rendering`) and `VisualCoreAudioDSP` (package `visualCore`) to the — Verified 2026-11-17: 2026-11-17: VisualCoreAudioDSP (visualCore) and VisualCoreAudio (rendering) added to DigitalZenGardenExperience and its tests in Packages/ExperiencesCreative/Package.swift; the package resolves and builds; .autonomy/checks/A20-P05.zg-ios27.json exit 0 (iOS 27.2)
  `DigitalZenGardenExperience` target of
  `Packages/ExperiencesCreative/Package.swift` (lead; the package still resolves and builds)

## Phase 2: Story 1 — quiet by default (P1) 🎯

- [X] T-A20-503 [P] [US1] Experience (agent E), per contracts/quiet.md and data-model.md: — Verified 2026-11-17: 2026-11-17: calm.sound, calm.drift, calm.haptics (range 0...1, default 0, outside the digest) as native Toggles Sound, Sand drift, Haptics (calm-sound, calm-drift, calm-haptics); kept as calm.v1 JSON, damaged ignored; grain drift 0.01 tray widths per second only with drift on and Reduce Motion off, still frame reused otherwise, SandScene.maxFrameLuminanceStep 0.02; GardenSounds stroke, place, remove (0.14-0.22 s, 190-320 Hz, gain 0.12-0.16) through GardenSoundSink over SoundEffectPlayer, enabled only with sound on, stopped on suspend; haptics .selection and .impactLight via ExperienceFeedback only with haptics on; .autonomy/checks/A20-P05.zg-ios27.json exit 0; written by an agent, retested
  - `Experience/Adapter/GardenCore.swift`: controls `calm.sound`, `calm.drift`, `calm.haptics` "∈ {0, 1}, default 0;
    core state outside the digest"; each a native switch with a spoken label in `Experience/GardenControls.swift`;
  - storage: "stored as the experience value `calm.v1` (JSON `{sound, drift, haptics}`), ignored when damaged",
    restored when the experience opens;
  - `Experience/SandScene.swift`: "grain offset += 0.01 tray widths per second of frame time when `calm.drift` is on
    and Reduce Motion is off; otherwise 0, with the still frame reused"; the relief, stones and shadows never move;
  - `Experience/GardenSounds.swift` (new): `stroke`, `place`, `remove` "procedural one-shot tones (0.12–0.25 s,
    180–420 Hz, gain ≤ 0.2)" from VisualCoreAudioDSP through `SoundEffectPlayer`, whose `isEnabled` follows
    `calm.sound` (set off at start); the player stops when the experience suspends;
  - `Experience/GardenPresenter.swift`: tones on stroke commit, stone placement and removal only with sound on; a
    light selection haptic on stone selection and a light impact on placement through `ExperienceFeedback.haptic(_:)` (`HapticKind.selection`,
    `.impactLight`; the person's switch and rate limit), only with haptics on; test seams after `MazePresenter`: a
    `GardenSoundSink` (nil: `SoundEffectPlayer`) and an `ExperienceFeedback` (nil: `.shared`);
  - no GL call outside the scene protocol; `///` on every new declaration
  (FR-A20-501, 502, 503)
- [X] T-A20-504 [P] [US1] Tests (agent E): `ExperienceTests/CalmTests.swift` (defaults off; switches persist across a — Verified 2026-11-17: 2026-11-17: CalmTests (10: defaults off, calm.v1 across a reopen, damaged ignored, digest unchanged, tones and haptics only when on, sink disabled while off, stop on suspend) and ReducedMotionTests (5: identical frames with drift off and under Reduce Motion, different with drift on, luminance step 6.4e-06 below 0.02, Reduce Flashing unchanged); 90 experience and 51 core tests pass, each under 10 s; .autonomy/checks/A20-P05.zg-ios27.json exit 0; written by an agent, retested
  reopen through `calm.v1`; damaged value ignored; digest unchanged by the switches; tone and haptic requests only
  when on; player disabled while sound is off) and `ExperienceTests/ReducedMotionTests.swift` (two renders at
  different frame times identical with the drift off and with the drift on under Reduce Motion, different with the
  drift on otherwise; Reduce Flashing leaves the picture the same); each test under 10 s (FR-A20-501–503; SC-A20-501,
  504)

## Phase 3: Story 2 — the garden in the app (P1)

- [X] T-A20-505 [P] [US2] Interface (agent U): `Apps/VisualCore/Tests/UI/DigitalZenGarden/ZGSupport.swift` (launch — Verified 2026-11-17: 2026-11-17: ZGSupport (launch with -vcCandidates, identifiers experience.a20.digital-zen-garden.<name>) and ZGGardenUITests: rows pattern adds a stroke and undo takes it back (17.9 s); a placed river pebble is removed and undo restores it (27.9 s); .autonomy/checks/A20-P05.app-ui.json exit 0 (build, unit, chunk b3, iOS 27.2 phone); written by an agent, retested
  like `LWSupport` with `-vcCandidates`; identifiers `experience.a20.digital-zen-garden.<name>`) and
  `ZGGardenUITests.swift` (rake the rows pattern, undo empties the description's stroke count; stone tool: place a
  river pebble, remove it, undo restores it); each under 60 s (FR-A20-504; SC-A20-502)
- [X] T-A20-506 [P] [US2] Interface (agent U): `Apps/VisualCore/Tests/UI/DigitalZenGarden/ZGLibraryUITests.swift` — Verified 2026-11-17: 2026-11-17: ZGLibraryUITests: rows raked, saved as Evening, undone to no stroke, Evening opened with its stroke (33.7 s); .autonomy/checks/A20-P05.app-ui.json exit 0 (chunk b3, iOS 27.2 phone); written by an agent, retested
  (rake a pattern, save as "Evening", reset through undo, open "Evening"; the description shows one stroke); under
  60 s (FR-A20-504; SC-A20-502)
- [X] T-A20-507 [US2] Add the serial chunk `"b3": ["ZGGardenUITests", "ZGLibraryUITests"]` to `scripts/release_check.py` — Verified 2026-11-17: 2026-11-17: scripts/release_check.py serial chunk b3 = ZGGardenUITests, ZGLibraryUITests, added to SERIAL_CHUNKS; scripts/test_scripts.py exit 0
  and to `SERIAL_CHUNKS` (lead); `scripts/test_scripts.py` passes

## Phase 4: Story 3 — the campaign plan (P2)

- [X] T-A20-508 [P] [US3] Write `docs/apps/digital-zen-garden/device-campaign.md` (agent D, after — Verified 2026-11-17: 2026-11-17: docs/apps/digital-zen-garden/device-campaign.md rows ZG-D1 to ZG-D8, each with devices (D1, D2, D3), procedure, threshold and pending device campaign; no measured number; facts checked in code (30 fps cap, cached still, 480 x 360 field, resampler 0.004 and 512, ambient session); listed in the README; validate_docs exit 0; written by an agent, reviewed
  `docs/apps/living-wallpapers/device-campaign.md`) with rows ZG-D1 to ZG-D8 of clarification Q5, each with devices
  (D1, D2, D3), procedure, threshold and "pending device campaign"; no number claimed; D3 stays on iPadOS 26.5; list
  it in `docs/apps/digital-zen-garden/README.md` (FR-A20-505, 506; SC-A20-503)

## Phase 5: Records and evidence

- [X] T-A20-509 Contract: G-QUIET and G-DEVICE closed by "A20-P05" (G-DEVICE as the plan; its rows wait for devices); — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P05.contract.json exit 0; G-QUIET closed by A20-P05 (CalmTests, ReducedMotionTests, the b3 journeys) and G-DEVICE closed by A20-P05 with the campaign plan (its rows wait for devices); M07, M11, M13, M14, M20 and M28 available; M27 stays open for G-RELEASE
  rows whose gaps are all closed become available with evidence (`--name contract`, `check_app_contract.py --app
  digital-zen-garden --render`)
- [X] T-A20-510 Tests (review checkpoint): Digital Zen Garden on sim-27.2 (`--name zg-ios27`), documented API, — Verified 2026-11-17: 2026-11-17: review checkpoint: .autonomy/checks/A20-P05.zg-ios27.json, app-ui.json (build, unit, chunk b3), verify-27.json, documented-api.json, isolation.json, core-purity.json, photos-scan.json, experience-packages.json and script-tests.json, all exit 0; isolation proves no GL call outside the scene protocol
  isolation, core purity, the Photos scan; `xcodegen generate --spec project.yml`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-b3`; runner (`--name
  verify-27`); experience packages and script tests; isolation proves no GL call outside the scene protocol
  (FR-A20-501–504; SC-A20-501, 502, 504)
- [X] T-A20-511 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-17: 2026-11-17: converge round 1 appended T-A20-512 and T-A20-513 (implemented), round 2 converged with nothing appended; A20-P05 sealed (.autonomy/evidence/A20-P05.json) and recorded (VERIFIED-GATE A20-P05, 149 of 263); planning index, matrix, distinctiveness, metadata, Auto-Creator, catalog (--check PASS), validate_autocreator and validate_docs PASS; README and docs/automatedtesting.md updated
  A20-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

501 → 502 → {503/504, 505/506, 508} → 507 → 509 → 510 → 511. 503/504 (experience), 505/506 (interface) and 508
(document) are separate files; 502 precedes 503 because the sounds import VisualCoreAudio.

## Parallel examples

Agent E: T-A20-503, 504. Agent U: T-A20-505, 506. Agent D: T-A20-508. Lead: Package.swift (502), release_check.py
(507), contract, runs, commits.

## Implementation strategy

MVP: the quiet defaults and the reduced-motion fixture (503, 504). The interface journeys (505–507) prove the named
gardens in the app; the plan (508) closes G-DEVICE. Review checkpoint at 510. Commit boundaries: one commit per task.

## Phase 6: Convergence

- [X] T-A20-512 Correct `docs/apps/digital-zen-garden/README.md`: the experience asks only for the add-only Photos permission (`photo-library-add` in `Catalog/registrations.json`, when the still is saved through the share sheet), and the calm switches (sound, sand drift, haptics; off by default) are kept as the experience value `calm.v1` per FR-A20-506 (contradicts) — Verified 2026-11-17: 2026-11-17: docs/apps/digital-zen-garden/README.md now names the add-only Photos permission (photo-library-add, Catalog/registrations.json) and the calm switches kept as calm.v1; validate_docs exit 0
- [X] T-A20-513 Record in `specs/149-zg-p05-quiet-device/data-model.md` that a garden reset keeps the calm switches (a preference, like the quality tier), while a snapshot restore starts them off and the presenter re-sends the kept `calm.v1` switches at the next draw per data-model calm settings (unrequested) — Verified 2026-11-17: 2026-11-17: data-model.md records that a reset keeps the calm switches and a restore re-sends the kept calm.v1 switches (GardenCore.reset, GardenPresenter.applyKeptCalm; CalmTests); validate_docs exit 0
