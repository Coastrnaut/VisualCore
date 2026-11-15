# Research: A13-P03 (feature 098)

## D1 — Progress outside the engine
- **Decision**: progress is a device file owned by the presenter (clarification Q1), so engine replays and the
  runner's fixtures are unaffected; locks are applied where a person chooses a level.
- **Alternatives**: progress inside the engine state (rejected: fixtures for later levels would need every earlier level
  solved first, and the device file would have to be injected outside the replayed actions).

## D2 — Moves in the engine
- **Decision**: moves and undo are engine state and actions (state schema 2), replayable and saved with the session;
  bounded at 64.

## D3 — Store
- **Decision**: `ProgressStore` modelled on `ExperimentStore` (atomic write, read never writes, memory variant).

## D4 — Fixtures
- **Decision**: the five manifest fixtures stay (their digests change because the state gains `moves`); add a fixture
  solving level 1 then undoing the last move (unsolved again) for the undo rule.
