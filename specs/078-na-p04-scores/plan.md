# Implementation Plan: Neon Arcade — Phase 04 Scores and accessibility

**Branch**: `078-na-p04-scores` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-STEERINPUT and G-HIGHSCORES (app-local). Core: `Sensitivity` (five reaches), `HighScoreTable`
(`HighScoreEntry`, insertion with ranking and dedupe by run number, validation, JSON), `ArcadeAnnouncements` (event →
announcement text, collapsed by `AnnouncementPlanner(minimumInterval: 1.0)`). Experience: snapshot schema 4
(`sensitivity`, `runNumber`; migration 3 → 4), action `settings.sensitivity [0…4]`, `ArcadeGestures` uses the chosen
reach, `HighScoreStore` (load/save `high-scores.json` in `ExperienceStorage`, damage reporting), the presenter enters a
finished run once and shows the table on the title and game-over screens, announcements through the host's feedback
route, a sensitivity control; UI tests `Apps/VisualCore/Tests/UI/NeonArcade/` in a new serial chunk `r2`. No VisualCore
change. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A10-P03 plus `VisualCoreExperience.ExperienceStorage` (atomic write),
`VisualCoreSimulation.AnnouncementPlanner`, `VisualCoreExperienceHost.ExperienceFeedback.announce`,
`VisualCoreExperience.GestureAlternatives`. **Storage**: snapshot schema 4; storage file `high-scores.json` (≤ 2 KB).
**Testing**: ExperiencesCreative on sim-27.2; app build and unit; UI chunk `r2` on iOS 27; runner iOS 27; package
check; contract; script tests. **Performance**: the table is read once per open and written once per finished run.
**Constraints**: tests < 10 s (UI < 60 s); iOS 27; audits at the device campaign; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (no context) · II PASS (storage, planner and feedback reused; table, reaches and wording app-local) · II-a PASS
(no VisualCore change) · III PASS (table I/O on the main actor outside the step; never on the render path) · IV PASS
(table, sensitivity and announcements host-tested) · V PASS (schema 4 with 3 → 4 migration; versioned table file with
damage reporting) · VI PASS (render and UI tests on iOS 27) · VII PASS (labels, values, announcements, Dynamic Type,
native alternatives) · VIII PASS (local file only, no personal data, no network, no permission) · IX PASS (≤ 10
entries, ≤ 1 announcement per second) · X–XIII PASS. A10 rules: offline and private, accessibility, truthful — PASS.
Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/NeonArcade/Core/{Sensitivity,HighScoreTable,ArcadeAnnouncements}.swift       new
Packages/ExperiencesCreative/NeonArcade/CoreTests/{SensitivityTests,HighScoreTableTests,
  ArcadeAnnouncementsTests}.swift                                                                         new
Packages/ExperiencesCreative/NeonArcade/Experience/Adapter/{ArcadeCore,ArcadeManifest}.swift            modify
Packages/ExperiencesCreative/NeonArcade/Experience/{ArcadePresenter,ArcadeControls,ArcadeGestures}.swift modify
Packages/ExperiencesCreative/NeonArcade/Experience/HighScoreStore.swift                                  new
Packages/ExperiencesCreative/NeonArcade/ExperienceTests/{HighScoreStoreTests,...}.swift                 new/modify
Apps/VisualCore/Tests/UI/NeonArcade/{NASupport,NAArcadeUITests}.swift                                    new
Apps/VisualCore/App/ExperienceRegistry.swift (schema-3 example), scripts/release_check.py (chunk r2)     modify
docs/apps/neon-arcade/visualcore-contract.json (G-STEERINPUT, G-HIGHSCORES closed)                       modify
```

**Dependency direction** unchanged. **Lifecycle**: `HighScoreStore` is owned by the presenter, loaded in setup from the
launch storage, written when the presenter first sees a finished run whose run number is above the table's last
entered run. **Migration**: snapshot 3 → 4; table board version 1 (newer refused and reported). **Rollback**: revert;
an older build refuses a schema-4 snapshot and opens a new run; `high-scores.json` is ignored by it.

## Parallel work

Agent A: core files + tests. Agent B: experience (schema 4, store, presenter, controls, gestures, manifest) + tests
after A. Agent C: UI tests (independent files). Lead: registry, release_check chunk, regeneration, contract, runs,
commits.
