# Research: R02-G19-04

- **R1 Wells move between sites.** Decision: a well drag targets the nearest site within 24 points (not another well's),
  or removal outside the enclosure. Rationale: levels allow wells only on their sites (R02-G19-02), so a free-form drag
  position would always be refused; snapping to sites makes every drop either a legal change or nothing.
- **R2 Taps place on empty sites.** Decision: a tap on an empty site places a well in the first free slot with the
  panel's strength and sense. Rationale: the quickest way to start; strength and sense stay one panel choice, so a tap
  is never ambiguous.
- **R3 Preview is the kernel's swim.** Decision: the preview swims the previewed wells with the kernel's own
  `MicroscopicAuroraDish.swim`; nothing is approximated. Rationale: what the player sees before lifting is exactly what
  the commit gives; a catalog swim is cheap enough to recompute per move.
- **R4 "Scrub speed" is a scrubber.** Decision: a track below the dish maps its length to ticks 0 … ticks swum.
  Rationale: the swim is fixed-step and deterministic; "speed" is how fast the player moves through it.
- **R5 "Tap freeze field" is a presentation toggle.** Decision: a tap on the dish field toggles the freeze; frozen, the
  committed swim stays drawn and only the gauges preview. Rationale: lets the player compare a drop against the current
  pattern; it never changes the game.
- **R6 Thresholds and orbit as feature 474.** Decision: the same tap, drag, double-tap and orbit numbers, and the same
  arbitration (a second finger cancels and orbits). Rationale: every round-two game feels the same.
- **R7 Picking order as drawn.** Decision: wells win over sites (drawn later); the scrubber has its own band; the field
  is the rest of the enclosure. Rationale: what the finger seems to touch is what is picked.
