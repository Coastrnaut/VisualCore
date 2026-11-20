# Reversible timeline

Feature 214 (R02-F14). Spec: [specs/214-deterministic-timeline-and-reversible-history](../../specs/214-deterministic-timeline-and-reversible-history/spec.md).

## The rule

Going back in time is restore-and-replay, never running a simulation backwards: any deterministic `FixedStepSimulation`
value type can be scrubbed, edited and proved.

## Parts (VisualCoreSimulation)

- `EventLog` holds commands by step (0 … 10,000,000, at most 1,048,576 commands), in insertion order within a step.
  Commands at step s apply just before the simulation advances from s to s + 1.
- `SnapshotRing` keeps (step, state, hash) every `interval` steps (default 64), at most `capacity` (default 32), dropping
  the oldest.
- `ReplayHash` chains SHA-256 (FIPS 180-4) over every step: h₀ = SHA-256("vc.replay.v1" ‖ checksum₀), hₙ =
  SHA-256(hₙ₋₁ ‖ n ‖ checksumₙ), integers as 8 bytes little-endian. Identical runs give identical hashes on every device;
  any changed command changes every later hash.
- `ReversibleTimeline` steps forward, seeks back by restoring the latest kept snapshot at or before the target (or the
  start) and replaying, and recomputes after an edit: snapshots after the edited step are dropped and, if the timeline
  is past it, it re-seeks to its current step. A replay that reaches a kept snapshot with a different hash reveals a
  non-deterministic simulation; it is refused and the timeline is left unchanged.

## Stored form (VisualCoreExperience)

`TimelineRunDocument` writes JSON schema 1 (start state, log, step, hash; sorted keys). Opening replays to the stored step
and compares the hash; schema 0 (a log of `[step, command]` pairs) migrates through `MigrationChain`; a newer schema or
damaged data is refused.

## Failures

`TimelineError` reason codes: `r2-f14.negative-step`, `r2-f14.step-limit`, `r2-f14.log-limit`, `r2-f14.no-such-command`,
`r2-f14.ring-size`, `r2-f14.interval`, `r2-f14.hash-mismatch`, `r2-f14.newer-schema`, `r2-f14.malformed`; the experience
that reports one adds its id, seed and tick.

## Sources

SHA-256: NIST FIPS 180-4, through the existing `StableHash` helper. All code is original to VisualCore.
