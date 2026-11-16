# Data model: A15-P05 (feature 114)

| Entity | Fields | Rules |
|---|---|---|
| `ImportedMolecule` (engine) | atoms [element symbol, x, y, z in Å], bonds (inferred, single); no title (actions carry numbers only) | 1…500 atoms; supported elements only; finite, \|c\| ≤ 1,000 Å; no pair closer than 0.4 Å; source "imported file", license "your own data" |
| `MoleculeState` schema 4 | selection 0…5, mode, camera, selected atom, `imported` (optional), `pending` (optional: expected count and atoms so far) | selection 5 only with an import; schemas 1–3 migrate with neither; `pending` never shown |
| `ImportRefusal` | `tooLarge`, `unreadable`, or a parser reason with its line | one fixed sentence each; nothing changes |
| Stored import `import.xyz` and `import-title.txt` | the accepted bytes; the sanitized title | ≤ 65,536 bytes; title ≤ 40 characters, "Imported molecule" when missing; both replaced by the next import |
| Review document `data-review.md` | per element and molecule: value, units, source, license; the two statements | generated; byte-identical to the committed file |
