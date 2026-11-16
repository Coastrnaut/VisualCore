# Data model: A15-P04 (feature 113)

| Entity | Fields | Rules |
|---|---|---|
| `RecentMolecules` (`recent.json`, schema 1) | ids [String] newest first | at most 8; unique; ids not in the library dropped on read; ≤ 2,048 bytes; refusals damaged, oversized, newer-version, out-of-range (more than 8 or a malformed id) |
| `LabelMode` | all, selected, none | default all |
| `MoleculeSettings` (`settings.json`, schema 1) | labels: LabelMode | ≤ 1,024 bytes; same refusals; default on missing or refused |
| `StoreLoad<T>` | loaded(T), missing, refused(reason), unreadable(code) | a load never writes |
