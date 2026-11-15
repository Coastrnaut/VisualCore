# Data model: A09-P05

| Type | Fields | Rules |
|---|---|---|
| `AquariumState` (snapshot schema 4) | + `ambient: Bool` | missing → false |
| `AquariumConfiguration` (format 1) | format, id (UUID), name, savedAt, habitatIndex, lighting, decorKind, ambient, decor [kindId, x, y, rotation, scale] | name 1…40 after trimming; habitat, lighting, kind in range; ≤ 12 decor, positions in the tank, rotation −π…π, scale 0.5…2.0; known kinds |
| Library file | `aquarium-<lowercased uuid>.json` | ≤ 12 files; id must match the name; greater format → newer |
| `AmbientDimmer` | idle (s), brightness | 60 s idle, 2 s fade, 0.6 floor; not saved |
| `AquariumBudget` | bubblesPerVent, motes, causticsOctaves | per level and ambient, minimum combined |
