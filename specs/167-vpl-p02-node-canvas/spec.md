# Feature Specification: Visual Programming Lab — Phase 02 Node canvas and connections

**Feature Branch**: `167-vpl-p02-node-canvas` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A23-P02 (legacy ledger) · ID namespace FR-A23-2##, SC-A23-2##, T-A23-2##

**Input**: User description: archived manual `apps/23-visual-programming-lab.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: the initial node library (Time, Constant, Noise, Gradient, Mix, Blur, Output) placed and connected on a touch
    canvas;
  - regression fixture: a colour output cannot connect to a scalar input without an explicit converter, and the
    canvas says so;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-CANVAS of `docs/apps/visual-programming-lab/visualcore-contract.json`.
- **The experience arrives:** Visual Programming Lab is drawn in the one app for the first time and registered as a
  candidate; it is not yet available to a person (that is X-A23). The synthetic candidate of the app's tests moves to
  `a24.graphics-benchmark-lab`.
- **Not here:** the preview of the graph's picture (A23-P03), saving and examples (A23-P04).
- **No VisualCore or ProjectM change.** Follow `specs/160-ss-p02-compile-preview`.

## Clarifications

### Session 2026-11-18

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Host:** `ExperiencePresenter` (VisualCoreExperienceHost) offers `setup`, `resize`, `draw`, `teardown`,
  `makeControls(_:)`, `makeCanvasOverlay(_:)` (a native view over the drawing) and `pointer(_:viewSize:port:)` with
  `cancelPointers()`; `PointerEvent` (VisualCoreScenes) carries `id`, `phase` (began, moved, ended, cancelled),
  `location` in view points (origin top-left) and `timestamp`.
- **Actions:** `ExperienceControl(id:ranges:)` declares an action with one range per value (at most 24), and the engine
  refuses a value outside its range before the core sees it.
- **View:** `PlaneViewport` (VisualCoreMath) maps a plane (y up) to the screen (y down) with `plane(fromScreen:)`,
  `screen(fromPlane:)`, an anchored `pinched(by:anchor:)`, `panned(by:)` and `resized(to:)`.
- **Drawing:** `FullScreenShaderScene` binds `parameters` as `u_<name>`, as Shader Studio's presenter uses it.

- Q: What does the core hold, and which actions exist? → A: `LabCore`, snapshot schema 1, digest
  `a23.visual-programming-lab.v1`:
  - **State:** the graph (A23-P01's `VisualGraph`) and the selected node (or none). The digest covers the graph only;
    the selection is in the snapshot, not in the digest.
  - **Actions:**
    - `node.add [kind 0…6, x −4,096…4,096, y −4,096…4,096]`: the new node takes the smallest unused identity; refused
      at 32 nodes (`a23.too-many-nodes`) and for a second output (`a23.one-output`);
    - `node.move [id 1…9,999, x, y]`; `node.remove [id]` (removes its connections; clears the selection if it was
      selected); `node.select [id 0…9,999]` (0 clears);
    - `edge.connect [source 1…9,999, output index 0…1, target 1…9,999, input index 0…2]`: the indices count the
      kind's outputs and inputs in declaration order;
    - `edge.disconnect [target, input index]`.
  - **Refusals** (rule ids): `a23.not-whole`, `a23.unknown-node`, `a23.unknown-port`, `a23.type-mismatch`,
    `a23.input-taken`, `a23.cycle`, `a23.too-many-nodes`, `a23.one-output`.
  - **Pure editing:** `GraphEditor` in the core applies each edit to a `VisualGraph` and refuses with a
    `GraphEditRefusal`. A connection is checked by running `GraphChecker` on the graph with the new connection: any
    connection-stage issue or a cycle refuses it; output-stage issues (an incomplete graph) do not.
- Q: Where is each node and port on the canvas, and how big are touch targets? → A: `CanvasLayout` in the core, in
  canvas points (y down):
  - a node's position is its box's top-left corner; the box is 168 points wide, with a 32-point title row and one
    36-point row per port row (the larger of its input and output counts, at least one);
  - inputs sit on the left edge and outputs on the right edge, each at the middle of its row;
  - a port's target is a 44 × 44-point square centred on it, scaled by the zoom;
  - a wire is a cubic curve from the output to the input, with horizontal handles of length max(40, |dx| / 2);
  - hit testing takes a port first, then the topmost node box (the largest identity), else empty canvas.
- Q: How do touches map to edits? → A: In the presenter's `pointer`:
  - one finger starting on a port draws a rubber wire; ending on a port of the other direction connects (the output
    end is the source); ending on a port of the same direction shows "Connect an output to an input." and sends
    nothing; ending elsewhere does nothing;
  - one finger starting on a node body moves it (`node.move` on each move, the position clamped to ±4,096); a touch
    that moves less than 10 points selects the node; on empty canvas it pans the view, and a tap clears the
    selection;
  - two fingers pinch to zoom about their midpoint and pan with it.

  The view is `CanvasView`, a `PlaneViewport` with the canvas's y flipped: zoom 0.5…2 (1 by default) and the centre
  clamped to ±4,096. It is view state in the presenter, not part of the snapshot, and never sends an action.
- Q: What is drawn by the graphics host, and what by native views? → A:
  - **Host:** a full-screen grid shader drawn by `FullScreenShaderScene` (minor lines every 32 canvas points, major
    every 160) with the uniforms `zoom` and `pan`, at most 30 frames per second, at one quality tier (`level-0`);
  - **Native overlay** (`makeCanvasOverlay`): node boxes with titles and port labels, port dots coloured by type and
    marked by shape (circle scalar, diamond colour, square texture, triangle time), wires, the selection outline and
    the rubber wire; every node, port and wire has a spoken label;
  - **Controls** (`makeControls`): an "Add node" menu, "Remove", the list form (each node with each input and a
    picker of the outputs, connections shown as "Noise 2 image → Output 1 image"), a status line from `GraphChecker`
    ("Ready", "No output", "Output not connected", "Mix 3: input b is empty") and the feedback line for the last
    refusal.
  - The experience tests draw the canvas off screen: the picture changes with pan and zoom, and stays byte-identical
    after 10 `recreateContext` calls and after a resize there and back, with `leaked` 0.
- Q: How is Visual Programming Lab registered? → A: As Shader Studio was at A22-P02:
  - a candidate entry `a23.visual-programming-lab` in `Catalog/registrations.json` (capabilities of at most 40
    characters, quality tier `level-0`, a palette, manifest
    `Packages/ExperiencesCreative/VisualProgrammingLab/scenario-manifest.json`, permissions `[]`);
  - an `ExperienceRegistry` candidate (no examples: schema 1) and the `project.yml` product
    `VisualProgrammingLabExperience`;
  - the synthetic candidate in `AppModelTests` moves to `a24.graphics-benchmark-lab`;
  - the candidate lists of the app and script tests;
  - refusal sentences are built in the core (`EditMessages`), so they are tested without the GPU.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build a graph by placing and wiring nodes (Priority: P1) 🎯

A person opens Visual Programming Lab and sees a starter graph (Noise wired into Output) on a canvas. They add nodes
from the library, drag them into place, and connect an output port to an input port by dragging between them. Each
connection is drawn as a wire between the two ports.

**Why this priority**: the manual's journeys 1 and 2 and features 02 and 03 (node library, touch canvas with wires).

**Independent Test**: open the experience; add a Mix node; connect two image outputs to its inputs; read the graph.

**Acceptance Scenarios**:

1. **Given** the experience opens, **Then** the starter graph is shown with its nodes, ports and wire.
2. **Given** a node is added, **When** it is dragged, **Then** it moves and its wires follow.
3. **Given** an output port and an input of the same type, **When** the person drags from one to the other, **Then**
   a connection is made and drawn.

---

### User Story 2 - A wrong connection is refused and explained (Priority: P1)

When a person tries to connect ports of different types, to an input that is already fed, or in a way that would make
a loop, the connection is not made and a plain sentence says why, naming both value types or the loop.

**Why this priority**: the phase's regression fixture and feature 04 (clear invalid-connection feedback).

**Independent Test**: try a colour output into a scalar input, a second connection into a fed input, and a connection
that closes a loop.

**Acceptance Scenarios**:

1. **Given** a Constant's colour output and a Noise's scale input, **When** they are connected, **Then** nothing is
   connected and the message names colour and scalar.
2. **Given** a connection that would close a loop, **Then** it is refused and the message says it would make a loop.
3. **Given** a refused connection, **Then** the graph is exactly as before.

---

### User Story 3 - Zoom, pan and select (Priority: P2)

The person pinches to zoom and drags the empty canvas to pan, within limits, and taps a node to select it. The graph
itself does not change when the view changes.

**Why this priority**: feature 03 (zoom and selection) and the manual's rule that gestures have a deterministic
meaning.

**Independent Test**: zoom and pan; the graph's fingerprint is unchanged; selection marks one node.

**Acceptance Scenarios**:

1. **Given** a zoom beyond the limits, **Then** it stops at the limit.
2. **Given** any zoom or pan, **Then** the graph is unchanged.
3. **Given** a tap on a node, **Then** that node is selected and marked; a tap on empty canvas clears the selection.

---

### User Story 4 - The same graph without the canvas (Priority: P2)

Every canvas action is also possible without dragging: a list of the nodes, each with its inputs, where an input's
source is chosen from a list of outputs, plus buttons to add, select and remove nodes. VoiceOver reads each node, port
and connection.

**Why this priority**: the manual's risk 2 (touch wiring on small screens) and the constitution's accessible list
form.

**Independent Test**: build the journey graph using only the list form.

**Acceptance Scenarios**:

1. **Given** the list form, **When** a source is chosen for an input, **Then** the same connection is made as by
   dragging, with the same refusals.
2. **Given** VoiceOver, **Then** each node, port and connection has a spoken label.

---

### User Story 5 - The canvas survives interruptions (Priority: P2)

The canvas background is drawn by the graphics host; after a context loss, a resize or a rotation, the canvas draws
the same way and the graph, selection and view are unchanged.

**Why this priority**: the host's lifecycle rules and the phase's host-ownership gate.

**Independent Test**: draw off screen, rebuild the context and resize; compare.

**Acceptance Scenarios**:

1. **Given** a drawn canvas, **When** the context is rebuilt, **Then** the same picture is drawn and nothing leaks.

### Edge Cases

- **Adding a node past the limit of 32:** refused with a message; the graph is unchanged.
- **Adding a second Output:** refused; a graph has exactly one output.
- **Removing a node:** its connections are removed with it.
- **Removing the Output:** allowed; the status says the graph has no output.
- **A drag that ends away from any port:** no connection, no message.
- **A drag between two inputs or two outputs:** refused as the wrong direction.
- **A node dragged beyond the canvas bounds:** stops at the bound.
- **Small screens:** every port's touch target is at least 44 points at the default zoom.
- **An interrupted touch** (a call, the app moving to the background): the drag is dropped; the graph stays as of the
  last completed move and no rubber wire remains.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A23-201**: The experience MUST open with a starter graph and show every node with its ports and every
  connection as a wire.
- **FR-A23-202**: A person MUST be able to add nodes of the seven kinds, move them, select them, remove them, and
  connect and disconnect ports, by touch and by the list form, within the graph's limits.
- **FR-A23-203**: Every refused edit MUST leave the graph unchanged and show one plain sentence naming the reason
  (both value types for a mismatch, the loop for a cycle, the fed input, the limit or the second output).
- **FR-A23-204**: Zoom MUST be bounded, pan MUST be bounded, and neither MUST change the graph.
- **FR-A23-205**: Port touch targets MUST be at least 44 points at the default zoom; nodes, ports and connections
  MUST have spoken labels.
- **FR-A23-206**: The canvas MUST be drawn inside the host's context and redrawn the same after a context loss or
  resize; the experience MUST issue no graphics call of its own.
- **FR-A23-207**: The experience MUST be registered as a candidate with a scenario manifest, not available to a
  person.

### Key Entities

- **Edit**: add, move, remove, select, connect, disconnect, with its refusal.
- **Canvas view**: zoom and pan (view state, not part of the graph).
- **Canvas layout**: each node's box and each port's position and touch target; each wire's curve.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A23-201**: The journey graph (Noise and Gradient into Mix, Mix into Blur, Blur into Output) can be built from
  the starter graph by touch and by the list form, giving the same graph fingerprint.
- **SC-A23-202**: 100% of refusal fixtures (type mismatch, fed input, loop, node limit, second output, wrong
  direction) leave the fingerprint unchanged and show their sentence.
- **SC-A23-203**: 100% of view changes leave the fingerprint unchanged; zoom stays within its bounds.
- **SC-A23-204**: Every port target is at least 44 × 44 points at the default zoom.
- **SC-A23-205**: The canvas picture after 10 context rebuilds and after a resize back is byte-identical, with no
  leaked graphics resource.
- **SC-A23-206**: Each test finishes in under 10 seconds.

## Assumptions

- The graph model, library, file and checker of A23-P01 are reused unchanged.
- The host's native overlay and pointer events, its plane viewport and full-screen shader scenes exist in VisualCore
  (A23-P00 contract) and are reused unchanged.
- Device checks of touch wiring on small screens wait for the device campaign {device}.

## Traceability

| Source | Requirement |
|---|---|
| MVP: initial node library on a canvas | FR-A23-201, 202 |
| Regression fixture: colour cannot connect to scalar without a converter | FR-A23-203, SC-A23-202 |
| Host owns the graphics context | FR-A23-206, SC-A23-205 |
| Version 0.1 features 02, 03, 04 | FR-A23-201–205 |
| Manual risk 2 (touch wiring on small screens) | FR-A23-205, US4 |
| Contract G-CANVAS | FR-A23-201–206 |

## Negative Requirements

- No VisualCore or ProjectM change; no availability to a person; no preview of the graph's picture yet; no saving;
  no graphics call in the experience; no network; no feedback or loop nodes; no artwork.
