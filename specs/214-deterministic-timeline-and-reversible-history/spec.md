# Feature Specification: R02-F14 — Deterministic timeline and reversible history

**Feature Branch**: `214-deterministic-timeline-and-reversible-history` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Clarified

**Ledger gate**: R02-F14 (migration ledger, shared round feature) · ID namespace FR-R02F14-###, SC-R02F14-###, T-R02F14-###

**Input**: User description: the archived R02-F14 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"event log; snapshot ring; rewind; timeline editing; replay hashes; save migration", with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/214-deterministic-timeline-and-reversible-history`; FR-R02F14-###,
  SC-R02F14-###, T-R02F14-###.
- **Section 13 disposition: extend.** The framework steps simulations at a fixed rate (`FixedStepClock`,
  `FixedStepRunner`, the `FixedStepSimulation` protocol with a checksum), applies an immutable stream of commands by
  step (`ControlStream`), plays tweens on a `Timeline` that can seek, and stores versioned snapshots with digests and
  migration chains (`ExperienceSnapshot`, `StateDigest`, `MigrationChain`); experiences keep their own undo stacks. It has
  no editable command log, no snapshots kept while running, no going back in time, no hash of a whole run, and no stored
  form of a run that can be migrated. This feature adds those on top of the existing runner and protocol, without
  changing them.
- **Who the users are:** the player of Chrono Constellator, Backwards Aurora or Starlit Cartouche who drags time back
  and forth, changes a past move and watches the future replay; the engineer, who needs every rewind and replay to land
  on exactly the same state, proved by a hash, and a saved run to open in a later version.
- **Prerequisites:** R02-F03 (numerical foundations, seeded randomness) is pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** rewind time of a long run on D1–D3, recorded in the device campaign.
  **Owner-only items:** none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `FixedStepSimulation` (mutating `step(_ dt:)`, `checksum() -> UInt64`),
`ControlStream` (immutable entries) and `FixedStepRunner` (forward only) are in VisualCoreSimulation, which depends on
VisualCoreMath only; `StableHash.sha256(_:)` is in VisualCoreMath; `MigrationChain` (VisualCorePersistence) and
`ExperienceSnapshot`, `StateDigest` (VisualCoreExperience, which depends on Simulation and Persistence) exist; `RunDocument`
is taken (GraphicsBenchmarkLab) and `Checkpoint` is nested in DigitalZenGarden; the names `EventLog`, `SnapshotRing`,
`ReversibleTimeline`, `ReplayHash`, `TimelineError` are free.

- Q: Where do the parts live? → A: `EventLog`, `SnapshotRing`, `ReplayHash`, `ReversibleTimeline` and `TimelineError` in
  VisualCoreSimulation beside the runner (the simulation is any value type conforming to `FixedStepSimulation`); the
  stored form `TimelineRunDocument` and its migration in VisualCoreExperience, which already reaches `MigrationChain`, so
  no module dependency changes. Rationale: Section 13's home; Simulation stays pure. Impact: FR-R02F14-001…006.
- Q: When are a step's commands applied and in what order? → A: the commands at step s are applied, in insertion order,
  just before the simulation advances from step s to s + 1, with the fixed step duration of the timeline (default
  1/120 s, as `FixedStepClock`). Steps run 0 … 10,000,000; the log holds at most 1,048,576 commands. Insert appends at
  the end of its step; remove and replace address (step, index within step). Impact: FR-R02F14-001, 002; edge cases.
- Q: How are snapshots kept and how does a seek work? → A: a snapshot is taken every `interval` steps (default 64,
  1…65,536) into a ring of `capacity` snapshots (default 32, 1…1,024); when full, the oldest is dropped. Seek to k:
  k < 0 or k > 10,000,000 is refused; otherwise restore the newest snapshot with step ≤ k (or the start) and replay to k.
  A seek therefore replays at most interval − 1 steps when the snapshot is kept, or from the start when it was dropped.
  Impact: FR-R02F14-002, 003; SC-R02F14-004 (reworded below).
- Q: What exactly is the replay hash, and what does an edit do? → A: h₀ = SHA-256("vc.replay.v1" ‖ checksum₀ as 8 bytes
  little-endian); hₙ = SHA-256(hₙ₋₁ ‖ n as 8 bytes LE ‖ checksumₙ as 8 bytes LE), where checksumₙ is the state's
  checksum after n steps; snapshots also keep their hash. An edit at step s drops snapshots and hashes after s and, if the
  timeline is past s, re-seeks to its current step so its state and hash are those of the edited log at once.
  Impact: FR-R02F14-004, 005; SC-R02F14-002, 003.
- Q: What is stored, how are old versions migrated, and what are the failure codes? → A: `TimelineRunDocument` is JSON
  `{"schema":1,"start":<state>,"log":[{"step","command"}…],"step":n,"hash":"<hex>"}` (State and Command `Codable`,
  sorted keys); opening replays to `step` and compares the hash, refusing a mismatch. Schema 0, an earlier form whose log
  is a list of `[step, command]` pairs, is migrated by a `MigrationChain` step; schema above 1 is refused. Reason codes:
  `r2-f14.negative-step`, `r2-f14.step-limit`, `r2-f14.log-limit`, `r2-f14.no-such-command`, `r2-f14.ring-size`,
  `r2-f14.interval`, `r2-f14.hash-mismatch`, `r2-f14.newer-schema`, `r2-f14.malformed`; the experience adds its id,
  seed and tick. Impact: FR-R02F14-006, 007; SC-R02F14-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Go back in time and come forward again (Priority: P1) 🎯

The engineer runs a deterministic simulation for many steps with commands applied at chosen steps, then jumps to any
earlier step and forward again. Every jump lands on exactly the state a fresh run would have at that step.

**Why this priority**: scrubbing time is the core of all three games.

**Independent Test**: a seeded simulation is run to step N; seeking to every step k ≤ N gives the checksum a fresh run
to k gives; seeking forward again gives the original checksum at N.

**Acceptance Scenarios**:

1. **Given** a run of N steps, **When** it seeks to step k, **Then** its state's checksum equals a fresh run's at k.
2. **Given** a seek to k, **When** it steps forward to N, **Then** the checksum at N equals the original.
3. **Given** a seek beyond the recorded end, **When** asked, **Then** it runs forward to that step, or is refused past step 10,000,000.

### User Story 2 - Change the past (Priority: P1)

The engineer inserts, removes or changes a command at an earlier step. The future is recomputed from that step and the
new run is identical to a fresh run with the edited log.

**Independent Test**: after an edit at step s, the checksum at every later step equals a fresh run with the edited log;
steps before s are unchanged.

### User Story 3 - Prove a run (Priority: P1)

A run has a replay hash that depends on every step's state; two runs with the same seed, start and log give the same
hash on every device, and any difference in a single command changes it.

**Independent Test**: two runs give the same hash; changing one command changes the hash; the hash after a rewind and
replay equals the hash of a straight run.

### User Story 4 - Save a run and open it later (Priority: P2)

A run (its start, seed, log and hash) is saved with a schema version and opened by a later version; an older stored form
is migrated, a newer one refused, a damaged one refused.

**Independent Test**: a saved run reopens and replays to the same hash; an older-version example migrates; newer and
damaged forms are refused with a named reason.

### Edge Cases

- **A seek to a negative step, or past the step limit:** refused with a named reason.
- **An edit at a step before the first snapshot kept:** recomputed from the start.
- **Snapshot storage full:** the oldest snapshots are dropped and seeking still lands exactly (it replays from the start
  or the nearest kept snapshot).
- **Many commands at one step:** applied in insertion order just before that step advances.
- **A simulation whose checksum is not deterministic:** detected when a seek replays to a kept snapshot's step and the
  hash differs from the snapshot's, or when an opened run's replay does not reach its stored hash; reported as
  `r2-f14.hash-mismatch` and the timeline is left unchanged.
- **An empty log:** the run is the simulation's own stepping.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F14-001**: An event log MUST hold commands by step in a stable order (step, then insertion order), and MUST allow inserting, removing and replacing a command at a step;
  it holds at most 1,048,576 commands at steps 0…10,000,000.
- **FR-R02F14-002**: A reversible timeline MUST run a deterministic simulation forward one step at a time, applying the
  log's commands at each step, and MUST keep snapshots of the state every `interval` steps (1…65,536, default 64) in a ring of `capacity`
  (1…1,024, default 32).
- **FR-R02F14-003**: Seeking to any step MUST restore the nearest kept snapshot at or before it and replay the log
  forward, landing on exactly the state of a fresh run at that step.
- **FR-R02F14-004**: Editing the log at step s MUST discard snapshots after s and recompute later steps on demand, with
  results identical to a fresh run of the edited log.
- **FR-R02F14-005**: A replay hash MUST chain the simulation's checksum at every step from the start, be identical for
  identical runs on every device, and change when any command changes.
- **FR-R02F14-006**: A run MUST have a versioned stored form (start state, seed, log, step count, hash); older versions
  MUST migrate through the existing migration machinery, newer and damaged forms MUST be refused with a named reason.
- **FR-R02F14-007**: Invalid requests (a negative or too-large step, a log over its limit, a ring of zero size) MUST be
  refused with a stable reason code naming the feature.
- **FR-R02F14-008**: The existing runner, clock, stream, timeline and snapshot types and their tests MUST be unchanged;
  every new public name carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Event log**: commands by step with stable order and limits.
- **Snapshot ring**: kept states by step, bounded, oldest dropped first.
- **Reversible timeline**: start state, current state, current step, log, ring, replay hash.
- **Replay hash**: a chain over every step's checksum.
- **Run document**: versioned stored form of a run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F14-001**: For a seeded simulation run to 1,000 steps with 100 seeded commands, seeking to 200 seeded steps
  gives the fresh-run checksum every time, and seeking back to 1,000 gives the original.
- **SC-R02F14-002**: After 50 seeded edits, the checksum at every later step equals a fresh run of the edited log.
- **SC-R02F14-003**: Identical runs give identical hashes; changing any one of 100 commands changes the hash in 100 of
  100 cases; a rewind-and-replay gives the straight-run hash.
- **SC-R02F14-004**: With a ring of 4 snapshots and 1,000 steps, every seek is still exact, and a seek replays at most `interval` − 1 steps from a kept snapshot, or from the start when its
  snapshot was dropped.
- **SC-R02F14-005**: At least five positive, negative and boundary fixtures for logs, seeks and stored runs give their
  stated verdicts; a stored run round-trips byte for byte and an older-version example migrates to the same hash.
- **SC-R02F14-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- The simulation is a value type with a deterministic checksum (the existing `FixedStepSimulation` contract).
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: scrubbing controls, layout and accessibility belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Event log | FR-R02F14-001 |
| Snapshot ring | FR-R02F14-002 |
| Rewind | FR-R02F14-003 |
| Timeline editing | FR-R02F14-004 |
| Replay hashes | FR-R02F14-005 |
| Save migration | FR-R02F14-006 |
| Observability | FR-R02F14-007 |
| No Stage One breakage | FR-R02F14-008 |

## Negative Requirements / Excluded scope

- No GPU code, no new module, no change to existing undo stacks of experiences, no reverse simulation by running
  physics backwards (only snapshot-and-replay), no device run before ImplementationLock-100, no analytics.
