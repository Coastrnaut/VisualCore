# Feature Specification: R02-F10 — Spectral color & non-color clue accessibility

**Feature Branch**: `210-spectral-color-non-color-clue-accessibility` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Clarified

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
  Round 2 lock (ImplementationLock-100). **Device-only items:** viewing the three presets and the clue badges on the D1–D3 displays in light and dark
  mode, recorded as rows of the device campaign after ImplementationLock-100. **Owner-only
  items:** none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `Palette` (VisualCoreParameters, no dependencies) holds 2–8 sRGB stops and has
`linear(fromSRGB:)` / `sRGB(fromLinear:)`; `AccessibilityPreferences` (VisualCoreSimulation) has a synthesized
`Codable` and `keys(prefix:)` returning a two-element tuple used by `Apps/VisualCore/App/SettingsView.swift` through
`AccessibilitySettingsSection` (VisualCoreUI, which depends on Parameters and Simulation); `AccessibleColors.contrastRatio`
takes `UIColor`; `StateSign`/`stateSignProblems` live in VisualCoreSimulation; the shader library has `vc/color.glsl`
(sRGB) and `vc/sdf.glsl` (`vc_sdCircle`, `vc_sdBox2`, `vc_sdSegment`, `vc_foldDihedral`).

- Q: Which perceptual colour space carries lightness, hue rotation and colour differences? → A: OKLab and its polar
  form OKLCh (Ottosson 2020, published constants, MIT/public-domain reference code), converted from linear sRGB; the
  difference is the Euclidean OKLab distance (ΔE_OK). Rationale: one matrix pair and a cube root, cheap in a shader,
  near-uniform in hue, no white-point bookkeeping. Rejected: CIELAB/CIEDE2000 (costly, hue bends in blue), HSL (not
  perceptual). Impact: FR-R02F10-001, 002, 005, 009; SC-R02F10-001.
- Q: Which model simulates colour-vision deficiency, at what severity? → A: Machado, Oliveira and Fernandes (2009) 3 × 3
  matrices at severity 1.0 for protanopia, deuteranopia and tritanopia, applied in linear sRGB; achromatopsia replaces
  each colour by its relative luminance Y (Rec. 709 weights) on all three channels; results are clamped to 0…1.
  Rationale: one published matrix per condition, identical on CPU and GPU, rows sum to 1 so greys are kept. Rejected:
  Brettel–Viénot (two half-planes per condition, more branching for the same use). Impact: FR-R02F10-004, 009;
  SC-R02F10-002 (the reference values are the published matrices, checked against independently computed spot values).
- Q: When are two colours "distinguishable", and what are the presets? → A: ΔE_OK ≥ 0.08 under normal vision and under
  each of the four simulated conditions. Three built-in presets of six colours each — `cvd-warm-cool` (blue–orange axis,
  for red–green deficiencies), `cvd-red-cyan` (for tritan), `cvd-lightness` (a lightness ladder that also survives
  achromatopsia) — are constructed in code from OKLCh lightness ladders and hues chosen by this feature, not copied from
  a published palette, and must each pass the check under all five conditions. Rationale: 0.08 is well above the
  just-noticeable OKLab difference (about 0.02) for small coded marks; six colours fit a lightness ladder with that
  step. Impact: FR-R02F10-005, 006; SC-R02F10-003.
- Q: Where do the pieces live and how is the preference stored? → A: the pure colour science (`PerceptualColor`,
  `ColorVisionCondition`, palette check, presets, `CodedState`/`CodedStateSet`, `ClueShape`, `CluePattern`) goes in
  VisualCoreParameters beside `Palette`; the preference `colorVision: ColorVisionChoice` (`standard`, `warmCool`,
  `redCyan`, `lightness`) is added to `AccessibilityPreferences` in VisualCoreSimulation with a hand-written decoder
  (`decodeIfPresent`, unknown → `standard`), a new key `<prefix>.colorVision` from a new `colorVisionKey(prefix:)` (the
  two-element `keys(prefix:)` stays unchanged), and load/save extended; `AccessibilitySettingsSection` gains a picker
  and VisualCoreUI maps the choice to its preset; shapes and patterns are drawn by a new `vc/clue.glsl` built on
  `vc/sdf.glsl`, conversions by a new `vc/spectral.glsl`. Rationale: no new module dependency; old stored files and
  `@AppStorage` users keep working. Impact: FR-R02F10-007, 008, 009, 010; SC-R02F10-005.
- Q: What are the limits, the gamut rule and the failure reports? → A: eight shapes (circle, square, triangle, diamond,
  hexagon, plus, ring, star) × four patterns (solid, stripes, dots, crosshatch) = at most 32 coded states per set;
  names are 1…40 characters after trimming; out-of-gamut OKLCh results are brought back by bisecting chroma at
  constant lightness and hue (24 steps) until every linear channel is in 0…1. Failures throw `ColorAccessError` whose
  stable `reasonCode` is one of `r2-f10.non-finite`, `r2-f10.out-of-range`, `r2-f10.same-clue`, `r2-f10.empty-name`,
  `r2-f10.duplicate-name`, `r2-f10.too-many-states`, `r2-f10.duplicate-id`, each naming the offending index or ids.
  Shader–CPU tolerance is 2/255 per channel. Rationale: closed sets keep the clues learnable and drawable in code; the
  reason codes carry the feature id as the archived observability item asks. Impact: FR-R02F10-002, 007, 011;
  SC-R02F10-004, 005.

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
   shape and pattern within 2/255, and its spoken text is its name.

### User Story 2 - Colours stay apart for every common colour vision (Priority: P1)

The engineer picks a palette for coded states. The palette is checked under simulated protanopia, deuteranopia,
tritanopia and full colour blindness; colours that would merge for any of them are reported, and built-in presets are
offered that stay apart for each.

**Why this priority**: shapes carry the meaning, but colours that also stay apart make the game faster to read.

**Independent Test**: the simulation of each deficiency matches published reference values; the built-in presets pass
the separation check for every deficiency; a red–green pair is reported under protanopia.

**Acceptance Scenarios**:

1. **Given** a colour and a deficiency, **When** it is simulated, **Then** the result matches the reference values within
   1e-6, and a neutral grey is unchanged.
2. **Given** a palette, **When** it is checked, **Then** every pair whose ΔE_OK falls below 0.08 under normal vision or any
   deficiency is reported with the pair and the deficiency.
3. **Given** a built-in preset, **When** it is checked, **Then** no pair is reported.

### User Story 3 - Hue and brightness change without breaking contrast (Priority: P2)

The engineer of Hue Compass rotates hues and dims colours over time. Hue rotation keeps perceived lightness, brightness
is compared perceptually, and a contrast ratio can be computed for any two colours, not only interface colours.

**Independent Test**: a rotation by 360° returns the colour; a rotation keeps the perceptual lightness within 1e-9; the CPU and shader results agree on the simulator; the contrast of black and white is 21.

**Acceptance Scenarios**:

1. **Given** a colour and an angle, **When** its hue is rotated, **Then** its perceptual lightness is kept and an
   out-of-gamut result is brought back into the displayable range by bisecting chroma at constant lightness and hue.
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
- **A hue rotation leaving the displayable range:** brought back by chroma bisection, never clipped per channel silently.
- **A name that is empty or only spaces:** refused.
- **Older stored preferences:** opened with defaults for new fields.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F10-001**: Colours MUST convert between sRGB, linear light, OKLab and OKLCh as pure functions with a CPU
  reference, round-tripping within 1e-9; ΔE_OK is the Euclidean OKLab distance.
- **FR-R02F10-002**: Hue rotation MUST keep perceptual lightness, leave greys unchanged, return the colour after a full
  turn, and bring an out-of-range result back into the displayable range by bisecting chroma at constant lightness and hue (24 steps).
- **FR-R02F10-003**: Relative luminance, perceptual lightness and the WCAG contrast ratio MUST be available for any two
  colours as pure functions; the existing interface contrast function MUST give the same values as before.
- **FR-R02F10-004**: Protanopia, deuteranopia and tritanopia MUST be simulated with the Machado et al. (2009) matrices at
  severity 1.0 in linear light, achromatopsia by relative luminance, with a CPU reference; neutral greys are unchanged.
- **FR-R02F10-005**: A palette check MUST report every pair of colours whose ΔE_OK falls below 0.08 under normal vision or any simulated deficiency, naming the pair and the condition.
- **FR-R02F10-006**: Three built-in presets of six colours (`cvd-warm-cool`, `cvd-red-cyan`, `cvd-lightness`),
  constructed in code, MUST pass the palette check for every condition.
- **FR-R02F10-007**: A coded state MUST carry a colour, a drawn shape, a fill pattern and a written name; a set of coded
  states MUST be refused, with named reasons, when two states share both shape and pattern, a name is empty or repeated,
  two ids repeat, or the set exceeds 32 states (8 shapes × 4 patterns); names are 1…40 characters after trimming.
- **FR-R02F10-008**: Each shape and pattern MUST be drawable in code on the existing renderer (signed distance in the
  shader library) with a CPU reference, and the drawn coverage MUST match it within 2/255; the spoken text
  of a drawn clue MUST be its name.
- **FR-R02F10-009**: The shader library MUST offer the perceptual conversions, the hue rotation and the deficiency
  simulation, matching the CPU references within 2/255, compiled on the real ANGLE-backed context of both
  simulator runtimes.
- **FR-R02F10-010**: A colour-vision preference (`standard`, `warmCool`, `redCyan`, `lightness`) MUST be part
  of the stored accessibility preferences, MUST decode older stored files with a default and unknown values as the
  default, and MUST be shown in the common accessibility settings.
- **FR-R02F10-011**: Invalid input (non-finite or out-of-range components, a bad set of states) MUST be refused before
  drawing with a stable `r2-f10.*` reason code naming the offending index or ids.
- **FR-R02F10-013**: A drawn clue MUST carry an outline whose contrast ratio with the state colour and with the
  background it is placed on is at least 3:1 (WCAG non-text contrast); the clue badge and the colour-vision picker MUST
  scale with Dynamic Type up to the largest accessibility size and fit compact iPhone and regular iPad widths without
  truncating the name.
- **FR-R02F10-014**: The sources of the OKLab constants and the Machado et al. matrices, with their licences, MUST be
  cited in the architecture document; the presets and clue shapes are original and the copyright scan finds no image,
  font or icon asset added.
- **FR-R02F10-012**: Existing palettes, sRGB functions, state signs, accessibility preferences and their tests MUST be
  unchanged in behaviour; every new public name carries documentation; the API baseline and the reference regression are
  updated.

### Key Entities

- **Perceptual colour**: lightness, two opponent axes; polar form with chroma and hue.
- **Colour-vision condition**: normal, protanopia, deuteranopia, tritanopia, achromatopsia.
- **Coded state**: id, colour, shape, pattern, name.
- **Clue shape / clue pattern**: eight shapes (circle, square, triangle, diamond, hexagon, plus, ring, star) and four
  patterns (solid, stripes, dots, crosshatch), drawn by signed distance.
- **Colour-vision preset**: a named palette proved distinguishable under every condition.
- **Colour-vision preference**: the player's stored choice.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F10-001**: 1,000 seeded colours round-trip through the perceptual space within 1e-9 per component; hue
  rotation keeps lightness within 1e-9 for in-range results and returns the colour after 360° within 1e-9.
- **SC-R02F10-002**: Simulated deficiencies match the published matrices (checked against independently computed spot
  values) within 1e-6; greys are
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
| Layout and non-text contrast | FR-R02F10-013 |
| Source licence | FR-R02F10-014 |
| No Stage One breakage | FR-R02F10-012 |

## Negative Requirements / Excluded scope

- No second renderer or context; no image files, fonts or icons drawn by hand; no change to existing experiences'
  colours; no recolouring of the whole screen as a filter; no device run before ImplementationLock-100; no analytics.
