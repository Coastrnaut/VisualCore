# Spatial controls

Feature 222 (R02-F22). Spec: [specs/222-spatial-controls-and-analytic-picking](../../specs/222-spatial-controls-and-analytic-picking/spec.md).

## The rule

A touch lands on the handle the player meant, a drag follows the finger without jumps and holds where it would fling
the handle away, every edit is one undo away (a whole drag is one step), and a player who cannot drag reaches the same
result with discrete, spoken steps. Every result is exact or nil, the same on every device. The gesture recognizers,
cameras, `Ray3` and Effects Composer's own history are unchanged.

## Parts

- VisualCoreMath: `Plane3` (a point and a unit normal) and `Ray3.intersect(plane:)` (no hit when parallel within 1e-12
  or behind); `ScreenProjection.ray` turns a point in points (origin top left) of a w × h viewport into the world ray
  between clip depths −1 and +1 for any inverse view-projection, and `ScreenProjection.project` goes back.
- VisualCoreScenes: `SpatialHandle` with a `HandleKind` (point, axis, plane, rotation) and a hit radius;
  `HandlePicker.pick` takes the handle nearest the touch on screen within max(22 points, its hit radius) — a 44-point
  target — then the nearest in depth, then the lowest index, skipping handles behind the camera; at most 1,024 handles.
- `HandleDrag` with a `DragConstraint` (axis or plane) returns p₀ + (h − h₀), so the start ray gives the start exactly;
  it holds when the plane is seen edge-on (|d · n| < 0.1) or the ray runs along the axis (|d · a| > 0.995), clamps to
  optional bounds, and `angle(around:)` gives the turn of a rotation handle.
- `ControlHistory` keeps (label, before, after) entries for any `Codable` value, merges a drag's events under one key,
  clears redo on a new edit, drops the oldest beyond its depth (1 … 1,000, default 100) and is stored as JSON schema 1.
- `AssistiveStep` moves a value by exact steps (start + k · step) inside a range, refuses to step past a limit, and
  describes itself as "name, value" for VoiceOver; each step is a pair for `ControlHistory`.

## Failures

`SpatialControlError` reason codes: `r2-f22.viewport`, `r2-f22.handle-limit`, `r2-f22.parameter`,
`r2-f22.history-depth`, `r2-f22.newer-schema`, `r2-f22.malformed`; the experience that reports one adds its id.

## Limits

Handles are drawn by the consuming experiences in code; choosing a handle without touch (VoiceOver, Switch Control, a
keyboard) is done there by exposing handles as accessibility elements. Touch accuracy and VoiceOver use are measured on
D1–D3 in the device campaign.

## Sources

Ray-plane intersection, closest points of two lines, unprojection through an inverse view-projection and undo stacks
are textbook methods, re-implemented here. All code is original to VisualCore.
