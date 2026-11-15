# Feature Specification: Neon Arcade — Phase 03 Visual effects and audio/haptics

**Feature Branch**: `077-na-p03-effects` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A10-P03 (legacy ledger) · ID namespace FR-A10-3##, SC-A10-3##, T-A10-3##

**Input**: User description: archived manual `apps/10-neon-arcade.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — start/pause/restart/game-over flows with local scores (the run's score
  shown on the game-over screen; the stored high-score table is A10-P04's G-HIGHSCORES); regression fixture — swept
  collision catches high-speed hazards; graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/neon-arcade/visualcore-contract.json`): G-SOUNDFX (VisualCore's audio
  module, upstream: short sound effects synthesized in code and played without recordings or permissions) and
  G-TRANSITIONS (app-local: title, playing, paused and game-over screens and their transitions). The high-speed fixture
  completes the proof G-COLLISION2D named for this phase.
- **Owner rulings:** short tests; iOS 27 at phase gates; reference regression and iOS 26 at X-A10 (this phase changes
  VisualCore: its documentation and published interface record are updated here); every Spec Kit step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`VisualCoreAudio` (rendering package) holds only input sources and depends on the pure `VisualCoreAudioDSP` (core
package, host-testable); the microphone capture sets the session category itself, nothing plays sound; `ParticleSystem`
(seeded, `burst`, `step`, `instances`) and `ParticleRenderer` exist; `HapticKind` (selection, success, warning, error,
impactLight/Medium/Heavy) and `ExperienceFeedback.haptic(_:)` (respecting `hapticsEnabled`) exist;
`transitionDuration(_:reduceMotion:)` returns 0 under Reduce Motion; Neon Arcade has one quality tier.

- Q: Where do the sound effects live and what do they offer? → A: The pure part in `VisualCoreAudioDSP`:
  `SoundEffect` (waveform sine/triangle/square, start and end frequency 40…4,000 Hz, duration 0.02…1 s, attack and
  release ≥ 2 ms, noise 0…1 from a fixed internal generator seeded by the effect, gain 0…0.9) and
  `SoundEffectSynth.render(_:sampleRate:) -> [Float]` (deterministic, finite, |sample| ≤ gain ≤ 0.9, linear fades at
  both ends; invalid effects render silence of zero length). The playing part in `VisualCoreAudio`:
  `SoundEffectPlayer` over the system audio engine with at most 4 voices (a fifth request is dropped), the ambient
  session category (mixes with other audio, silenced by the silent switch, no input, so no permission), `stopAll()`
  on interruption and background, and an `isEnabled` switch.
- Q: How is the flow recorded and driven? → A: `ArcadeState` snapshot schema 3 adds `screen` (title, playing, paused,
  over), `sound` and `haptics` (on by default); migration 2 → 3 derives the screen from the run (over → over, paused →
  paused, otherwise playing) with sound and haptics on. A new experience opens on title. Actions: `run.start` (title →
  playing; over → a new run, playing), `run.pause [0…1]` (playing ↔ paused only), `run.restart` (paused or over → a
  new run, playing), `settings.sound [0…1]`, `settings.haptics [0…1]`; any other combination is refused with
  `a10.wrong-screen`. Only `playing` advances the run.
- Q: Which effects appear, and how are they bounded? → A: Derived by the presenter from the run's new events and wave
  changes since the last drawn state: pickup — a burst of 16 cyan particles at the orb's position (life 0.4 s); hit —
  a red ring expanding from the player for 0.3 s plus 24 particles, and a full-field red tint of alpha 0.25 for 6 steps
  unless reduced flashing, which keeps only the ring; wave start — a horizontal cyan sweep line for 0.5 s. At most 3
  bursts and 2 sounds start per step, one particle pool of 256, advanced by game steps (so pausing freezes them), drawn
  below the collision shapes.
- Q: What do the sounds and haptics sound and feel like? → A: Pickup: sine 880 → 1,320 Hz, 0.12 s, gain 0.5, haptic
  impactLight. Hit: triangle 160 → 60 Hz, 0.25 s, noise 0.3, gain 0.7, haptic impactHeavy. Wave: sine 300 → 600 Hz,
  0.4 s, gain 0.3, haptic selection. Game over: triangle 440 → 220 Hz, 0.5 s, gain 0.5, haptic error. Each effect is
  played only when its setting is on (sound by the player, haptics through the host's feedback route).
- Q: How do screens change, and how is the high-speed fixture expressed? → A: Screens cross-fade over
  `transitionDuration(0.25, reduceMotion:)` (0 under Reduce Motion), presentation only. The high-speed fixture is a
  core test that places a circle hazard above the player with a fall speed of 20, 50 and 100 units/s so that it
  crosses the player within one step (and a copy offset 1.5 units sideways) and checks one hit at that step (and none);
  the manifest's fixture 12 plays a run past its first hit and names the core test as the proof of the speed cases,
  as the manifests already do for properties actions cannot set up.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A game with a beginning, a pause and an end (Priority: P1) 🎯

A person opens Neon Arcade and sees a title screen; starting plays the game; pausing shows a paused screen that resumes
exactly where it was; losing the last life shows a game-over screen with the run's score, the wave reached and a way
to play again.

**Why this priority**: the manual's Phase 03 MVP (version 0.1 feature 03) and gap G-TRANSITIONS.

**Independent Test**: the flow moves only title → playing → paused ↔ playing → game over → playing (restart); the game
advances only while playing; every screen has a spoken description and native controls.

**Acceptance Scenarios**:

1. **Given** the experience opens with no saved game, **When** it appears, **Then** the title screen shows and nothing
   falls until the person starts.
2. **Given** a game in progress, **When** the person pauses, **Then** the paused screen shows, no step changes the game,
   and resuming continues from the same step.
3. **Given** the last life is lost, **When** the step ends, **Then** the game-over screen shows the final score and wave,
   and "play again" starts a new run in wave 1.
4. **Given** Reduce Motion is on, **When** any screen changes, **Then** the change is immediate (no animated
   transition).

---

### User Story 2 - Feedback you can see, hear and feel (Priority: P1)

Collecting an orb gives a short bright burst of particles, a rising chime and a light tap; being hit gives a red flash
ring, a low thud and a stronger tap; a new wave gives a soft sweep — all made by the app itself, never hiding hazards.

**Why this priority**: version 0.1 features 05 and 06 (particles, glow and feedback; sound and haptic toggles) and gap
G-SOUNDFX.

**Acceptance Scenarios**:

1. **Given** an orb pickup, **When** it happens, **Then** a particle burst appears at the orb's place, a pickup sound
   plays (sound on) and a light haptic fires (haptics on).
2. **Given** a hit, **When** it happens, **Then** a hit effect appears around the player, a hit sound plays and a strong
   haptic fires; with reduced flashing the full-field flash is replaced by a non-flashing outline.
3. **Given** effects on screen, **When** the game state is compared with and without effects, **Then** it is identical:
   effects never change the game.
4. **Given** the sound is switched off, **When** events happen, **Then** nothing plays; the same for haptics.

---

### User Story 3 - Fast hazards never pass through (Priority: P1)

A hazard moving much faster than anything in the normal game still hits the player if its path crosses the player
between two steps.

**Why this priority**: the manual's Phase 03 regression fixture and the remaining proof of G-COLLISION2D.

**Acceptance Scenarios**:

1. **Given** a hazard falling 20, 50 or 100 units per second straight through the player's position within one step,
   **When** the step runs, **Then** a hit is recorded at that step.
2. **Given** the same hazard passing beside the player, **When** the step runs, **Then** no hit is recorded.

### Edge Cases

- **Sound when the device is silenced or another app plays audio:** effects follow the system's silent switch and mix
  with other audio; no permission is ever requested.
- **An audio interruption (call, alarm) or backgrounding:** playback stops; nothing is queued for later.
- **Many events in one step:** at most a fixed number of sounds and particle bursts start per step; extra ones are
  dropped, never delayed.
- **Pausing during a burst:** effects freeze with the game; they never advance while paused.
- **Restoring a saved game in the title or game-over screen:** the same screen returns.
- **Quality levels:** Neon Arcade keeps one quality level in this phase; particle budgets by level come with the glow
  caps of A10-P05.

## Requirements *(mandatory)*

### Functional Requirements

**Sound effects (G-SOUNDFX, VisualCore audio)**

- **FR-A10-301**: The shared audio module MUST offer short sound effects described as data (tone, frequency sweep,
  envelope, noise amount, duration ≤ 1 s) rendered into sample buffers deterministically, bounded (no non-finite
  sample, peak below full scale) and click-free (fade in and out).
- **FR-A10-302**: It MUST offer a player that plays such buffers mixed with other audio, follows the silent switch,
  needs no permission, stops on interruption and background, and limits simultaneous voices.
- **FR-A10-303**: The audio module's documentation and published interface record MUST be updated; the reference
  regression is scheduled for X-A10.

**Flow (G-TRANSITIONS, app-local)**

- **FR-A10-310**: The game MUST have the screens title, playing, paused and game over, with only the transitions of
  story 1, recorded in the saved state; the game advances only while playing.
- **FR-A10-311**: Screen changes MUST be animated by presentation only and take no time under Reduce Motion.

**Effects (app-local over VisualCore particles, haptics and the new audio)**

- **FR-A10-320**: Pickups, hits and wave starts MUST produce visual effects, sounds and haptics derived from the game's
  events, capped per step, never changing the game state, with the game's collision shapes always drawn above them.
- **FR-A10-321**: Sound and haptics MUST each have an on/off setting saved with the game; reduced flashing MUST replace
  full-field flashes with non-flashing cues.

**Fixture**

- **FR-A10-330**: A regression fixture MUST prove that hazards at 20, 50 and 100 units per second crossing the player
  within one step are hit, and the same hazards beside the player are not.

### Key Entities

- **Screen**: title, playing, paused, game over.
- **Sound effect**: id, waveform description, duration, gain.
- **Effect event**: kind (pickup, hit, wave), step, position.
- **Settings**: sound on/off, haptics on/off.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A10-301**: 100 % of screen changes follow the allowed transitions; 0 game steps advance outside playing.
- **SC-A10-302**: Every bundled sound effect renders identical buffers twice, with 0 non-finite samples, peak ≤ 0.9,
  first and last 2 ms within 5 % of silence, and duration ≤ 1 s.
- **SC-A10-303**: Playback starts and stops on the iOS 27 simulator with no permission prompt and no recording.
- **SC-A10-304**: Game digests are identical with effects, sounds and haptics on or off.
- **SC-A10-305**: 100 % of high-speed crossings (20, 50, 100 units/s) are hit and 0 % of side passes.
- **SC-A10-306**: The nine standard scenarios and the fixtures pass on iOS 27; each package test finishes in under 10
  seconds.

## Assumptions

- Effect kinds, particle counts, sound shapes, caps and transition times are set in clarification.
- High-score storage, touch sensitivity settings and the full accessibility pass are A10-P04; glow readability caps
  and balance A10-P05.

## Out of Scope

- Music, recorded sounds, voice, a sound mixer screen, high-score tables, achievements.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 03 (start/pause/restart/game-over flows) — Phase 03 MVP | FR-A10-310, 311; story 1 |
| v0.1 feature 05 (particles, glow, feedback constrained by readability) | FR-A10-320; story 2 |
| v0.1 feature 06 (sound/haptic toggles, reduced-flash controls) | FR-A10-301, 302, 321; story 2 |
| Phase 03 regression fixture "swept collision catches high-speed hazards"; manual §11 fixture 3 | FR-A10-330; story 3 |
| Brainstorm: scene transitions | FR-A10-310, 311 |
| Contract gaps G-SOUNDFX, G-TRANSITIONS; G-COLLISION2D's phase-3 proof | FR-A10-301–303, 310, 311, 330 |
| Constitution A10: visuals and sounds are code; readability over effects | FR-A10-301, 320 |

## Negative Requirements

- No recorded, purchased or generated audio files and no artwork; no microphone or any other permission; no network;
  no music licensing; effects never decide hits or change the game; no claims of skill, reflex, cognitive or health
  benefits; no second renderer or context; no ProjectM code.
