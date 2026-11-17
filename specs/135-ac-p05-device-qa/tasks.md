# Tasks: Ambient Clock — Phase 05 Overnight device tests and App Store QA

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/qa.md](contracts/qa.md), [quickstart.md](quickstart.md). Gate A18-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A18-P05 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only. No device
action, no audit. Precedent: `specs/134-ac-p04-power-visibility/tasks.md`.

## Phase 1: Setup

- [ ] T-A18-501 Baseline: cite the A18-P04 evidence (`.autonomy/checks/A18-P04.{ac-ios27,app-unit,verify-27}.json`) on the tree recorded at A18-P04, whose Packages are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Foundational — the VisualCore cache (fixture)

- [ ] T-A18-502 Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/CachedScene.swift` per data-model.md ("`init(child:)`, `key`, `passThrough` default true, `childDrawCount`, `invalidate()`; an RGBA8 target of the drawable size, remade on resize, forgotten after a context loss; owns the child") with `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/CachedSceneTests.swift` per contracts/qa.md (120 renders, one draw, identical frames; a key change draws once and equals the child's own frame; resize and repeated setup redraw once; pass-through draws every frame; teardown leaves no GPU object); the row in `Packages/VisualCoreRendering/README.md` and the API baseline (FR-A18-501–503)

## Phase 3: Story 1 — a still clock does almost no work (P1) 🎯 MVP

- [ ] T-A18-503 [US1] Update `Packages/ExperiencesCreative/AmbientClock/Experience/AmbientPresenter.swift`: wrap the crossfade in a `CachedScene`; `isStill` = (no motion or reduced) ∧ ¬seconds ∧ no fade; `stillKey` over theme, palette, tier, night dim and tint, drift step, idle dim and size; `passThrough = !isStill`; `backgroundDrawCount`; and `ExperienceTests/StillWorkTests.swift` (motion off, seconds off: 120 frames at a fixed instant, one background draw and identical frames; a palette change one more; motion on 120; seconds on with motion off is pass-through; a resize redraws once) (FR-A18-501, 502; SC-A18-501, 502)

## Phase 4: Story 2 — the overnight campaign (P1)

- [ ] T-A18-504 [P] [US2] Write `docs/apps/ambient-clock/device-campaign.md` with rows AC-D1 to AC-D10 of clarification Q3, each with device class, procedure, threshold and "pending device campaign"; no number claimed (FR-A18-504, 506; SC-A18-503)

## Phase 5: Story 3 — night and motion from the interface (P2)

- [ ] T-A18-505 [US3] Write `Apps/VisualCore/Tests/UI/AmbientClock/{ACSupport,ACPowerUITests}.swift` (launched like `IASupport`, identifiers `experience.a18.ambient-clock.<name>`: the clock opens with its time label; night mode on and reduce motion on change their values; a relaunch without reset keeps them) and add the serial chunk `"z2": ["ACPowerUITests"]` to `scripts/release_check.py` and `SERIAL_CHUNKS` (lead) (FR-A18-505; SC-A18-504)

## Phase 6: Records and evidence

- [ ] T-A18-506 Contract: G-DEVICE closed by "A18-P05" (the campaign plan; its rows wait for devices); rows whose gaps are all closed become available with evidence (`--name contract`)
- [ ] T-A18-507 Tests: rendering on sim-27.2 (`--name rendering-ios27 -- … --only-testing VisualCoreRenderingTests`), Ambient Clock (`--name ac-ios27`), public and documented API; app build, unit and interface (`--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-z2`), runner (`--name verify-27`), packages, catalog and script tests (SC-A18-504)
- [ ] T-A18-508 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A18-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A18-501 → 502 → 503 → {504 in parallel} → 505 → 506 → 507 → 508.

## Parallel examples

Agent V: T-A18-502. Agent E, after V: T-A18-503. Agent U: T-A18-505 (interface tests). Lead: T-A18-504 (docs),
release_check.py, README, API baseline, contract, runs, commits.

## Implementation strategy

MVP: the cache and the still rule (502, 503). The campaign (504) and the interface tests (505) close the phase. Review
checkpoints after 502 and at 507.
