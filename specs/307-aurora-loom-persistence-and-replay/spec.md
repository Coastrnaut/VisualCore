# Feature Specification: R02-G01-07 — Aurora Loom: persistence and replay

**Feature Branch**: `307-aurora-loom-persistence-and-replay` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-07 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0107-###,
SC-R02G0107-###, T-R02G0107-###

**Input**: User description: the archived R02-G01-07 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Atomic saves, deterministic fixed seeds, migration and reconcilable scores" for Aurora Loom, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/307-aurora-loom-persistence-and-replay`; FR-R02G0107-###, SC-R02G0107-###,
  T-R02G0107-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate) in
  `Packages/ExperiencesRound02/AuroraLoom`; saving to disk is the one app's shared saved-state store (one atomic state
  file per experience, unreadable files quarantined, newer schemas refused); this feature defines what Aurora Loom puts
  in it.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** a save surviving a real app termination on hardware is a D1–D3
  observation after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** the saved-state store and migration chain of the experience contract (UA-F05), R02-F24
  progression, and R02-G01-01 … 06.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): the app's `SavedStateStore` keeps one `state.json` per experience holding the
encoded `ExperienceSnapshot` (schema version and payload), writes it atomically, moves an unreadable file aside (at most
three copies) and refuses a newer schema; the engine applies the experience's `MigrationChain` to older payloads;
Aurora Loom's adapter writes snapshot schema 2 `{level, records, progress, mode, tutorial}` with a 1 → 2 step; its
progress keeps per level the best moves and stars; the kernel's records carry previous and next fingerprints.

- Q: What is stored for each result, and when is it written? → A: each result keeps its best moves, stars and the
  winning trace — the ordered moves (ribbon, control, step) of the play that earned it — plus `verified`. A win in
  campaign or daily mode replaces the stored result only when it has fewer moves (ties keep the earlier trace). The
  shared store writes the snapshot at the app's save points (leaving the experience, backgrounding); this feature does
  not change when. Impact: FR-R02G0107-001, 003; SC-R02G0107-001.
- Q: How are scores reconciled on restore? → A: for every result with a trace: the certified level is generated, a
  fresh play replays the trace (each move legal), and the result is kept only if the play ends won after exactly
  `bestMoves` moves and `stars` equals the stars rule for that count; otherwise it is dropped. The adapter exposes the
  number dropped (`reconciliation.dropped`) and the presenter announces it once. Results without a trace (from schema 2)
  are kept, marked unverified. The frontier is restored as saved but never below one level after the highest kept
  result. Impact: FR-R02G0107-003; SC-R02G0107-003.
- Q: How do migrations work? → A: schema 3 adds the trace and `verified` to each result. 1 → 2 is the existing step;
  2 → 3 copies results with no trace and `verified: false`. A payload of schema 4 or newer is refused by the shared
  store (newer schema); a damaged payload is refused with `damaged` and the opening state is used. Impact:
  FR-R02G0107-002; SC-R02G0107-002.
- Q: How does replay work? → A: the action `replay.start [level]` opens mode `replay(level)` with a fresh play of that
  level when a verified result with a trace exists (`r02-g01.no-replay` otherwise); `replay.step` applies the next move
  of the trace (`r02-g01.replay-end` after the last); `replay.stop` returns to campaign at that level. During replay
  every other play action is refused with `r02-g01.replay`; replay never changes progress. Impact: FR-R02G0107-004;
  SC-R02G0107-004.
- Q: Which inputs make the state deterministic? → A: the seed (opening level), the certified catalog (fixed planned
  seeds), the calendar date given to `mode.daily` and the recorded actions; the state reads no clock and no random
  source, so a save restores and replays identically on every device. Impact: FR-R02G0107-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Progress is never lost or corrupted (Priority: P1) 🎯

A player who closes the app mid-level or after winning finds the same level, moves, mode, stars and open levels when
they return; a damaged or interrupted save never loses earlier progress silently.

**Why this priority**: lost progress is the fastest way to lose a player.

**Independent Test**: any reachable state survives a save and restore exactly (equal digest); a damaged payload is
refused with a named reason and the earlier state stays.

**Acceptance Scenarios**:

1. **Given** a state with progress, a mode and moves made, **When** it is saved and restored, **Then** the restored state
   has the same digest, progress, mode and tutorial step.
2. **Given** a save from the previous schema, **When** it is restored, **Then** it migrates without losing progress.

### User Story 2 - Scores that can be checked (Priority: P1)

Every recorded result (best moves and stars) carries the winning moves that earned it; on restore each result is
replayed on its certified level and kept only if the replay wins in exactly the recorded number of moves with the
recorded stars, so an edited save cannot claim scores it did not earn.

**Why this priority**: the source requires reconcilable scores.

**Independent Test**: honest saves restore every result; edited results (stars, moves, trace) are dropped and counted.

### User Story 3 - Watch a winning replay (Priority: P2)

A player can watch the best solution they found for any solved level replayed move by move, without changing their
progress.

**Why this priority**: replay makes the saved scores visible and teaches.

**Independent Test**: replay of a stored trace reproduces the same fingerprints move by move and ends won; actions other
than stepping and stopping are refused during replay.

### Edge Cases

- **Interrupted write:** the shared store writes atomically, so either the earlier or the new state is read.
- **Damaged, edited or newer saves:** a damaged payload or a newer schema is refused with a named reason and the opening
  state is used; an edited result is dropped and counted while the rest is kept.
- **Old saves without traces (schema 2):** results are kept but marked unverified; they still open levels but cannot be
  replayed.
- **Deterministic seeds:** the opening level, the daily level and every certified level come from fixed seeds and dates,
  so the same save replays identically on every device.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0107-001**: The experience state (level, records, progress with traces, mode, tutorial step) MUST be a
  versioned snapshot (schema 3) that the shared store saves atomically, restoring to an identical digest.
- **FR-R02G0107-002**: Migration MUST bring schema 1 and schema 2 saves to schema 3 without losing progress; results
  without a trace are kept as unverified.
- **FR-R02G0107-003**: Each campaign or daily win MUST store the winning moves of the best result; on restore every
  verified result MUST be replayed on its certified level and dropped when it does not win in its recorded moves with its
  recorded stars; the number of dropped results MUST be reported.
- **FR-R02G0107-004**: A replay mode MUST play a stored trace move by move from a fresh level without changing progress,
  refusing other play actions with a named reason.
- **FR-R02G0107-005**: All randomness MUST derive from fixed seeds or the given calendar date; no clock or random source
  is read by the state.
- **FR-R02G0107-006**: Invalid requests MUST be refused with stable reason codes; existing tests pass; new public names
  documented; the reference regression passes.

### Key Entities

- **Result**: level, best moves, stars, the winning moves (trace), verified or not.
- **Snapshot schema 3**: level, records, progress (results with traces), mode, tutorial step.
- **Replay**: the level, the trace and the position in it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0107-001**: 500 seeded reachable states round-trip through the snapshot with equal digests.
- **SC-R02G0107-002**: Schema 1 and 2 payloads for 100 seeded states migrate and restore with progress kept.
- **SC-R02G0107-003**: For 200 seeded saves, every honest result survives restore and every edited result (stars,
  moves, trace step) is dropped and counted.
- **SC-R02G0107-004**: Every stored trace of the 100 certified levels replays to a win with the recorded fingerprints;
  replay never changes progress.
- **SC-R02G0107-005**: Existing tests pass; each test under 10 s; the reference regression passes 7 of 7.

## Assumptions

- The shared saved-state store (atomic write, quarantine of unreadable files, newer-schema refusal) is reused unchanged.
- Replay controls (start for a solved level, step, stop) join the existing scrolling, Dynamic Type panel of R02-G01-06,
  with labels and values; announcements of each replay step use the shared feedback route.
- All texts original; no network, no accounts.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Atomic saves | FR-R02G0107-001 (shared store) |
| Deterministic fixed seeds | FR-R02G0107-005 |
| Migration | FR-R02G0107-002 |
| Reconcilable scores | FR-R02G0107-003 |
| Replay | FR-R02G0107-004 |
| No Stage One breakage | FR-R02G0107-006 |

## Negative Requirements / Excluded scope

- No cloud sync, accounts, leaderboards or network; no purchases or ads; no device run before ImplementationLock-100.
