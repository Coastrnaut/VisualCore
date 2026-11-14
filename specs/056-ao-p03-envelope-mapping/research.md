# Research: A07-P03 (feature 056)

## 0. Verified facts (2026-11-14)

- `FeatureExtractor` gives 16 `bandEnergies`, `flux`, `onset` per frame; `AudioMapper` smooths one feature into a range.
- `JourneyState` schema 2: world, distance, speedChoice (2/4/7), speed, seed, paused, source. `TunnelResponse` gives
  bounded, step-limited ripple and ambient with Reduce Motion/Flashing halving.
- `RailFlight.advance(by:limits:)` takes `ComfortLimits`; scaling `maxAcceleration` implements easing.

## 1. Decisions

- **D1 Envelope in Core:** pure function of plain arrays and flags, running-peak normalisation (decay 0.5 s), attack
  0.03 s / release 0.3 s smoothing, onset floor 0.8 on transient. Alternative: four `AudioMapper`s (would need audio
  imports in Core and give no running-peak normalisation).
- **D2 Continuous speed:** speedTarget replaces speedChoice; `speed.select` presets kept for scenarios and quick taps.
- **D3 Easing:** acceleration × 0.33 / 0.66 / 1.0. Alternative: easing curves (not needed; trapezoidal ramp is gentle).
- **D4 WorldResponse:** one type for all worlds, parameterised by the world's primary range; TunnelResponse becomes
  the tunnel's case (kept source-compatible).
- **D5 Calm motion:** persisted toggle OR system Reduce Motion selects `ComfortLimits.reducedMotion`.
