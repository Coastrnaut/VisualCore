# Implementation Plan: Audio Odyssey — Phase 05 Long-session performance and accessibility verification

**Branch**: `058-ao-p05-performance-a11y` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-JOURNEYBUDGET in VisualCoreScenes (`StreamingBudget`, `StreamingLevel`) and G-JOURNEYA11Y in the experience
(`JourneyAnnouncer` in Core; presenter announcements through `AnnouncementSink`). Register three quality tiers and apply
the host's level in the presenter (window, fog end, star share) with `forceTierForTesting`. Prove the precision
fixture at 10^9, a 3,600-frame measured run with constant pool and ledger, and persistence across sessions.
Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: VisualCoreScenes for the budget (no new package dependency); VisualCoreUI
already linked. **Storage**: unchanged (snapshot schema 3, preset format 1). **Testing**: host `swift test`
(StreamingBudget; CameraRail at 10^9); ExperiencesCreative on sim-27.2 (announcer, pieces at index 1.25 × 10^8,
presenter tiers, 3,600-frame run, announcements, persistence); app build and unit; runner iOS 27; public API; script
tests. **Constraints**: tests < 10 s (the 3,600-frame run draws offscreen at small size; measured, not wall-clock
asserted); iOS 27 only.

## Constitution Check

I PASS · II PASS (budget generic in VisualCore; announcer wording per experience) · II-a PASS (VisualCore change →
reference regression at X-A07) · III PASS · IV PASS (budget and announcer pure) · V PASS · VI PASS · VII PASS
(announcements only with VoiceOver, throttled; spoken description) · VIII PASS · IX PASS (bounded levels, pool, ledger)
· X PASS · XI–XIII PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/StreamingBudget.swift                                            new
Packages/VisualCore/Tests/VisualCoreScenesTests/StreamingBudgetTests.swift                                    new
Packages/VisualCore/Tests/VisualCoreMathTests/CameraRailTests.swift                                           modify (10^9 case)
Packages/ExperiencesCreative/AudioOdyssey/Core/{JourneyAnnouncer,OdysseyQuality}.swift                         new
Packages/ExperiencesCreative/AudioOdyssey/CoreTests/{JourneyAnnouncerTests,LongDistanceTests}.swift            new
Packages/ExperiencesCreative/AudioOdyssey/Experience/{OdysseyPresenter,AudioOdysseyExperience}.swift           modify
Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/{OdysseyQualityTests,OdysseyLongSessionTests,
  OdysseyAnnouncementTests,OdysseyPersistenceTests}.swift                                                      new
Catalog/registrations.json (quality_tiers level-0/1/2), docs/api, Packages/VisualCore/README.md,
  docs/apps/audio-odyssey/visualcore-contract.json (G-JOURNEYBUDGET, G-JOURNEYA11Y closed)                     modify
```

**Lifecycle**: unchanged; the announcer lives in the presenter and is reset on setup. **Migration**: none.
**Rollback**: revert.

## Parallel work

Agent A: StreamingBudget + tests + CameraRail 10^9 test. Agent B: Core JourneyAnnouncer, OdysseyQuality,
LongDistanceTests. Agent C (after A, B): presenter tiers, announcements, factory, experience tests. Lead:
registrations, docs, baseline, contract, runs, commits.
