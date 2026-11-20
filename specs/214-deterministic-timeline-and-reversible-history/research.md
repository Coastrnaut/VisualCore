# Research: R02-F14

- **R1 Snapshot-and-replay rewind.** Decision: rewind restores the nearest kept snapshot at or before the target step and
  replays commands forward. Rationale: exact for any deterministic simulation; simulations need not be invertible.
  Alternatives: running physics backwards (not exact, not general); storing every step (memory grows without bound).
- **R2 Command timing.** Decision: commands at step s apply, in insertion order, before the step from s to s + 1.
  Rationale: matches `ControlStream`'s "commands at step" use in `FixedStepRunner`.
- **R3 Replay hash.** Decision: a SHA-256 chain (FIPS 180-4, `StableHash.sha256`) over the step index and checksum,
  little-endian, seeded with the domain string "vc.replay.v1" and the start checksum. Rationale: one value proves the
  whole run; any change at any step changes every later hash. Alternatives: hashing only the final state (misses
  transient differences).
- **R4 Edits.** Decision: editing at step s drops snapshots and hashes with step > s and re-seeks the timeline to its
  current step if it is past s. Rationale: state and hash are always those of the current log.
- **R5 Stored form.** Decision: `TimelineRunDocument` (JSON, sorted keys, schema 1) with a `MigrationChain` step from a
  schema-0 form (log as [step, command] pairs); opening replays to the stored step and compares the hash. Rationale:
  reuse of the existing migration machinery; a damaged run is detected, not trusted.
- **R6 As built (implementation, 2026-11-19).** Snapshots are stored at positive multiples of `interval` only when the
  step lies beyond the ring's newest snapshot, so backward replays never add or evict; a replay that reaches a kept
  snapshot's step compares hashes. A backward seek restores the latest snapshot ≤ k and so never replays through a kept
  one: the restored snapshot's (and the start's) `checksum()` is therefore compared with the recorded value, and a
  difference throws `hashMismatch` — this is how a non-deterministic simulation is caught on backward seeks. Extras:
  `EventLog.steps`, `ReversibleTimeline.hash(at:)` (seeks a copy). Measured: 15 snapshots after 1,000 steps (64…960),
  capacity 4 keeps 768…960; replays from a kept snapshot ≤ 63 steps; 100/100 single-command changes alter the hash; the
  3-step known-answer hash is pinned in the tests and cross-checked independently.
