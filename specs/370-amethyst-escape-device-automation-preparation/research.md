# Research: R02-G07-10

- **R1 — Form of the contract.** Decision: feature 310's JSON definition plus a written plan. Rationale: UA-F13's
  script needs data, the owner needs prose; the check keeps them tied. Alternatives: a new format (rejected: one
  campaign script must read every experience alike).
- **R2 — Coverage source.** Decision: the open `{device}` task lines of `specs/36[1-9]-amethyst-escape-*/tasks.md`
  plus the six UA-F13 measurement names, as the check already computes for R02-G07. Rationale: every Amethyst Escape device
  promise, including R02-G07-06's hearing, feeling and VoiceOver, is a task line (T-R02G0706-011), so no extra items are
  added to the check's table.
- **R3 — Scenario set.** Decision: 11 standard and game scenarios plus `fixture-level-1-solved`. Rationale: they
  exercise launch, input, persistence, lifecycle and the full game on hardware, and the fixture proves a stored win
  restores on the device; the acceptance rows and the other fixtures are pure rule outcomes proven on host and
  simulator.
- **R4 — Release step.** Decision: a second step `device-rows-r02-g07` beside `device-rows`. Rationale: the existing
  step name stays stable for its recorded evidence; each experience fails separately.
