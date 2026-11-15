# Research: A11-P04 (feature 085)

Facts verified on 2026-11-15 (clarification session).

## D1 — Presets

- **Decision**: `Presets.make(_ id: PresetID, random: inout SeededRandom, catalog:) -> PhysicsWorld` for free play (the
  seeded starting scene), pendulum, spring chain and stacked objects with the clarified geometry; each preset carries
  name, author and license; `LicenseAudit` lists them (role `preset`) and the two tutorials (role `tutorial`).
- **Rationale**: presets are data built from the existing world types; no new physics.

## D2 — Starting world and reset

- **Decision**: `PlaygroundState` (schema 4) holds `world`, `random`, `origin` (`.preset(0…3)` or `.slot(0…3)`),
  `startingWorld` (the world as opened, schema of the world) and `tutorial` progress. `reset` sets `world =
  startingWorld` with time scale 1, running, no grab and no selection (the generator keeps going, so later drops stay
  seeded). `experiment.preset` builds the preset with the generator and makes it the starting world.

## D3 — Documents and store

- **Decision**: `ExperimentDocument` (schema 1: name, origin, world) with `encode()` (sorted keys) and `decode(_:)`
  returning the document or a refusal (`damaged`, `newer-version`, `invalid-world`); the world inside is decoded with
  `PhysicsWorld.decode` (any supported world schema) and validated. `ExperimentStore` (experience target) maps slots to
  `experiment-<slot>.json` over `ExperienceStorage`, reporting `empty-slot` and storage errors; never rewrites a refused
  file; `clear` removes. Opening: the presenter asks the core for a state built from the document
  (`PlaygroundCore.opening(document:slot:from:)`) and restores it through `ExperienceShell.restore` with a snapshot of
  the current schema.

## D4 — Tutorials

- **Decision**: `Tutorials.all` (two tutorials, steps with text and a pure condition over (state, step-start tick, step
  start paused tick)); `TutorialProgress` (id, step, startTick); evaluated after every applied action and every host
  step; completing the last step ends the tutorial; `tutorial.stop` clears progress only.

## D5 — Fixtures

- **Decision**: manifest fixtures 27 pendulum, 28 spring chain energy (1,200 ticks), 29 stack preset, 30 reset to the
  experiment after edits and time controls, 31 tutorial "Controlling time" completed by its actions, 32 tutorial
  "Springs and energy", 33 schema-3 migration; slot save/open/refusal is tested in the experience tests (storage is
  outside the replay).
