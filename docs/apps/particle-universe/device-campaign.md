# Particle Universe — device campaign plan

**Status: nothing measured on a device.** Every row below is pending. Feature 038 (A04-P06), FR-A04-632, task
T-A04-622 ({device}). Particle Universe (`a04.particle-universe`) is measured as a row of the one VisualCore app's
device campaign (Auto-Creator.md section 23), not as a separate app. Simulator results, including the `PROFILE:` line
of `ParticleProfileTests` (A04-P05), are development signals only and never device evidence.

## When and in which order

1. Not before the gate `ImplementationLock-100` is recorded: `python3 scripts/migration_ledger.py guard-device` must
   exit 0. No install, launch or test of the app on a physical device happens earlier.
2. The owner has provisioned signing, paired, trusted and unlocked the devices (owner steps; otherwise the row is
   `BLOCKED_OWNER_ACTION`).
3. Order: **D1** (iPhone 15), then **D2** (iPad Pro 13-inch M5), then **D3** (iPad A16). **D3 stays on iPadOS 26.5
   and is never updated**; if it reports another version, its campaign is blocked and the owner is told.
4. The runner of the campaign, `scripts/run_device_campaign.py`, is planned for UA-F13 (Auto-Creator.md 23.3) and does
   not exist yet. Hardware identifiers go only to untracked private files.

## What each device records for Particle Universe

| Measurement | What is recorded | Source in the code |
|---|---|---|
| Frame pacing | Frame intervals of the drawn frames at the default scene and with the most emitters, first-run and warm runs separate, at least 200 samples per device | `PerformanceRecord.pacing` (VisualCoreDiagnostics, written by `ExperienceSession.makeRecord`); budgets row "Particle Universe frame-time detail" in `docs/performance/budgets.md` (status: proposal) |
| Drawn-detail steps under load | Each detail tier change and its cause: frame time (`FrameBudgetMonitor`: step down when more than a quarter of the last 120 recorded frames exceed 1.2× the budget, step up when at least 95% of the last 600 stay under 0.8×), heat or Low Power Mode (the host's ceiling wins) | `PerformanceRecord.qualityLevel`, `stepsDown`, `stepsUp`; `ParticleUniverse/Core/FrameBudgetMonitor.swift`, `ParticleUniverse/Experience/ParticlePresenter.swift` |
| Thermal behaviour | The thermal state over the run and the drawn detail it forced; the simulation itself is never thinned | `PerformanceRecord.thermal`, `lowPower`; `DeviceConditions` (VisualCoreDiagnostics) through `DeviceConditionsSource.swift` |
| Memory | Resident memory and the render resources of the session (`ResourceRegistry` counts) while playing, after saving and opening scenes, and after leaving the experience | `PerformanceRecord.memoryFootprintBytes`, `gpuBytes`, `gpuPeakBytes`, `memoryEvents`; `ResourceRegistry` |
| Launch | Time from opening the experience to its first drawn frame, first-run and warm runs separate | `PerformanceRecord.launchMs`, `firstPresentMs`, `firstLaunch` |
| Accessibility system audits | `PUAccessibilityAuditUITests.testAuditDefaultTextSize` and `testAuditLargestAccessibilityTextSize`, run with `VC_RUN_AUDITS=1` (`AppUITestSupport.swift`; deferred to the devices by owner ruling of 2026-11-13) | `Apps/VisualCore/Tests/UI/ParticleUniverse/PUAccessibilityAuditUITests.swift` |
| Persistence and lifecycle | Saved scenes survive relaunch; pause and resume; the container inventory holds only `scene-<uuid>.json` files and the app's `state.json` in the experience's folder | [privacy-and-credits.md](privacy-and-credits.md) |

Each row is recorded pass, fail or `BLOCKED_OWNER_ACTION`; skipped is never success. No measured value of Particle
Universe's speed, timing, heat or memory appears in any document or store text until a device row records it.

## Links

- Release checklist: [release-checklist.md](release-checklist.md) (rows with status `pending-campaign-ii`).
- Known limitations: [known-limitations.md](../../release/known-limitations.md), section "Particle Universe".
- Build and owner steps: [build-and-archive.md](../../release/build-and-archive.md).
