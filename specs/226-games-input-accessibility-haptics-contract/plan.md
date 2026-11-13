# Implementation Plan: R02-F26 — Games input, accessibility and haptics contract

**Branch**: spec directory only, work on `main` | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

A shared contract for the 75 games: a deterministic gesture arbiter over the existing recognizers; gesture and native
action sets on the presenter with a check that every gesture action has a native control; pure planners for VoiceOver
announcements and haptics with rate limits; a state-sign check for colour independence; system players for
announcements and haptic feedback behind sink protocols; a haptics switch in Settings stored as an optional shell
preference and handed to the game at launch. Reduce Motion and Reduce Flashing are reused unchanged.

## Technical Context

**Language/Version**: Swift 6.4.2, Xcode 27.2. **Dependencies**: VisualCoreScenes (recognizers, `PointerEvent`,
`PointerTracker`), VisualCoreSimulation (accessibility preferences), VisualCoreUI (system observer, settings section),
VisualCoreExperience (`ShellPreferences`, `ExperienceControl`), VisualCoreExperienceHost (`ExperiencePresenter`, session,
host view), the app (`ExperienceLaunch`, `SettingsView`). Public Apple APIs: `UIImpactFeedbackGenerator`,
`UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator`, `UIAccessibility.post(notification:argument:)`
(all available on iOS 26).
**Storage**: `ShellPreferences.haptics: Bool?` (absent = on), schema 1 unchanged.
**Testing**: pure host tests (`swift test --package-path Packages/VisualCore`), rendering-package tests on sim-27.2 and
sim-26.5 (players with fake sinks, host wiring), the A01–A04 package tests (their action sets), app unit tests and one
short interface test (switch survives relaunch), the reference regression.
**Constraints**: players and planners on the main actor; arbiter pure and `Sendable`; no audits before the device
campaign; tests short.

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Proven renderer | No rendering change | pass |
| II App-neutral API | Generic contract, no game names; documented; baseline updated | pass |
| III GPU lifecycle and threads | No GPU objects; players on the main actor | pass |
| IV Host-testable logic | Arbiter, planners and checks pure and host-tested first | pass |
| V Implementation before devices | Haptic feel and firing are {device} | pass |
| VI Evidence | Planners tested with fake sinks; device items recorded as device-only | pass |
| VII Native, accessible UI | Native switch with label and identifier; announcements; colour independence | pass |
| VIII Public APIs, privacy | Public UIKit only; no permission; one stored switch | pass |
| IX Bounded input | Non-finite positions and extra pointers rejected; bounded queues | pass |
| X Licensing | Code only | pass |
| XI One app | No target change | pass |
| XII One purchase, no ads | Not touched | pass |
| XIII Code-driven visuals | Not touched | pass |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/GestureArbiter.swift                      new
Packages/VisualCore/Tests/VisualCoreScenesTests/GestureArbiterTests.swift               new
Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPlans.swift               new  AnnouncementPlanner, HapticPlanner, StateSign check
Packages/VisualCore/Tests/VisualCoreSimulationTests/AccessibilityPlansTests.swift       new
Packages/VisualCore/Sources/VisualCoreExperience/ShellModel.swift                       modify  ShellPreferences.haptics
Packages/VisualCore/Sources/VisualCoreExperience/GestureAlternatives.swift              new     check over the two action sets
Packages/VisualCoreRendering/Sources/VisualCoreUI/AccessibilityPlayers.swift            new     HapticPlayer, Announcer, sink protocols
Packages/VisualCoreRendering/Tests/VisualCoreUITests/AccessibilityPlayersTests.swift     new  (or the rendering tests target that holds UI tests)
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperiencePresenter.swift modify  gestureActions, nativeActions (default empty)
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceSession.swift   modify  owns players; hands a feedback handle to the experience
Apps/VisualCore/App/ExperienceRegistry.swift, AppModel.swift, SettingsView.swift       modify  haptics in launch and Settings
Apps/VisualCore/Tests/Unit/, Apps/VisualCore/Tests/UI/SettingsUITests.swift             modify  tests
READMEs, docs/api/visualcore-public-api.txt                                              modify
```

## Commands

As in R02-F02: host tests, `xcodebuild_package.py` for VisualCoreRendering and ExperiencesCreative on both runtimes,
`xcodebuild_app.py` for the app's unit test and one interface chunk, `check_public_api.py --update`,
`check_documented_api.py --sources Apps/VisualCore`, the two reference chunks.

## Rollback

Additive; separate commits; `git revert` restores the previous behaviour; the optional preference stays readable.
