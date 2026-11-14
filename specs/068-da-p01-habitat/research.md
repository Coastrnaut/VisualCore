# Research: A09-P01 (feature 068)

## 0. Verified facts (2026-11-14)

- `ExperienceCore`: `stepDuration`, `prepare(seed:)`, `update(step:)`, `apply(_:)`, `reset()`, `snapshotPayload()`,
  `restore(payload:seed:)`, `migrations`, `controls`, `qualityTiers` (default 1), `writeDigest(into:)`.
- The session steps the core only while running; suspension stops stepping.
- `SeededRandom` saves and restores its state (`SeededRandom.State`, `SeededRandom+State.swift`).
- `PrimitiveRenderer` draws a `SceneNode` tree (rect, circle, line, polygon ≤ 256 points, polyline) in one batch.
- The A08 experience is the structural template (Core/CoreTests/Experience/Adapter/ExperienceTests, manifest,
  candidate registration, `check_experience_packages.py`).

## 1. Decisions

- **D1 Wander (clarification 1):** turn ±(turn rate × dt) from the generator, ease speed toward cruise, inward steer
  within 1 unit of a bound, move, clamp and reflect. Rationale: bounds hold by construction; schools come in A09-P02.
  Alternative rejected: unbounded random walk with soft walls (can leave on a large step).
- **D2 Units (clarification 2):** tank 16 × 9, swim bounds x 0.5…15.5, y 1.5…8.5, step 1/60 s; uniform scaling.
- **D3 Catalog (clarification 3):** Swift data + JSON codec with validation; licenses ["MIT"], author "VisualCore
  project"; reasons `missing-license`, `unsupported-license`, `unknown-shape`, `unknown-reference`,
  `invalid-number`, `too-many-fish`. Alternative rejected: a bundled JSON resource only (no compile-time check).
- **D4 Actions and state (clarification 4):** `habitat.select [0…1]`, `lighting.level [0…2]`, `motion.pause [0…1]`;
  schema 1 = document + step + paused + generator state; `qualityTiers` 1.
- **D5 Shapes (clarification 5):** fish polygon of 12 outline points + tail triangle, mirrored by heading; plants as
  polylines (ribbon) or fans of lines with sway from the step; water as a rect in the habitat colour scaled by the
  lighting level; gravel band as a rect.
- **D6 Manifest fixtures (catalog's five):** (1) swim bounds after a long run, (2) save/restore with the Kelp habitat
  and bright lighting, (3) pause then steps (no motion while paused, standing in for suspension), (4) catalog refusal
  is proven by core tests (no action loads a catalog), so the fixture applies the other habitat and checks the
  validated catalog holds both, (5) bounded counts after habitat switches.
