# Implementation Plan: Digital Zen Garden — Phase 05 Responsiveness and idle-power QA

**Branch**: `149-zg-p05-quiet-device` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-QUIET with three calm switches (sound, drift, haptics, all off by default and kept as experience
values) and the reduced-motion fixture, proves the garden journeys in the app's interface (serial chunk `b3`), and
closes G-DEVICE with a device-campaign plan (ZG-D1 to ZG-D8, all pending). No VisualCore change.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/quiet.md](contracts/quiet.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI, XCTest UI tests and Markdown.
- **Dependencies:** adds `VisualCoreAudio` and `VisualCoreAudioDSP` to the experience target for `SoundEffectPlayer`
  and procedural tones (Package.swift, lead).
- **Testing:** the A20 package tests on sim-27.2; `release_check.py --only app-build-for-testing-ios27 app-unit-ios27
  app-ui-ios27-b3`; the runner on iOS 27.
- **Constraints:** interface tests under 60 s each; audits wait for devices; no device install before
  ImplementationLock-100. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| V | PASS: device rows wait for ImplementationLock-100; nothing runs on a device |
| VI | PASS: no simulator number presented as device evidence |
| IX | PASS: switches labelled; audits are campaign row ZG-D8 |
| A20 calm by default | PASS: sound, drift and haptics off by default; Reduce Motion forces the drift off; nothing flashes |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                                         modify  VisualCoreAudio, VisualCoreAudioDSP
Packages/ExperiencesCreative/DigitalZenGarden/Experience/{Adapter/GardenCore,SandScene,GardenPresenter,GardenControls}.swift   modify  calm switches, drift, sound, haptics
Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenSounds.swift                         new     procedural tones
Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/{CalmTests,ReducedMotionTests}.swift  new
Apps/VisualCore/Tests/UI/DigitalZenGarden/{ZGSupport,ZGGardenUITests,ZGLibraryUITests}.swift        new
scripts/release_check.py (chunk "b3", SERIAL_CHUNKS)                                                modify
docs/apps/digital-zen-garden/device-campaign.md                                                     new
docs/apps/digital-zen-garden/visualcore-contract.json (G-QUIET, G-DEVICE closed)                   modify
```

- **Lifecycle:** the sound player stops when the experience suspends (its own background rule).
- **Migration:** none; the snapshot is unchanged. **Rollback:** revert the commits.

## Parallel work

- **Agent E:** the calm switches, drift, sounds, haptics and their tests.
- **Agent U:** the interface tests.
- **Agent D:** the campaign plan.
- **Lead:** Package.swift, release_check.py, the contract, the runs and the commits.
