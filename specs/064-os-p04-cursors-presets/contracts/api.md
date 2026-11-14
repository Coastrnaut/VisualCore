# Contract: A08-P04 experience actions and files

- Actions: A08-P03's nine + `freeze.set [0…1]`, `cursors.show [0…1]`, `cursor.a [0…1]`, `cursor.b [0…1]`,
  `cursor.level [−1…1]`, `cursor.frequency [0…1]`, `preset.apply [0…N−1]` (rule `a08.invalid-preset`); snapshot schema 3.
- Files: `scope-<uuid>.json` in the experience's storage, format 1, settings only.
- Accessibility identifiers: `freeze.toggle`, `cursors.show`, `cursor.a`, `cursor.b`, `cursor.level`,
  `cursor.frequency`, `cursor.readout`, `preset.<index>`, `preset.name`, `preset.save`, `preset.rename`, `preset.delete`.
- No VisualCore API change.
