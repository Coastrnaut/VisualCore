# Research: R02-G22-04

- **R1 Reverse painter's order for picking.** Decision: gauge, sprouts, root, cells, in that priority (the reverse of
  feature 513's order), through the drawn camera with the orbit. Rationale: the target drawn last is what the finger
  sees; feature 504.
- **R2 Cells by casting onto the board plane.** Decision: the finger's ray is cast onto z = 0 and the cell index is
  computed from the fit rule. Rationale: exact, O(1) per cell, and independent of tier geometry.
- **R3 One tool, two buttons.** Decision: the tool (nutrient or blocker) is presentation state chosen by two buttons.
  Rationale: a segmented picker's segments ignored interface-test taps at R02-G21-09.
- **R4 Previews by the kernel's own rule.** Decision: `MyceliumArchitectPlay.changed` and `MyceliumArchitectGrowth.report`
  compute the ghost; nothing is duplicated. Rationale: a ghost that disagreed with the run would mislead.
- **R5 Seed direction by board angle.** Decision: the cast travel's angle chooses the nearest of eight directions (ties
  lower). Rationale: deterministic, independent of the orbit's projection distortion.
- **R6 Constants equal feature 504's.** Decision: tap 10 points and 0.5 s, drag 16 points, double tap 0.35 s and 22
  points, orbit 90° / 60° per view size, yaw ±60°, pitch −20° … +35°, allowance 12 points. Rationale: every round-two
  game feels the same.
- **R7 Presentation state is not saved.** Decision: tool, preview, inspection, orbit and shown pulse reset at opening,
  next level, reset and restore; snapshot schema stays 1. Rationale: no migration for presentation.
