# Tasks: Digital Zen Garden — Phase 05 Responsiveness and idle-power QA

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/quiet.md](contracts/quiet.md), [quickstart.md](quickstart.md). Gate A20-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P05 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
device step. No VisualCore change. Precedent: `specs/142-lw-p05-device-tests/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [ ] T-A20-501 Baseline: cite the A20-P04 evidence (`.autonomy/checks/A20-P04.{zg-ios27,app-unit,verify-27}.json`) on
  the tree recorded at A20-P04 (`1d8c1637`), whose Packages, Apps and `project.yml` are unchanged since (owner ruling
  of 2026-11-14)
- [ ] T-A20-502 Add `VisualCoreAudio` (package `rendering`) and `VisualCoreAudioDSP` (package `visualCore`) to the
  `DigitalZenGardenExperience` target of
  `Packages/ExperiencesCreative/Package.swift` (lead; the package still resolves and builds)

## Phase 2: Story 1 — quiet by default (P1) 🎯

- [ ] T-A20-503 [P] [US1] Experience (agent E), per contracts/quiet.md and data-model.md:
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
- [ ] T-A20-504 [P] [US1] Tests (agent E): `ExperienceTests/CalmTests.swift` (defaults off; switches persist across a
  reopen through `calm.v1`; damaged value ignored; digest unchanged by the switches; tone and haptic requests only
  when on; player disabled while sound is off) and `ExperienceTests/ReducedMotionTests.swift` (two renders at
  different frame times identical with the drift off and with the drift on under Reduce Motion, different with the
  drift on otherwise; Reduce Flashing leaves the picture the same); each test under 10 s (FR-A20-501–503; SC-A20-501,
  504)

## Phase 3: Story 2 — the garden in the app (P1)

- [ ] T-A20-505 [P] [US2] Interface (agent U): `Apps/VisualCore/Tests/UI/DigitalZenGarden/ZGSupport.swift` (launch
  like `LWSupport` with `-vcCandidates`; identifiers `experience.a20.digital-zen-garden.<name>`) and
  `ZGGardenUITests.swift` (rake the rows pattern, undo empties the description's stroke count; stone tool: place a
  river pebble, remove it, undo restores it); each under 60 s (FR-A20-504; SC-A20-502)
- [ ] T-A20-506 [P] [US2] Interface (agent U): `Apps/VisualCore/Tests/UI/DigitalZenGarden/ZGLibraryUITests.swift`
  (rake a pattern, save as "Evening", reset through undo, open "Evening"; the description shows one stroke); under
  60 s (FR-A20-504; SC-A20-502)
- [ ] T-A20-507 [US2] Add the serial chunk `"b3": ["ZGGardenUITests", "ZGLibraryUITests"]` to `scripts/release_check.py`
  and to `SERIAL_CHUNKS` (lead); `scripts/test_scripts.py` passes

## Phase 4: Story 3 — the campaign plan (P2)

- [ ] T-A20-508 [P] [US3] Write `docs/apps/digital-zen-garden/device-campaign.md` (agent D, after
  `docs/apps/living-wallpapers/device-campaign.md`) with rows ZG-D1 to ZG-D8 of clarification Q5, each with devices
  (D1, D2, D3), procedure, threshold and "pending device campaign"; no number claimed; D3 stays on iPadOS 26.5; list
  it in `docs/apps/digital-zen-garden/README.md` (FR-A20-505, 506; SC-A20-503)

## Phase 5: Records and evidence

- [ ] T-A20-509 Contract: G-QUIET and G-DEVICE closed by "A20-P05" (G-DEVICE as the plan; its rows wait for devices);
  rows whose gaps are all closed become available with evidence (`--name contract`, `check_app_contract.py --app
  digital-zen-garden --render`)
- [ ] T-A20-510 Tests (review checkpoint): Digital Zen Garden on sim-27.2 (`--name zg-ios27`), documented API,
  isolation, core purity, the Photos scan; `xcodegen generate --spec project.yml`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-b3`; runner (`--name
  verify-27`); experience packages and script tests; isolation proves no GL call outside the scene protocol
  (FR-A20-501–504; SC-A20-501, 502, 504)
- [ ] T-A20-511 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
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
