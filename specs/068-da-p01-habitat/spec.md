# Feature Specification: Digital Aquarium — Phase 01 Habitat model and content license audit

**Feature Branch**: `068-da-p01-habitat` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A09-P01 (legacy ledger) · ID namespace FR-A09-1##, SC-A09-1##, T-A09-1##

**Input**: User description: archived manual `apps/09-digital-aquarium.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — one complete aquarium with two fish species and plants; regression
  fixture — fish avoid leaving the designated swim bounds; graphics-context ownership stays solely in the VisualCore
  host.
- **Gap built here** (contract `docs/apps/digital-aquarium/visualcore-contract.json`): G-HABITAT (app-local habitat
  document, species catalog, content license records and their audit). G-STEERING (bounded steering with a neighbour
  search in VisualCore) stays for A09-P02: this slice moves fish with a seeded, bounded wander that never leaves the
  swim bounds.
- **Experience:** created in `Packages/ExperiencesCreative/DigitalAquarium`, registered as a candidate with its
  scenario manifest; the slice draws a real aquarium (water, plants, two fish species, all in code) — no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression at X-A09; every Spec Kit step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: an
`ExperienceCore` declares `stepDuration` (default 1/120 s), `update(step:)`, `apply(_:)`, `reset()`, snapshot payload and
restore with a `MigrationChain`, `qualityTiers` (default 1) and controls; the session steps the core only while
running (suspension stops stepping); `SeededRandom` (xoshiro256**) saves and restores its state
(`SeededRandom+State.swift`); `PrimitiveRenderer` draws a `SceneNode` tree of rect, circle, line, polygon (≤ 256
points) and polyline shapes in one batch; `ExperienceStorage` holds per-experience files.

- Q: How do fish move in this phase, and what guarantees the bounds? → A: Each fixed step (1/60 s) every fish turns by
  a seeded random amount within ±(species turn rate × step), eases its speed toward the species cruise speed (never
  above the maximum), steers inward when closer than a margin of 1 unit to a bound, then moves; a final clamp keeps the
  position inside the bounds and reflects the outward velocity component, so leaving is impossible by construction.
  Bounded steering with neighbours (schools) replaces the wander rules in A09-P02; the bounds guarantee stays.
- Q: Which coordinates and bounds does the habitat use? → A: Habitat units: the tank is 16 × 9 units (x 0…16, y 0…9,
  y up); the swim bounds are x 0.5…15.5 and y 1.5…8.5 (above the gravel band); plants stand on y 1.0; drawing maps
  the tank to the canvas with uniform scaling and letterboxing in the water colour. The tank and bounds belong to the
  habitat document, so later habitats can change them within validated limits.
- Q: Where does the catalog live, and how is it validated? → A: In the experience's core as Swift data
  (`SpeciesCatalog.bundled`) with a JSON encoding and a validating decoder used by tests and the audit; items carry
  `author` and `license`, and the allowed licenses are exactly ["MIT"] (the repository's license, author "VisualCore
  project"); shapes are an enumeration (fish: `teardrop`, `slender`; plants: `ribbon`, `fan`); a starter habitat
  names species and plants by id. Refusal reasons: `missing-license`, `unsupported-license`, `unknown-shape`,
  `unknown-reference`, `invalid-number`, `too-many-fish`. The license audit is generated as
  `docs/apps/digital-aquarium/content-licenses.md` and checked against the catalog by a test.
- Q: Which actions and saved state does the experience have? → A: Actions `habitat.select [0…1]` (two starter
  habitats: "Reef" with clownfish-like orange fish and blue tangs, "Kelp" with silver fish and gold fish, each with
  plants), `lighting.level [0…2]` (dim, soft, bright) and `motion.pause [0…1]`; snapshot schema 1 holds the habitat
  document, the step count, the pause flag and the generator state; one quality level (`level-0`), declared by the
  core. Species names are descriptive, never brand or real-animal-care names ("orange striped fish", not a product).
- Q: What does a fish look like, and how many are there? → A: A fish is a closed polygon (body outline of 12 points
  from the species shape, scaled by size) plus a tail triangle, rotated to its heading and mirrored when swimming left;
  the tail swings with the animation phase. Starter habitats hold 6 to 10 fish and 4 to 6 plants; a habitat may hold
  at most 24 fish and 12 plants, so a frame draws at most 36 shapes plus the water and gravel.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A complete aquarium to watch (Priority: P1) 🎯

A family opens Digital Aquarium and sees one complete aquarium: a water body with depth, plants swaying at the bottom
and fish of two different species swimming calmly through it, every element drawn by the app itself.

**Why this priority**: the manual's MVP for this phase (journey 1, "choose starter habitat and watch animated fish").

**Independent Test**: opening the experience shows a non-blank aquarium whose habitat holds at least two species and
at least one plant; the same seed draws the same aquarium.

**Acceptance Scenarios**:

1. **Given** the starter habitat, **When** the experience opens, **Then** the aquarium contains fish of exactly two
   species (6 to 10 fish) and 4 to 6 plants, drawn as distinct shapes and colours.
2. **Given** the same seed, **When** the aquarium is opened twice and advanced by the same number of steps, **Then** the
   habitat state is identical.
3. **Given** a person choosing the other starter habitat, **When** it is applied, **Then** the fish, plants and water
   colour change to that habitat's definition.

---

### User Story 2 - Fish stay in the water (Priority: P1)

The person never sees a fish swim through the glass, sink below the gravel or leave the screen: every fish stays inside
the habitat's swim bounds, turning back before it reaches an edge.

**Why this priority**: the manual's Phase 01 regression fixture.

**Independent Test**: over a long simulated run from many seeds, no fish position ever lies outside the swim bounds.

**Acceptance Scenarios**:

1. **Given** any seed and the starter habitat, **When** the simulation advances 10,000 fixed steps, **Then** every fish
   position at every step lies inside the swim bounds (inclusive).
2. **Given** a fish placed at a corner of the bounds heading outward, **When** the next step runs, **Then** it turns
   back and stays inside.
3. **Given** fish speeds, **When** the simulation runs, **Then** no fish exceeds its species' maximum speed.

---

### User Story 3 - Content with known provenance (Priority: P2)

The owner can show, for every species, plant and habitat the aquarium ships with, who made it and under which license,
and the aquarium refuses content whose record is missing or unsupported.

**Why this priority**: the manual's content license audit and the risk "asset provenance and licensing are central";
catalog fixture "asset catalog rejects missing/unsupported resources gracefully".

**Independent Test**: the license audit lists every bundled content item with author and license; a catalog with a
missing license, an unknown shape or an unknown species is refused with a reason, and the starter habitat still opens.

**Acceptance Scenarios**:

1. **Given** the bundled catalog, **When** it is audited, **Then** 100 % of species, plants and habitats carry an author
   and a license from the allowed list.
2. **Given** a catalog entry without a license, with an unknown body shape or a habitat naming an unknown species,
   **When** it is loaded, **Then** it is refused with a named reason and the remaining valid content stays usable.

---

### User Story 4 - The aquarium is saved and restored (Priority: P2)

A person's aquarium survives leaving and returning: the chosen habitat and the fish come back as they were, and an
older or damaged saved state never breaks the experience.

**Why this priority**: the habitat document is the base of later editing and saving (A09-P03); catalog fixtures "save/
load preserves species, decor transforms and lighting" and "background/resume does not fast-forward fish simulation".

**Acceptance Scenarios**:

1. **Given** a running aquarium, **When** its state is saved and restored, **Then** habitat, species, plants and fish
   positions are identical.
2. **Given** the experience is suspended for any wall-clock time, **When** it resumes, **Then** the fish continue from
   where they were (no fast-forward).
3. **Given** a damaged or newer saved state, **When** it is restored, **Then** it is refused and the starter habitat
   opens.

### Edge Cases

- **Habitat with no fish or no plants:** valid only if the catalog allows it; the starter habitats always have both.
- **Too many fish:** fish counts per habitat are capped; a habitat asking more is refused.
- **Very small screens or iPad landscape:** the aquarium fills the canvas with the same habitat coordinates; drawing
  scales, the simulation does not.
- **Reduce Motion:** fish keep swimming (the display stays alive) but plant sway and the fish's random turning are halved
  (FR-A09-123); the preference is presentation only.
- **Non-finite numbers in a saved state or catalog:** refused.

## Requirements *(mandatory)*

### Functional Requirements

**Habitat model and catalog (G-HABITAT)**

- **FR-A09-101**: The aquarium MUST be described by a versioned habitat document (habitat id, water colour, plants,
  fish with species, position, velocity and heading, decor list, lighting level) that can be validated and stored.
- **FR-A09-102**: A species catalog MUST define at least two fish species (body shape, colours, size, maximum speed) and
  plants (shape, colours, height), and at least two starter habitats that combine them.
- **FR-A09-103**: Every catalog item MUST carry its author and license; loading MUST refuse items with a missing or
  unsupported license, an unknown shape or a reference to an unknown item, naming the reason.
- **FR-A09-104**: A license audit MUST list every bundled item with its author and license and fail when any item lacks
  them.

**Simulation**

- **FR-A09-110**: Fish MUST move with a seeded, fixed-step bounded wander (no wall-clock dependence): positions stay
  inside the swim bounds, speeds stay at or below the species maximum, headings follow velocity.
- **FR-A09-111**: The same seed and steps MUST give the same habitat state; suspension MUST NOT advance the simulation.

**Experience**

- **FR-A09-120**: The experience MUST draw the water, plants and fish procedurally through the host's renderer only,
  with a spoken description naming the habitat, the species and the fish count.
- **FR-A09-121**: The person MUST be able to choose a starter habitat and to pause and resume the motion; the state MUST
  be saved and restored by the host.
- **FR-A09-123**: Every control MUST have a VoiceOver label and value; with Reduce Motion on, plant sway and the fish's
  random turning MUST be halved while the fish keep swimming (the state and digest do not depend on the preference).
- **FR-A09-122**: The experience MUST be registered as a candidate with a scenario manifest holding the nine standard
  scenarios and fixtures for the swim bounds, save/restore, no fast-forward on resume, catalog refusal and bounded
  counts.

### Key Entities

- **Habitat document**: id, version, water colour, plants, fish, decor, lighting.
- **Fish**: species, position, velocity, heading, animation phase.
- **Species / plant / starter habitat**: catalog items with author and license.
- **Swim bounds**: the rectangle (and depth band) fish stay inside.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A09-101**: Each starter aquarium shows 2 species (6 to 10 fish) and 4 to 6 plants; the same seed gives an
  identical state.
- **SC-A09-102**: Over 10,000 steps from at least 20 seeds, 0 fish positions lie outside the swim bounds and 0 speeds
  exceed the species maximum.
- **SC-A09-103**: 100 % of bundled catalog items carry author and license; 100 % of malformed catalog fixtures are
  refused with a named reason.
- **SC-A09-104**: Save/restore round trips are identical; a resume after any suspension continues from the same step.
- **SC-A09-105**: The nine standard scenarios and the fixtures pass on iOS 27; each package test finishes in under 10
  seconds.

## Assumptions

- Bounded steering with a neighbour search (schooling) comes in A09-P02; this phase's wander is the simplest bounded
  motion that proves the habitat model.
- Feeding, decoration placement and editing come in A09-P03; bubbles, caustics and depth layers in A09-P04.

## Out of Scope

- Schools, feeding, placement gestures, particles, caustics, ambient mode, presets beyond the starter habitats.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 01 (one complete aquarium with two fish species and plants) | FR-A09-101, 102, 120; story 1 |
| Catalog fixture "Fish avoid leaving designated swim bounds" | FR-A09-110; story 2 |
| Catalog fixture "Asset catalog rejects missing/unsupported resources gracefully"; manual risk 1 (asset licensing) | FR-A09-103, 104; story 3 |
| Catalog fixtures "Save/load preserves species…", "Background/resume does not fast-forward" | FR-A09-111, 121; story 4 |
| Catalog fixture "Long-running scene keeps fish count… bounded" | FR-A09-110, edge case "too many fish" |
| Contract gap G-HABITAT | FR-A09-101–104 |

## Negative Requirements

- No artwork, sprites or textures from outside the code; no network; no permission; no realism, animal-care or
  wellbeing claims; no second renderer or context; no ProjectM code.
