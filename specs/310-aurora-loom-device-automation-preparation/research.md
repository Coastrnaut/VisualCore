# Research: R02-G01-10

- **R1 — Form of the contract.** Decision: one JSON definition plus a written plan, like A21's `device-campaign.md`
  with a machine-readable twin. Rationale: UA-F13's script needs data, the owner needs prose; the check keeps them tied.
  Alternatives: prose only (rejected: not checkable); a Swift type (rejected: no Swift change needed before UA-F13).
- **R2 — Coverage source.** Decision: the open `{device}` task lines of `specs/30[1-9]-aurora-loom-*/tasks.md` (features 301–309; 310's own campaign task excluded) plus the
  six UA-F13 measurement names. Rationale: those lines are where earlier features deferred their device proof; scanning
  them makes a forgotten item fail the check. The R02-G01-06 items (hearing, feeling, VoiceOver) are named in its
  header, not a task line, so the definition lists them as `R02-G01-06:sound`, `R02-G01-06:haptics`,
  `R02-G01-06:voiceover`, and the check requires those three ids too.
- **R3 — Scenario set.** Decision: 11 standard and game scenarios plus `fixture-replay`. Rationale: they exercise launch,
  input, persistence, lifecycle and the full game on hardware; the 80 acceptance rows are pure rule outcomes already
  proven on the host and simulator.
