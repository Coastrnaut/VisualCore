# Feature Specification: Interactive Anatomy — Phase 02 Region scene/selection renderer

**Feature Branch**: `125-ia-p02-scene-selection` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A17-P02 (legacy ledger) · ID namespace FR-A17-2##, SC-A17-2##, T-A17-2##

**Input**: User description: archived manual `apps/17-interactive-anatomy.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: toggleable layered mesh groups and an accessible structure list;
  - regression fixture: toggling layers never makes hidden structures selectable;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-SCENE (the procedural shapes and the material table), G-PICK (picking and selection), G-CAMERA
  (framing and reset) and G-BUDGETS (triangle, draw and label budgets per quality tier) of
  `docs/apps/interactive-anatomy/visualcore-contract.json`.
- **Experience A17 inside the one app:** registered as a candidate experience, not a standalone app. Visuals are
  code: every mesh is built from VisualCore's procedural generators; no asset of any kind.
- Follow `specs/111-me-p02-renderer` and `specs/124-ia-p01-content-schema`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the knee as a 3D model (Priority: P1) 🎯

A learner opens Interactive Anatomy and sees the right knee drawn in 3D: the bones, the cartilage and menisci, and
the ligaments and tendons, each layer in its own material. They turn, tilt and zoom the view, and reset it.

**Why this priority**: the phase's deliverable; nothing else can be seen without the scene.

**Independent Test**: open the experience; read the frame; step the camera; reset.

**Acceptance Scenarios**:

1. **Given** the experience opens, **Then** all 14 parts of the knee are drawn and the frame is not blank.
2. **Given** a camera step (turn, tilt or zoom), **Then** the frame changes and the knee stays in view; at a limit
   the step is refused with a sentence.
3. **Given** Reset view, **Then** the camera returns to the opening view exactly.

---

### User Story 2 - Select a structure by touch or from the list (Priority: P1)

The learner taps a structure in the model, or picks it from a list of all structures, and it is highlighted and named;
the view frames it. Tapping empty space clears the selection.

**Why this priority**: the selection half of the deliverable, and the accessible alternative to touch.

**Independent Test**: tap through the centre of each structure; pick each from the list; tap empty space.

**Acceptance Scenarios**:

1. **Given** a tap whose ray passes through a visible structure, **Then** the nearest visible structure along the ray
   is selected, highlighted and named in the canvas description.
2. **Given** a structure picked from the list, **Then** the result equals a tap selection of that structure.
3. **Given** a tap that hits nothing, **Then** the selection is cleared.
4. **Given** a selection, **Then** the camera frames that structure: its bounding sphere is inside the view.

---

### User Story 3 - Show and hide layers (Priority: P1)

The learner hides a layer (for example the ligaments) to see the bones beneath, and shows it again. A hidden
structure can never be selected, by touch or from the list.

**Why this priority**: the phase's MVP and its regression fixture.

**Independent Test**: hide each layer; tap through each hidden structure's centre; try the list.

**Acceptance Scenarios**:

1. **Given** a layer is hidden, **Then** exactly that layer's structures stop being drawn.
2. **Given** a hidden structure, **When** a tap passes through it, **Then** it is not selected (the nearest visible
   structure behind it may be).
3. **Given** a hidden structure in the list, **Then** it cannot be selected, and the list says it is hidden.
4. **Given** the selected structure's layer is hidden, **Then** the selection is cleared.

---

### User Story 4 - Stay within budgets (Priority: P2)

On any supported device the model stays within its triangle, draw and label budgets at each quality level.

**Why this priority**: the manual's bounded resources (§12) and gap G-BUDGETS.

**Independent Test**: build the scene at each quality level; count triangles and draws.

**Acceptance Scenarios**:

1. **Given** each quality level, **Then** the scene's triangle and draw counts are within that level's budget.
2. **Given** content over a budget, **Then** it is refused with a typed reason before anything is drawn.

### Edge Cases

- **All layers hidden:** nothing is drawn except the backdrop; every tap misses; the canvas description says no
  layer is shown.
- **A tap exactly on the boundary between two structures:** the nearer hit wins; equal distances resolve by the
  inventory order.
- **A declared mesh that the scene cannot build:** the experience refuses to open with a sentence naming the mesh;
  nothing is drawn.
- **Context loss or a canvas resize:** the scene is rebuilt from the content and draws the same frame; the selection
  and visibility are kept.
- **Reduce Motion:** framing a selection moves the camera immediately (no flight in this phase).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A17-201**: The scene MUST build every declared mesh of the bundled region from VisualCore's procedural
  generators. Every mesh MUST pass mesh validation and stay within its mesh budget at every quality level. The same
  content and level MUST give the same mesh digest twice.
- **FR-A17-202**: The experience MUST draw every visible structure with its layer's material, in one scene, inside the
  VisualCore host. It MUST NOT create or own a graphics context.
- **FR-A17-203**: The camera MUST orbit (turn and tilt in steps) and zoom (in steps) within stated limits. It MUST
  refuse a step beyond a limit with a sentence, and Reset view MUST restore the opening view.
- **FR-A17-204**: A tap MUST select the nearest visible structure hit by the camera ray through the tap. A miss MUST
  clear the selection. Equal distances MUST resolve by the inventory order. Picking MUST be deterministic.
- **FR-A17-205**: Hidden structures MUST never be hit by picking and MUST NOT be selectable from the list. Hiding the
  selected structure's layer MUST clear the selection.
- **FR-A17-206**: Each of the three layers MUST be shown or hidden as a group. The canvas description MUST name the
  shown layers and the selection.
- **FR-A17-207**: An accessible list MUST contain every structure grouped by layer, each with its English name and
  its layer in words. Choosing a visible structure from it MUST equal a tap selection.
- **FR-A17-208**: Selecting a structure MUST frame it: the structure's bounding sphere MUST lie inside the view, and
  the camera MUST stay within its limits.
- **FR-A17-209**: Each quality level MUST have triangle, draw and label budgets. Content over a budget MUST be refused
  with a typed reason.
- **FR-A17-210**: The experience MUST be registered as a candidate experience inside the one app, with its standard
  scenarios and fixtures. Its state (camera steps, visible layers, selection) MUST be saved and restored through the
  experience snapshot, and damaged or newer state refused.

### Key Entities

- **Region scene**: one item per structure mesh (structure, mesh, layer, material), the scene's bounds and counts.
- **Quality level**: segment counts and budgets (triangles, draws, labels).
- **View state**: camera steps, visible layers, selected structure.
- **Pick**: the structure hit and the distance along the ray, or none.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A17-201**: All declared meshes are built at every quality level; 0 fail validation or exceed their budget.
- **SC-A17-202**: A tap through the centre of each of the 14 parts selects that part when all layers are shown, and a
  tap from the outside through each part on a hidden layer never selects it.
- **SC-A17-203**: After selecting each of the 14 parts, its bounding sphere is inside the view at both canvas aspects
  0.5 and 2.
- **SC-A17-204**: The scene's triangle and draw counts are within the budget of every quality level.
- **SC-A17-205**: The experience opens and draws non-blank frames inside the one app, and its standard scenarios pass
  on iOS 27. Every test runs in under 10 s.

## Assumptions

- The content is the bundled right knee of A17-P01; its 20 declared meshes and their kinds are binding.
- Isolate, translucent ghosts and the saved view document are A17-P03 (G-LAYERS rest, G-GHOST, G-VIEW). In-scene
  labels are A17-P04 (G-LABELS); their budget is set now. Layer signs that do not rely on colour, announcements and
  the VoiceOver review of the list are A17-P04 (G-A11Y).

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 deliverable: region scene/selection renderer | FR-A17-201, 202, 204 |
| MVP: toggleable layered mesh groups and accessible structure list | FR-A17-206, 207 |
| Regression fixture: hidden structures are never selectable | FR-A17-205, SC-A17-202 |
| Context ownership in the host | FR-A17-202 |
| Contract G-SCENE | FR-A17-201, 202 |
| Contract G-PICK | FR-A17-204, 205 |
| Contract G-CAMERA | FR-A17-203, 208 |
| Contract G-BUDGETS | FR-A17-209 |
| Manual §12 budgets and fallback | FR-A17-209, SC-A17-204 |

## Negative Requirements

- No second renderer, no graphics-context code in the experience and no direct GL calls outside VisualCore.
- No asset of any kind (meshes, textures, images); no network; no medical claim.
- No isolate, ghosting, saved view document, in-scene labels or search in this phase.
- No VisualCore change unless a generator or pass is missing (none is expected).
