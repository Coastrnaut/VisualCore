# Data model: A13-P03

| Entity | Fields | Rules |
|---|---|---|
| `LevelProgress` | id, open, solved, best | solved ⇒ open, best 1…999; unsolved ⇒ best nil |
| `Progress` (file schema 1) | levels (20, catalog order) | level 1 open; ≤ 16 KB |
| `Move` | tile index, before, after (orientations) | after = toggle(before) |
| `MazeState` (schema 2) | schema 1 + moves (≤ 64) | migration 1 → 2: no moves |
