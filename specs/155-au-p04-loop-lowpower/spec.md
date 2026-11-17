# Feature Specification: Aurora — Phase 04 Audio and low-power experience

**Feature Branch**: `155-au-p04-loop-lowpower` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A21-P04 (legacy ledger) · ID namespace FR-A21-4##, SC-A21-4##, T-A21-4##

**Input**: User description: archived manual `apps/21-aurora.md` §9 Phase 04 `/speckit-specify` prompt (verbatim in
the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: a low-power static view and a reduced-flash mode;
  - regression fixture: repeated theme (preset) changes release GPU targets;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:**
  - G-LOOP, in VisualCore (VisualCoreAudio): an ambient loop player, with `///` documentation, tests, the API
    baseline update and the seven-step ProjectM reference regression in two chunks (CLAUDE.md rule 13);
  - G-LOWPOWER, in the experience: the low-power still view, the reduced-flash mode, the static fallback frame and the
    release of GPU targets on preset changes.
- **Aurora stays a candidate.** The experience does not play the loop yet (its control comes in A21-P05). Follow
  `specs/148-zg-p04-library-a11y` and, for the audio change, A10-P03's `SoundEffectPlayer` (feature 077).

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `SoundEffectPlayer` (VisualCoreAudio) runs an `AVAudioEngine` with `AVAudioPlayerNode` voices on the `.ambient`
  session, starts lazily, schedules each buffer once, observes the interruption, media-services reset and
  `didEnterBackground` notifications on an injected `NotificationCenter`, and has an injected output for tests.
  `SoundEffectSynth` (VisualCoreAudioDSP) renders bounded one-shot effects of at most 1 s.
- `ResourceRegistry.stats` (VisualCoreRendering) reports live counts and bytes of textures, buffers and render
  targets; `CachedScene` reuses one drawn picture until its key changes; `RenderCapabilities.fragmentHighp` reports
  high fragment precision.
- The public API baseline is `docs/api/visualcore-public-api.txt`, checked by `scripts/check_public_api.py` and
  rewritten deliberately with `--update`; VisualCoreRendering's README lists each module's public types.

- Q: What does VisualCore gain for the loop, and where? → A: Two public types, each with `///` documentation and
  tests:
  - `AmbientLoopRecipe` and `AmbientLoopSynth` in VisualCoreAudioDSP: a loop of a whole number of seconds (4…16,
    default 8) at 48 kHz built from up to six sine partials, each with a whole number of cycles per loop, and a slow
    amplitude swell with a whole number of cycles per loop, so the end meets the start exactly; peak gain at most 0.3;
    deterministic for the same recipe; finite.
  - `AmbientLoopPlayer` in VisualCoreAudio: plays one recipe's buffer looped on an `AVAudioPlayerNode` of its own
    engine on the `.ambient` session, `volume` clamped to 0…1 (a non-finite value ignored), `isEnabled`, `play()`,
    `stop()`, stopped on interruption, media-services reset and backgrounding (as `SoundEffectPlayer`), with an
    injected output and notification center for tests. No microphone and no permission.
- Q: How is the reduced-flash mode defined and measured? → A: On (by its control or the system's Reduce Flashing), the
  twinkle amplitude is 0 and the change between skies takes 4.0 s instead of 2.0 s; the frame-to-frame change in mean
  luminance (Rec. 709 of the sRGB-decoded pixels) stays under 0.02 of full scale, measured off screen at 30 frames
  per second, including during a change between skies.
- Q: What is the still view? → A: A "Still sky" control (presentation only, not saved in 0.1) wraps the sky in a
  `CachedScene` whose key is the state digest and the size: the sky is drawn once and reused until a change; the
  clock does not advance while it is on. The person's limit applies. A change between skies in the still view
  completes, then holds.
- Q: What is the fallback when the shader cannot run? → A: When `aurora-sky.frag` fails to compile or
  `RenderCapabilities.fragmentHighp` is false, the experience draws a minimal gradient shader (the preset's sky colour
  to a darker horizon, under the limit) and shows "This device shows a simpler sky." If even that fails, the host's
  clear colour (the sky colour) remains; never grey. A test seam forces each path.
- Q: How is the release of GPU targets measured? → A: `ResourceRegistry.stats` bytes after the first drawn frame are
  the baseline; after ten preset changes, each finished, the live bytes of textures, buffers and render targets equal
  the baseline.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A still sky that saves power (Priority: P1) 🎯

A person who wants the screen to stay calm and cheap can switch to a still view: the sky is drawn once and held, and
nothing is redrawn until the person changes something.

**Why this priority**: the manual's version 0.1 feature 04 and risk 1 (battery).

**Independent Test**: turn the still view on; count how often the sky is drawn over many frames; change a control.

**Acceptance Scenarios**:

1. **Given** the still view, **When** many frames pass without a change, **Then** the sky is drawn once.
2. **Given** the still view, **When** a control changes, **Then** the sky is drawn once more and held again.

---

### User Story 2 - Nothing flashes (Priority: P1)

With the reduced-flash mode on (or the system's Reduce Flashing), the brightness of the sky changes only slowly from
frame to frame, even during a change between skies.

**Why this priority**: the manual's version 0.1 feature 04 and risk 2.

**Independent Test**: turn reduced flash on; measure the change in mean brightness between consecutive frames, also
during a change between skies.

**Acceptance Scenarios**:

1. **Given** reduced flash on, **When** consecutive frames are read, **Then** the change in mean brightness stays under
   the declared step.

---

### User Story 3 - The sky never shows a broken grey screen, and changing skies leaks nothing (Priority: P1)

When the device cannot draw the sky's shader, a calm still sky appears instead of a grey screen. Changing skies
many times leaves the GPU memory where it started.

**Why this priority**: the manual's regression fixture and its fallback rule.

**Independent Test**: force a shader failure; change presets many times and read the memory held.

**Acceptance Scenarios**:

1. **Given** a failing shader or a missing precision, **When** the sky is drawn, **Then** the fallback still sky is
   shown with a message.
2. **Given** ten changes between presets, **Then** the bytes held in render targets return to the baseline.

---

### User Story 4 - A sound loop the whole app can use (Priority: P2)

VisualCore can play a quiet, seamless, synthesised loop through the device's ambient sound session, with its own
volume, stopping when the app is interrupted or moves to the background.

**Why this priority**: G-LOOP; the experience uses it in A21-P05.

**Independent Test**: render the loop; check it is seamless and bounded; drive interruption and background events.

**Acceptance Scenarios**:

1. **Given** the loop's buffer, **Then** it is finite, within its gain and continuous at the loop point.
2. **Given** an interruption or a move to the background, **Then** the loop stops; volume stays within 0…1.

### Edge Cases

- **The still view and Reduce Motion together:** the still view wins; the picture is held.
- **A control change in the still view during a change between skies:** the change completes, then the picture holds.
- **The fallback frame and the limit:** the fallback still sky obeys the brightness limit.
- **The loop with the silent switch on:** silent (the ambient session follows the switch).
- **A volume that is not a number:** ignored; the previous volume stays.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A21-401**: The experience MUST offer a still view that draws the sky once and holds it until a change.
- **FR-A21-402**: A reduced-flash mode (also following the system's Reduce Flashing) MUST keep the frame-to-frame
  change in mean brightness under a declared step, including during a change between skies.
- **FR-A21-403**: When the sky's shader cannot be compiled or the device lacks the needed precision, a still fallback
  sky under the limit MUST be shown with a message, never a grey screen.
- **FR-A21-404**: Repeated preset changes MUST return the bytes held in render targets to their baseline.
- **FR-A21-405**: VisualCore MUST provide an ambient loop player: a seamless synthesised buffer, its own volume 0…1, the
  ambient session category, stopped on interruption and in the background, with `///` documentation, tests and the
  API baseline update.
- **FR-A21-406**: The seven-step ProjectM reference regression MUST pass in two chunks after the VisualCore change.
- **FR-A21-407**: The experience MUST NOT play the loop in this phase.

### Key Entities

- **Still view**: a flag; the held picture and its key.
- **Reduced-flash step**: the largest allowed frame-to-frame change in mean brightness.
- **Ambient loop**: its synthesised buffer, volume, state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A21-401**: In the still view the sky is drawn once per change over 100 frames.
- **SC-A21-402**: With reduced flash on, 100% of sampled consecutive frames change mean brightness by less than the
  declared step.
- **SC-A21-403**: 100% of forced failures show the fallback sky; render-target bytes after ten preset changes equal the
  baseline.
- **SC-A21-404**: The loop buffer is continuous at its loop point within a declared tolerance; the reference regression
  passes 7 of 7; each unit test runs under 10 seconds.

## Assumptions

- The loop's sound and its control in the experience come in A21-P05.

## Traceability

| Source | Requirement |
|---|---|
| MVP: low-power static view and reduced-flash mode | FR-A21-401, 402 |
| Regression fixture: repeated theme changes release GPU targets | FR-A21-404, SC-A21-403 |
| Algorithm rule 4: static fallback frame | FR-A21-403 |
| Manual risks 1 and 2 | FR-A21-401, 402 |
| Contract G-LOOP, G-LOWPOWER | FR-A21-401–407 |

## Negative Requirements

- No recording, file or network sound; no microphone; no permission; no availability before X-A21; no second
  renderer.
