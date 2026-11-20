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
