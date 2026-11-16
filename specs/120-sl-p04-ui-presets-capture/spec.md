# Feature Specification: Simulation Lab — Phase 04 Experiment UI, presets and capture

**Feature Branch**: `120-sl-p04-ui-presets-capture` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A16-P04 (legacy ledger) · ID namespace FR-A16-4##, SC-A16-4##, T-A16-4##

**Input**: User description: archived manual `apps/16-simulation-lab.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — a deterministic tiny CPU reference for each algorithm (built in
  A16-P01, kept and re-asserted here); regression fixture — pause and a one-step advance run exactly one discrete
  iteration in every family, through the controls; graphics context ownership stays solely in the audited VisualCore
  host.
- **Gaps built here** (contract `docs/apps/simulation-lab/visualcore-contract.json`):
  - **G-UI:** the inspector with effective values and ranges; touch seeding and painting mapped to cells, with a control
    alternative; the visible approximation label; the spoken state; the Reduce Motion and Reduce Flashing step-rate rule.
  - **G-LEGEND:** the histogram of the field over fixed bins at a bounded update rate; the legend's spoken range. The
    legend itself exists from A16-P03.
  - **G-PRESETS:** the experiment preset schema, the bundled presets with source and license, and the saved library
    with its cap.
  - **G-CAPTURE:** a PNG of the paused field at an allowed size, handed to the share sheet.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A16; every Spec Kit step runs. Follow `specs/119-sl-p03-rd-wave` and
  `specs/113-me-p04-library`.

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time), with the facts checked
in code:
- `ExperiencePresenter.pointer(_:viewSize:port:)` and `gestureActions` carry touches (`PointerEvent`: id, phase,
  location in points).
- The host gives the controls `@Environment(\.experienceStillRenderer)` (`ExperienceSession.renderStill(width:height:)`
  on the host's own context), and `StillImageEncoder` and `TemporaryFolder` exist (Fractal Explorer's capture).
- `ExperienceStorage` (`write(_:to:)`, `list()`, quota 64 files) and `MigrationChain` exist (Fractal Explorer's bookmarks).
- The scheduler's base rates are 10, 240 and 120 iterations per second, at speeds ×0.25 … ×4.
- `SimulationLabExperience.make` ignores `reduceFlashing` today and opens paused under Reduce Motion.

- Q: What does a tap or drag write, and what is the control alternative? → A: A new action `sim.paint [x, y, mode]`
  (cell column and row 0…63, mode 0 = tap, 1 = drag). It is recorded like every action and never changes the step count.
  - Automaton: a tap toggles the cell; a drag sets it alive.
  - Reaction-diffusion: u = 0.25 and v = 0.5 in the disc of radius 2 cells around it (wrap).
  - Wave: height 1 in the cell and its four neighbours, in both the current and the previous field (no initial
    velocity); edge cells stay 0.

  A drag sends one action per newly entered cell (consecutive duplicates skipped). A tap outside the grid square sends
  nothing. The control alternative is a "Seed" row in the controls: column and row steppers (default the centre,
  32, 32) and a Seed button that sends `sim.paint [x, y, 0]`.
- Q: How is the histogram binned and how often does it update? → A: 16 equal bins over the family's display range:
  - the automaton over 0…1, so dead cells fall in bin 0 and alive cells in bin 15;
  - reaction-diffusion v over 0…1;
  - the wave over −1…1.

  Finite values outside the range fall into the end bins; non-finite cells are counted apart. While running, it is
  computed from the CPU field at most once every 15 frames (4 per second at 60 frames per second), never on every
  step. A non-step change (family, preset, paint, reset, restore, single step) updates it at the next frame. It is
  app-local (`SimulationHistogram`); a VisualCoreSimulation histogram is not added, because there is one consumer.
  The contract records this. The legend overlay draws the 16 bars, and the description adds "most cells in bin k
  (low…high)".
- Q: What is the Reduce Motion and Reduce Flashing step-rate rule? → A:
  - Under Reduce Motion the speed is capped at ×1.
  - Under Reduce Flashing the automaton is capped at ×0.25, which is 2.5 generations per second and stays under three
    flashes per second; the other families are capped at ×1.
  - The presenter refuses a faster `sim.speed` with `a16.reduced-motion` and the sentence "Faster speeds are off while
    Reduce Motion or Reduce Flashing is on.", and the speed picker disables those entries.
  - On activation and on a family change, a speed above the cap is lowered to the cap through `sim.speed`. The
    deterministic core does not know the settings; the runner plays with both settings off.
- Q: What is the preset schema, which presets are bundled and how is the library bounded? → A:
  - The `ExperimentPreset` schema 1 holds name (≤ 60 characters), spec (`SimulationSpec`), palette id (`standard`),
    annotation (≤ 200 characters), source and license.
  - The allowed licenses are `original` and `public-domain`. The six family presets are bundled: Life (Conway 1970),
    HighLife (Thompson 1994), Seeds (Silverman), Spots and Mazes (Pearson 1993 classification of Gray-Scott parameters)
    and Pulse (original). The parameter values are `public-domain` scientific facts, and Pulse is `original`.
  - Saved presets are one file per preset (`preset-<uuid>.json`) in the experience's `ExperienceStorage`, the Fractal Explorer bookmarks pattern, capped at 24. `NamedLibrary` is not used, because it writes to Application Support outside the experience's storage handle; this was corrected at plan.
    Saving at the cap is refused with "The library holds 24 experiments; delete one first."
  - Schema 1 is the first, so "migrate from the previous schema" is met by the `MigrationChain` at version 1: version
    1 passes unchanged, and newer (≥ 2) and damaged files are reported and skipped. A saved preset whose spec is now
    refused is skipped with a problem.
  - Loading a saved preset sends a new action `sim.spec [family, a, b, Δt]`: the family's two parameters (feed and kill,
    speed and damping, or the rule index and 0) and the time step. It is validated by `SimulationSpec.refusal()` and
    starts at step 0 with the same seed, running and speed.
- Q: How is a picture captured and shared? → A: The controls' Capture button renders the field with the host's still
  renderer at 1024 × 1024 pixels and encodes a PNG into the temporary folder `a16-captures`, replacing the previous
  file. A ShareLink offers the file; nothing is written to Photos and no usage string is added.
  - A running simulation is paused by `sim.pause` for the capture and resumed by `sim.run` afterwards, so the field
    and the step count are unchanged.
  - A failure shows "The picture could not be captured. Please try again." and leaves no file.
  - The folder is emptied when the experience opens.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Draw into the field and step it exactly (Priority: P1) 🎯

A person taps the field to seed a cell or drags to paint, sees it change at once, and can do the same without touch
through a control. Paused, one step advances exactly one iteration.

**Why this priority**: the phase's regression fixture and the main interaction of the experiment.

**Independent Test**: pause; tap a cell; read the field; step once; compare with one CPU iteration.

**Acceptance Scenarios**:

1. **Given** any family, paused, **When** a cell is tapped, **Then** exactly that cell changes (the automaton toggles
   it; reaction-diffusion seeds the inhibitor in a small disc; the wave adds a pulse) and the step count does not change.
2. **Given** a drag across cells, **Then** every cell on the path is painted once, and the result equals sending the
   same cells through the control alternative.
3. **Given** a paused family, **When** Step is pressed, **Then** the field equals one CPU iteration of the previous
   field and the step count rises by one.

---

### User Story 2 - Know what the numbers mean (Priority: P1)

A person sees the effective value and range of every parameter of the current family and a label stating the
approximation in use (grid size, precision, boundary), and VoiceOver speaks the state: running or paused, step count
and parameter values.

**Why this priority**: truthful labels are a constitution rule for this experience.

**Independent Test**: open each family; read the inspector, the approximation label and the description.

**Acceptance Scenarios**:

1. **Given** any family, **Then** the inspector lists each parameter with its value, unit and range, and the time step
   with its limit, and the approximation label is visible.

---

### User Story 3 - See the distribution (Priority: P2)

A person sees a histogram of the field's values beside the legend, updated a few times a second while it runs, and
hears the legend's range.

**Why this priority**: the remaining part of the legend gap.

**Independent Test**: run a family; count histogram updates over a fixed number of steps; read the bins.

**Acceptance Scenarios**:

1. **Given** a field, **Then** the histogram has a fixed number of bins whose counts sum to the cell count, with
   non-finite cells counted apart, and it updates at most at the stated rate.

---

### User Story 4 - Keep and reuse experiments (Priority: P2)

A person picks a bundled preset (each with its source and license), saves the current experiment under a name, and
loads it later. The library refuses to grow beyond its cap.

**Why this priority**: the presets gap.

**Independent Test**: save, reload the library from disk, load; fill to the cap; damage a file.

**Acceptance Scenarios**:

1. **Given** a saved experiment, **When** the library is opened in a new session, **Then** it lists the experiment and
   loading it gives the same spec.
2. **Given** a damaged or newer file, **Then** it is reported and skipped; the rest of the library loads.

---

### User Story 5 - Share a picture (Priority: P3)

A person captures the paused field as a picture and shares it through the system share sheet.

**Why this priority**: the capture gap.

**Independent Test**: capture twice; read the folder; force a failure.

**Acceptance Scenarios**:

1. **Given** a paused field, **When** it is captured, **Then** one PNG of the chosen size exists and replaces the
   previous one, and the field and the step count are unchanged.
2. **Given** a failing capture, **Then** a message is shown and no file is left.

### Edge Cases

- **A tap outside the grid square:** nothing changes.
- **Painting while running:** allowed; the painted cells take part in the next iteration.
- **Reduce Motion or Reduce Flashing on:** the speed is lowered to the cap on activation and on a family change; a faster
  choice is refused with its sentence.
- **A saved preset whose spec is now refused** (for example a time step beyond the limit): reported and skipped, not
  loaded.
- **A full library:** saving is refused with "The library holds 24 experiments; delete one first."
- **A capture while running:** the simulation is paused for the capture and resumes afterwards; the field is not
  advanced by the capture.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A16-401**: A tap on the field MUST send `sim.paint [x, y, 0]` and change exactly the cells of the family's brush
  (Clarification Q1). A drag MUST send `sim.paint [x, y, 1]` once per newly entered cell. The Seed row MUST send the
  same action. Painting never changes the step count.
- **FR-A16-402**: Pause and a single step MUST advance exactly one iteration in every family, through the controls.
- **FR-A16-403**: Each algorithm's deterministic tiny CPU reference MUST stay asserted by a fixture.
- **FR-A16-410**: An inspector MUST show every parameter of the current family with value, unit and range, and the
  time step with its limit; an approximation label MUST state grid size, storage precision and boundary, reading
  "Approximation: 64 × 64 cells, exact states (0 or 1), wrap boundary." for the automaton, "Approximation: 64 × 64 cells,
  half-precision values, wrap boundary, explicit Euler step." for reaction-diffusion and "Approximation: 64 × 64 cells,
  half-precision values, fixed zero boundary, leapfrog step." for the wave.
- **FR-A16-411**: The spoken state MUST include running or paused, step count and the parameter values.
- **FR-A16-412**: The speed MUST be capped at ×1 under Reduce Motion, and the automaton at ×0.25 under Reduce
  Flashing. A faster speed MUST be refused with `a16.reduced-motion` and its sentence.
- **FR-A16-420**: A 16-bin histogram over the family's display range MUST count every finite cell into one bin
  (clamped to the end bins), count non-finite cells apart, and update at most once every 15 frames while running.
- **FR-A16-430**: An experiment preset MUST hold a spec, a palette id and an annotation; bundled presets MUST carry a
  source and a license from an allowed set; saved presets MUST round-trip, migrate from the previous schema and refuse
  damaged or newer files without a crash; a saved preset MUST be deletable; the library MUST keep at most 24; loading a saved preset MUST go through `sim.spec`.
- **FR-A16-440**: A capture of the paused field MUST write one 1024 × 1024 PNG into `a16-captures`, replacing the previous one, and
  hand it to the share sheet; a failure MUST show a message and leave no file; capturing MUST NOT change the field or
  the step count.
- **FR-A16-450**: The runner's standard scenarios MUST pass on iOS 27.

### Key Entities

- **Brush**: per family, the cells and values a tap writes.
- **Histogram**: fixed bins over the family's value range, a non-finite count, an update interval.
- **Experiment preset**: name, spec, palette id, annotation; bundled ones with source and license.
- **Preset library**: saved presets on disk, with a cap.
- **Capture**: the latest PNG of the paused field.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A16-401**: In each family, a tap changes exactly the brush's cells, and a paused step equals one CPU iteration
  (100 % of cells).
- **SC-A16-402**: The histogram's counts plus the non-finite count equal 4,096 for every family, and over 60 running
  frames it updates at most 4 times.
- **SC-A16-403**: Saved presets survive a library reload; a damaged and a newer file are each reported and skipped; the
  library holds at most 24, and the 25th save is refused.
- **SC-A16-404**: Two captures leave exactly one PNG of the chosen size; a forced failure leaves none.
- **SC-A16-405**: Every test runs in under 10 s; the runner's standard scenarios pass on iOS 27.

## Assumptions

- VisualCore types are reused with no change: the pointer events and the canvas overlay of the host,
  `ExperienceStorage`, `MigrationChain`, `TemporaryFolder`, `StillImageEncoder`, the host's still renderer. Fractal Explorer's bookmarks
  and capture are the precedent. A FieldGrid histogram in VisualCoreSimulation is assessed and recorded in the
  contract; the default is app-local, because there is one consumer.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 MVP: tiny CPU reference per algorithm | FR-A16-403 |
| Regression fixture: pause and one step = one iteration | FR-A16-402, SC-A16-401 |
| Contract G-UI | FR-A16-401, 410–412 |
| Contract G-LEGEND | FR-A16-420, SC-A16-402 |
| Contract G-PRESETS | FR-A16-430, SC-A16-403 |
| Contract G-CAPTURE | FR-A16-440, SC-A16-404 |
| EGL/context ownership in the host | FR-A16-440 (the capture renders on the host's context) |

## Negative Requirements

- No camera, Photos or file-system permission and no usage string; no network; no accounts; no second renderer or
  context; no VisualCore change unless the contract records it; no images other than the user's own captures; no
  presets of unknown source or license.
