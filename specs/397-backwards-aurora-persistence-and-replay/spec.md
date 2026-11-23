# Feature Specification: R02-G10-07 — Backwards Aurora: persistence and replay

**Feature Branch**: `397-backwards-aurora-persistence-and-replay` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G10-07 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1007-###,
SC-R02G1007-###, T-R02G1007-###

**Input**: User description: the archived R02-G10-07 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Atomic saves, deterministic fixed seeds, migration and reconcilable scores" for Backwards Aurora, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/397-backwards-aurora-persistence-and-replay`; FR-R02G1007-###,
  SC-R02G1007-###, T-R02G1007-###.
- **Packaging (ADR-0009):** experience R02-G10 (`r02-g10.backwards-aurora`, free; a registered candidate) in
  `Packages/ExperiencesRound02/BackwardsAurora`; saving to disk is the one app's shared saved-state store (one atomic
  state file per experience, unreadable files quarantined, newer schemas refused); this feature defines what
  Backwards Aurora puts in it.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 76" milestone figure. **Device-only items:** a save surviving a real app termination on hardware is a
  D1–D3 observation after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** the saved-state store and migration chain of the experience contract (UA-F05), R02-F14
  (reversible history), R02-F24 progression, and R02-G10-01 … 06.
- **Model:** feature 387 (Nocturne Garden's persistence and replay), including the lesson of features 377, 367, 357, 347,
  337 and 327: the saved frontier is restored as saved (raising it from the kept results would open levels for an honest
  daily win).

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
387's answers where the games agree. Facts checked in code (read-only, 2026-11-23): the shared `SavedStateStore` keeps
one `state.json` per experience, writes it atomically, moves an unreadable file aside and refuses a newer schema; the
engine applies the experience's `MigrationChain`; Backwards Aurora's adapter writes snapshot schema 2 `{level, mode,
progress, records, tutorial}` with a 1 → 2 step; `BackwardsAuroraProgress.Result` keeps `reversalsMade` (the play's
reversal records, undone ones included) and `stars`; the play's records have kinds reverse, undo and redo; the controls
are `wave.reverse`, `play.undo`, `play.redo`, `level.next`, `level.select`, `mode.daily`, `mode.practice`,
`mode.campaign` and `tutorial.dismiss`; the presenter holds the sound choice (off by default) since R02-G10-06.

- Q: What is stored for each result, and when is it written? → A: each result keeps its fewest reversals made, its stars
  and the winning trace — the ordered effective reversals (start, end) of the play that earned it, each as the kernel
  applied it; a reversal that was undone and not redone is left out, so the trace never contains an undo or a redo —
  plus `verified`. Reversals made still counts every reversal record, undone ones included, as since R02-G10-05, so it
  is at least the trace's length. A campaign or daily win replaces the stored result only when it is better (ties keep
  the earlier trace); practice records nothing. The shared store writes at the app's save points; this feature does not
  change when. Impact: FR-R02G1007-001, 003; SC-R02G1007-001.
- Q: How are scores reconciled on restore? → A: for every result with a trace: the certified level is generated, a
  fresh play (campaign budget) replays the trace (each reversal legal), and the result is kept only if the play ends
  won, the trace's length is at most `reversalsMade`, and `stars` equals the stars rule for `reversalsMade` and the
  level's certified smallest reversal count; otherwise it is dropped. (A lowered `reversalsMade` can never claim fewer
  reversals than the trace proves; a raised one only worsens the score.) The adapter exposes the number dropped (never
  in the digest) and the presenter announces it once as `state` ("n saved results could not be checked and were
  removed.", "1 saved result could not be checked and was removed."). Results without a trace (schema 1 or 2) are kept,
  marked unverified. The frontier is restored as saved. Impact: FR-R02G1007-003; SC-R02G1007-003.
- Q: How do migrations work? → A: schema 3 adds the trace and `verified` to each result, the mode `replay(level)` and
  the sound choice. 1 → 2 is the existing step; 2 → 3 copies results with an empty trace and `verified: false` and sets
  the sound choice off. Schema 4 or newer is refused by the shared store; a damaged payload is refused with `damaged`
  and the opening state is used. Impact: FR-R02G1007-002, 007; SC-R02G1007-002.
- Q: How does replay work? → A: `replay.start [level]` opens mode `replay(level)` with a fresh play of that level when
  a verified result with a trace exists (`r02-g10.no-replay` otherwise); `replay.step` applies the next reversal of the
  trace (`r02-g10.replay-end` after the last or once the play ended); `replay.stop` returns to campaign at that level
  (the frontier when it is not open). During replay every other play control except `tutorial.dismiss` and
  `settings.sound` is refused with `r02-g10.replay` (the panel's section ends, the freeze preview and the camera are
  presentation only and stay allowed); replay never changes progress; the tutorial is done during replay. The refusals
  are shown and announced in words: "There is no saved solution to replay for this level.", "The replay is over." and
  "Stop the replay first."; a replayed win claims no stars. Impact: FR-R02G1007-004; SC-R02G1007-004.
- Q: Which inputs make the state deterministic, and how is the sound choice changed? → A: the seed (opening level),
  the certified catalog (fixed planned seeds), the calendar date given to `mode.daily` and the recorded actions; the
  state reads no clock and no random source. The sound choice is changed by `settings.sound [0 … 1]` (whole numbers; 1
  on), stored in the snapshot, never in the digest, and applied by the presenter when the experience opens or the
  value changes. Impact: FR-R02G1007-005, 007.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Progress is never lost or corrupted (Priority: P1) 🎯

A player who closes the app mid-level or after winning finds the same level, wave, reversals made, mode, stars and open
levels when they return; a damaged or interrupted save never loses earlier progress silently.

**Why this priority**: lost progress is the fastest way to lose a player.

**Independent Test**: any reachable state survives a save and restore exactly (equal digest); a damaged payload is
refused with a named reason and the earlier state stays.

**Acceptance Scenarios**:

1. **Given** a state with progress, a mode, a reshaped wave and reversals made, **When** it is saved and restored,
   **Then** the restored state has the same digest, progress, mode and tutorial step.
2. **Given** a save from an earlier schema, **When** it is restored, **Then** it migrates without losing progress.

### User Story 2 - Scores that can be checked (Priority: P1)

Every recorded result (fewest reversals made and stars) carries the winning reversals that earned it; on restore each result is
replayed on its certified level and kept only if the replay wins with the recorded reversals made and stars, so an edited
save cannot claim scores it did not earn.

**Why this priority**: the source requires reconcilable scores.

**Independent Test**: honest saves restore every result; edited results (stars, reversals made, trace) are dropped and
counted.

### User Story 3 - Watch a winning replay (Priority: P2)

A player can watch the best solution they found for any solved level replayed reversal by reversal, without changing their
progress.

**Why this priority**: replay makes the saved scores visible and teaches the folds.

**Independent Test**: replay of a stored trace reproduces the same fingerprints reversal by reversal and ends won; play actions
other than stepping and stopping are refused during replay.

### Edge Cases

- **Interrupted write:** the shared store writes atomically, so either the earlier or the new state is read.
- **Damaged, edited or newer saves:** a damaged payload or a newer schema is refused with a named reason and the opening
  state is used; an edited result is dropped and counted while the rest is kept.
- **Old saves without traces (schema 1 or 2):** results are kept but marked unverified; they still open levels but
  cannot be replayed.
- **Undone reversals:** a stored trace holds only the effective reversals of the winning play in order (an undone
  reversal and its undo are left out), so replay never needs an undo; reversals made still counts undone ones, so it is
  at least the trace's length.
- **Deterministic seeds:** the opening level, the daily level and every certified level come from fixed seeds and dates,
  so the same save replays identically on every device.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1007-001**: The experience state (level, records, progress with traces, mode, tutorial step, sound choice)
  MUST be a versioned snapshot (schema 3) that the shared store saves atomically, restoring to an identical digest.
- **FR-R02G1007-002**: Migration MUST bring schema 1 and schema 2 saves to schema 3 without losing progress; results
  without a trace are kept as unverified.
- **FR-R02G1007-003**: Each campaign or daily win MUST store the winning reversals of the best result; on restore every
  verified result MUST be replayed on its certified level and dropped unless it wins with at most its recorded reversals
  made and its stars match the stars rule for them; the number of dropped results MUST be reported.
- **FR-R02G1007-004**: A replay mode MUST play a stored trace reversal by reversal from a fresh level without changing progress,
  refusing other play actions with a named reason.
- **FR-R02G1007-005**: All randomness MUST derive from fixed seeds or the given calendar date; no clock or random source
  is read by the state.
- **FR-R02G1007-006**: Invalid requests MUST be refused with stable reason codes; existing tests pass; new public names
  documented; the reference regression passes.
- **FR-R02G1007-007**: The player's settings MUST persist: the sound choice (the game's only setting of its own) is part
  of the snapshot (not the digest), changed by `settings.sound [0 … 1]` and applied when the experience opens; migrated
  saves default it to off.

### Key Entities

- **Result**: level, fewest reversals made (undone ones included), stars, the winning effective reversals (trace), verified or
  not.
- **Snapshot schema 3**: level, records, progress (results with traces), mode, tutorial step, sound choice.
- **Replay**: the level, the trace and the position in it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1007-001**: 500 seeded reachable states round-trip through the snapshot with equal digests; the sound choice
  (on and off) survives the round trip and changes no digest.
- **SC-R02G1007-002**: Schema 1 and 2 payloads for 100 seeded states migrate and restore with progress kept.
- **SC-R02G1007-003**: For 200 seeded saves, every honest result survives restore and every edited result (stars,
  reversals made below the trace's length, trace step) is dropped and counted.
- **SC-R02G1007-004**: Every stored trace of the 100 certified levels replays to a win with the recorded fingerprints;
  replay never changes progress.
- **SC-R02G1007-005**: Existing tests pass; each test under 10 s; the reference regression passes 7 of 7.

## Assumptions

- The shared saved-state store (atomic write, quarantine of unreadable files, newer-schema refusal) is reused unchanged.
- Replay controls (start for a solved level, step, stop) join the accessible panel of R02-G10-06, with labels and
  values; announcements of each replay step use the shared feedback route.
- All texts original; no network, no accounts.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Atomic saves | FR-R02G1007-001 (shared store) |
| Deterministic fixed seeds | FR-R02G1007-005 |
| Migration | FR-R02G1007-002 |
| Reconcilable scores | FR-R02G1007-003 |
| Replay | FR-R02G1007-004 |
| Settings | FR-R02G1007-007 |
| No Stage One breakage | FR-R02G1007-006 |

## Negative Requirements / Excluded scope

- No cloud sync, accounts, leaderboards or network; no purchases or ads; no device run before ImplementationLock-100; no
  availability before X-R02-G10.
