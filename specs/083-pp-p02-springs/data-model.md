# Data model: A11-P02

| Entity | Fields | Rules |
|---|---|---|
| `Spring` (world) | id, a: body id + local point, or a world point; b: body id + local point; restLength | bodies exist and differ; rest 0.1…10 m; ≤ 16 springs; ids unique ascending |
| Force levels | gravityLevel 0…2 (0, 1.62, 9.81), dragLevel 0…2 (0, 0.05, 1.0), stiffnessLevel 0…3 (20, 60, 150, 400 N/m) | settings' gravity and drags equal the levels' values |
| `ContactCacheEntry` | bodyA id, bodyB id (or wall index), point index, normal and tangent impulse | finite; rebuilt each tick |
| `PhysicsWorld` schema 2 | schema 1 fields + springs, nextSpringId, levels, contactCache | migration 1 → 2: no springs, Earth, low drag, stiffness 1, empty cache |
| Snapshot | `PlaygroundState` schema 2 | `MigrationChain(currentVersion: 2)`; schema-1 example restores |
