# Research: A10-P04 Scores and accessibility

Facts verified on 2026-11-14: see spec Clarifications.

## D1 — Sensitivity
- **Decision**: `Sensitivity.reaches = [2.5, 2.0, 1.5, 1.0, 0.6]`, default index 2; `steering(offset:step:)` = clamp
  (offset ÷ reach, −1, 1). The gesture reads the step from the last drawn state.
- **Alternatives**: a continuous slider (harder to test and to label); acceleration curves (later balance).

## D2 — High-score table
- **Decision**: insertion keeps entries sorted by score descending, ties by run ascending; drops beyond 10; refuses
  score ≤ 0, wave < 1, non-finite or duplicate run; `lastRun` records the highest run entered so a run is entered once.
- **Store**: `ExperienceStorage.write` (atomic) of the sorted-key JSON; load decodes and validates; any failure → empty
  table plus `problem` text; the damaged file stays until the next successful write.

## D3 — Interrupted save
- **Decision**: tests write a valid table, then place a partial file under a hidden temporary name and also truncate a
  copy; reading the real name returns the complete table; reading the truncated copy reports damage.

## D4 — Announcements
- **Decision**: `ArcadeAnnouncements.texts(for cues:, run:, newHighScore:)` → texts; the presenter submits them to an
  `AnnouncementPlanner(minimumInterval: 1.0)` and sends the planner's output through `ExperienceFeedback.announce`.

## D5 — UI tests
- **Decision**: `NAArcadeUITests` (4 tests: start and steer, pause and resume, sensitivity, title best score) using
  `NASupport` modelled on `DASupport`; chunk `r2` serial like `q2`.
