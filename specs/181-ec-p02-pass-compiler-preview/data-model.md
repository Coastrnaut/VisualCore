# Data Model: A25-P02

- **PassPlan:** passes [PlanPass(node: EffectNode?, input: .source | .slot(0|1), output: .slot(0|1) | .result)],
  `slotsUsed` (0…2), lifetimes (slot → the intervals writer…reader in pass order; a slot is written again from the
  fourth enabled node on, so each slot holds a list of intervals `k…k+1`); an empty chain gives one copy pass.
- **ComposerCore:** chain (EffectChain), history (EditHistory, not stored), lastRefusal (rule id or nil); snapshot
  schema 1 = the chain file's body; digest `a25.effects-composer.v1`.
- **ProgramDiagnostic:** effect (EffectID), line (Int), message (String).
- **Pool cap:** at most 4 targets alive per preview (source, two slots, result), each at most 2,048 × 2,048.
