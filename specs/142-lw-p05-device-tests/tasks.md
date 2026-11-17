# Tasks: Living Wallpapers — Phase 05 Resolution, colour and heat device tests

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/interface.md](contracts/interface.md), [quickstart.md](quickstart.md). Gate A19-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A19-P05 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
device step. No VisualCore change. Precedent: `specs/135-ac-p05-device-qa/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A19-501 Baseline: cite the A19-P04 evidence (`.autonomy/checks/A19-P04.{lw-ios27,app-unit,verify-27}.json`) on the tree recorded at A19-P04 (`a011b924`), whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A19-P04 evidence cited: .autonomy/checks/A19-P04.lw-ios27.json, A19-P04.app-unit.json and A19-P04.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A19-P04 record commit a011b924

## Phase 2: Story 1 — the export journey in the app (P1) 🎯

- [X] T-A19-502 [P] [US1] Experience: `Packages/ExperiencesCreative/LivingWallpapers/Experience/LaunchOptions.swift` (`exportLimit(from:)` reads `-lwExportLimit <n>`, n a positive integer, else nil; pure and always compiled) and the presenter, under `DEBUG || VISUALCORE_AUTOMATION` only, uses `min(context limit, n)`; `ExperienceTests/LaunchOptionsTests.swift` (parsing, missing, non-positive, the cap) (FR-A19-501) — Verified 2026-11-17: 2026-11-17: LaunchOptions.exportLimit(from:) and cappedLimit(context:arguments:) (pure); the presenter caps its edge limit under DEBUG || VISUALCORE_AUTOMATION only; LaunchOptionsTests (7 tests: value, among arguments, missing, missing value, non-integer, non-positive, the cap); .autonomy/checks/A19-P05.lw-ios27.json exit 0 (iOS 27.2); written by an agent, retested
- [X] T-A19-503 [P] [US1] Interface: `Apps/VisualCore/Tests/UI/LivingWallpapers/{LWSupport,LWExportUITests}.swift` per contracts/interface.md (launched like `ACSupport` with `-vcCandidates`; identifiers `experience.a19.living-wallpapers.<name>`): the iPhone SE export journey (progress ends, message names PNG, 750 × 1334 and sRGB, `share` exists, a history line names iPhone SE); with `-lwExportLimit 1024` and iPhone 16 Pro portrait the notice names 1206 × 2622, 1024 and 470 × 1024, and `export-offered` exports at 470 × 1024; each under 60 s (FR-A19-501; SC-A19-501) — Verified 2026-11-17: 2026-11-17: LWSupport and LWExportUITests: the iPhone SE export journey (Exported PNG, 750 × 1334 pixels, sRGB; share; history-0 names iPhone SE) and, with -lwExportLimit 1024, the iPhone 16 Pro notice (1206 × 2622, 1024, 470 × 1024) and the offered export; .autonomy/checks/A19-P05.app-ui.json exit 0 (iOS 27.2 phone, chunk a3; 28 s and 30 s); written by an agent, retested

## Phase 3: Story 2 — no claim on any screen (P1)

- [X] T-A19-504 [US2] Interface: `Apps/VisualCore/Tests/UI/LivingWallpapers/LWClaimsUITests.swift`: collect the static texts and button labels of the experience and of its help sheet; none of the refused phrases (case-insensitive); the help contains "You set the wallpaper yourself" (FR-A19-502; SC-A19-502) — Verified 2026-11-17: 2026-11-17: LWClaimsUITests, two journeys (the editor with the notice and its help; the screen after an export and the result's help): no refused phrase in any collected text, and the help says You set the wallpaper yourself; .autonomy/checks/A19-P05.app-ui.json exit 0 (35 s and 39 s; a single journey took 64 s and was split by the lead)
- [X] T-A19-505 Add the serial chunk `"a3": ["LWExportUITests", "LWClaimsUITests"]` to `scripts/release_check.py` and to `SERIAL_CHUNKS` (lead) — Verified 2026-11-17: 2026-11-17: scripts/release_check.py serial chunk a3 = LWExportUITests, LWClaimsUITests, added to SERIAL_CHUNKS; scripts/test_scripts.py exit 0

## Phase 4: Story 3 — the campaign plan (P2)

- [X] T-A19-506 [P] [US3] Write `docs/apps/living-wallpapers/device-campaign.md` with rows LW-D1 to LW-D8 of clarification Q3, each with device (D1, D2, D3), procedure, threshold and "pending device campaign"; no number claimed; D3 stays on iPadOS 26.5 (FR-A19-503, 504; SC-A19-503) — Verified 2026-11-17: 2026-11-17: docs/apps/living-wallpapers/device-campaign.md rows LW-D1 to LW-D8, each with device (D1, D2, D3), procedure, threshold and pending device campaign; no measured number; facts checked in code (ExportGeometry 8192 and 64,000,000, templates, the add-only usage string); validate_docs exit 0; written by an agent, reviewed

## Phase 5: Records and evidence

- [ ] T-A19-507 Contract: G-DEVICE closed by "A19-P05" (the plan; its rows wait for devices); rows whose gaps are all closed become available with evidence (`--name contract`)
- [ ] T-A19-508 Tests: Living Wallpapers on sim-27.2 (`--name lw-ios27`), documented API, isolation, the scans; app build, unit and interface (`xcodegen generate --spec project.yml`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-a3`); runner (`--name verify-27`); packages and script tests; the isolation check and the scans prove no GL, wallpaper or Photos library call in the experience (FR-A19-505; SC-A19-501, 504)
- [ ] T-A19-509 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A19-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

501 → {502, 503, 506} → 504 → 505 → 507 → 508 → 509. 502 (experience), 503/504 (interface) and 506 (document) are
separate files.

## Parallel examples

Agent E: T-A19-502. Agent U: T-A19-503, 504. Agent D: T-A19-506. Lead: release_check.py (505), contract, runs,
commits.

## Implementation strategy

MVP: the export journey in the interface (502, 503). The claims test (504, 505) closes the regression fixture; the
plan (506) closes G-DEVICE. Review checkpoint at 508.
