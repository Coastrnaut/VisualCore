# Feature Specification: Molecular Explorer — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `109-me-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A15-P00 (legacy ledger) · ID namespace FR-A15-0##, SC-A15-0##, T-A15-0##

**Input**: User description: archived manual `apps/15-molecular-explorer.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Molecular Explorer (`a15.molecular-explorer`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/MolecularExplorer` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with
  Adapter/, ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target, bundle identifier,
  in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met by the one app
  itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A14;
  the contract lives in `docs/apps/molecular-explorer/`.
- **Visuals are code:** atoms, bonds, highlights, label backdrops and backgrounds are procedural geometry and shaders;
  bundled data (element properties, curated molecule coordinates) needs a license and provenance record.
- **Constitution:** 2.11.0 adds the A15 experience rules (committed at the start of this gate, `aaeeb3a7`).
- **Evidence:** host and simulator only; device tasks are tagged {device} and wait for ImplementationLock-100.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
the A15 constitution commit is `aaeeb3a7` and the A15-P00 specify commit `fc60a33d` (the phase start: the no-change
diff of `Packages` and `External` is taken from it); the reference submodule is pinned at `d93edd1`; fourteen
experiences are registered (`Catalog/registrations.json`, A01–A14). VisualCore offers `VisualCoreMath` `Vec3`, `Mat4`,
`Quat`, `OrbitCamera` (with `OrbitBounds`), `FramingFlight`, `Ray3`/`RayHit3` with ray–sphere, box and triangle casts
(`RayIntersection.swift`) and `NumericHygiene`; `VisualCoreScenes` `MeshGenerators` with `plane`, `cube` and
`uvSphere(segments:rings:radius:)` only, `MeshBuilder`, `MeshBudget` and the gesture recognizers (`DragRecognizer`,
`PinchRecognizer`, `RotateRecognizer`, `TapRecognizer`) with `GestureArbiter`; `VisualCorePersistence` `DocumentStore`,
`DocumentEnvelope` and `MigrationChain`; `VisualCoreRendering` `MeshRenderer` (Lambert lighting, per-vertex colours,
`MeshFog`, one draw per mesh item), `DepthMeshPass`, `PrimitiveRenderer`, `RenderTarget` and `ResourceRegistry`, and
instanced drawing only inside `ParticleRenderer` (`vcglDrawArraysInstanced` of quads with `vcglVertexAttribDivisor`
in `DynamicVertexBuffer`). No cylinder or capsule mesh generator, no instanced lit-mesh drawing, no ray–cylinder test,
no element catalog and no text-record parser exist in any framework product (grep for cylinder, capsule, xyz and
element finds nothing in VisualCore's sources). A file import exists only app-locally, through SwiftUI's
`fileImporter` in the controls of A06–A08.

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A14: the one app is the shell;
  this phase proves it builds for testing with Molecular Explorer absent; the targets come with A15-P01's first rules.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least one
  test that exercises it; an implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: Which package holds Molecular Explorer? → A: `Packages/ExperiencesCreative/MolecularExplorer` (Auto-Creator.md
  §16), as A05–A14 did; no new package is created.
- Q: Does Molecular Explorer need a permission or a new privacy answer? → A: No. The XYZ import goes through the system
  document picker, which needs no permission and no usage string; only the file the person chooses is read (with
  security-scoped access) and copied into the experience's own storage; no network, camera, location, microphone or
  photo access; the app's privacy answers do not change.
- Q: Which pieces exist, and who owns the missing ones? → A: Vectors, matrices, quaternions, the orbit camera, ray–sphere
  picking, the UV sphere, the mesh builder, the lit mesh renderer with depth, gestures, persistence with migration and
  experience storage exist. Gaps and owners, following the manual's phases (P01 atom/bond domain and strict XYZ
  parser, P02 camera/atom/bond renderer, P03 selection and display styles, P04 curated content and persistence, P05
  import fuzz/error and scientific review): the element catalog with sourced properties, the atom, bond and molecule
  domain, the strict XYZ parser and distance-based bond inference marked as estimated → app-local (A15-P01); a
  cylinder mesh generator → `VisualCoreScenes` if reusable, else app-local, and many atoms and bonds drawn by batching
  over `MeshRenderer` (instanced lit meshes assessed for VisualCoreRendering, never a second renderer), the camera
  framing and persisted camera → app-local over `OrbitCamera` (A15-P02); atom picking over `Ray3` ray–sphere casts,
  ball-and-stick and space-filling modes, labels and the metadata panel → app-local (A15-P03); the curated library
  with attributions, recent molecules and visual settings → app-local over `ExperienceStorage` and `MigrationChain`
  (A15-P04); the import through the document picker, fuzz and error cases and the data review → app-local (A15-P05).
  The audit confirms or corrects each from the code and the manual's phase list.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Molecular Explorer gets a map of what VisualCore already provides for each capability the
experience needs — instanced geometry, materials, camera controls, lighting and structured scientific data
visualization — and for each version 0.1 feature, with real files, declared names and package products, each marked
available, requires adaptation or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the five brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Molecular Explorer work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Molecular Explorer absent, so
Phase 01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Molecular Explorer is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Molecular Explorer can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable 3D drawing path were missing, **Then** the decision
   is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a sphere mesh but no cylinder for bonds, or ray–sphere picking but no
  ray–cylinder test): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example a file import in Oscilloscope Studio's controls,
  or batched particles in Particle Universe) but not in a framework product: not counted as available; reuse needs it
  in VisualCore first.
- **Instancing on OpenGL ES** (the manual's algorithm decision 3): the audit records whether instanced mesh drawing
  exists or only batching; the choice and its owner are named, nothing is built here.
- **Untrusted text input** (the manual's algorithm decision 1): the audit records that no bounded record parser exists
  in VisualCore (if so) and assigns the strict XYZ parser with its limits to a phase.
- **Inferred bonds presented as fact** (the manual's algorithm decision 2 and domain rule): recorded as a rule (inferred
  bonds are labelled estimates with conservative element thresholds), not solved here.
- **Picking and camera persistence** (algorithm decision 4): the audit records the existing ray casts and orbit camera;
  the camera state is kept apart from molecule data; owner named.
- **Data without a source:** every bundled element property and molecule coordinate needs source, units and license;
  the check's owner is named.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Molecular Explorer work starts.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A15-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A15-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A15-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least these MUST be assessed: the element catalog with sourced properties; the atom,
  bond and molecule domain with versioned schemas; the strict, bounded XYZ parser with typed errors; distance-based
  bond inference marked as estimated; sphere and cylinder geometry for atoms and bonds; instanced or batched drawing of
  many atoms and bonds; ball-and-stick and space-filling display modes; ray picking of atoms; orbit, pan and zoom with
  a persisted camera apart from molecule data; element labels and a metadata panel; the curated molecule library with
  attributions; file import through the system document picker; recent molecules and visual settings persistence.
- **FR-A15-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record the
  phase-start commit, the reference pin and the results.
- **FR-A15-005**: The one app MUST build for testing with Molecular Explorer absent; the experience package check MUST
  pass; Molecular Explorer MUST stay unregistered and unavailable (its targets come with A15-P01's first rules).
- **FR-A15-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking or molecule database download, no medicinal, toxicity, safety or therapeutic claims, no predictive
  molecular dynamics, no trusting of arbitrary PDB or complex input, no presenting inferred bonds as measured, no
  purchased, generated or hand-made images, textures, models or artwork, no unlicensed data), the data and license rule
  (every bundled element property and molecule records its source, units and license) and a stop/go decision with
  reasons.
- **FR-A15-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A15-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A15-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A15-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A15-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A15-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (14 registered experiences, none of them A15).
- **SC-A15-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A15-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides 3D pieces used by earlier experiences — vectors, matrices and quaternions, an orbit camera, mesh
  generators (a UV sphere among them) and a mesh builder, a lit mesh renderer with depth, ray casts against spheres,
  boxes and triangles, gesture recognizers with arbitration, accessibility planners, experience storage, document
  stores with migration and quality tiers; the audit confirms each from the code and records what is missing (for
  example a cylinder mesh, instanced mesh drawing, a ray–cylinder test, an element catalog or a text-record parser).
- Elements, molecules, bond rules, copy and the interface are app-local; generic pieces (for example a cylinder mesh
  generator or a bounded line-record parser) are assessed for VisualCore ownership.
- Later phases (A15-P01 to A15-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A15-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A15-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A15-005, US3 |
| Review gate: written stop/go decision | FR-A15-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A15-008 |
| Brainstorm capabilities (instanced geometry, materials, camera controls, lighting, structured scientific data visualization) | FR-A15-002 |
| Manual non-goals, algorithm decisions 1–4 and the domain rule on inferred bonds | FR-A15-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network.
