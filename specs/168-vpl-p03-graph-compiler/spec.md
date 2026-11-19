# Feature Specification: Visual Programming Lab — Phase 03 Bounded graph compiler and preview

**Feature Branch**: `168-vpl-p03-graph-compiler` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A23-P03 (legacy ledger) · ID namespace FR-A23-3##, SC-A23-3##, T-A23-3##

**Input**: User description: archived manual `apps/23-visual-programming-lab.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: the touch graph canvas (built at A23-P02) now shows the picture its graph makes;
  - regression fixture: a disconnected Output gives a clear error state, and no picture is compiled from an invalid
    graph;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-COMPILE, G-OPERATORS and G-BUDGET of `docs/apps/visual-programming-lab/visualcore-contract.json`.
- **Still a candidate:** not available to a person until X-A23. Saving and examples come in A23-P04.
- **No VisualCore or ProjectM change.** Follow `specs/160-ss-p02-compile-preview` and `specs/167-vpl-p02-node-canvas`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the picture the graph makes (Priority: P1) 🎯

A person builds a graph on the canvas and sees its picture in a preview panel: Noise makes a cloudy texture, Gradient
a smooth ramp between two colours, Mix blends two pictures, Blur softens one, and Output shows the result. Time makes
the picture move; Constant supplies a number or a colour.

**Why this priority**: the manual's journey 3 and feature 05 (a preview that compiles a bounded acyclic graph).

**Independent Test**: build the journey graph; the preview shows its picture; compare with references.

**Acceptance Scenarios**:

1. **Given** the starter graph (Noise into Output), **Then** the preview shows the noise texture.
2. **Given** a Gradient into Output, **Then** the preview shows the ramp, matching a reference within a small
   tolerance.
3. **Given** a Mix of two pictures with amount 0, 0.5 and 1, **Then** the preview shows the first, the blend and the
   second.

---

### User Story 2 - An invalid graph shows a clear state, never a broken picture (Priority: P1)

When the graph cannot be drawn (the Output is not connected, a required input is empty, there is no Output), the
preview shows a plain message saying why and draws no picture from that graph; when the graph becomes valid again, the
picture returns.

**Why this priority**: the phase's regression fixture.

**Independent Test**: disconnect the Output; read the preview state and the message; reconnect.

**Acceptance Scenarios**:

1. **Given** a disconnected Output, **Then** the preview says "Output not connected" and no pass of that graph is
   compiled or drawn.
2. **Given** the connection is restored, **Then** the picture returns.

---

### User Story 3 - A graph is checked against a memory budget before anything is drawn (Priority: P1)

Before any texture is made, the graph's passes and the textures they need over their lifetimes are counted; a graph
that would need more than the budget is refused with a message, and nothing is allocated.

**Why this priority**: the manual's risk 1 (user graphs consuming excessive texture memory) and algorithm rule 3.

**Independent Test**: build graphs at and one past the texture limit; read the refusal and the graphics counts.

**Acceptance Scenarios**:

1. **Given** a graph at the texture limit, **Then** it compiles and the textures counted equal those the graphics host
   reports.
2. **Given** a graph one texture past the limit, **Then** it is refused before any allocation and the graphics counts
   are unchanged.
3. **Given** a chain of passes, **Then** textures whose pictures are no longer needed are reused, so the peak is lower
   than one texture per pass.

---

### User Story 4 - Edits recompile only what changed (Priority: P2)

Editing a node recompiles that node and the nodes downstream of it, not the rest; a change of the view never
recompiles; and nothing is compiled from a control directly, only at the next frame.

**Why this priority**: the manual's algorithm rule 4 (cache by content hash; invalidate downstream).

**Independent Test**: change one node's parameter in the journey graph; read which passes were marked changed.

**Acceptance Scenarios**:

1. **Given** the journey graph and a change to Gradient's angle, **Then** Gradient, Mix, Blur and Output are marked
   changed and Noise is not.
2. **Given** several edits before one frame, **Then** one compile happens at that frame.

---

### User Story 5 - The preview survives interruptions (Priority: P2)

After a context loss, a resize or a rotation, the preview is rebuilt from the graph and draws the same picture, with no
leaked graphics resource.

**Why this priority**: the host's lifecycle rules.

**Independent Test**: draw, rebuild the context 10 times, resize there and back; compare.

**Acceptance Scenarios**:

1. **Given** a drawn preview, **When** the context is rebuilt or the view resized and restored, **Then** the same
   picture is drawn and nothing leaks.

### Edge Cases

- **A node not reaching the Output:** compiled into no pass.
- **Scalar and colour nodes (Time, Constant):** compiled into values, not passes.
- **Blur at its radius limit:** drawn; a radius past the limit cannot be entered (the parameter range).
- **The preview hidden:** no preview pass is drawn; the graph and its state are unchanged.
- **A graph whose compile fails on the device's graphics driver:** the preview shows the failure's message and the
  canvas keeps working.
- **Time:** the preview's time comes from the frame clock and stops when the experience is paused.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A23-301**: A valid graph MUST compile into an ordered, bounded schedule of picture passes, one or more per
  texture node reaching the Output, with Time and Constant compiled into values, drawn inside the host's context.
- **FR-A23-302**: The seven node kinds MUST draw as declared: Noise (layered noise by scale, octaves and speed),
  Gradient (a ramp at an angle between two colours), Mix (a blend by amount), Blur (a two-pass blur with a capped
  radius), Output (the result in the preview), Time and Constant (values).
- **FR-A23-303**: An invalid graph MUST compile into no pass and show the checker's message in the preview.
- **FR-A23-304**: The schedule's textures MUST be counted, with reuse by lifetime, and checked against a documented
  limit before any allocation; a graph past the limit MUST be refused with a message and allocate nothing.
- **FR-A23-305**: Each pass MUST carry a content key, and an edit MUST mark changed exactly the edited node and its
  downstream nodes; compiles MUST happen at most once per frame, at the next frame, never from a control.
- **FR-A23-306**: After a context loss or a resize, the preview MUST be rebuilt from the graph and draw the same
  picture; nothing may leak.
- **FR-A23-307**: The experience MUST issue no graphics call of its own; every pass runs through VisualCore.

### Key Entities

- **Pass schedule**: ordered passes, each with its operator, inputs, values, output texture slot and content key.
- **Texture slot**: a texture reused by passes whose lifetimes do not overlap.
- **Budget**: slots, sizes and bytes of a schedule, against the limit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A23-301**: Gradient, Mix and Constant pictures match their references within 2 of 255 per channel; Noise is
  deterministic for a fixed time and differs with scale; Blur of a linear ramp equals the ramp away from the edges
  within 2 of 255; Output copies its input exactly.
- **SC-A23-302**: 100% of invalid-graph fixtures compile no pass and show their message.
- **SC-A23-303**: A graph at the slot limit compiles and its counted bytes equal the bytes the host reports; one past
  is refused with the host's counts unchanged; a chain of 5 passes needs at most 2 slots.
- **SC-A23-304**: An edit marks changed exactly the edited node and its downstream nodes for 100% of the edit fixtures;
  N edits before a frame give one compile.
- **SC-A23-305**: 10 context rebuilds and a resize there and back give a byte-identical preview with no leak.
- **SC-A23-306**: Each test finishes in under 10 seconds.

## Assumptions

- The A23-P01 core and the A23-P02 canvas are reused; the full-screen passes, render targets, resource budget and GLSL
  library of VisualCore are reused unchanged (A23-P00 contract).
- Device measurements of preview cost and memory wait for the device campaign {device}.

## Traceability

| Source | Requirement |
|---|---|
| MVP: canvas with its picture | FR-A23-301, 302 |
| Regression fixture: disconnected Output gives a clear error state | FR-A23-303, SC-A23-302 |
| Host owns the graphics context | FR-A23-307, FR-A23-306 |
| Algorithm rules 3–4 (bounded schedule; cache and invalidate downstream) | FR-A23-301, 304, 305 |
| Manual risk 1 (texture memory) | FR-A23-304, SC-A23-303 |
| Version 0.1 features 02 (drawing), 05 | FR-A23-301–303 |
| Contract G-COMPILE, G-OPERATORS, G-BUDGET | FR-A23-301–307 |

## Negative Requirements

- No VisualCore or ProjectM change; no availability to a person; no saving; no graphics call in the experience; no
  network; no feedback or loop nodes; no artwork or images; no unmeasured performance claim.
