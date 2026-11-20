# Data model: R02-G01-03

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomSceneSnapshot` | levelNumber, steps (`AuroraLoomSteps`), gates, omega, tolerance, ribbon ω, stage, failure, lit gates [3][4], time (ticks, Double) | immutable value; made by the adapter; time ≥ 0 |
| `AuroraLoomPalette` | night #07121A, teal #1FD1B4, magenta #E0389C, gold #D8E83A | RGB 0 … 1 |
| `AuroraLoomTier` | 0, 1, 2 → layers 1/3/5, segments 32/64/128, glow passes 0/1/2 | names `level-0` … `level-2` |
| `AuroraLoomSceneGeometry` | ribbon centre lines, ribbon meshes per layer, gate rings, marker positions, camera (view, projection) | finite; |position| ≤ scene bounds |
| `AuroraLoomExperienceCore` | play (`AuroraLoomPlay`), level number, quality tier | controls `ribbon.move` [0…2, 0…1, 0…15], `play.undo`, `play.redo`, `level.next`; digest of the play fingerprint; snapshot schema 1 = level number + records |
