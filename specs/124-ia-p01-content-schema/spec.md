# Feature Specification: Interactive Anatomy — Phase 01 Licensed content inventory and schema

**Feature Branch**: `124-ia-p01-content-schema` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A17-P01 (legacy ledger) · ID namespace FR-A17-1##, SC-A17-1##, T-A17-1##

**Input**: User description: archived manual `apps/17-interactive-anatomy.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: one anatomy region rather than the full body. A clinical review is a person's action: it is recorded as an
    owner action, and until it is done the content carries the not-reviewed label (constitution 2.13.0, A17);
  - regression fixture: every displayed label maps to an existing structure and its mesh ids;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-CONTENT of `docs/apps/interactive-anatomy/visualcore-contract.json` — the content inventory,
  the structure graph and its versioned schema, as pure data tested without a GPU.
- **Licensed content, under the rule that visuals are code:** no mesh assets are licensed or bundled. The geometry is
  procedural (A17-P02), so the inventory licenses only text and data: public-domain sources and original writing.
- Follow `specs/117-sl-p01-algorithms`.

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `Packages/ExperiencesCreative/Package.swift` holds every experience's targets (the Simulation Lab precedent).
- `VisualCoreScenes/MeshShapes.swift` offers `revolution`, `tube` and `extrusion`, and `Mesh.uvSphere` exists.
- `VisualCorePersistence` has `MigrationChain`.
- No A17 source exists yet.

- Q: Which structures, with which ids, names and layers? → A: Fourteen structures in three layers. Ids are
  `knee.<name>`, English names are given here, and Terminologia Anatomica names are the standard names.
  - **Bones** (`bones`): femur (Femur), tibia (Tibia), fibula (Fibula), patella (Patella).
  - **Cartilage and menisci** (`cartilage`): femoral articular cartilage (Cartilago articularis femoris), tibial
    articular cartilage (Cartilago articularis tibiae), medial meniscus (Meniscus medialis), lateral meniscus
    (Meniscus lateralis).
  - **Ligaments and tendons** (`ligaments`): anterior cruciate ligament (Ligamentum cruciatum anterius), posterior
    cruciate ligament (Ligamentum cruciatum posterius), medial collateral ligament (Ligamentum collaterale tibiale),
    lateral collateral ligament (Ligamentum collaterale fibulare), patellar ligament (Ligamentum patellae),
    quadriceps tendon (Tendo musculi quadricipitis femoris).

  Parents form a tree under the region root: the joint parts sit under `knee.joint`, which is the root and has no
  geometry. Neighbours are the pairs that touch, for example the femur and the patella.
- Q: Which sources and licenses? → A: Three citation kinds:
  - Gray's Anatomy, 20th edition (1918), cited by its section titles (Osteology: The Femur, The Tibia, The Fibula,
    The Patella; Syndesmology: The Knee-joint; Myology: the quadriceps femoris), license `public-domain`;
  - Terminologia Anatomica (1998) for the standard names only, license `facts`, since names are terms and not
    copyrightable text;
  - the descriptions themselves, written in plain words for this experience, license `original`.

  The allowed set is {public-domain, original, facts}. The geometry license is `original` (procedural code). The
  review status is `not-reviewed`, with no reviewer or date, and the manifest's sentence is "Not reviewed by a
  clinician."
- Q: In what form is the content stored and validated? → A: The content is one JSON resource of the core target,
  `Core/Content/knee-right.json`: schema 1, content version 1, sorted keys, capped at 256 KB. A decoder reads it and
  then a validator runs. Refusals are typed reasons, each with a sentence naming the item: `damaged`, `newer-version`,
  `too-large`, `missing-reference`, `duplicate-id`, `parent-cycle`, `empty-text`, `unsourced`, `bad-license`,
  `non-finite` and `colliding-synonym`. The region's coordinate convention is centimetres, +Y superior, +Z
  anterior, +X lateral for the right knee, with a bounding box of about 14 × 30 × 14 cm.
- Q: What are mesh ids and labels at this phase? → A: The region declares a list of procedural meshes, each an id
  (`mesh.<structure>.<part>`) with a kind (`revolution`, `tube`, `extrusion` or `sphere`). Every structure names
  1–3 of them, every mesh belongs to exactly one structure, and the root has none. A label is a structure's English
  name, anchored on its first mesh. The regression fixture: every label resolves to an existing structure, and every
  structure's mesh ids to declared meshes. A17-P02 builds each declared mesh and adds a check that none is missing.
- Q: Which targets come in this phase? → A: Only `InteractiveAnatomyCore` (pure Swift, depending on
  `VisualCoreMath`) with its content resource, plus `InteractiveAnatomyCoreTests`, in
  `Packages/ExperiencesCreative/Package.swift`. The experience target, registration and catalog entry come with the
  scene in A17-P02, so nothing appears in the app now.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A trustworthy content inventory (Priority: P1) 🎯

A reviewer reads the region's content inventory: every structure with its standard name, plain-language description,
layer and sources, every source with its license, and the review status. Nothing is shown without a source.

**Why this priority**: the phase's deliverable and the manual's risk 1 (medical mistakes).

**Independent Test**: load the bundled region; count structures with at least one source; read the manifest's
licenses and review status.

**Acceptance Scenarios**:

1. **Given** the bundled region, **Then** every structure has a standard name, a description and at least one source,
   and every source names its license.
2. **Given** no clinical review is recorded, **Then** the manifest says "not reviewed by a clinician".

---

### User Story 2 - Every label maps to something real (Priority: P1)

A person who later taps or searches a label always lands on an existing structure with geometry; no label is
orphaned.

**Why this priority**: the phase's regression fixture.

**Independent Test**: validate the region; break a reference on purpose; read the refusal.

**Acceptance Scenarios**:

1. **Given** the bundled region, **Then** every label resolves to a structure, and every structure to one or more
   declared mesh ids.
2. **Given** content with a label, parent, neighbour or mesh id that does not exist, **Then** validation refuses it
   and names the broken reference.

---

### User Story 3 - Content that is safe to store and evolve (Priority: P2)

The content and any later saved view are versioned; damaged, newer or malformed data is refused safely.

**Why this priority**: the manual's versioned domain schemas.

**Independent Test**: round-trip the region; feed damaged, newer and out-of-range data.

**Acceptance Scenarios**:

1. **Given** the region, **When** it is encoded and decoded, **Then** it is equal.
2. **Given** damaged, newer or invalid data (an empty name, a non-finite bound, a duplicate id), **Then** it is
   refused with a reason and nothing crashes.

### Edge Cases

- **A structure with no geometry yet:** refused; every structure needs at least one mesh id.
- **A cycle in the parent graph:** refused.
- **Duplicate ids, names or synonyms that collide across structures:** ids are refused; colliding synonyms are
  refused.
- **Text without a source, or a source without a license:** refused.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A17-101**: The region MUST be described by a versioned content schema with:
  - the region: id, systems, coordinate convention, bounding volume, content version;
  - each structure: id, standard name, English name, synonyms, layer, parent, neighbours, mesh ids, description and
    source references;
  - a manifest: the text license, the geometry license, the review status with reviewer and date, and the citations.
- **FR-A17-102**: The bundled region MUST be the right knee joint, with its structures in three layers (bones;
  cartilage and menisci; ligaments and tendons).
- **FR-A17-103**: Validation MUST refuse content where:
  - a label, parent, neighbour or mesh id is missing;
  - an id is duplicated, or a parent cycle exists;
  - a name or description is empty, or text has no source;
  - a source has a license outside the allowed set;
  - a bound is not finite;
  - the schema is unsupported.

  Each refusal MUST name the problem.
- **FR-A17-107**: Each description MUST be 1 to 3 sentences of at most 400 characters, describing form, position and
  connections only. It MUST carry no diagnostic, symptom or treatment statement (the words diagnose, diagnosis,
  symptom, treatment, treat, cure, injury advice and medical advice are refused by validation, reason `clinical-text`).
- **FR-A17-104**: Without a recorded clinical review, the manifest MUST state "not reviewed by a clinician".
- **FR-A17-105**: The content, the model and its validation MUST be testable without a GPU.
- **FR-A17-106**: The experience is not registered in this phase; no interface appears.

### Key Entities

- **Anatomy region**: id, systems, convention, bounds, version.
- **Anatomical structure**: id, names, synonyms, layer, parent, neighbours, mesh ids, description, sources.
- **Content manifest**: licenses, review status, citations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A17-101**: 100 % of the bundled structures have a source, a description and at least one mesh id; 100 % of
  the sources have an allowed license.
- **SC-A17-102**: Every kind of broken reference listed in FR-A17-103 is refused in a test that names it.
- **SC-A17-103**: The region round-trips unchanged; damaged and newer data is refused.
- **SC-A17-104**: Every test runs in under 10 s; the app and its registry are unchanged.

## Assumptions

- Mesh ids name procedural meshes that A17-P02 builds with VisualCore's `MeshShapes`. This phase declares them, and
  A17-P02 must supply each one; a check then fails if any declared id has no geometry.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 deliverable: licensed content inventory and schema | FR-A17-101, 103 |
| MVP: one region, review recorded | FR-A17-102, 104 |
| Regression fixture: every label maps to an existing structure or mesh id | FR-A17-103, SC-A17-102 |
| Manual §6 versioned schemas | FR-A17-101, SC-A17-103 |
| Contract G-CONTENT | FR-A17-101–105 |

## Negative Requirements

- No medical claim; no licensed, purchased, generated, scanned or hand-modelled asset; no unsourced text; no network;
  no interface or registration in this phase; no VisualCore change.
