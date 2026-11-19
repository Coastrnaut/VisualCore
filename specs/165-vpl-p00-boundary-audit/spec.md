# Feature Specification: Visual Programming Lab — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `165-vpl-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A23-P00 (legacy ledger) · ID namespace FR-A23-0##, SC-A23-0##, T-A23-0##

**Input**: User description: archived manual `apps/23-visual-programming-lab.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Visual Programming Lab (`a23.visual-programming-lab`) is an experience of the VisualCore
  app, built in `Packages/ExperiencesCreative/VisualProgrammingLab` (Auto-Creator.md §16 layout). It never gets a
  standalone target, bundle identifier, in-app product or store listing. The manual's gate "the app can compile an
  empty SwiftUI shell" is met by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A22. The contract lives in `docs/apps/visual-programming-lab/`.
- **Visuals are code:** every node's output, the example graphs and every preview are code; no purchased, generated
  or photographic image.
- **Constitution:** 2.19.0 adds the A23 experience rules (committed at the start of this gate, `0a9405b5`).
- **Synthetic candidate:** the app's tests use `a23.visual-programming-lab` as the synthetic not-yet-integrated id
  (since A22-P02); this phase keeps it, and A23-P02 moves it on when A23 becomes a real candidate.
- Follow `specs/158-ss-p00-boundary-audit`.

## Clarifications

### Session 2026-11-18

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code by a read-only survey, then spot-checked:
- **Commits:** the A23 constitution commit is `0a9405b5` and the A23-P00 specify commit is `7b64fedf`, the phase start
  for the no-change diff of `Packages` and `External`. The reference submodule is pinned at `d93edd1`.
- **Registry and catalog:**
  - twenty-two experiences are registered in `Catalog/registrations.json` (A01–A22), and the candidates list is
    empty;
  - `a23` appears in neither file as a registration; `AppModelTests` uses it as the synthetic not-yet-integrated id;
  - the catalog lists Visual Programming Lab as free, family "Developer and creator tools", launcher category tools.
- **Host rule:** `RenderHost`, `ResourceRegistry`, `RenderScene` and `ExperiencePresenter` are main-actor. GL work
  happens only inside a scene's `setup`, `resize`, `render` and `teardown`, with the host's context current.
- **VisualCore offers** (public in a framework product and tested):
  - **pass graphs:** `EffectGraphDescription` (VisualCoreEffectsGraph; `Codable`, `currentVersion = 1`) and
    `EffectGraphValidator.validate(_:width:height:quotaBytes:)` (a private Kahn topological order, `EffectGraphError`
    with `.cycle`, a 32-pass limit `PassSchemas.maxPasses`, a 256 MiB default quota). `EffectRenderer` and
    `EffectScene` (VisualCoreEffects) draw a validated graph. The pass types are a closed set (`PassSchemas.all`:
    copy, colorMatrix, blur, bloom, distort, composite, feedback, flashLimit), every pass consumes a texture chain,
    and there is no generator, constant, time or scalar mix pass;
  - **passes and targets:** `FieldPass` (named sampler inputs, typed `FieldUniform`s, drawing into a target or the
    framebuffer; it refuses to sample its own output), `PingPongTarget`, `ResourceRegistry.makeRenderTarget` with
    target pools, `ResourceBudget` and `ResourceLedger`;
  - **GLSL:** the `vc/` library (`noise.glsl`: `vc_valueNoise`, `vc_gradientNoise`, `vc_fbm`; `color.glsl`;
    `palette.glsl`: `vc_palette`; `hash.glsl`; `sdf.glsl`; `field.glsl`). The blur shader is internal to
    VisualCoreEffects;
  - **parameters:** `ParameterDefinition`, `ParameterSchema`, `ParameterEditor`, `ParameterHash` (VisualCoreParameters)
    and the parameter panel (VisualCoreUI);
  - **persistence:** `MigrationChain`, `NamedLibrary`, `DocumentStore` (VisualCorePersistence), `ExperienceStorage`
    and `ExperienceSnapshot` (VisualCoreExperience), and `DigestBuilder` / `StableHash` for content hashes;
  - **canvas math:** `PlaneViewport` and `Camera2D` (VisualCoreMath) and the gesture recognizers (VisualCoreScenes).
- **Missing:** no public DAG or topological-sort utility, no typed ports, no node-editor canvas, no content-hash cache
  for compiled subgraphs, no migration for `EffectGraphDescription`, and no existing node-graph experience.

- Q: Does the graph compile into VisualCore's effect graph or into the experience's own pass schedule? → A: Into the
  experience's own pass schedule, drawn with VisualCore's public `FieldPass`, render targets and `vc/` GLSL. The
  effect graph's pass set is closed and chain-only (no generators, constants, time or scalar ports), so mapping nodes
  onto it would need a VisualCore change in every phase. The schedule is app-local (gap G-COMPILE), with a note that a
  second user would justify an upstream pass-registry change.
- Q: Who owns typed ports, type checking, topological order and cycle rejection? → A: The experience's pure core
  (gaps G-MODEL and G-TYPES), tested by `swift test`. VisualCore's Kahn order is private and works on passes, not
  typed ports. A cycle is reported with its path of edges.
- Q: How are blur and the other node operators drawn? → A: As app-local fragment programs over `FieldPass`, using the
  `vc/` noise, palette and colour functions. Blur is a separable two-pass Gaussian with a capped radius, written in the
  experience, because VisualCoreEffects' blur shader is internal (gap G-OPERATORS). No VisualCore change is planned.
- Q: How are graphs persisted? → A: As versioned envelopes in the experience's `ExperienceStorage`, with a
  `MigrationChain` for the graph schema and named graphs after Shader Studio's `ProjectLibrary` (gap G-LIBRARY). The
  session snapshot holds the open graph. Damaged and newer files are refused and never deleted automatically (the
  manual's risk 3).
- Q: Who owns the canvas and the memory budget? → A: The canvas is app-local SwiftUI over `PlaneViewport` and the
  gesture recognizers, with large targets, zoom and an accessible list form (gap G-CANVAS; risk 2). A static texture
  budget is computed from the compiled schedule before any target is allocated and checked against
  `ResourceBudget` (gap G-BUDGET; risk 1). The caps (nodes, edges, texture count and size, blur radius) are set in
  A23-P01 and A23-P03.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Visual Programming Lab gets a map of what VisualCore already provides for each capability
the experience needs (a render graph, compositing, a parameter system, reusable effects and graph serialization) and
for each version 0.1 feature. Every entry has real files, declared names and package products, and is marked
available, requires adaptation, or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Visual Programming Lab work, and the starting
commit is recorded, so later phases can prove what they changed upstream.

**Independent Test**: the regression's results are recorded for an unchanged tree; the baseline document names the
commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** its two chunks are read for the phase-start tree, **Then** 7 of 7
   steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Visual Programming Lab absent.
Phase 01 then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Visual Programming Lab is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Visual Programming Lab can proceed, what is missing upstream, and which
module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** drawing a chain of passes over render targets in the host's context, sampling one
   pass's output in the next, or drawing a bounded generated fragment program were missing and could not be built over
   the existing renderer, **Then** the decision is "stop" and names the blocker (a missing host is never permission for
   a second backend).

### Edge Cases

- **A capability exists only partly** (for example passes exist but no schedule that orders them): marked "requires
  adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's multi-pass compositor or
  blur): not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **Graphs that would use too much texture memory** (the manual's risk 1): the audit records where a static budget can
  be computed before any compile and which VisualCore budget it is checked against.
- **Touch wiring on a small screen** (the manual's risk 2): the audit records the canvas's ownership, target sizes,
  zoom and the accessible list form.
- **Graph files that must stay readable across versions** (the manual's risk 3): the audit records the versioned
  envelope and migration support and where the graph format's policy is owned.
- **A cycle or a type mismatch in a graph:** the audit records that rejection happens in the pure model before any GPU
  work.
- **A context loss or resize during a preview:** the audit records how passes and textures are rebuilt from the
  compiled schedule.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A23-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (programs, full-screen passes with texture inputs, render targets and their budget,
  the GLSL library), the experience host, the build and release steps, source ownership and the reference regression
  steps, each with real paths.
- **FR-A23-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A23-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the graph, node, port and edge models, versioned and validated, with documented caps;
  - the node registry and its typed ports (scalar, colour, texture, time);
  - type checking, topological ordering and cycle rejection before any GPU work;
  - compiling a graph into a bounded pass schedule with texture lifetimes and a static memory budget;
  - drawing that schedule in the host's context, one pass sampling another's output;
  - the node operators Time, Constant, Noise, Gradient, Mix, Blur and Output;
  - a touch canvas with wires, zoom, pan and selection, plus an accessible list form;
  - local graph save and open with versioned files and migration, and refusal of damaged or newer files;
  - caching compiled results by content hash and invalidating downstream nodes on edits;
  - resize, orientation and context-loss rebuild from the graph.
- **FR-A23-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A23-005**: The one app MUST build for testing with Visual Programming Lab absent. The experience package check
  MUST pass. Visual Programming Lab MUST stay unregistered and unavailable; its targets come with A23-P01's first rules.
- **FR-A23-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, no community sharing,
    no private API, no arbitrary scripting or user code, no unbounded loops or feedback nodes, no compile off the
    host's thread, no unmeasured performance claim, and no purchased, generated or photographic images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: texture
    memory from user graphs, touch wiring on small screens, and the graph format's migration policy;
  - a stop/go decision with reasons.
- **FR-A23-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A23-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A23-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A23-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A23-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A23-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (22 registered experiences, none of them A23).
- **SC-A23-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A23-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the pieces earlier experiences used (field passes with texture inputs, render targets, the GLSL
  library, parameters, experience storage and versioned envelopes): the audit confirms each from the code and records
  what is missing.
- The node library, canvas, copy and interface are app-local; generic pieces (for example a pass schedule) are
  assessed for VisualCore ownership.
- Later phases (A23-P01 to A23-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A23-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A23-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A23-005, US3 |
| Review gate: written stop/go decision | FR-A23-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A23-008 |
| Brainstorm capabilities (render graph, compositing, parameter system, reusable effects, graph serialization) | FR-A23-002 |
| Manual non-goals and risks 1–3 | FR-A23-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API; no permission and no usage string.
