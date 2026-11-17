# Research: A18-P00 (feature 130)

## Facts (verified in code, 2026-11-16)

The facts of the clarification session hold. VisualCore provides shaders, fields, the GLSL library, particles, quality
tiers, persistence (`NamedLibrary` for favourites), contrast, accessibility planners and scene phase. It has no clock
source, time-change observer, GPU text, crossfade, experience-level frame-rate control, keep-awake, night mode or
pixel drift.

## Decisions

- **D1 Scope:** audit only. The one app is the shell.
- **D2 Matrix scope:** the five brainstorm capabilities (shader backgrounds, animation, typography integration, scene
  transitions, configuration and presets) and the six version 0.1 features:
  - locale-aware time;
  - four themes;
  - 12/24-hour typography with seconds;
  - the theme editor with favourites;
  - night mode and motion reduction;
  - foreground, time-zone and daylight-saving updates.

  Cross-cutting rows cover context loss and resize, quality tiers, accessibility, persistence with migration, bounded
  resources, screen care and truthful claims.
- **D3 Availability rule:** clarification 2.
- **D4 Gap owners** (the manual's phases):

  | Gaps | Phase |
  |---|---|
  | The clock model and formatting, time-change handling, and accessibility of the time | A18-P01 |
  | The native clock overlay and one shader theme | A18-P02 |
  | The four themes, the theme editor, favourites and their schema | A18-P03 |
  | Night mode, motion reduction, screen care and keep-awake | A18-P04 |
  | Overnight device tests and QA rows | A18-P05 |
  | Release | A18-P06 |

  Two generic pieces are assessed for VisualCore ownership in their phase:
  - an injectable clock source with time-change observation (G-CLOCK, `VisualCoreExperience`, A18-P01), whose second
    consumer is A14's "Now";
  - a crossfade between full-screen scenes (G-TRANSITION, `VisualCoreRendering`, A18-P03).
- **D5 Permissions:** clarification 4. The keep-awake setting is opt-in and is the first allowed `isIdleTimerDisabled`
  use, in one named file.
- **Alternatives considered:**
  - drawing text in the GPU path (rejected: the canvas overlay with system fonts reuses the host and keeps Dynamic
    Type and VoiceOver);
  - a simulated clock (rejected: constitution, time is the system's).
