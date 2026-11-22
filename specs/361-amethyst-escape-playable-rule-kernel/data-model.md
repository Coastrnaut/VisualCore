# Data model: R02-G07-01

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapeShell` | apertures (own sectors, sorted, non-empty), walls (own sectors, sorted; wall j between j and j + 1 mod N; at most N − 1), blocked (own sectors, sorted; never all) | named "shell n (inner/outer)" in words |
| `AmethystEscapeLevel` | id, seed, difficulty 1 … 5, sectors 6 … 12, shells 2 … 5, start (sector of shell 0, not blocked), budget 1 … 60, tutorial, fingerprint | the outermost shell has exactly one aperture (the exit gap); schema 1; sorted-key JSON |
| `AmethystEscapePocket` | shell 0 … K − 1, sector 0 … N − 1 (absolute) | own sector = (sector − offset) mod N |
| `AmethystEscapeCrystal` | offsets (one per shell, 0 … N − 1), pearl (pocket) | rotate moves the pearl only with its own shell |
| `AmethystEscapeTransition` | moved(pocket), exited, wedge(pocket), stuck | the advance of clarification Q2 |
| `AmethystEscapeAction` | rotate(shell, step ±1), advance | each accepted one spends one move |
| `AmethystEscapePlay` | stage, crystal, moves, failure (`wedge(shell, sector)`, `budget`), records, undo/redo stacks (snapshots) | records carry previous and next fingerprints |
| `AmethystEscapeRecord` | schema, level seed, move, kind (rotate, advance, undo, redo), action (nil for undo and redo), previous and next fingerprints | appended for every accepted action |
| `AmethystEscapeRules.Position` | crystal, moves, outcome (playing, won, failed) | moves: rotate(r, +1) and rotate(r, −1) for each shell r in order, then advance when it is not refused |
