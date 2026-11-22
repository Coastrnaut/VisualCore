# Research: R02-G08-04

- **R1 Drag the cut-plane rim.** Decision: a rim drag tilts the plane's normal by the drag in the camera's right and up
  directions and snaps to the nearest of the 13 directions (largest |dot|); the depth then keeps the plane through the
  same preview centre (nearest crossing depth). Rationale: the design's "drag cut-plane rim"; the kernel only accepts
  the 13 directions, so the snap is the honest preview of what a cut can be. Alternatives: a free normal (not a legal
  cut).
- **R2 Depth slider.** Decision: a drag on the plane's interior moves the depth by whole crossing depths, 24 points per
  step along the projected normal. Rationale: the design's "depth slider" without a separate widget in the scene; the
  panel's depth − and + are the same steps. Alternatives: a fixed on-screen slider (hides the crystal on small views).
- **R3 Tap to commit.** Decision: a tap within the preview polygon sends one `piece.cut` with the current choice; the
  pieces' opening is the cinematic split. Rationale: the design's "tap commit for cinematic split"; the preview wins at
  touch-down so a tap on the plane is never read as a piece choice. Alternatives: a long press (slower, less
  discoverable).
- **R4 Analytic picking.** Decision: the touch ray through the drawn camera against the opened preview rim and polygon
  first, then the nearest opened face polygon of a piece, with a 22-point fallback target. Rationale: R2-F22's analytic
  picking; deterministic and host-testable.
- **R5 Orbit bounds.** Decision: yaw ±40°, pitch 10° … 60° (authored 30°), distance refit to the bounding sphere of
  radius 1.45. Rationale: R2-F22's constrained orbit avoids the vertical singularity and keeps the whole opened crystal
  visible.
- **R6 The preview while dragging.** Decision: the candidate choice is drawn through the existing preview of R02-G08-03
  (it is presentation state already); a cancel returns to the choice at touch-down. Rationale: the player sees the exact
  plane a commit would cut with.
