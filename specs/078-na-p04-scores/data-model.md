# Data Model: A10-P04

- **Sensitivity**: steps 0…4, reaches 2.5, 2.0, 1.5, 1.0, 0.6 units; default 2.
- **HighScoreEntry**: `score` 1…9,999,999, `wave` ≥ 1, `run` ≥ 1.
- **HighScoreTable**: `boardVersion` 1, `entries` (≤ 10, sorted), `lastRun` ≥ 0.
- **ArcadeState** (snapshot schema 4): schema-3 fields + `sensitivity` 0…4 (default 2) + `runNumber` ≥ 1.
- **File**: `high-scores.json` in the experience's storage.
