# Contract: Effects Composer presets, compare and actions (A25-P03)

- **Presenter:** `save(name:)`, `open(file:)`, `rename(file:to:)`, `remove(file:)`; results are `PresetLibraryFailure`
  codes and messages.
- **Identifiers:** `compare`, `presets`, `preset-name`, `preset-save`, `preset-row-<n>`, `preset-open-<n>`,
  `preset-remove-<n>`.
- **Action:** `view.compare [0…1]`.
- **Accessibility actions:** "Move up", "Move down", "Turn off"/"Turn on", "Raise <name>", "Lower <name>".
- **As built (A25-P03):** opening a preset sends `chain.stage [index 0…7, id 1…65535, effect 0…4, on 0…1, v0…v3]` for
  each node of the opened chain, then `chain.replace [count 0…8]`, which commits `ChainEdit.replace` as one undoable
  edit (an action carries at most 24 values, and a restored snapshot would empty the history); staged nodes are
  neither stored nor digested; an unstaged position is refused as `a25.not-staged`. The controls hold ten actions;
  `preset-message` shows the library's sentence; `<n>` in the preset identifiers is the file number.
