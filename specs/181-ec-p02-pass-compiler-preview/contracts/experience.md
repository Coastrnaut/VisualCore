# Contract: Effects Composer experience (A25-P02)

- **Actions:** `chain.add [0…4, 0…8]`, `chain.remove [0…7]`, `chain.move [0…7, 0…7]`, `chain.enable [0…7, 0…1]`,
  `chain.set [0…7, 0…3, 0…1]`, `edit.undo []`, `edit.redo []`; refusals `a25.not-whole` and `a25.<ChainRefusal code>`.
- **Identifiers** (prefixed `experience.a25.effects-composer.`): `add-<effect>`, `node-<i>`, `enable-<i>`, `up-<i>`,
  `down-<i>`, `remove-<i>`, `value-<i>-<name>-down`, `value-<i>-<name>-up`, `undo`, `redo`, `status`, `diagnostics`.
- **Presenter seams (tests only):** `programOverride: [EffectID: String]`, `lastResult` (the result target's pixels).
- **Registration:** candidate, permissions ["photo-library-add"], tier `level-0`, 60 frames per second.
