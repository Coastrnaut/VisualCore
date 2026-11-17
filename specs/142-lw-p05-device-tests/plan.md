# Implementation Plan: Living Wallpapers — Phase 05 Resolution, colour and heat device tests

**Branch**: `142-lw-p05-device-tests` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-DEVICE with a device-campaign plan (LW-D1 to LW-D8, all pending), and proves A19-P04's export
journey and the no-claims rule in the app's interface: a new serial chunk `a3` with `LWExportUITests` and
`LWClaimsUITests`. A launch argument `-lwExportLimit`, active only in automation builds, makes the fallback notice
reachable on the simulator. No VisualCore change.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/interface.md](contracts/interface.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, XCTest UI tests and Markdown.
- **Testing:**
  - `LivingWallpapersCoreTests` and `LivingWallpapersExperienceTests` on sim-27.2;
  - `release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-a3` on the iOS 27.2 phone;
  - the runner.
- **Constraints:**
  - interface tests take under 60 s each;
  - audits wait for devices;
  - no device install before ImplementationLock-100.

  No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| V | PASS: device rows wait for ImplementationLock-100; nothing runs on a device |
| VI | PASS: no simulator number presented as device evidence |
| IX | PASS: the audits are campaign row LW-D8 (owner ruling of 2026-11-13) |
| A19 platform truth | PASS: the interface texts are scanned for refused claims |

Post-design: PASS.

## Project Structure

```text
docs/apps/living-wallpapers/device-campaign.md                                                        new
Packages/ExperiencesCreative/LivingWallpapers/Experience/{WallpaperPresenter,LaunchOptions}.swift      modify/new  -lwExportLimit
Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/LaunchOptionsTests.swift                 new
Apps/VisualCore/Tests/UI/LivingWallpapers/{LWSupport,LWExportUITests,LWClaimsUITests}.swift            new
scripts/release_check.py (chunk "a3", SERIAL_CHUNKS)                                                   modify
docs/apps/living-wallpapers/visualcore-contract.json (G-DEVICE closed)                                 modify
```

- **Lifecycle:** none new.
- **Migration:** none. **Rollback:** revert the commits.

## Parallel work

- **Agent D:** the campaign plan.
- **Agent E:** the launch option and its unit test.
- **Agent U:** the interface tests.
- **Lead:** release_check.py, the contract, the runs and the commits.
