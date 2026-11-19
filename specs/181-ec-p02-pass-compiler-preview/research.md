# Research: A25-P02 (feature 181)

- **R1 Ping-pong slots.** Decision: alternate two slots and write the last pass into a result target. Rationale: at
  most two intermediates, never reading the output. Alternative: one target per pass (rejected: unbounded).
- **R2 Result then present.** Decision: draw the chain into a result target of the source's size, then present it.
  Rationale: the result is what tests read back and what export will reuse (A25-P04); the last good picture is kept.
- **R3 Normalized set values.** Decision: `chain.set` takes 0…1 mapped to the parameter's range. Rationale:
  `ExperienceControl` ranges are fixed per control, and parameters differ per effect.
- **R4 History not stored.** Decision: the snapshot holds the chain only. Rationale: undo across launches is not in the
  manual's journeys; the snapshot stays small and versioned.
- **R5 Diagnostics from FieldPassError.** Decision: parse "<file>:<line>: <message>". Rationale: the message format is
  `FieldPass`'s; no VisualCore change.
