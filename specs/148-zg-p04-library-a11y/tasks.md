# Tasks: Digital Zen Garden — Phase 04 Persistence, accessibility and still export

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/library.md](contracts/library.md), [quickstart.md](quickstart.md). Gate A20-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/141-lw-p04-save-share/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A20-401 Baseline: cite the A20-P03 evidence (`.autonomy/checks/A20-P03.{zg-ios27,app-unit,verify-27}.json`) on the tree recorded at A20-P03 (`3fe9ab7a`), whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A20-P03 evidence cited: .autonomy/checks/A20-P03.zg-ios27.json, A20-P03.app-unit.json and A20-P03.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A20-P03 record commit 3fe9ab7a

## Phase 2: Story 1 — named gardens (P1) 🎯

- [X] T-A20-402 [US1] Create `Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenLibrary.swift` per data-model.md ("at most 12 gardens, names 1…40 characters after trimming", `library.json` kind `a20.garden-library` and `garden-<n>.json` kind `a20.saved-garden`, each ≤ 262,144 bytes; save replacing an existing name; rename refusing a used name; delete; damaged, newer and oversized files listed as unreadable with their codes and kept; a failed write keeps the previous file; messages "The library holds 12 gardens." and "A garden is already called <name>."), wire it in `DigitalZenGardenExperience.make` with the launch's `storage`, and open a garden through the shell's restore path so the history restarts; write `ExperienceTests/LibraryTests.swift` over a temporary storage (round trip exact, list, rename, delete, the cap, duplicate names, each refusal, a failed write, opening restarts the history and the digest equals the opened document's) (FR-A20-401, 402; SC-A20-401) — Verified 2026-11-17: 2026-11-17: Experience/GardenLibrary.swift (counter-numbered garden files with an index, 12 gardens, names 1...40 trimmed, replace on an existing name with confirmation, rename refusing a used name, delete, unreadable files listed with their codes and kept, a failed write keeps the previous file, the size refused before writing) wired through the launch's storage; opening restores the document through the shell; ExperienceTests/LibraryTests.swift (10 tests) pass in .autonomy/checks/A20-P04.zg-ios27.json exit 0; written by an agent, retested

## Phase 3: Story 2 — accessibility (P1)

- [X] T-A20-403 [US2] Extend `Packages/ExperiencesCreative/DigitalZenGarden/Experience/{GardenControls,GardenPresenter}.swift`: library and share controls with spoken labels and values; the description names tone, strokes, stones and the selection; `port.announce` for undo, redo, save, open, delete and refusals; one-column stacking at the accessibility text sizes; write `ExperienceTests/AccessibilityTests.swift` (every control labelled; the description; announcements recorded through the port; `ImageRenderer` at `.accessibility5` grows in height and fits the width) (FR-A20-403; SC-A20-403) — Verified 2026-11-17: 2026-11-17: GardenControls (labels and values from one source, library and picture sections, confirmations, one-column stacking at accessibility sizes) and GardenPresenter (description naming tone, strokes, stones and the selection; announcements for undo, redo, save, open, delete and refusals); ExperienceTests/AccessibilityTests.swift (5 tests incl. ImageRenderer at accessibility5) pass in .autonomy/checks/A20-P04.zg-ios27.json exit 0; written by an agent, retested

## Phase 4: Story 3 — bounded history (P1)

- [X] T-A20-404 [US3] Write `Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/BoundedHistoryTests.swift`: 10,000 seeded commands of every kind (strokes of at most 64 points) leave `done.count ≤ 100`, an encoded done + undone under 2,457,600 bytes, a document within its caps and refusals beyond 400 strokes and 24 stones; under 10 s (FR-A20-404; SC-A20-402) — Verified 2026-11-17: 2026-11-17: ExperienceTests/BoundedHistoryTests.swift (10,000 seeded commands through GardenCore actions: done at most 100, encoded history under 2,457,600 bytes checked every 500 commands, caps refused, undo lands on the checkpoint; 2,400 raw points stop at 2,048; 1.24 s) passes in .autonomy/checks/A20-P04.zg-ios27.json exit 0; written by an agent, retested

## Phase 5: Story 4 — share a still (P2)

- [X] T-A20-405 [US4] Create `Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenStill.swift` (1600 × 1200 PNG from `experienceStillRenderer`, one file in `TemporaryFolder("DigitalZenGarden-Still")`, replaced by the next export, removed after a failure) with a `ShareLink` control; write `ExperienceTests/StillTests.swift` (the size and PNG type read back; a second export replaces the first; a failure leaves no file); set the registration's permissions to `["photo-library-add"]` in `Catalog/registrations.json` and rebuild the catalog (lead) (FR-A20-405, 406) — Verified 2026-11-17: 2026-11-17: Experience/GardenStill.swift (1600 x 1200 PNG from the still renderer, one file in TemporaryFolder DigitalZenGarden-Still, replaced, removed after a failure; Transferable file for ShareLink) and ExperienceTests/StillTests.swift (3 tests) pass in .autonomy/checks/A20-P04.zg-ios27.json exit 0; Catalog/registrations.json permissions photo-library-add and the catalog rebuilt; written by an agent, retested

## Phase 6: Records and evidence

- [X] T-A20-406 Digital Zen Garden tests on sim-27.2 (`--name zg-ios27`), documented API, isolation, core purity and a Photos scan (`--name photos-scan -- sh -c '! grep -rnE "import Photos|PhotosUI|PHPhotoLibrary" Packages/ExperiencesCreative/DigitalZenGarden'`) (SC-A20-404) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P04.zg-ios27.json (51 core, 75 experience tests, iOS 27.2), A20-P04.documented-api.json, A20-P04.isolation.json, A20-P04.core-purity.json and A20-P04.photos-scan.json, all exit 0, each read before this tick
- [ ] T-A20-407 Contract: G-LIBRARY and G-A11Y closed by "A20-P04"; rows whose gaps are all closed become available with evidence (`--name contract`)
- [ ] T-A20-408 Catalog, app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit`), release usage descriptions (`--name usage -- python3 scripts/release_check.py --only app-release-build app-usage-descriptions`), runner (`--name verify-27`), packages and script tests
- [ ] T-A20-409 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A20-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

401 → 402 → 403 → 404 → 405 → 406 → 407 → 408 → 409. 402–405 are one experience (one writer); the registration's
permission in 405 is the lead's.

## Parallel examples

Agent E: T-A20-402–405 sources and tests. Lead: registration permission, runs, contract, commits.

## Implementation strategy

MVP: named gardens (402). Accessibility (403) and the bounded history (404) close the gates; the still (405) completes
the phase title. Review checkpoints after 402 and at 406.
