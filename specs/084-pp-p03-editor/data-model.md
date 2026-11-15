# Data model: A11-P03

| Entity | Fields | Rules |
|---|---|---|
| `PhysicsBody` (schema 3) | + `pinned: Bool` | pinned ⇒ velocity 0 and inverse mass and inertia 0 in the tick; static bodies are not pinnable |
| `Grab` | bodyId, localAnchor (m), target (m) | body exists, dynamic, unpinned; target inside the stage |
| Overlay settings | showVelocity, showForces | default false |
| `PhysicsWorld` (schema 3) | schema 2 + pinned flags, `selectedId?`, `grab?`, overlay settings | migration 2 → 3: all false or nil |
| Snapshot | `PlaygroundState` schema 3 | `MigrationChain(currentVersion: 3)`; schema-1 and schema-2 examples restore |
