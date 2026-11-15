# Tasks: Neon Arcade — Phase 05 Balance, device QA and storefront

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A10-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A10-P05 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers). iOS 27 only; reference regression and iOS 26 at X-A10; device tasks tagged {device} stay
open until ImplementationLock-100. Precedents: `specs/078-na-p04-scores/tasks.md`, `specs/072-da-p05-ambient/tasks.md`.

## Phase 1: Setup

- [X] T-A10-501 Baseline: cite the A10-P04 evidence on the unchanged tree (`.autonomy/checks/A10-P04.{arcade-ios27,app-ui,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: cited .autonomy/checks/A10-P04.{arcade-ios27,app-ui,verify-27}.json on the unchanged tree (no rerun)

## Phase 2: Foundational — budgets, contrast and balance in the core

- [X] T-A10-502 [P] [US1] Core: new `Packages/ExperiencesCreative/NeonArcade/Core/{ArcadeBudget,Contrast,SimulatedPlayer}.swift` per contracts/api.md, data-model.md and research D1–D3 (`ArcadeBudget.levels = 3` with "glowFactor (1.2, 1.4, 1.6), glowOpacityCap (0.25, 0.30, 0.35), particleCap (48, 128, 256), pulse (false, true, true)"; `Contrast` relative luminance, ratio and compositing; simulated players idle, dodger, collector); tests new `Packages/ExperiencesCreative/NeonArcade/CoreTests/{ArcadeBudgetTests,ContrastTests,BalanceTests}.swift` (caps per level and monotone across levels, glow alpha never above the cap, burst counts ≥ 1 and ≤ cap; contrast of known colour pairs; every catalog item's core vs the field ≥ 4.5 for hazards and ≥ 3 for player and orbs, hazard core vs its glow composited at each level's cap ≥ 3; over 20 seeds and ≤ 6,000 steps: idle median wave ≤ 2, dodger median wave ≥ 3, collector median score > dodger > idle; identical results at 1/30 and 1/60 s pacing); a missed target or ratio is fixed in `Core/{ArcadeCatalog,Difficulty}.swift` and recorded in research.md (FR-A10-501, 502, 510; SC-A10-502, 503) — Verified 2026-11-14: 2026-11-14: ArcadeBudget (3 levels, caps), Contrast (WCAG ratios; spike-ball 5.69 vs field, 3.80 vs glow at 0.35), SimulatedPlayer (idle/dodger/collector); balance over 20 seeds met without tuning (idle wave 2.0, dodger 3.0, collector score 66.5 > 41.5 > 25.5); 117 core tests pass on the host (core targets only)

## Phase 3: Stories 1–3

- [ ] T-A10-503 [US1] Experience: `NeonArcade/Experience/Adapter/ArcadeCore.swift` (`qualityTiers` = `ArcadeBudget.levels`, `setQualityTier` presentation-only, the digest independent of the tier); `NeonArcade/Experience/{ArcadePresenter,ArcadeEffectsLayer,NeonArcadeExperience}.swift` (draw glow and bursts with the level's budget; level 0 under injected Low Power Mode, otherwise the host's tier clamped; reduced flashing removes the pulse; particles above a lowered cap removed oldest first; collision shapes above glow at rule size); `Catalog/registrations.json` a10 `quality_tiers` ["level-0", "level-1", "level-2"]; tests in `NeonArcade/ExperienceTests/{ArcadeRenderTests,ArcadeCoreTests,ArcadeSessionTests}.swift` (per level the drawn glow radius, opacity and live particles within caps; a level change mid-run keeps shapes and digest; Low Power Mode → level 0; reduced flashing → steady glow; declared tiers equal the presenter's levels and the registration) (FR-A10-501–503; SC-A10-501)
- [ ] T-A10-504 [P] [US3] Storefront and device plan: `scripts/build_catalog.py` accepts an optional registration `summary` (string, 1…300 characters) used in place of the design summary, with a test in `scripts/test_scripts.py` (present, absent, too long, not a string); `Catalog/registrations.json` a10 `summary` "Neon Dodge: steer through falling hazards and collect orbs in waves." and capabilities each proved by a named test, listed as a capability → proving-test table in `docs/apps/neon-arcade/README.md` and checked by new `specs/079-na-p05-balance/scan-claims.sh` (every named test exists in the sources; no skill, reflex, cognitive or health words in the catalog entry and README) modelled on `specs/073-da-p06-release/scan-realism.sh`; `python3 scripts/build_catalog.py`; new `docs/apps/neon-arcade/device-campaign.md` per clarification 4 (rows with device, procedure, threshold, status "pending device campaign") linked from `docs/apps/neon-arcade/README.md` (FR-A10-520, 521; SC-A10-504)
- [ ] T-A10-505 [US1] Manifest and contract: `NeonArcade/Experience/Adapter/ArcadeManifest.swift` fixtures 17–19 (the same 600-step run at levels 0, 1, 2 with one digest) and `ArcadeManifestTests`, regenerate `NeonArcade/scenario-manifest.json`; `docs/apps/neon-arcade/visualcore-contract.json` G-GLOWCAPS closed by "A10-P05" (row M11 available); `--name contract -- python3 scripts/check_app_contract.py --app neon-arcade --render` (FR-A10-522)
- [ ] T-A10-506 [US3] {device} Device campaign measurements per `docs/apps/neon-arcade/device-campaign.md` (frame pacing per level on the reference phone and tablet, thermal state over 10 minutes, glow readability in bright light, audio routes, VoiceOver) — runs only after ImplementationLock-100

## Phase 4: Polish & evidence

- [ ] T-A10-507 Arcade tests on sim-27.2 (`--name arcade-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests`; each test < 10 s) (SC-A10-501–503, 505)
- [ ] T-A10-508 App build, unit, UI chunk r2 (`--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-r2`) and runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27`)
- [ ] T-A10-509 Package check, distinctiveness, claims scan and script tests (`--name claims -- bash specs/079-na-p05-balance/scan-claims.sh`; `--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name distinctiveness -- python3 scripts/check_distinctiveness.py`; `--name script-tests -- python3 scripts/test_scripts.py`) (SC-A10-504)
- [ ] T-A10-510 Run `/speckit-converge` and `/speckit-implement` until nothing is appended (T-A10-506 {device} stays open by design); then seal and record A10-P05

## Dependencies

T-A10-501 → 502 → 503 → 505 → Polish; 504 in parallel with 503 (different files). T-A10-506 waits for ImplementationLock-100.

## Parallel examples

Agent A: T-A10-502. Agent B: T-A10-503 after A. Agent C: T-A10-504. Lead: regeneration, contract, runs, commits.

## Implementation strategy

MVP: the per-level caps with readable shapes (US1); then balance (US2) and the storefront and device plan (US3).
