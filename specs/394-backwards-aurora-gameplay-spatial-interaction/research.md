# Research: R02-G10-04

- **R1 Picking on the timeline plane.** Decision: the touch ray through the drawn camera meets z = 0; ends (22-point
  target) win over the band, the band over a sample column. Rationale: every pick names a kernel position; the ends are
  small and must stay grabbable. Alternatives: screen-space nearest sample (breaks under orbit).
- **R2 Taps move the nearer end.** Decision: a tap left of the section moves the start, right moves the end, inside
  moves the nearer end. Rationale: "tap segment ends" with two taps from any section, and one tap to adjust.
- **R3 Swipe to reverse.** Decision: a mostly sideways drag from the band sends one reversal on release, either
  direction. Rationale: "swipe the interval to reverse"; release-only, so a swipe can be abandoned with a second finger.
- **R4 Freeze preview from the kernel.** Decision: a 0.5 s hold (and every swipe) shows the kernel's reversal with its
  bends and tear; time-driven effects stop. Rationale: "timeline freeze preview" as an exact diagnostic, never a
  graphics estimate.
- **R5 Orbit.** Decision: yaw ±35°, pitch −15° … +20°, refit distance, double tap or "Reset view". Rationale: R02-F22's
  constrained orbit; presentation only.
- **R6 Reuse of R02-G09-04 patterns.** Decision: controller, picker, preview, orbit and panel shapes follow Nocturne
  Garden's so the host and wiring tests carry over.
