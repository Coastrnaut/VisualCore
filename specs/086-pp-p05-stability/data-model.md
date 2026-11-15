# Data model: A11-P05

| Entity | Fields | Rules |
|---|---|---|
| `PhysicsBody` (world schema 4) | + `asleep: Bool`, `restTicks: Int` | asleep ⇒ velocities 0 and dynamic, unpinned, ungrabbed; restTicks 0…60 |
| `WorkCount` | narrowPhaseTests, contacts, contactPoints, solverPointUpdates | derived per tick; never saved |
| `DrawingBudget` | level 0…2: coils, circleSegments, hatchSpacing? | presentation only |
| `PlaygroundState` (schema 5) | schema-4 state with a schema-4 world | migration 4 → 5: bodies awake, restTicks 0 |
