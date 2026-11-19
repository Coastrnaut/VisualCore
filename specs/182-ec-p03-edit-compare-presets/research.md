# Research: A25-P03 (feature 182)

- **R1 Gates over the earlier phase map.** Decision: the manual's per-phase gates decide each phase's scope; presets
  come forward to P03, import moves to P04, export to P05. Rationale: the gates are the acceptance criteria.
- **R2 Library after GraphLibrary.** Decision: one file per preset and an index; files are the truth. Rationale: proven
  refusal and recovery rules (A23-P04), no deletion without the person.
- **R3 Replace edit.** Decision: open = one `replace` edit. Rationale: undo returns to the chain before opening.
- **R4 Audit through runObserver.** Decision: observe every validated run. Rationale: covers every pass the host draws,
  not just the plan.
