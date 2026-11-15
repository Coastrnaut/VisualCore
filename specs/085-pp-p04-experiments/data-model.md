# Data model: A11-P04

| Entity | Fields | Rules |
|---|---|---|
| `PresetID` | freePlay 0, pendulum 1, springChain 2, stackedObjects 3 | name, author "VisualCore project", license "MIT" |
| `Origin` | preset(0…3) or slot(0…3) | — |
| `TutorialProgress` | tutorial 0…1, step 0…n−1, startTick | absent when no tutorial runs |
| `PlaygroundState` (schema 4) | world, random, origin, startingWorld, tutorial? | startingWorld validates; migration 3 → 4: origin free play, startingWorld = world without grab and selection, no tutorial |
| `ExperimentDocument` (file schema 1) | schema, name (1–24 chars), origin, world | refusals `damaged`, `newer-version`, `invalid-world`; slot files `experiment-0…3.json` |
