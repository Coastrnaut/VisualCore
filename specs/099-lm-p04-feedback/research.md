# Research: A13-P04 (feature 099)

## D1 — Hint from the recorded solution
- **Decision**: the hint is the first turnable tile whose orientation differs from the level's recorded solution
  (clarification Q1); following hints reaches the solution in at most as many hints as tiles differ.
- **Rationale**: every level records a verified solution (A13-P01, proven in A13-P03); no search is needed until the
  solver (A13-P05).
- **Alternatives**: a search from the current board (rejected: that is G-SOLVER's job); revealing the whole solution
  (rejected by the negative requirements).

## D2 — Hint as an engine action
- **Decision**: `hint.show` in the engine changes only the selection and is replayable; refused `a13.already-solved`.
- **Alternatives**: presenter-only hint (rejected: not replayable, no native-action parity with the runner).

## D3 — Success cue detection
- **Decision**: reuse A13-P03's solve-transition detection in the presenter (drawn frame solved after unsolved).
- **Alternatives**: engine-side event (rejected: the engine has no presentation clock; the cue must not change digests).

## D4 — Sound and haptic routes
- **Decision**: a small `MazeSoundSink` protocol with a default over `SoundEffectPlayer` (as Neon Arcade's
  `ArcadeSoundSink`), and `ExperienceFeedback.haptic(.success)` for the haptic (person's switch, rate limit). Tests pass
  a recording sink and a feedback route with a recording haptic sink.

## D5 — Border brightness
- **Decision**: `SuccessCue.brightness(elapsed:reduceMotion:reduceFlashing:)` = 1 + 0.5·sin(π·t/0.6) for 0 ≤ t < 0.6
  s, otherwise 1; exactly 1 under Reduce Flashing; under Reduce Motion also 1 (static border). One rise and fall, so
  no repetition (well under three changes a second).

## D6 — Signs and contrast
- **Decision**: nine `StateSign`s in `MazeStyle` (clarification Q4) checked by `stateSignProblems`; contrast of each
  state colour composited over the board colour against the board colour ≥ 3 : 1 via `contrastRatio` in an experience
  test (UIKit on the simulator). The unlit target colour rises from (0.62, 0.16, 0.18) to a brighter red meeting 3 : 1.

## D7 — Description bound
- **Decision**: text grouped by tile kind and beam branch (clarification Q5); a test builds a 12 × 12 board with 144
  tiles and a beam at the caps and checks ≤ 4,000 characters.
