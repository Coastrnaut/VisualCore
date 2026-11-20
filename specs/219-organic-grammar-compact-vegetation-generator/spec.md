# Feature Specification: R02-F19 — Organic grammar & compact vegetation generator

**Feature Branch**: `219-organic-grammar-compact-vegetation-generator` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-F19 (migration ledger, shared round feature) · ID namespace FR-R02F19-###, SC-R02F19-###, T-R02F19-###

**Input**: User description: the archived R02-F19 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"L-systems; parametric petals, caps, stems; deterministic instancing", with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/219-organic-grammar-compact-vegetation-generator`; FR-R02F19-###,
  SC-R02F19-###, T-R02F19-###.
- **Section 13 disposition: new, on existing parts.** The framework has seeded randomness (`SeededRandom`), the mesh
  builder with budgets and validation, curve tubes and mesh merging (`CurveMeshes`, feature 208) and instanced drawing of
  one mesh many times (`MeshInstance`, `InstancedMeshRenderer`, feature 209). It has no rewriting grammar, no turtle
  interpretation into branches, no petal, cap or stem shapes and no deterministic scattering of plants. This feature adds
  those on top of the existing parts, which stay unchanged; the section 13.4 map's new module is not created (the R02-F05
  precedent).
- **Who the users are:** the player of Nocturne Garden, Mushroom Weather, Binary Gardens or Mycelium Architect, who grows
  flowers, mushrooms and branching mycelium that look organic and differ from plant to plant, yet return identically
  when the same garden is reopened; the engineer, who needs plants within vertex budgets, built only by code, identical on
  every device.
- **Prerequisites:** R02-F05 (meshes) is pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** the frame cost of a dense instanced garden on D1–D3, recorded in the
  device campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): VisualCoreScenes depends on VisualCoreSimulation (`SeededRandom`) and VisualCoreMath
(`Vec3`, `Mat4`); `Mesh.tube(samples:radius:sides:caps:)` draws a constant-radius tube along `CurveSamples` and
`Mesh.merged(_:budget:)` joins meshes; `MeshInstance(model:color:)` and `InstancedMeshRenderer` are in
VisualCoreRendering; no grammar, turtle or plant code exists; the names `LSystem`, `PlantGrammar`, `PlantTurtle`,
`PlantSkeleton`, `PetalShape`, `CapShape`, `StemShape`, `PlantMesh`, `PlantScatter`, `PlantInstance` and `PlantError`
are free.

- Q: Where do the parts live, and what are the symbols and limits? → A: all in VisualCoreScenes (pure, host-tested).
  Symbols are single characters; the turtle reads F (draw a segment of the current step), f (move without drawing),
  + and − (turn about up by ±δ), & and ^ (pitch about left by ±δ), \ and / (roll about heading by ±δ), | (turn 180°),
  [ and ] (push and pop the state), ! (radius × radius factor), P (petal), C (cap), L (leaf); every other character
  only rewrites. Limits: generations 0 … 12, word length ≤ 1,048,576, at most 64 rules of up to 8 successors of up to
  256 symbols, branches ≤ 65,536. Impact: FR-R02F19-001, 002; Edge Cases.
- Q: How is chance made deterministic, and how does the turtle keep its frame? → A: one `SeededRandom` stream seeded with
  the grammar's seed; in each generation the word is read left to right and every symbol with a weighted rule draws one
  `double()` to pick a successor by cumulative weight (weights finite and > 0; a symbol with one successor draws
  nothing). The turtle starts at the origin with heading +y, left −x, up +z (Prusinkiewicz and Lindenmayer 1990
  conventions), re-orthonormalises its frame after every rotation, and records branches (start, end, radius, bracket
  depth) and markers (kind, position, heading, left, up, size = current step) in word order. Impact: FR-R02F19-001,
  002; SC-R02F19-001.
- Q: What are the petal, cap and stem shapes exactly? → A: a petal is a thin closed lens (front and back faces meeting at the rims; implementation, 2026-11-20: an open
  two-sided sheet cannot validate because welding by position makes every inner edge non-manifold) along a spine of length ℓ
  (0 < ℓ ≤ 100) bent in its plane by a total curl c (|c| ≤ π), with half-width w · sin(π t) (0 < w ≤ ℓ) at spine fraction
  t, n segments (2 … 64) and 3 points across; a cap is a closed surface of revolution of radius R (0 < R ≤ 100) and height
  h (0 < h ≤ 100), z = h · √(1 − (r/R)²) above a flat underside with a rim of depth d (0 ≤ d < h), with s sides
  (8 … 128) and k rings (2 … 64); a stem is a closed tapered tube of length L (0 < L ≤ 100), radii r₀ ≥ r₁ > 0, a bend b
  (|b| ≤ π) and s sides (3 … 64), m segments (1 … 64). The plant mesh draws each branch with `Mesh.tube` (two
  samples, the branch radius, 6 sides, caps) and places petals, caps and leaves (leaf = petal of half width) at markers in
  their frames, then `Mesh.merged`. Impact: FR-R02F19-003, 004; SC-R02F19-002, 003.
- Q: How does scattering work? → A: dart throwing over a rectangle x₀ < x₁, z₀ < z₁ (finite) with spacing d > 0: up to
  30 · maxCount seeded candidates (maxCount 1 … 65,536), each accepted when no accepted instance is closer than d
  (checked through a grid of cell size d/√2), stopping at maxCount; each accepted instance draws its scale in
  [s_min, s_max] (0 < s_min ≤ s_max ≤ 100), yaw in [0, 2π) and variant in 0 ..< variants (1 … 64), in that order. A
  `PlantInstance` holds position (y = 0), scale, yaw, variant and the model matrix T · R_y · S, ready for `MeshInstance`.
  Impact: FR-R02F19-005; SC-R02F19-004.
- Q: What is stored, and what are the failure codes? → A: `PlantGrammar` is `Codable` JSON schema 1 with sorted keys (start
  word, rules as predecessor and weighted successors, generations, angle, step, radius, radius factor, seed); schema 1 is
  the first stored form, a newer one refused. Reason codes (`PlantError`): `r2-f19.generations`, `r2-f19.word-limit`,
  `r2-f19.rule`, `r2-f19.weight`, `r2-f19.brackets`, `r2-f19.turtle-parameter`, `r2-f19.shape-parameter`,
  `r2-f19.branch-limit`, `r2-f19.scatter-area`, `r2-f19.scatter-parameter`, `r2-f19.newer-schema`, `r2-f19.malformed`;
  the experience adds its id, seed and tick. Impact: FR-R02F19-006, 007; SC-R02F19-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Grow a branching structure from a grammar (Priority: P1) 🎯

The engineer writes a small grammar (a starting word and rewriting rules, some chosen by weighted chance) and grows it a
number of generations; the result is turned into branches with positions, directions and thicknesses.

**Why this priority**: every consumer's plant shape comes from it.

**Independent Test**: known grammars give their known words and branch counts; the same seed gives the same plant, a
different seed a different one; limits are refused.

**Acceptance Scenarios**:

1. **Given** a grammar without chance, **When** grown, **Then** the word equals its hand-derived result.
2. **Given** a grammar with chance and a seed, **When** grown twice, **Then** both words and both branch sets are
   identical.
3. **Given** a grammar that would grow beyond the limit, **When** grown, **Then** it is refused with a named reason.

### User Story 2 - Petals, caps and stems as parametric shapes (Priority: P1)

The engineer asks for a petal (length, width, curl), a mushroom cap (radius, height, rim) or a stem (length, radii,
bend) and gets a closed or open mesh within budget, valid, with normals.

**Independent Test**: every shape over seeded parameter sets passes mesh validation, stays within budget and has its
stated dimensions.

### User Story 3 - A plant mesh from branches and parts (Priority: P2)

The branches become tapered stems and the grammar's markers become petals and caps at their places, merged into one mesh
within budget.

**Independent Test**: the merged mesh's vertex count equals the sum of its parts, it validates, and markers land where
the branches say.

### User Story 4 - Scatter plants deterministically (Priority: P1)

The engineer scatters plant instances over an area with a minimum spacing, each with a seeded size, turn and variant; the
same seed gives the same garden on every device, ready for instanced drawing.

**Independent Test**: no two instances are closer than the spacing, all lie in the area, the count is within its limit,
and two scatters with the same seed are identical.

### User Story 5 - Save and reopen a grammar (Priority: P2)

A grammar with its settings and seed is saved with a schema version and reopened later; newer and damaged forms are
refused.

**Independent Test**: grammars round-trip byte for byte and grow to the same plant; newer and damaged forms are refused.

### Edge Cases

- **A rule set with no rule for a symbol:** the symbol is kept as it is.
- **Unbalanced branch brackets:** refused with a named reason.
- **Weights that are zero or negative:** refused.
- **Zero generations:** the starting word itself.
- **A scatter area too small for even one instance, or a spacing too large:** the result is what fits, never an
  overlap; an empty area is refused.
- **Parameters outside their ranges:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F19-001**: A grammar MUST rewrite a starting word for a number of generations with deterministic and
  seeded weighted-choice rules, within stated limits.
- **FR-R02F19-002**: A turtle MUST interpret the word into branches (start, end, radii, depth) and part markers (petal,
  cap, leaf positions and frames), deterministically.
- **FR-R02F19-003**: Petal, cap and stem shapes MUST be generated from parameters as valid meshes within budget.
- **FR-R02F19-004**: A plant mesh MUST combine stems for the branches and parts at the markers into one mesh within
  budget, reusing the existing tube and merge operations.
- **FR-R02F19-005**: A scatter MUST place instances over an area with a minimum spacing and seeded size, turn and variant,
  deterministically, as transforms ready for the existing instanced renderer.
- **FR-R02F19-006**: Grammars MUST have a versioned stored form; newer and damaged forms MUST be refused.
- **FR-R02F19-007**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F19-008**: Existing types, experiences and their tests MUST be unchanged; every new public name carries
  documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Grammar**: start word, rules (with weights), generations, turn angle, step, seed.
- **Branch**: start, end, start and end radius, depth.
- **Part marker**: kind (petal, cap, leaf), position, frame, size.
- **Shape settings**: petal, cap and stem parameters.
- **Scatter**: area, spacing, count limit, size and turn ranges, variants, seed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F19-001**: Three hand-derived grammars give their exact words and branch counts; 100 seeded grammars with weighted
  rules grow identically twice and differ for different seeds in at least 95 of 100 cases.
- **SC-R02F19-002**: Every petal, cap and stem over 200 seeded parameter sets validates, stays within budget and has its
  stated length, radius or height within 1e-9.
- **SC-R02F19-003**: Plant meshes from 50 seeded grammars stay within budget, have every part (branch tube, petal,
  cap, leaf) valid as a closed mesh on its own, in-range indices, finite positions and unit normals, and each part at its
  marker within 1e-9 (implementation, 2026-11-20: touching parts share positions, so the merged mesh is not one
  manifold).
- **SC-R02F19-004**: 100 seeded scatters keep every pair at least the spacing apart, every instance in its area, and repeat
  identically.
- **SC-R02F19-005**: Grammars round-trip byte for byte and grow to the same plant; newer and damaged forms are refused.
- **SC-R02F19-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- Plants are stylised, not botanically accurate.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: garden editing, colours, layout and accessibility belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| L-systems | FR-R02F19-001, 002 |
| Parametric petals, caps, stems | FR-R02F19-003, 004 |
| Deterministic instancing | FR-R02F19-005 |
| Schema migration | FR-R02F19-006 |
| Observability | FR-R02F19-007 |
| No Stage One breakage | FR-R02F19-008 |

## Negative Requirements / Excluded scope

- No new module, no change to the mesh builder, curve tubes, instanced renderer or any experience, no images or
  generated art, no botanical simulation (growth over time, light competition), no device run before
  ImplementationLock-100, no analytics.
