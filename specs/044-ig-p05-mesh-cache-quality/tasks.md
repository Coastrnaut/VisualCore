# Tasks: Infinite Geometry — Phase 05 Mesh, cache and quality regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A05-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No device task (timing in the device campaign).

## Phase 1: Setup

- [X] T-A05-501 Baseline: ExperiencesCreative on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name baseline -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P05.baseline.json (ExperiencesCreative sim-27.2, exit 0)

## Phase 2: Foundational (VisualCore, G-MESHCACHE and G-MESHLOD)

- [X] T-A05-502 [P] [US2] Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshCacheTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreScenes/MeshCache.swift` per contracts/api.md (`Mesh.byteSize`; `MeshCache` "16 entries, 32 MiB" defaults, LRU by use counter, oversize mesh returned not stored, maxEntries 0 stores nothing; hits/misses/evictions); tests: A→B→A one hit two builds; 200 seeded random access sequences against a reference LRU model never exceed limits and evict the same keys; oversize and zero-limit cases (FR-A05-510, 511, 530; SC-A05-503) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P05.visualcore-host.json (MeshCacheTests 9/9)
- [X] T-A05-503 [P] [US1] Write `Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/TessellationChoiceTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreDiagnostics/TessellationChoice.swift` per contracts/api.md ("clamp(round(full × share), minimum…full); non-finite → minimum; budget variant lowers while vertices(segments) > budget, never below minimum"); tests: monotonic in share over a fine grid, bounds, budget variant, non-finite (FR-A05-531) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P05.visualcore-host.json (TessellationChoiceTests 5/5)

## Phase 3: User Story 1 — adaptive tessellation (P1) 🎯

- [ ] T-A05-504 [US1] Add a `segments` parameter (default 24) to the solid build in `Packages/ExperiencesCreative/InfiniteGeometry/Core/Composition.swift` and a cache signature (StableHash of kind, order, repeats, scale, motif seed, segments); in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift` declare `qualityTiers = 4` and `qualityProfile` (Full/High/Medium/Low, element shares 1, ⅔, ½, ⅓), implement `setQualityTier` storing a clamped tier outside the digest and snapshot, and `segments(forTier:)` via `TessellationChoice.segments(full: 24, minimum: 8, share:)`; reference composition stays at 24 (FR-A05-501–505)
- [ ] T-A05-505 [US1] In `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift` draw the solid from a presenter-owned `MeshCache` at the tier's segments (switch at the next frame; renderer rebuilt when the drawn mesh changes; cache kept across context recreation) and expose drawn triangle count and cache counts for tests (FR-A05-506, 510)
- [ ] T-A05-506 [US1] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryQualityTests.swift`: for solid orders 3, 5, 8, 12 the drawn triangles are non-increasing over tiers 0–3 with tier 3 ≤ 50% of tier 0, every tier mesh validates within `MeshBudget.default`; digest identical at every tier for every kind; snapshot bytes identical; through a session `qualityPin` selects the level's tessellation; A→B→A presets at one tier give one cache hit; a tier change between frames switches the drawn mesh; after `recreateContext()` the cached CPU meshes are still hits and the frame draws (SC-A05-501–503)

## Phase 4: User Story 3 — proportions (P2)

- [ ] T-A05-507 [US3] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryProportionTests.swift` at views of 9:19.5, 1:1, 4:3, 19.5:9: kaleidoscope pixel bounding box square within 1 px; tilings' world-to-pixel scale equal in x and y within 1 px at a probe pair; solid's projected bounding sphere extents equal within 1 px; name the multi-aspect check in fixture 5's doc in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryManifest.swift` (FR-A05-520, 540; SC-A05-504)
- [ ] T-A05-508 Regenerate `Packages/ExperiencesCreative/InfiniteGeometry/scenario-manifest.json` if it changes (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) (FR-A05-540)

## Phase 5: Polish & evidence

- [X] T-A05-509 Framework host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name visualcore-host -- swift test --package-path Packages/VisualCore --filter "MeshCacheTests|TessellationChoiceTests"`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P05.visualcore-host.json (exit 0)
- [ ] T-A05-510 Experiences package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`)
- [ ] T-A05-511 Experiences package on sim-26.5 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name experiences-ios26 -- … --destination sim-26.5 --action test`)
- [ ] T-A05-512 App build and unit (`xcodegen generate --spec project.yml` first, then `python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A05-513 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27`)
- [ ] T-A05-514 Runner iOS 26 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name verify-26 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 26`) (SC-A05-505)
- [ ] T-A05-515 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; VisualCore README (MeshCache, TessellationChoice); Auto-Creator.md §13 rows (FR-A05-532)
- [X] T-A05-516 Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A05-P05.reference-1.json (exit 0)
- [X] T-A05-517 Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A05-P05.reference-2.json (exit 0)
- [ ] T-A05-518 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P05 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A05-519 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A05-P05

## Dependencies

T-A05-501 → (502 ∥ 503) → 504 → 505 → 506 ∥ 507 → 508 → Polish.

## Parallel examples

Agent A: T-A05-502. Agent B: T-A05-503. Agent C: T-A05-504–507 (against contracts/api.md). Lead: 508, docs, runs, commits.

## Implementation strategy

MVP: tier tessellation (US1) on the framework parts; cache (US2) through the presenter; proportions (US3); evidence last.
