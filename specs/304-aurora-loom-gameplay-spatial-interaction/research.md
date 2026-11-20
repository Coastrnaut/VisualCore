# Research: R02-G01-04

- **R1 Handle kinds.** Decision: anchors are R02-F22 axis handles (`HandleKind` along y) dragged with
  `HandleDrag(.axis(y))` clamped to −H … +H; dials are turn handles (`HandleKind.rotation` about x) dragged with `HandleDrag(.plane(x))` and
  read with `angle(around: centre)`. Rationale: the shared spatial controls already handle grazing angles, clamping and
  picking; the game adds only the step mappings.
- **R2 One move per gesture.** Decision: the candidate step is previewed during the drag and one `ribbon.move` is sent on
  release when it differs. Rationale: the move allowance counts committed choices; sending a move per crossed step would
  spend the allowance on the way to the target.
- **R3 Arbitration as a state machine.** Decision: idle → dragging (one finger on a handle) → idle on release; any state →
  orbiting on a second finger (cancelling a drag); orbiting → cancelled when one finger lifts, → idle when all lift;
  `.cancelled` phases end everything without a move. Rationale: deterministic and fully scriptable on the host.
- **R4 Orbit and framing.** Decision: `AuroraLoomOrbit(azimuth, elevation)` with azimuth = 18° + offset (offset ± 40°) and
  elevation 10° … 60°; the camera distance is refitted per orbit and aspect by the same bisection R02-G01-03 uses, over a
  content box that now includes the rails and dials. Rationale: the 5 % framing guarantee holds at every orbit.
- **R5 Selection.** Decision: the controller owns the selected ribbon (picked handle or stepper); the presenter mirrors it
  for the scene outline and the description. Rationale: one source of truth, host-tested.
