# Feature Specification: R02-F14 — Deterministic timeline and reversible history

**Feature Branch**: `214-deterministic-timeline-and-reversible-history` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

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
3. **Given** a seek beyond the recorded end, **When** asked, **Then** it runs forward to that step (or is refused past a
   stated limit).

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
- **Many commands at one step:** applied in a stated, stable order.
- **A simulation whose checksum is not deterministic:** detected by the replay check and reported.
- **An empty log:** the run is the simulation's own stepping.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F14-001**: An event log MUST hold commands by step in a stable order (step, then insertion order), and MUST
  allow inserting, removing and replacing a command at a step; it MUST be bounded by stated limits.
- **FR-R02F14-002**: A reversible timeline MUST run a deterministic simulation forward one step at a time, applying the
  log's commands at each step, and MUST keep snapshots of the state every stated interval in a bounded ring.
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
- **SC-R02F14-004**: With a ring of 4 snapshots and 1,000 steps, every seek is still exact, and a seek replays at most
  the stated interval times (dropped snapshots + 1) steps.
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
