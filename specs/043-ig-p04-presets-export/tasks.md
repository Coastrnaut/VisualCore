# Tasks: Infinite Geometry — Phase 04 Scene editing and export

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A05-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No device task. No VisualCore change.

## Phase 1: Setup

- [X] T-A05-401 Baseline: ExperiencesCreative on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name baseline -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P04.baseline.json (ExperiencesCreative sim-27.2, exit 0)

## Phase 2: Foundational

- [ ] T-A05-402 [P] [US1] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryDocumentTests.swift` first, then `Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryDocument.swift` per contracts/api.md (version 1; name "trimmed, ≤ 60, empty → \"Untitled\""; 18-value `openValues` layout with the seed split into two 32-bit halves; `init?(openValues:name:)`) and the atomic `composition.open` action in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift` (all values validated together; out-of-range or non-finite → out of range; camera outside the built composition's bounds → rule; otherwise the whole state replaced; added to the controls list); tests: document from core → open on a changed engine → digest equal, for every preset kind; partial or invalid values refused with the digest unchanged; Codable round trip (FR-A05-401, 402)

## Phase 3: User Story 1 — save and reopen exactly (P1) 🎯

- [ ] T-A05-403 [P] [US1] Write `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryLibrary.swift` (ParticleLibrary pattern: `composition-<uuid>.json` = {document, digest, format: 1, id, saved}, sorted keys; unique names with numeric suffix; unreadable and newer counted, never deleted or rewritten; atomic writes; quota refusal keeps files; last error message) and `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryLibraryTests.swift` (save/list/open/rename/delete; duplicate → "Name 2"; empty → "Untitled"; quota of 64 files refused with files intact; damaged and newer files counted and refused; reload after a new library instance sees every entry) (FR-A05-401, 403–405)

## Phase 4: User Story 2 — still export (P1)

- [ ] T-A05-404 [US2] Write `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryExport.swift` (`size(canvas:maxEdge:)` long edge 2048 capped, canvas aspect, nil for zero size; `png(still:canvas:maxEdge:)` → `GeometryCapture` Transferable with PNG data in memory; no metadata) and add the library section (name field, Save, list with Open/Rename/Delete, unreadable/newer notes, message) and an export section (Export button, ShareLink when ready, message on failure) to `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryControls.swift`; pass the library from `Packages/ExperiencesCreative/InfiniteGeometry/Experience/InfiniteGeometryExperience.swift` (`make` creates it from `storage`); labels and identifiers on every control (FR-A05-410–413, 430, 431)
- [ ] T-A05-405 [US2] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryExportTests.swift` through an `ExperienceSession` (`renderStill`): for each preset kind two exports have identical decoded pixels and the exact size; the export matches the on-screen picture within 2/255 at probes after scaling (render both at the view's pixel size); the digest is unchanged by an export; a zero-size canvas returns nil; an impossible size reports an error and the session keeps running (FR-A05-410–413, SC-A05-403)

## Phase 5: User Story 3 — no leaks over transitions (P2)

- [ ] T-A05-406 [US3] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryGPUStabilityTests.swift`: through a session, cycle all curated presets three times drawing a frame after each change; `renderHost` resource ledger live counts after cycles 2 and 3 equal cycle 1, nothing leaked; open saved documents of every kind twice in turn with the same equality (FR-A05-420, SC-A05-404)
- [ ] T-A05-407 [US1] Regenerate `Packages/ExperiencesCreative/InfiniteGeometry/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`; controls list grew) and record the M17/M18 consumers in `docs/apps/infinite-geometry/visualcore-contract.md` (FR-A05-432)

## Phase 6: Polish & evidence

- [ ] T-A05-408 Experiences package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`)
- [ ] T-A05-409 Experiences package on sim-26.5 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name experiences-ios26 -- … --destination sim-26.5 --action test`)
- [ ] T-A05-410 App build and unit (`xcodegen generate --spec project.yml` first, then `python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A05-411 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27`)
- [ ] T-A05-412 Runner iOS 26 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name verify-26 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 26`) (SC-A05-405)
- [ ] T-A05-413 Public API unchanged (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`)
- [ ] T-A05-414 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P04 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A05-415 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A05-P04

## Dependencies

T-A05-401 → 402 ∥ 403 (403 uses the document API of contracts/api.md) → 404/405 → 406 → 407 → Polish.

## Parallel examples

Agent A: T-A05-402. Agent B: T-A05-403. Agent C: T-A05-404–406. Lead: 407, runs, commits.

## Implementation strategy

MVP: saved compositions (US1) and still export (US2); the stability fixture (US3); evidence last.
