# Data model: R02-F22

| Entity | Fields | Rules |
|---|---|---|
| Plane3 | point, normal (unit) | finite; normal not zero |
| ScreenProjection | (functions) | viewport finite > 0; point inside 0 … w, 0 … h |
| SpatialHandle | id, position, kind, hitRadius (points) | position finite; hitRadius finite ≥ 0 |
| HandleKind | point, axis(Vec3), plane(Vec3), rotation(Vec3) | vectors finite, not zero |
| HandlePicker | (function) | ≤ 1,024 handles; touch radius raised to ≥ 22 points |
| DragConstraint | axis(direction), plane(normal) | unit after normalising; non-zero |
| HandleDrag | start, constraint, startHit, last, bounds | grazing: plane abs(d · n) < 0.1, axis abs(d · a) > 0.995 |
| ControlHistory | entries (label, before, after, key), undone, depth, dropped | depth 1 … 1,000 (default 100); JSON schema 1 |
| AssistiveStep | name, start, step, range, k | step finite > 0; range finite, min ≤ max ≤ min + 1e9 · step; start inside |
| SpatialControlError | viewport, handleLimit, parameter(String), historyDepth, newerSchema(Int), malformed(String) | `reasonCode` `r2-f22.*` |
