# Research: R02-G21-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (VisualCoreExperience: atomic
  write-then-replace, quarantine of unreadable files, at most 3 kept, newer-schema refusal) and the engine's
  `MigrationChain` (VisualCorePersistence). Rationale: one audited path for every experience; this feature only defines
  the payload.
- **R2 Trace per result.** Decision: store the winning play's effective actions (each ring, phase, luminosity and tilt
  action as the kernel applied it, an undone action left out unless redone, a failed run that was undone left out,
  then `.run`), not the kernel records. Rationale: actions are the minimal, replayable proof; the net list (each
  arrangement action or run appends and clears the redo list, each undo moves the last net action to it, each redo
  moves it back; begin, dismissTutorial, pause, resume and showResult skipped) needs no undo in replay; a level is won
  only by its run and a won play is final, so every honest trace ends with exactly one `.run`. Alternative: storing
  undo and redo (replay would need undo; rejected by clarification Q1).
- **R3 Reconciliation on restore.** Decision: replay each trace with a trace or marked verified on a fresh play of its
  certified level (campaign budget, begun with its tutorial dismissed, `BinaryGardensExperienceCore.freshPlay`); keep
  the result only when the play wins, the actions the trace spends (the replayed play's `actionsSpent`, net by
  construction) are at most `actionsSpent` and `stars` is 505's stars rule for `actionsSpent` against
  `generated(number:).plan.size`; report the count dropped. Rationale: an edited save cannot claim unearned scores;
  honest saves lose nothing. Results without a trace not marked verified (schemas 1 and 2) are kept, unverified.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 327 … 497).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels;
  lowering it on a drop would close levels an honest player opened.
- **R5 Replay as a mode.** Decision: `replay(level)` in `BinaryGardensMode` with `replay.start/step/stop` in the core,
  so a replay is part of the deterministic state, saved and testable on the host. The position is the count of ring,
  phase, luminosity, tilt and run records of the play (a replay never undoes); `replay.step` refuses with
  `r02-g21.replay-end` once that count reaches the trace's length or the play has left `playing`.
- **R6 Trace bound.** Decision: a trace with more than 64 actions, an action the kernel refuses, an action after the
  run, a failing run or no final run never verifies, nor a result marked verified with an empty trace. The kernel's
  budget is at most 24, so an honest trace has at most 25 actions; the bound only stops an edited save from making the
  check replay a long list (at most 100 × 64 = 6,400 kernel actions per restore).
- **R7 Actions spent versus trace.** Decision: `actionsSpent` keeps counting undone arrangement actions (R02-G21-05's
  rule), so reconciliation requires the trace's actions to be at most `actionsSpent`, not equal. Rationale: an honest
  play with undos spends more than its effective actions; a lowered `actionsSpent` still cannot claim less than the
  replay proves, and a raised one only lowers the stars, which must then match the rule.
- **R8 The shown tick in replay.** Decision: replay steps by action, never by time; `replay.start` shows tick 48 as
  every fresh play does, a step keeps the shown tick (the report always covers ticks 1 … 48), and `clock.show` stays
  allowed during replay. Rationale: the shown tick is presentation (feature 503, R12) and is never saved, so a restored
  replay shows tick 48.
- **R9 Sound choice in the state.** Decision: `settings.sound [0 … 1]` sets `soundOn`, stored under `"sound"`, in `==`,
  never in the digest; a reset and a migrated save turn it off; the presenter applies it when the experience opens and
  when it changes, replacing 506's presenter-held choice. Rationale: the only setting of the game must survive a
  restart; a presentation choice must not change the state's identity.
- **R10 Digest v3.** Decision: `"r02-g21.binary-gardens.v3"` over the level number, the play fingerprint, the progress
  (with traces and `verified`) and the mode, as feature 497's v3; never the tutorial step, the shown tick, the sound
  choice or the dropped count. Rationale: progress now carries traces, so the domain string changes with its shape.
- **R11 Certified levels once per process.** Decision: reconciliation reads `generated(number:)`, the adapter's
  per-process cache. Consequence: the first restore in a process certifies each traced level once (the solver judges at
  most 5,000 arrangements per level; the whole-catalog fallback only if a certified candidate stopped certifying, which
  the catalog tests guard); later restores replay only. Alternative: rebuild the candidate without the solver and take
  the band's plan length (rejected: it would trust an uncertified level and diverge from feature 497).
- **R12 A saved replay.** Decision: a payload in mode `replay(k)` names level k, and when its result is verified its
  ring, phase, luminosity, tilt and run records are exactly the first actions of the saved trace in order with no undo
  or redo (event records skipped), otherwise `damaged`; after reconciliation, a replay whose result was dropped or is
  unverified returns to campaign at k (the frontier when k is not open). Rationale: a replay must never carry an
  arrangement the trace did not produce.
