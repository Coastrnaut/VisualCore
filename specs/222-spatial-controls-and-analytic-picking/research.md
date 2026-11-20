# Research: R02-F22

- **R1 Unprojection.** Decision: NDC from points (origin top left, y down) as (2x / w − 1, 1 − 2y / h); unproject clip
  depths −1 and +1 with the inverse view-projection (GL convention of `Mat4.perspective`). Rationale: works for any
  camera matrix, not only `OrbitCamera`. Alternatives: camera-specific rays (already `OrbitCamera.ray`, kept unchanged).
- **R2 Ray-plane.** Decision: t = (p₀ − o) · n / (d · n), no hit for |d · n| < 1e-12 (the `Ray3` tolerance) or t < 0.
- **R3 Picking rule.** Decision: screen distance first, then NDC depth, then index; radius at least 22 points (a 44-point
  target, the platform minimum). Rationale: the player aims on screen; depth only breaks ties, so a large near handle
  never steals a touch aimed at a small far one.
- **R4 Offset-keeping drags.** Decision: p₀ + (h − h₀) rather than h − offset. Rationale: the start ray returns p₀
  bit for bit, since h − h₀ is exactly zero. Axis drags use the closest point of the axis line to the ray (line-line
  closest points); thresholds |d · n| < 0.1 (plane) and |d · a| > 0.995 (axis) hold the drag where the hit would race
  away.
- **R5 Snapshot history.** Decision: entries hold before and after values, coalesced by key. Rationale: generic over any
  `Codable` state, exact undo by restoring values, a drag is one entry. Alternatives: inverse commands (Effects
  Composer's design; needs per-type inverses).
- **R6 Integer-indexed steps.** Decision: value = start + k · step with integer k. Rationale: floating accumulation would
  drift; this returns exactly.
