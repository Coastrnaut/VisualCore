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

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `VisualCoreScenes`: `Mesh.revolution`, `tube`, `extrusion` and `surface` throw `MeshError` and check a `MeshBudget`.
  `Mesh.uvSphere`, `Mesh.validate(requireClosed:budget:)`, `Mesh.bounds` and `Mesh.digest` (SHA-256) also exist.
- `VisualCoreMath`: `OrbitCamera.ray(ndc:aspect:)` exists, `Ray3` intersects spheres and triangles (two-sided
  Möller–Trumbore), `RayHit3.nearest` exists, and so do `Mat4` translation, scale and rotation.
- `VisualCoreRendering`: `DepthMeshPass` draws opaque `MeshRenderer` items with depth, `MeshRenderer` culls back faces,
  and the renderers share one program (Molecular Explorer's presenter makes and releases them together).
- The host calls the presenter's `setup` again after a context recreation. No graphics-context code lives in an
  experience.

- Q: Which quality levels and budgets? → A: Two levels, declared as `Core.qualityTiers == 2`, with the registration's
  tiers `level-0` and `level-1`:
  - level-0 (full): revolutions with 48 segments, tubes with 16 sides, spheres 32 × 16; at most 60,000 triangles;
  - level-1 (reduced): 24 segments, 8 sides, 16 × 8; at most 20,000 triangles.

  At both levels: at most 32 draws (one per mesh; the knee has 20) and at most 16 labels (labels are drawn in
  A17-P04). Content over a budget is refused with the reason `over-budget`, naming the level and the count. The
  per-mesh `MeshBudget` is the level's triangle budget.
- Q: How is the schematic geometry built and placed? → A: Each declared mesh is built from its kind, with fixed
  schematic parameters per mesh id, in the region's convention (centimetres; +Y superior, +Z anterior, +X lateral):
  - a revolution profile about the Y axis for shafts and condyles;
  - a tube along a path for ligaments and tendons;
  - an extruded outline for cartilage and the menisci;
  - a sphere for the patella.

  Each mesh is placed by its own model matrix (translation, rotation, scale), and its world bounds come from the mesh
  bounds through that matrix. A structure's bounding sphere encloses its meshes' world bounds. Every mesh must
  validate, and the closed kinds (revolution with poles, sphere, capped tube, capped extrusion) must also be closed.
- Q: What are the camera's steps and limits, and how is a selection framed? → A: The camera follows the Molecular
  Explorer precedent:
  - **Opening view:** the target is the region's centre, at turn step 2 (30°), tilt step 1 (10°) and zoom step 0, at
    the distance that fits the region's bounding sphere × 1.25 in the narrower axis of a 60° field of view.
  - **Steps:** turn steps of 15° wrap around; tilt steps of 10° within −6…6; zoom steps of × 0.85 within −4…6. A step
    beyond a limit is refused with rule code `a17.camera-limit` and a sentence.
  - **Selection:** framing moves the target to the structure's centre and sets the distance that fits its bounding
    sphere × 1.25, keeping the turn and tilt. The move is immediate.
  - **Reset view:** restores the opening view exactly and keeps the selection and layers.
- Q: What are the actions, and how do picking and the list work? → A:
  - **Actions:**
    - `structure.select [i]`, where i is 0…13 in inventory order of the parts;
    - `structure.clear`;
    - `layer.show [layer 0…2, 0/1]`;
    - `camera.turn [−1/+1]`, `camera.tilt [−1/+1]` and `camera.zoom [−1/+1]`;
    - `view.reset`.
  - **Refusals:** selecting a hidden structure is refused with `a17.hidden-structure`, and an index out of range with
    `a17.invalid-choice`.
  - **Picking:** a tap becomes the ray `OrbitCamera.ray(ndc:aspect:)`. Hidden structures are skipped, and structures
    whose bounding sphere the ray misses are skipped. The remaining world-space triangles are tested, the nearest hit
    wins, and equal distances resolve by inventory order. A hit sends `structure.select`, and a miss sends
    `structure.clear`.
  - **The list:** a native list of the 14 parts grouped by layer, each row naming the structure and its layer in
    words. A visible row sends the same `structure.select`; a hidden row is marked "Hidden" and is disabled.
- Q: What is saved, and what does it look like? → A: The experience snapshot is schema 1 JSON with the turn, tilt and
  zoom steps, the visible layers (three booleans), the selected structure id (optional) and the framed structure id
  (optional; the camera target and fit, kept after the selection is cleared until Reset view). Restoring refuses damaged
  or newer data, and an unknown structure id. The digest is built from this canonical state, so drawing never changes
  it. The materials and colours are:
  - bones ivory (0.90, 0.86, 0.76);
  - cartilage and menisci blue-grey (0.55, 0.70, 0.85);
  - ligaments and tendons rose (0.80, 0.45, 0.45);
  - the selection amber (1.00, 0.80, 0.20);
  - the backdrop (0.07, 0.08, 0.10).

  The canvas description names the selection and the shown layers in words, so nothing relies on colour alone. The
  layer toggles are this phase's part of G-LAYERS (the manual's Phase 02 MVP). Isolate, the never-hidden selection
  rule for isolate and the saved view document remain A17-P03.

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
- **A quality level change:** the other level's scene is used for drawing and picking; the camera steps, visible
  layers and selection are kept.
- **A restored state whose selection is on a hidden layer:** the selection is cleared on restore, as when the layer
  is hidden.
- **A drag or a multi-touch gesture on the canvas:** ignored in this phase; the camera moves only by its controls, and
  only a single tap picks.

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
- **SC-A17-202**: For each of the 14 parts, at least one of 26 probe rays selects that part when all layers are
  shown. The probes come from outside the region along the axis and diagonal directions and aim at the part's centre.
  No probe ever selects a part whose layer is hidden.
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
