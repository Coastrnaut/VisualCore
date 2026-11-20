# Feature Specification: R02-F22 — Spatial controls and analytic picking

**Feature Branch**: `222-spatial-controls-and-analytic-picking` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-F22 (migration ledger, shared round feature) · ID namespace FR-R02F22-###, SC-R02F22-###, T-R02F22-###

**Input**: User description: the archived R02-F22 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"ray/plane intersection; depth-aware handles; undo semantics; assistive controls", with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/222-spatial-controls-and-analytic-picking`; FR-R02F22-###, SC-R02F22-###,
  T-R02F22-###.
- **Section 13 disposition: extend.** The framework has gesture recognizers (`TapRecognizer`, `DragRecognizer`,
  `PinchRecognizer`, `RotateRecognizer`, `LongPressRecognizer`, `DoubleTapRecognizer`, `PointerTracker`), cameras
  (`OrbitCamera` with `ray(ndc:aspect:)` and `project`, `Camera2D`), `Ray3` with box, sphere and triangle hits, `Mat4`
  with `inverse`, and accessibility preferences (reduce motion). It has no plane hit, no way to turn a touch on screen
  into a world ray for any camera, no depth-aware choice among on-screen handles, no constrained handle drag, no shared
  undo history for spatial edits and no assistive (non-gesture) alternative for moving things. This feature adds those
  beside the existing types, which stay unchanged; Effects Composer keeps its own chain history.
- **Who the users are:** every player who drags, rotates or places something in a scene — the touch lands on the handle
  they meant even when handles overlap or sit at different depths, a drag follows the finger without jumps, a mistake
  is one undo away, and a player who cannot drag (VoiceOver, Switch Control, a keyboard) can do the same with discrete
  steps; the engineer, who needs every result exact, finite and identical on every device.
- **Prerequisites:** R02-F03 (numerical foundations) and R02-F05 (geometry) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** touch accuracy and VoiceOver use on D1–D3, recorded in the device
  campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `Ray3` (`init?` normalises, box, sphere and triangle hits returning `RayHit3`, tolerance
1e-12), `Mat4` (column vectors, `applyPoint` divides by w, `inverse`, `perspective` with GL clip depth −1 … 1),
`OrbitCamera.ray(ndc:aspect:)` and `viewProjection(aspect:)` are in VisualCoreMath; the gesture recognizers are in
VisualCoreScenes; Effects Composer has its own `EditHistory` (experience-local, unchanged); the names `Plane3`,
`ScreenProjection`, `SpatialHandle`, `HandleKind`, `HandlePicker`, `HandleDrag`, `DragConstraint`, `ControlHistory`,
`AssistiveStep` and `SpatialControlError` are free.

- Q: How does a screen point become a ray, and how is a plane hit? → A: in VisualCoreMath, `ScreenProjection.ray` maps a
  point (x, y) in points, origin top left, inside a viewport w × h (finite, > 0) to NDC (2x / w − 1, 1 − 2y / h), unprojects
  it at clip depths −1 and +1 through the inverse view-projection and returns the `Ray3` between them; nil outside the
  viewport (edges included inside), for non-finite input or a degenerate unprojection. `ScreenProjection.project` is
  the reverse (screen point and NDC depth; nil when clip w ≤ 0, behind the camera). A `Plane3` is a point and a unit
  normal (nil for a non-finite or zero normal); `Ray3.intersect(plane:)` gives t = (p₀ − o) · n / (d · n), no hit when
  |d · n| < 1e-12 or t < 0, the normal turned to face the ray. Impact: FR-R02F22-001; SC-R02F22-001.
- Q: Which handle does a touch pick? → A: `HandlePicker.pick` (VisualCoreScenes) projects each `SpatialHandle`
  (id, position, kind, hit radius in points ≥ 0); handles behind the camera or outside the depth range −1 … 1 are
  skipped; a handle is a candidate when its screen distance to the touch is at most max(touch radius, its hit radius),
  the touch radius being at least 22 points (half the 44-point minimum target; smaller values are raised); candidates
  rank by screen distance, then NDC depth (nearer first), then index. At most 1,024 handles (`.handleLimit` beyond).
  Impact: FR-R02F22-002; SC-R02F22-002.
- Q: How does a drag follow the finger without jumps or flings? → A: `HandleDrag` starts from a handle position p₀, a
  ray and a `DragConstraint` (`.axis(direction)` or `.plane(normal)`, unit vectors) and stores the start hit h₀; each
  update returns p₀ + (h − h₀), so the start ray returns exactly p₀. The hit h is the ray-plane hit for a plane, and for
  an axis the point of the axis line closest to the ray. The constraint is grazing — and the drag holds its last
  position — when |d · n| < 0.1 for a plane or |d · a| > 0.995 for an axis; a drag that would start grazing is refused
  (nil). An optional box clamps the result. Impact: FR-R02F22-003; SC-R02F22-003.
- Q: What does the history store and how are drags coalesced? → A: `ControlHistory<Value>` (Value `Sendable`,
  `Equatable`, `Codable`) stores entries of (label, before, after, coalescing key); `record` ignores before == after,
  merges into the newest entry when both carry the same non-nil key (keeping the first before and the latest after),
  clears redo, and past the depth (1 … 1,000, default 100) drops the oldest entry and counts it. `undo()` returns the
  value to restore (the newest entry's before) and moves the entry to redo; `redo()` returns its after; both return nil
  with nothing to do and leave the history unchanged. JSON schema 1 with sorted keys; `decode` refuses newer schemas and
  damaged forms. Impact: FR-R02F22-004, 006; SC-R02F22-004, 006.
- Q: What are assistive controls exactly, and what do they say? → A: `AssistiveStep` holds a name, a start value, a step
  (finite > 0) and a range (finite, min ≤ max ≤ min + 1e9 · step, the start inside); its value is start + k · step for an
  integer k kept so the value stays in the range (a step past a limit does nothing and reports so), so n steps up then n
  down return exactly when they stay in range. `description` is "<name>, <value>" with the value printed with as many
  decimals as the step needs (at most 6), locale-independent, for VoiceOver's adjustable value; each step returns the
  (before, after) pair for `ControlHistory`. Errors (`SpatialControlError`): `r2-f22.viewport`, `r2-f22.handle-limit`,
  `r2-f22.parameter`, `r2-f22.history-depth`, `r2-f22.newer-schema`, `r2-f22.malformed`. Impact: FR-R02F22-005, 007;
  SC-R02F22-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A touch becomes a world point (Priority: P1) 🎯

The engineer turns a touch on screen into a ray through the scene for the current camera and finds where it meets a
plane (the ground, a wall, a working plane), exactly, or learns that it does not meet it.

**Why this priority**: every spatial control starts here.

**Independent Test**: for seeded cameras and points, the ray through a projected world point passes through that
point, and the plane hit lies on the plane.

**Acceptance Scenarios**:

1. **Given** a world point projected to the screen, **When** a ray is made from that screen point, **Then** the ray
   passes through the world point.
2. **Given** a ray parallel to a plane or pointing away from it, **When** it is intersected, **Then** there is no hit.

### User Story 2 - Pick the handle the player meant (Priority: P1)

Several handles are on screen, some overlapping, some nearer to the camera; a touch selects the one the player meant:
the nearest on screen within a generous touch radius, and among equally near ones the one closest to the camera.

**Independent Test**: on seeded handle sets, the chosen handle is the one the rule names, never one outside the touch
radius, and never a handle hidden behind the camera.

### User Story 3 - Drag a handle without jumps (Priority: P2)

A handle dragged along an axis or across a plane follows the finger: the grab offset is kept, so it never jumps under
the finger, and grazing angles that would fling it far away are refused rather than followed.

**Independent Test**: a drag that returns to its start returns the handle exactly; a drag at a grazing angle is held.

### User Story 4 - Undo and redo (Priority: P2)

Every edit made with a control can be undone and redone; a whole drag is one step, not hundreds.

**Independent Test**: a sequence of edits and drags undone fully returns the exact start; redo replays it; a new edit
after undo clears redo; the history is bounded.

### User Story 5 - Assistive controls (Priority: P2)

A player who cannot drag moves, rotates or scales a selected thing in discrete steps (increment and decrement), with
spoken values, and the result is the same kind of edit as a drag, undoable the same way.

**Independent Test**: stepping up n times then down n times returns the exact start; every step is announced with its
value; steps respect the same limits as drags.

### Edge Cases

- **A touch outside the viewport, a degenerate camera or a non-finite input:** no ray, no pick, no crash.
- **No handle within the touch radius:** nothing is picked.
- **Two handles at the same screen distance and depth:** the lower index wins, every time.
- **A drag plane seen edge-on:** the drag holds its last position instead of jumping.
- **Undo with nothing to undo, redo with nothing to redo:** refused quietly, history unchanged.
- **Limits:** too many handles, a history deeper than its bound, invalid step sizes: refused with a named reason or
  bounded (oldest history dropped and counted).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F22-001**: A ray MUST be made from any screen point for a camera's view and projection, and MUST intersect
  planes exactly, reporting no hit when parallel or behind.
- **FR-R02F22-002**: Picking MUST choose, among handles in front of the camera, the one nearest the touch on screen
  within a touch radius of at least the platform's minimum touch target, then the nearest in depth, then the lowest
  index.
- **FR-R02F22-003**: Dragging MUST move a handle along an axis or across a plane keeping the grab offset, and MUST hold
  position when the constraint is seen at a grazing angle.
- **FR-R02F22-004**: A history MUST undo and redo edits exactly, coalesce a drag into one step, clear redo on a new edit
  and stay within a bound.
- **FR-R02F22-005**: Assistive controls MUST offer discrete increment and decrement steps with a spoken description,
  recorded as ordinary edits.
- **FR-R02F22-006**: The history MUST have a versioned stored form; newer and damaged forms MUST be refused.
- **FR-R02F22-007**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F22-008**: Existing types (gesture recognizers, cameras, `Ray3`, Effects Composer's history) and their tests
  MUST be unchanged; every new public name carries documentation; the API baseline and the reference regression are
  updated.

### Key Entities

- **Plane**: a point and a unit normal.
- **Screen ray**: built from a screen point, the viewport and the inverse view-projection.
- **Handle**: an id, a world position, a kind (point, axis, plane, rotation) and a touch radius.
- **Drag session**: the grabbed handle, its constraint, the grab offset, the start value.
- **Control history**: applied and undone edits, its bound and dropped count.
- **Assistive step**: the property, the step size, its limits and the spoken description.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F22-001**: For 1,000 seeded cameras and points, the ray through the projection of a world point passes
  within 1e-9 (relative to the scene size) of it; plane hits lie on their plane within 1e-12.
- **SC-R02F22-002**: For 200 seeded handle sets, the picked handle always equals the rule's choice, including ties and
  handles behind the camera.
- **SC-R02F22-003**: A drag that returns its finger to the start returns the handle to its start exactly; when the
  constraint is seen at a grazing angle the handle holds its last position.
- **SC-R02F22-004**: Seeded edit sequences undone fully return the exact start value and redone return the exact end;
  a 500-event drag is one undo step; the history never exceeds its bound.
- **SC-R02F22-005**: Assistive steps up n times then down n times (staying in range) return exactly to the start for 100
  seeded cases, and
  every step has a non-empty description.
- **SC-R02F22-006**: Histories round-trip byte for byte; newer and damaged forms are refused.
- **SC-R02F22-007**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- Screen points are in points with the origin at the top left, as UIKit delivers them; the viewport is the drawable's
  size in the same unit.
- The consumer experiences decide what a handle edits and how it looks; this slice ships the geometry, the choice, the
  drag, the history and the assistive steps with their proofs.
- Visual design of handles, colours and layout belongs to the consuming experiences, drawn in code.
- Choosing a handle without touch (VoiceOver, Switch Control, a keyboard) is done by the consuming experience, which
  exposes each handle as an accessibility element by its id; this slice supplies what is done once one is chosen
  (assistive steps recorded in the history). Layout follows the viewport in points, the same on iPhone and iPad in
  either orientation.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Ray/plane intersection | FR-R02F22-001 |
| Depth-aware handles | FR-R02F22-002, 003 |
| Undo semantics | FR-R02F22-004, 006 |
| Assistive controls | FR-R02F22-005 |
| Observability | FR-R02F22-007 |
| No Stage One breakage | FR-R02F22-008 |

## Negative Requirements / Excluded scope

- No new module, no change to the gesture recognizers, cameras, `Ray3` or Effects Composer, no rendering of handles in
  this slice, no physics, no device run before ImplementationLock-100, no analytics.
