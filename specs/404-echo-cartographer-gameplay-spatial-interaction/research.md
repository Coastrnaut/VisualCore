# Research: R02-G11-04

- **R1 Floor-plane picking.** Decision: the touch ray through the drawn camera meets y = 0; the cell whose square
  contains the hit inside the chamber is picked, after markers within 22 points. Rationale: exact, cheap, the same at
  every orbit; markers get a generous target because they are dragged. Alternatives: picking wall tops at 0.5·s height
  (rejected: a tap on a wall then picks the cell behind it at some angles; the floor cell under the finger is what the
  player names).
- **R2 Tap pulses only from known-open cells.** Decision: a tap on a known-open cell pulses; any other cell moves the
  cursor. Rationale: the kernel refuses pulses from unknown cells anyway; moving the cursor makes the tap useful for
  claims and markers through the panel. Alternatives: tap pulses everywhere (rejected: refusal noise).
- **R3 Hold to claim.** Decision: a press held 0.5 s and lifted claims the held cell; moving cancels. Rationale: a claim
  can cost energy on a miss, so it needs a deliberate gesture; the 0.5 s hold matches the earlier games' freeze
  threshold. Alternatives: double tap to claim (rejected: double tap resets the view).
- **R4 Markers by drag.** Decision: drag from a marker moves it (two mark actions: off, on); drag from an unmarked cell
  places one at the release cell. Rationale: the catalog's "triangulate via dragging markers" with only the declared
  mark control; each step is undoable.
- **R5 Orbit and reset.** Decision: yaw ±35°, pitch −15° … +20° around the authored view, distance refitted per aspect;
  double tap on empty space or "Reset view". Rationale: feature 394's proven bounds; camera motion never touches the
  rules.
- **R6 Panel parity.** Decision: every certified witness replays through the panel (cursor steppers, pulse, claim).
  Rationale: R2-F26's accessible control path.
