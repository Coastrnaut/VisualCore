# Feature Specification: R02-F10 — Spectral color & non-color clue accessibility

**Feature Branch**: `210-spectral-color-non-color-clue-accessibility` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F10 (migration ledger, shared round feature) · ID namespace FR-R02F10-###, SC-R02F10-###, T-R02F10-###

**Input**: User description: the archived R02-F10 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"hue transforms; perceptual luminance; shape encoding; colorblind presets; noncolor status", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/210-spectral-color-non-color-clue-accessibility`; FR-R02F10-###, SC-R02F10-###,
  T-R02F10-###.
- **Section 13 disposition: extend.** The framework has palettes of two to eight sRGB stops sampled in linear light
  (`Palette`), sRGB encode and decode on the CPU and in the shader library, one WCAG contrast ratio that only takes
  interface colours (`AccessibleColors.contrastRatio`), the reduce-motion and reduce-flashing preferences
  (`AccessibilityPreferences`) and a pairing of each colour-coded state with a written sign plus a check that signs are
  present and distinct (`StateSign`, `stateSignProblems`, from R02-F26). It has no perceptual colour space, no hue
  transform, no simulation of colour-vision deficiency, no palette that is proved distinguishable for those viewers, no
  drawn shape or pattern clue and no rule that a colour-coded state must also be readable without colour. This feature
  adds those on the existing modules and the existing renderer; it reuses `Palette`, the sRGB functions, `StateSign` and
  `AccessibilityPreferences` and does not duplicate them.
- **Who the users are:** the player with a colour-vision deficiency, or anyone in poor light, who must tell every
  colour-coded state apart by a shape, a pattern or a word; the player who chooses a colour-vision setting once and sees
  it everywhere; the engineer of Aurora Loom, Hue Compass, Colorfall Canyons or Backwards Aurora, who rotates hues,
  compares brightness and must prove that every rule coded by colour can be read another way.
- **Prerequisites:** R02-F07 (linear-light emissive path) and UA-F02 (common settings) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009: one USD 1.99 unlock); the
  Round 2 lock (ImplementationLock-100). **Device-only items:** viewing the presets on D1–D3 displays. **Owner-only
  items:** none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Colour-coded states are readable without colour (Priority: P1) 🎯

A player who cannot tell red from green plays an experience whose rules are coded by colour. Every coded state also
shows a distinct shape or pattern and has a written name that VoiceOver reads, so no rule depends on colour alone.

**Why this priority**: it is the accessibility promise of the feature; without it a colour-coded game is unplayable
for about one man in twelve.

**Independent Test**: a set of coded states is checked; a set where two states differ only by colour is refused with a
named reason; each accepted state's clue is drawn on the simulator and compared with its CPU reference.

**Acceptance Scenarios**:

1. **Given** a set of coded states each with a colour, a shape, a pattern and a name, **When** it is checked, **Then**
   it is accepted only if every two states differ in shape or pattern and every name is present and unique.
2. **Given** two states with the same shape and pattern, **When** the set is checked, **Then** it is refused naming
   both states and the reason.
3. **Given** an accepted state, **When** its clue is drawn, **Then** the drawn coverage matches the CPU reference of the
   shape and pattern within the stated tolerance, and its spoken text is its name.

### User Story 2 - Colours stay apart for every common colour vision (Priority: P1)

The engineer picks a palette for coded states. The palette is checked under simulated protanopia, deuteranopia,
tritanopia and full colour blindness; colours that would merge for any of them are reported, and built-in presets are
offered that stay apart for each.

**Why this priority**: shapes carry the meaning, but colours that also stay apart make the game faster to read.

**Independent Test**: the simulation of each deficiency matches published reference values; the built-in presets pass
the separation check for every deficiency; a red–green pair is reported under protanopia.

**Acceptance Scenarios**:

1. **Given** a colour and a deficiency, **When** it is simulated, **Then** the result matches the reference values within
   the stated tolerance, and a neutral grey is unchanged.
2. **Given** a palette, **When** it is checked, **Then** every pair whose perceptual difference falls below the stated
   threshold under any deficiency is reported with the pair and the deficiency.
3. **Given** a built-in preset, **When** it is checked, **Then** no pair is reported.

### User Story 3 - Hue and brightness change without breaking contrast (Priority: P2)

The engineer of Hue Compass rotates hues and dims colours over time. Hue rotation keeps perceived lightness, brightness
is compared perceptually, and a contrast ratio can be computed for any two colours, not only interface colours.

**Independent Test**: a rotation by 360° returns the colour; a rotation keeps the perceptual lightness within the stated
tolerance; the CPU and shader results agree on the simulator; the contrast of black and white is 21.

**Acceptance Scenarios**:

1. **Given** a colour and an angle, **When** its hue is rotated, **Then** its perceptual lightness is kept and an
   out-of-gamut result is brought back into the displayable range by a stated rule.
2. **Given** two colours, **When** their contrast ratio is computed, **Then** it equals the WCAG value, and the
   interface-colour function gives the same value as before.

### User Story 4 - One colour-vision setting for the whole app (Priority: P2)

The player chooses a colour-vision setting once in Settings. Every experience that uses coded states reads it, and a
stored settings file written before this feature still opens with the old choices kept.

**Independent Test**: the setting round-trips through storage; a file from before the feature decodes with the new
setting at its default and the reduce-motion and reduce-flashing choices unchanged.

**Acceptance Scenarios**:

1. **Given** a stored preference file without the new setting, **When** it is loaded, **Then** the earlier choices are
   kept and the new setting is its default.
2. **Given** an unknown stored value, **When** it is loaded, **Then** the default is used and nothing fails.

### Edge Cases

- **A non-finite or out-of-range colour component:** refused with a named reason before any conversion.
- **An empty set of coded states, or one state:** accepted (nothing to confuse).
- **More states than distinct shape and pattern pairs:** refused with the limit named.
- **A hue rotation of a grey:** the grey is unchanged.
- **A hue rotation leaving the displayable range:** brought back by the stated rule, never clipped per channel silently.
- **A name that is empty or only spaces:** refused.
- **Older stored preferences:** opened with defaults for new fields.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F10-001**: Colours MUST convert between sRGB, linear light and a perceptual colour space (lightness, two
  opponent axes, and its polar chroma and hue form) as pure functions with a CPU reference, round-tripping within a
  stated tolerance.
- **FR-R02F10-002**: Hue rotation MUST keep perceptual lightness, leave greys unchanged, return the colour after a full
  turn, and bring an out-of-range result back into the displayable range by reducing chroma at constant lightness and hue.
- **FR-R02F10-003**: Relative luminance, perceptual lightness and the WCAG contrast ratio MUST be available for any two
  colours as pure functions; the existing interface contrast function MUST give the same values as before.
- **FR-R02F10-004**: Protanopia, deuteranopia, tritanopia and achromatopsia MUST be simulated by a published model in
  linear light, with a CPU reference; neutral greys are unchanged.
- **FR-R02F10-005**: A palette check MUST report every pair of colours whose perceptual difference falls below a stated
  threshold under normal vision or any simulated deficiency, naming the pair and the condition.
- **FR-R02F10-006**: At least three built-in colour-vision-safe presets of at least six colours MUST exist and MUST pass
  the palette check for every condition.
- **FR-R02F10-007**: A coded state MUST carry a colour, a drawn shape, a fill pattern and a written name; a set of coded
  states MUST be refused, with named reasons, when two states share both shape and pattern, a name is empty or repeated,
  or the set exceeds the number of distinct shape and pattern pairs.
- **FR-R02F10-008**: Each shape and pattern MUST be drawable in code on the existing renderer (signed distance in the
  shader library) with a CPU reference, and the drawn coverage MUST match it within a stated tolerance; the spoken text
  of a drawn clue MUST be its name.
- **FR-R02F10-009**: The shader library MUST offer the perceptual conversions, the hue rotation and the deficiency
  simulation, matching the CPU references within a stated tolerance, compiled on the real ANGLE-backed context of both
  simulator runtimes.
- **FR-R02F10-010**: A colour-vision preference (standard or one of the simulated conditions' safe presets) MUST be part
  of the stored accessibility preferences, MUST decode older stored files with a default and unknown values as the
  default, and MUST be shown in the common accessibility settings.
- **FR-R02F10-011**: Invalid input (non-finite or out-of-range components, a bad set of states) MUST be refused before
  drawing with a stable reason code that names the feature R2-F10.
- **FR-R02F10-012**: Existing palettes, sRGB functions, state signs, accessibility preferences and their tests MUST be
  unchanged in behaviour; every new public name carries documentation; the API baseline and the reference regression are
  updated.

### Key Entities

- **Perceptual colour**: lightness, two opponent axes; polar form with chroma and hue.
- **Colour-vision condition**: normal, protanopia, deuteranopia, tritanopia, achromatopsia.
- **Coded state**: id, colour, shape, pattern, name.
- **Clue shape / clue pattern**: a small closed set drawn by signed distance.
- **Colour-vision preset**: a named palette proved distinguishable under every condition.
- **Colour-vision preference**: the player's stored choice.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F10-001**: 1,000 seeded colours round-trip through the perceptual space within 1e-9 per component; hue
  rotation keeps lightness within 1e-9 for in-range results and returns the colour after 360° within 1e-9.
- **SC-R02F10-002**: Simulated deficiencies match the model's published reference values within 1e-6; greys are
  unchanged within 1e-12.
- **SC-R02F10-003**: Every built-in preset passes the palette check under all five conditions; a classic red–green pair
  is reported under protanopia and deuteranopia.
- **SC-R02F10-004**: Shader and CPU results agree within 2/255 at every sampled pixel for conversions, hue rotation,
  simulation and each clue shape and pattern, on iOS 27.2 and 26.5 simulators.
- **SC-R02F10-005**: At least five positive, negative and boundary fixtures for coded-state sets give their stated
  verdicts and reasons; a stored file from before the feature opens with its choices kept.
- **SC-R02F10-006**: Existing palette, colour, state-sign and preference tests pass unchanged; the reference regression
  passes 7 of 7; each unit test finishes in under 10 seconds.

## Assumptions

- Colours are sRGB with components 0…1; the displayable range is the sRGB gamut.
- The perceptual space and deficiency model are published and freely usable; their constants are cited in the docs.
- Consumers are future round-2 experiences; existing experiences are not changed in this slice.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Hue transforms | FR-R02F10-001, 002, 009 |
| Perceptual luminance | FR-R02F10-001, 003 |
| Shape encoding | FR-R02F10-007, 008 |
| Colourblind presets | FR-R02F10-004, 005, 006, 010 |
| Non-colour status | FR-R02F10-007, 008, 011 |
| Schema migration | FR-R02F10-010 |
| Observability | FR-R02F10-011 |
| No Stage One breakage | FR-R02F10-012 |

## Negative Requirements / Excluded scope

- No second renderer or context; no image files, fonts or icons drawn by hand; no change to existing experiences'
  colours; no recolouring of the whole screen as a filter; no device run before ImplementationLock-100; no analytics.
