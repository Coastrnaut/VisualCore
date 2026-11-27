# Feature Specification: R02-G21-07 — Binary Gardens: persistence and replay

**Feature Branch**: `507-binary-gardens-persistence-and-replay` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-07 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2107-###,
SC-R02G2107-###, T-R02G2107-###

**Input**: User description: the archived R02-G21-07 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Atomic saves, deterministic fixed seeds, migration and reconcilable scores" for Binary Gardens, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/507-binary-gardens-persistence-and-replay`; FR-R02G2107-###, SC-R02G2107-###,
  T-R02G2107-###.
- **Packaging (ADR-0009):** experience R02-G21 (`r02-g21.binary-gardens`, free; a registered candidate since
  R02-G21-03) in `Packages/ExperiencesRound02/BinaryGardens`; saving to disk is the one app's shared saved-state store
  (one atomic state file per experience, unreadable files quarantined, newer schemas refused); this feature defines what
  Binary Gardens puts in it. No app target, bundle identifier, XcodeGen scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and its
  prior-round device prerequisites, the "content count 81" milestone figure (the 100 certified levels of R02-G21-02
  stand) and the paths `Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore`; entitlement comes from the
  shared purchase controller (tier free). **Device-only items:** a save surviving a real app termination on hardware is a
  D1–D3 observation after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** the saved-state store and migration chain of the experience contract (UA-F05), R02-F14
  (reversible history), R02-F23 (puzzle contract), R02-F24 progression, R02-F26 (accessibility and the shared feedback
  route), and R02-G21-01 … 06.
- **Prerequisites not yet in code (planned, specified and tasked, 2026-11-27):** R02-G21-04 (feature 504, in progress:
  its core parts — the view orbit, the picker, the gesture controller and the snapshot additions — are committed, its
  panel and presenter work is not), R02-G21-05 (feature 505: progress and stars, the modes campaign, practice and
  daily, the state-derived tutorial with `tutorial.dismiss`, `level.select`, the codes `r02-g21.locked` and
  `r02-g21.date`, snapshot schema 2 and digest domain v2) and R02-G21-06 (feature 506: announcements, haptics, eased
  lights and the presenter-held Sound toggle, off by default). This feature builds on them and is implemented after all
  three gates are recorded; where a requirement below names their parts, it names them as prerequisites.
- **Model:** feature 497 (Mushroom Weather's persistence and replay, itself modelled on feature 487), adapted to ring,
  phase, luminosity and tilt actions, the run of the light and the shown tick, including the lesson carried since
  feature 327: the saved frontier is restored as saved (raising it from the kept results would open levels for an honest
  daily win).

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
497's answers where the games agree. Facts checked in committed code (read-only, 2026-11-27):

- **Shared store:** `SavedStateStore` (VisualCoreExperience) keeps one `state.json` per experience folder, writes a
  hidden temporary file and then replaces the target (a reader sees the earlier or the new complete state), moves a file
  it cannot read aside as `quarantine-<n>.json` (at most 3 kept) before writing, and reports a state of a newer schema
  as `snapshot.newer-schema`; the engine applies the experience's `MigrationChain`.
- **Adapter (feature 503):** `BinaryGardensExperienceCore` writes snapshot schema 1 `{"level", "records"}` (sorted
  keys), has no migration steps, digests `"r02-g21.binary-gardens.v1"` (the level number and the play fingerprint),
  declares nine controls (`star.ring`, `star.phase`, `star.luminosity`, `orbit.tilt`, `light.run`, `play.undo`,
  `play.redo`, `level.next`, `clock.show`), refuses a restore as `BinaryGardensRestoreRefusal` (`damaged`,
  `levelNumber(n)`, `kernel(error)`), restores by replaying the records on a fresh play of the saved level, and shows
  tick 48 at an opening, after `level.next`, a reset and a restore; the shown tick (1 … 48) is presentation, kept by
  every accepted action and never advanced by time; the core reads no clock.
- **Kernel (feature 501):** `BinaryGardensRecord` carries the schema, the level seed, its 0-based index, the kind, the
  action and the fingerprints before and after; the kinds are ring, phase, luminosity, tilt, run, undo, redo, begin,
  dismissTutorial, pause, resume and showResult; `BinaryGardensAction` (Codable) is `ring(star:index:)`,
  `phase(star:step:)`, `luminosity(star:index:)`, `tilt(step:)` or `run`; each arrangement action spends 1 action, the
  run spends none and ends the level won or failed; undo and redo restore exact moments (the play's own actions spent
  included), undo works in a failed play and returns it to playing, a won play is final;
  `BinaryGardensPlay.replay(level:records:)` reproduces every record and fingerprint or throws `r02-g21.malformed`;
  level budgets lie in 1 … 24 (`BinaryGardensLevel.budgets`).
- **Content (feature 502):** the 100 witnesses `docs/games/binary-gardens/levels/NNN.witness.json` store the actions (the
  certified plan, then the run) and the play fingerprints after `begin`, after `dismissTutorial` on a tutorial level and
  after each action; `BinaryGardensPlan.size` is the plan's arrangement actions without the run.
- **Presenter (feature 503):** a refusal is shown with words from `BinaryGardensMirror.refusalText(code:)`; there is no
  sound, sound choice, replay or announcement in the experience today.
- **From the prerequisite specifications (not yet in code):** feature 505 makes the snapshot schema 2
  `{"level", "mode", "progress", "records", "tutorial"}` with a 1 → 2 step, digest domain `"r02-g21.binary-gardens.v2"`
  (level, play fingerprint, progress, mode), `BinaryGardensProgress` (least actions spent and stars per level, the
  frontier; actions spent count every accepted ring, phase, luminosity and tilt record, undone ones included),
  `BinaryGardensMode` (`campaign`, `practice` with budget 24 on a copy of the level, `daily(level)`) and five controls
  (`level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`); feature 506 adds the Sound toggle
  held by the presenter (off by default, presentation only, "saving it is R02-G21-07") and the announcement kinds
  `rejection`, `outcome`, `level` and `state`.

- Q: What is stored for each result, and when is it written? → A: each result keeps its least actions spent, its stars
  and the winning trace — the ordered effective actions of the play that earned it (a ring change with its star and ring
  index, a phase change with its star and step, a luminosity change with its star and index, a tilt change with its
  step), each as the kernel applied it, followed by the run; an action that was undone and not redone is left out (a
  failed run that was undone included), so the trace never contains an undo or a redo — plus `verified`. Actions spent
  still count every ring, phase, luminosity and tilt record, undone ones included, as since R02-G21-05, so they are at
  least the actions the trace spends (the run spends none). A campaign or daily win replaces the stored result only when
  it spends fewer actions (ties keep the earlier trace); practice and replay record nothing. The shared store writes at
  the app's save points; this feature does not change when. Impact: FR-R02G2107-001, 003; SC-R02G2107-001.
- Q: How are scores reconciled on restore? → A: for every result with a trace or marked verified: the certified level is
  generated, a fresh play (campaign budget, begun with its tutorial dismissed as the adapter does) replays the trace
  (each arrangement action accepted while the play is playing, then exactly one final run), and the result is kept only
  if the play ends won, the actions the trace spends are at most `actionsSpent`, and `stars` equals the stars rule for
  `actionsSpent` and the level's certified action count; otherwise it is dropped. A trace longer than 64 actions, an
  action the kernel refuses, an action after the run, a failing run, a trace without a final run and a result marked
  verified with an empty trace never verify (an honest trace holds at most 24 arrangement actions and the run). The
  adapter exposes the number dropped (never in the digest or `==`) and the presenter announces it once as `state` ("n
  saved results could not be checked and were removed.", "1 saved result could not be checked and was removed.").
  Results without a trace that are not marked verified (written under schema 1 or 2) are kept, unverified. The frontier
  is restored as saved. Impact: FR-R02G2107-003, 009; SC-R02G2107-003.
- Q: How do migrations work? → A: schema 3 adds the trace and `verified` to each result, the mode `replay(level)` and
  the sound choice. 1 → 2 is feature 505's step; 2 → 3 copies results with an empty trace and `verified: false` and sets
  the sound choice off. Schema 4 or newer is refused by the shared store (`snapshot.newer-schema`); a damaged payload is
  refused with `damaged` and the opening state is used. Impact: FR-R02G2107-002, 007; SC-R02G2107-002.
- Q: How does replay work, and what does it do with the shown tick? → A: `replay.start [level]` (1 … 100) opens mode
  `replay(level)` with a fresh play of that level (campaign budget), tick 48 shown and the tutorial done, when a
  verified result with a trace exists (`r02-g21.no-replay` otherwise; during a replay it restarts it); `replay.step`
  applies the next action of the trace — a ring, phase, luminosity or tilt action, or finally the run
  (`r02-g21.replay-end` after the last or once the run ended; `r02-g21.no-replay` outside replay); `replay.stop` returns
  to campaign at that level (the frontier when it is not open; `r02-g21.no-replay` outside replay). Replay steps by
  action, never by time: a step keeps the shown tick (the report always covers ticks 1 … 48), and `clock.show` stays
  allowed so the player can scrub the cycle at any step. During replay every other control except `tutorial.dismiss`
  and `clock.show` (presentation) and `settings.sound` is refused with `r02-g21.replay` (the panel's selected star,
  previews, inspections and the view are presentation only and stay allowed, but an action they would send is refused);
  replay never records a result and never changes progress. The refusals are shown and announced in words: "There is
  no saved solution to replay for this level.", "The replay is over." and "Stop the replay first."; a replay step is
  announced and felt like the action it applies, and a replayed win claims no stars. A save taken during a replay
  restores the replay only when its ring, phase, luminosity, tilt and run records are exactly the first actions of that
  level's verified trace, in order, with no undo or redo; otherwise it is refused as `damaged`. A restored replay whose
  result did not survive reconciliation, or was not verified, returns to campaign at that level (the frontier when it is
  not open). Impact: FR-R02G2107-004, 008; SC-R02G2107-004, 006.
- Q: Which inputs make the state deterministic, and how is the sound choice changed? → A: the seed (opening level), the
  certified catalog (fixed planned seeds and the certified candidates), the calendar date given to `mode.daily` and the
  recorded actions; the state reads no clock and no random source, and the shown tick never moves by time. The sound
  choice is changed by `settings.sound [0 … 1]` (whole numbers, `r02-g21.not-whole` otherwise; 1 on, 0 off; allowed in
  every mode), stored in the snapshot (key `"sound"`), part of `==` but never of the digest, and applied by the presenter
  when the experience opens or the value changes (replacing R02-G21-06's presenter-only choice); a reset turns it off.
  Impact: FR-R02G2107-005, 007.
- Q: Which existing tests may change? → A: only the assertions this feature deliberately changes, updated in place and
  named in the tasks: the declared control list (four new controls: `replay.start`, `replay.step`, `replay.stop`,
  `settings.sound`), the schema version 3 (the newer-schema refusal test's literal versions in
  `BinaryGardensExperienceCoreTests` and the `schemaVersion` assertion in `BinaryGardensSceneSnapshotTests` included),
  the digest domain v3 (over the level, the play fingerprint, the progress with its traces and the mode; never the
  tutorial step, the shown tick, the sound choice or the dropped count), and R02-G21-06's presenter-held sound choice, which
  now comes from the state. Every other existing test passes unchanged. Impact: FR-R02G2107-006; SC-R02G2107-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Progress is never lost or corrupted (Priority: P1) 🎯

A player who closes the app mid-level or after winning finds the same level, stars' rings, phases and luminosities, tilt,
actions left, mode, stars and open levels when they return; a damaged or interrupted save never loses earlier progress
silently.

**Why this priority**: lost progress is the fastest way to lose a player.

**Independent Test**: any reachable state survives a save and restore exactly (equal digest); a damaged payload is
refused with a named reason and the earlier state stays.

**Acceptance Scenarios**:

1. **Given** a state with progress, a mode and a changed arrangement, **When** it is saved and restored, **Then** the
   restored state has the same digest, progress, mode, tutorial step and sound choice, and shows tick 48.
2. **Given** a save from schema 1 or schema 2, **When** it is restored, **Then** it migrates without losing progress
   and the sound choice is off.
3. **Given** a payload that is not valid JSON of its schema, **When** it is restored, **Then** it is refused as
   `damaged` and the opening state is used.

### User Story 2 - Scores that can be checked (Priority: P1)

Every recorded result (least actions spent and stars) carries the winning actions that earned it; on restore each
result is replayed on its certified level and kept only if the replay wins within the recorded actions spent and the
stars match, so an edited save cannot claim scores it did not earn.

**Why this priority**: the source requires reconcilable scores.

**Independent Test**: honest saves restore every result; edited results (stars, actions spent, trace) are dropped and
counted.

**Acceptance Scenarios**:

1. **Given** a campaign win of a level with one undone ring change, **When** the state is saved and restored, **Then**
   the result is kept, verified, with a trace that leaves the undone change out.
2. **Given** a saved result whose stars were raised, **When** it is restored, **Then** it is dropped, the dropped count
   is 1, the other results are kept and the frontier is unchanged.

### User Story 3 - Watch a winning replay (Priority: P2)

A player can watch the best solution they found for any solved level replayed action by action — each ring move, phase
shift, brightness change and tilt, then the run of the light — and scrub the cycle at any step, without changing their
progress.

**Why this priority**: replay makes the saved scores visible and shows which star had to move, shift or brighten and
how far the plane had to tilt for every world to keep its light over the whole cycle.

**Independent Test**: replay of a stored trace reproduces the same fingerprints action by action and ends won; play
actions other than stepping, stopping, showing a tick and the sound setting are refused during replay.

**Acceptance Scenarios**:

1. **Given** a verified result for level k, **When** the player starts its replay and steps to the end, **Then** each
   step's play fingerprint equals the recorded one, the replay ends won and the progress is unchanged.
2. **Given** a replay in progress, **When** the player asks for a ring change, **Then** it is refused with
   `r02-g21.replay` and announced as "Stop the replay first."
3. **Given** a level without a verified result, **When** the player starts a replay, **Then** it is refused with
   `r02-g21.no-replay`.

### Edge Cases

- **Interrupted write:** the shared store writes atomically, so either the earlier or the new state is read.
- **Damaged, edited or newer saves:** a damaged payload or a newer schema is refused with a named reason and the opening
  state is used; an edited result is dropped and counted while the rest is kept.
- **Old saves without traces (schema 1 or 2):** results are kept but marked unverified; they still open levels but
  cannot be replayed.
- **Undone actions:** a stored trace holds only the effective ring, phase, luminosity and tilt actions of the winning
  play in order, then the run (an undone action and its undo are left out, and so is a failed run that was undone), so
  replay never needs an undo; the actions spent still count undone actions, so they are at least the actions the trace
  spends.
- **A save taken during a replay:** it restores the replay only when its records are exactly the first actions of that
  level's verified trace; otherwise the payload is refused as `damaged` and the opening state is used.
- **A replay whose result was dropped on restore:** it returns to campaign at that level, or the frontier when that
  level is not open.
- **Practice wins and the practice budget:** practice records nothing, so no stored trace needs more than a campaign
  budget; reconciliation always replays with the campaign budget.
- **The shown tick, the panel's selected star, previews, the inspected world, the hint level and the view:**
  presentation only; not saved, so a restored state shows tick 48, the panel's default selection, no preview, no
  inspection, hint level 1 and the authored view.
- **Restore work:** at most 100 results, each a replay of at most 64 actions on a certified level that is generated once
  per process (the first use of a level in a process runs its certifying solver, at most 5,000 arrangements judged;
  later restores in the process reuse it); no other search runs during a restore.
- **Deterministic seeds:** the opening level, the daily level and every certified level come from fixed seeds and dates,
  so the same save replays identically on every device.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2107-001**: The experience state (level, records, progress with traces, mode, tutorial step, sound choice)
  MUST be a versioned snapshot (schema 3) that the shared store saves atomically, restoring to an identical digest.
- **FR-R02G2107-002**: Migration MUST bring schema 1 and schema 2 saves to schema 3 without losing progress; results
  without a trace are kept as unverified.
- **FR-R02G2107-003**: Each campaign or daily win MUST store the winning actions of the best result; on restore every
  result with a trace or marked verified MUST be replayed on its certified level and dropped unless it wins spending at
  most its recorded actions and its stars match the stars rule for those actions; the frontier is restored as saved and
  the number of dropped results MUST be reported.
- **FR-R02G2107-004**: A replay mode MUST play a stored trace action by action from a fresh level without changing
  progress, keeping the shown tick and allowing `clock.show`, and refusing other play actions with a named reason.
- **FR-R02G2107-005**: All randomness MUST derive from fixed seeds or the given calendar date; no clock or random source
  is read by the state.
- **FR-R02G2107-006**: Invalid requests MUST be refused with stable reason codes (`r02-g21.no-replay`,
  `r02-g21.replay-end`, `r02-g21.replay` and the existing codes, `r02-g21.not-whole` among them for the new controls'
  values); existing tests pass apart from the
  named assertions this feature changes; new public names are documented with `///`; the reference regression passes.
- **FR-R02G2107-007**: The player's settings MUST persist: the sound choice (the game's only setting of its own) is part
  of the snapshot (not the digest), changed by a settings control and applied when the experience opens; migrated saves
  default it to off.
- **FR-R02G2107-008**: The replay controls (Replay for a level with a verified result, Step, Stop) and the replay
  position MUST appear in the control panel with accessibility labels, values and identifiers; replay refusals and the
  dropped-result count MUST be shown and announced in words through the shared feedback route.
- **FR-R02G2107-009**: The number of dropped results and the reason of a refused restore MUST be kept for diagnostics,
  and refused replay actions MUST be logged by reason code as the presenter logs other refusals.

### Key Entities

- **Result**: level, least actions spent (undone changes included), stars, the winning effective actions (trace: ring,
  phase, luminosity and tilt actions, then the run), verified or not.
- **Snapshot schema 3**: level, mode (campaign, practice, daily or replay with its level), progress (results with
  traces), records, sound choice, tutorial step.
- **Replay**: the level, the trace and the position in it (the trace actions applied).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2107-001**: 500 seeded reachable states round-trip through the snapshot with equal digests; the sound choice
  (on and off) survives the round trip and changes no digest.
- **SC-R02G2107-002**: Schema 1 and 2 payloads for 100 seeded states migrate and restore with progress kept and the
  sound choice off.
- **SC-R02G2107-003**: For 200 seeded saves, every honest result survives restore and every edited result (stars,
  actions spent below what the trace spends, a trace step, an illegal, failing, run-less or overlong trace) is dropped
  and counted; the frontier never changes.
- **SC-R02G2107-004**: Every stored trace of the 100 certified levels (won through the adapter with the certified
  actions and the run) replays to a win with the fingerprints of its witness file; replay never changes progress.
- **SC-R02G2107-005**: Existing tests pass apart from the named assertions this feature changes; each new test finishes
  under 10 s on the host (asserted locally only, never on CI); the reference regression passes 7 of 7.
- **SC-R02G2107-006**: Through the experience port on the iOS 27 simulator, a replay reproduces the fingerprints action
  by action and ends won, other actions are refused during replay, the dropped count is announced exactly once, and a
  restored sound choice is applied when the experience opens.
- **SC-R02G2107-007** {device}: after ImplementationLock-100, a save survives a real app termination on D1, D2 and D3.

## Assumptions

- The shared saved-state store (atomic write, quarantine of unreadable files, newer-schema refusal) is reused unchanged.
- R02-G21-04, R02-G21-05 and R02-G21-06 are recorded before this feature is implemented; their progress, modes,
  tutorial, panel and feedback route are used as specified.
- Replay controls join the accessible panel of R02-G21-06, with labels and values; announcements of each replay step
  use the shared feedback route.
- Error handling: refusals carry stable reason codes and are shown and announced in words (R02-G21-06); a refused
  restore uses the opening state and is logged. Observability: the number of dropped results and the restore refusal
  reason are kept for diagnostics.
- The stored schema examples of earlier schemas for the app registry come with R02-G21-09.
- All texts original; no network, no accounts.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Atomic saves | FR-R02G2107-001 (shared store) |
| Deterministic fixed seeds | FR-R02G2107-005 |
| Schema migration | FR-R02G2107-002 |
| Reconcilable scores | FR-R02G2107-003 |
| Replay | FR-R02G2107-004 |
| Settings | FR-R02G2107-007 |
| Error handling, no Stage One breakage | FR-R02G2107-006 |
| Accessibility | FR-R02G2107-008 |
| Observability | FR-R02G2107-009 |
| Deterministic tests | SC-R02G2107-001 … 004 |
| Nonfunctional (bounded restore work, timing, regression) | FR-R02G2107-006; SC-R02G2107-005 |

## Negative Requirements / Excluded scope

- No cloud sync, accounts, leaderboards or network; no purchases or ads; no new art, model or shader; no device run
  before ImplementationLock-100; no availability before X-R02-G21.
