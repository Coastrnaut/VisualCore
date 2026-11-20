# Feature Specification: R02-F19 — Organic grammar & compact vegetation generator

**Feature Branch**: `219-organic-grammar-compact-vegetation-generator` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

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

- **SC-R02F19-001**: Three hand-derived grammars give their exact words and branch counts; 100 seeded grammars grow
  identically twice and differ for different seeds in at least 95 of 100 cases.
- **SC-R02F19-002**: Every petal, cap and stem over 200 seeded parameter sets validates, stays within budget and has its
  stated length, radius or height within 1e-9.
- **SC-R02F19-003**: Plant meshes from 50 seeded grammars validate, stay within budget, and have each part at its marker
  within 1e-9.
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
