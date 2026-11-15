# Feature Specification: Physics Playground — Phase 04 Saved experiments and tutorials

**Feature Branch**: `085-pp-p04-experiments` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A11-P04 (legacy ledger) · ID namespace FR-A11-4##, SC-A11-4##, T-A11-4##

**Input**: User description: archived manual `apps/11-physics-playground.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — simulation pause, single step, time scale and reset, where reset now
  restores the experiment that was loaded; regression fixture — spring energy has known bounded behaviour in the
  experiments; graphics-context ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/physics-playground/visualcore-contract.json`): G-EXPERIMENTS (presets for a
  pendulum, a spring chain and stacked objects; saved experiments in the experience's own storage), app-local; no
  VisualCore change is planned.
- **Out of this phase:** stability caps and sleeping bodies (A11-P05), release documents (A11-P06), sharing or export
  of experiments.
- **Owner rulings:** short tests; iOS 27 at phase gates; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`ExperienceStorage` offers `write` (atomic), `read`, `exists`, `list` and `remove` per experience; Neon Arcade's
`HighScoreStore` keeps a versioned file there, reports damaged or newer files once and leaves them in place;
`ExperienceShell` offers `snapshot()` and `restore(_:)`; the world is schema 3 with springs (one global stiffness
level), levels, pins, selection, grab and overlays; experience actions carry numbers only.

- Q: What do the presets contain? → A: Free play (the seeded starting scene); pendulum (a pinned steel pivot circle of
  radius 0.15 m at (5, 7) and a steel bob of radius 0.3 m on a 2.5 m spring released 30° from vertical, drag none,
  stiffness level 3); spring chain (five rubber circles of radius 0.2 m joined by 0.8 m springs hanging from a ceiling
  anchor at (5, 8), drag low, stiffness level 2); stacked objects (five wood boxes 0.5 m wide stacked on the floor at
  x = 5). Each preset records author "VisualCore project" and license "MIT"; the content license document lists them.
- Q: How does the world remember its experiment, and how does a saved experiment open? → A: The core state keeps the
  opened experiment's starting world and its origin (preset 0–3 or slot 0–3); `reset` restores that world (running, normal
  speed, no grab, no selection). `experiment.preset [0…3]` opens a preset through an action (replayable). A saved slot is
  read by the experience's store, validated, and opened by restoring a snapshot built from it (outside the replay),
  becoming the new starting world.
- Q: How are experiments saved? → A: An `ExperimentStore` writes `experiment-<slot>.json` (document schema 1: name,
  origin, world of the current schema without grab and selection, sorted keys) through `ExperienceStorage.write`;
  reading refuses with the reasons `empty-slot`, `damaged` (not JSON or truncated), `newer-version` and `invalid-world`,
  leaving the file in place; clearing removes the file. Names are 1–24 characters (cut, or "Experiment N" when empty).
- Q: Which tutorials exist and how do steps complete? → A: "Controlling time": pause (paused), step once (exactly one
  tick advanced while paused since the step began), half speed (time scale ½), reset (the world equals the starting
  world and runs). "Springs and energy": open the spring chain (origin preset 2), show force arrows, let it run 3 s (360
  ticks while running since the step began). Actions `tutorial.start [0…1]` and `tutorial.stop`; progress (tutorial,
  step, the tick when the step began) is part of the state and checked after every action and step; the current
  step's text is spoken and shown.
- Q: How is the energy fixture measured? → A: Spring chain, gravity on, drag low, 1,200 ticks: total energy sampled each
  second never rises by more than 0.5 % and ends below its start. Pendulum, drag none, 600 ticks: total energy within
  5 % of the start. The world becomes schema 4 (origin, starting world, tutorial progress); migration 3 → 4 sets origin
  free play, the current world as the starting world and no tutorial.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start from a ready-made experiment (Priority: P1) 🎯

A person picks a preset — a pendulum, a spring chain or a stack of boxes — or free play, and it opens ready to run;
pause, single step, time scale and reset work on it, and reset brings back the preset exactly as it opened.

**Why this priority**: the manual's version 0.1 feature 05 (presets) and this phase's MVP gate (reset restores the
experiment).

**Independent Test**: each preset opens with its bodies and springs; after running and editing, reset returns the
world to the preset's starting state exactly.

**Acceptance Scenarios**:

1. **Given** the preset list, **When** the person opens the pendulum, **Then** a bob hangs from a fixed pivot by a stiff
   spring and swings when started from its tilted position.
2. **Given** the spring chain, **When** it runs, **Then** a row of balls joined by springs hangs from the ceiling and
   oscillates and settles.
3. **Given** the stacked objects, **When** it runs, **Then** a stack of boxes stands on the floor.
4. **Given** any experiment that was run, edited, paused, stepped and slowed, **When** reset is used, **Then** the world
   equals the experiment as it opened, running at normal speed.

---

### User Story 2 - Save and reopen my experiment (Priority: P1)

A person saves the current experiment into one of four slots with a name, and later reopens it exactly as saved; a
slot can be overwritten or cleared; a damaged or newer saved file never breaks the experience.

**Why this priority**: the phase's deliverable (saved experiments) and the constitution's "experiments are stored only
on the device".

**Acceptance Scenarios**:

1. **Given** an edited experiment, **When** it is saved to a slot and reopened, **Then** the world is the one saved, and
   reset then returns to it.
2. **Given** a damaged, truncated or newer saved file, **When** the slot is opened, **Then** it is refused with a reason
   and the file is left untouched.
3. **Given** a slot, **When** it is cleared, **Then** its file is removed and the slot shows as empty.

---

### User Story 3 - Learn by doing (Priority: P2)

A person follows a short tutorial that asks them to do one thing at a time — pause, step once, slow down, reset; or
open the spring chain, show the force arrows and watch the energy — and each step completes by itself when they do it.

**Why this priority**: the phase's deliverable (tutorials) and journey 3 (pause, single-step, inspect energy, reset).

**Acceptance Scenarios**:

1. **Given** the "Controlling time" tutorial, **When** the person pauses, steps once, picks half speed and resets, **Then**
   each step completes as its condition is met, in order, and the tutorial ends.
2. **Given** the "Springs and energy" tutorial, **When** the person opens the spring chain, turns on force arrows and lets
   it run, **Then** the steps complete and the energy panel is shown.
3. **Given** a tutorial, **When** the person stops it, **Then** the world is unchanged and the tutorial hides.

---

### User Story 4 - Spring energy stays bounded (Priority: P1)

In the spring experiments, total energy never grows: with drag and damping it falls steadily, and the pendulum's
energy stays within a stated band over its first swings.

**Why this priority**: the phase's regression fixture (manual §11 fixture 4).

**Acceptance Scenarios**:

1. **Given** the spring chain with gravity and drag on, **When** it runs for 10 s, **Then** its total energy never rises
   by more than 0.5 % between seconds and ends below its start.
2. **Given** the pendulum with drag off, **When** it runs for 5 s, **Then** its total energy stays within 5 % of the
   start.

### Edge Cases

- **Saving while grabbed or selected:** the saved experiment leaves out the grab and the selection.
- **Opening a preset or a slot during a tutorial:** the tutorial continues if its next step expects it, otherwise it
  stays on its step.
- **An empty slot:** opening it is refused with a reason.
- **A slot name:** 1–24 characters; longer names are cut; an empty name becomes "Experiment N".
- **Storage unavailable or full:** saving reports the failure and changes nothing.
- **A preset after an edit:** opening a preset discards unsaved edits (the person is told before).
- **Reduce Motion and VoiceOver:** tutorial steps are announced; nothing decorative moves.

## Requirements *(mandatory)*

### Functional Requirements

**Experiments (G-EXPERIMENTS, app-local)**

- **FR-A11-401**: The experience MUST ship three licensed presets (pendulum, spring chain, stacked objects) and free play,
  each a validated experiment document that opens with defined bodies, springs and settings.
- **FR-A11-402**: The world MUST remember the experiment it was opened from, and reset MUST restore exactly that
  experiment (normal speed, running, no grab, no selection).
- **FR-A11-403**: The person MUST be able to save the current experiment to one of four named slots, reopen it, and clear
  it, through the experience's own storage only; saved files are versioned, and a damaged, truncated or newer file is
  refused with a reason and left untouched.

**Tutorials**

- **FR-A11-410**: The experience MUST offer two tutorials whose steps each have a text and a condition on the world, that
  advance automatically when the condition holds, and that can be stopped at any time without changing the world.

**Bounded energy**

- **FR-A11-420**: In the spring presets, total energy MUST be non-increasing within stated tolerances with drag on, and
  within a stated band without drag over a short run.

**State and records**

- **FR-A11-430**: The world MUST become schema 4 (the opened experiment and tutorial progress) with a migration from
  schema 3; the scenario manifest MUST add fixtures for each preset, reset to the experiment, save and reopen,
  refusals of damaged files, both tutorials and the energy bounds.
- **FR-A11-431**: Every preset and tutorial text MUST record its author and license in the content license document.

### Key Entities

- **Experiment document**: schema version, name, world (bodies, springs, levels, settings), origin (preset or slot).
- **Slot**: index 0–3, name, saved document file.
- **Tutorial**: id, name, steps (text, condition).
- **World (schema 4)**: schema-3 world plus the opened experiment and tutorial progress.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A11-401**: Each preset opens valid; reset after any sequence of edits and time controls equals the opened
  experiment in 100 % of fixtures.
- **SC-A11-402**: Save and reopen round trips are identical; 100 % of damaged, truncated and newer sample files are
  refused and left byte-identical.
- **SC-A11-403**: Both tutorials complete when their actions are performed, and stopping leaves the world unchanged.
- **SC-A11-404**: Spring-chain energy rises < 0.5 % between seconds and ends below its start over 10 s; pendulum energy
  stays within 5 % over 5 s without drag.
- **SC-A11-405**: The standard scenarios and fixtures pass on iOS 27; each package test finishes in under 10 s.

## Assumptions

- `ExperienceStorage` (write, read, exists, remove) is reused as Neon Arcade's high-score store does; files are atomic.
- The presets are original content (MIT, VisualCore project).

## Out of Scope

- Sharing, exporting or importing experiments; more than four slots; a tutorial editor; plots.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 05 (presets: pendulum, spring chain, stacked objects) | FR-A11-401; story 1 |
| v0.1 feature 04 / Phase 04 MVP gate (pause, step, time scale, reset) | FR-A11-402, 410; stories 1, 3 |
| Phase 04 regression fixture (spring energy bounded) | FR-A11-420; story 4 |
| Phase 04 deliverable (saved experiments and tutorials) | FR-A11-403, 410 |
| Journey 3 (pause, single-step, inspect energy, reset from a preset) | stories 1, 3 |
| Contract gap G-EXPERIMENTS; constitution A11 (offline and private, licenses) | FR-A11-401–403, 431 |

## Negative Requirements

- No network, no account, no sharing; experiments stay on the device; no artwork; no claim of engineering accuracy;
  drawing never changes the world.
