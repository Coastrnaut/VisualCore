# Data model: A15-P04 (feature 113)

| Entity | Fields | Rules |
|---|---|---|
| `RecentMolecules` (`recent.json`, schema 1) | ids [String] newest first | at most 8; unique; ids not in the library dropped on read; ≤ 2,048 bytes; refusals damaged, oversized, newer-version, out-of-range (more than 8 ids, a duplicate, a malformed id — empty, longer than 32 characters or not lowercase letters, digits and hyphens — or a schema version below 1) |
| `LabelMode` | all, selected, none | default all; `selected` with no atom selected shows no label |
| `MoleculeSettings` (`settings.json`, schema 1) | labels: LabelMode | ≤ 1,024 bytes; same refusals (out-of-range: an unknown label mode or a schema version below 1); default on missing or refused |
| `StoreLoad<T>` | loaded(T), missing, refused(reason), unreadable(code) | a load never writes |
