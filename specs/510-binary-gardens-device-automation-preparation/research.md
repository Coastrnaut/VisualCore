# Research: R02-G21-10

- **R1 — Form of the contract.** Decision: feature 310's JSON definition plus a written plan, as feature 500 shipped
  them. Rationale: UA-F13's script needs data, the owner needs prose; the check keeps them tied. Alternatives: a new
  format (rejected: one campaign script must read every experience alike).
- **R2 — Coverage source.** Decision: the open `{device}` task lines of `specs/50[1-9]-binary-gardens-*/tasks.md` plus
  the six UA-F13 measurement names, as the check already computes for R02-G21 (range 501 … 509). Rationale: every
  Binary Gardens device promise, including R02-G21-06's hearing, feeling and VoiceOver, is a task line
  (T-R02G2106-011); 501, 502 and 505 have none, so no extra items are added to the check's table.
- **R3 — Scenario set.** Decision: 11 standard and game scenarios plus `fixture-level-1-solved`. Rationale: they
  exercise launch, input, persistence, lifecycle and the full game on hardware, and the fixture proves a stored win
  restores on the device; the 80 acceptance rows and `fixture-run-fails`, `fixture-undo-redo` are pure rule
  outcomes proven on host and simulator.
- **R4 — Release step.** Decision: a step `device-rows-r02-g21` after `device-rows-r02-g20`. Rationale: existing step
  names stay stable for their recorded evidence; each experience fails separately.
- **R5 — Row wording.** Decision: BG-D4 names feature 504's gestures and constants (tap under 10 points and 0.5 s, drag
  from 16 points, one luminosity or tilt step per 32 points, double tap within 0.35 s and 22 points); BG-D8 follows
  feature 509's journey (level 1's one-action plan: star 2 to luminosity index 0, "level 1 of 2", then Run, 3 of 3
  stars, relaunch). Rationale: the rows describe the experience as 504 … 509 leave it; controls that 505 … 507 add are
  written from their specifications and re-read at their record.
