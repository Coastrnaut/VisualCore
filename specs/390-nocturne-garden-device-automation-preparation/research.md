# Research: R02-G09-10

- **R1 — Form of the contract.** Decision: feature 310's JSON definition plus a written plan. Rationale: UA-F13's script
  needs data, the owner needs prose; the check keeps them tied. Alternatives: a new format (rejected: one campaign
  script must read every experience alike).
- **R2 — Coverage source.** Decision: the open `{device}` task lines of `specs/37[1-9]-nocturne-garden-*/tasks.md` plus
  the six UA-F13 measurement names, as the check already computes for R02-G09. Rationale: every Nocturne Garden device
  promise, including R02-G09-06's hearing, feeling and VoiceOver, is a task line (T-R02G0906-011), so no extra items are
  added to the check's table.
- **R3 — Scenario set.** Decision: 11 standard and game scenarios plus `fixture-level-1-solved`. Rationale: they
  exercise launch, input, persistence, lifecycle and the full game on hardware, and the fixture proves a stored win
  restores on the device; the acceptance rows and the other fixtures are pure rule outcomes proven on host and
  simulator.
- **R4 — Release step.** Decision: a second step `device-rows-r02-g09` beside `device-rows`. Rationale: the existing
  step name stays stable for its recorded evidence; each experience fails separately.
