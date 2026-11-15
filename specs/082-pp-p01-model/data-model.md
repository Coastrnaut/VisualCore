# Data model: A11-P01

| Entity | Fields | Rules |
|---|---|---|
| `WorldSettings` | gravity Vec2 (m/s²), linearDrag, angularDrag (s⁻¹), tick 1/120 s, iterations 10, stage 10 × 8 m | gravity finite and ≤ 20 m/s² in magnitude; drags 0…5; iterations 1…20 |
| `PhysicsBody` | id Int, shape (circle radius / box halfExtents), materialId, isStatic, position, angle, velocity, angularVelocity | sizes 0.15…1.0 m; static ⇔ mass 0 (inverse mass and inertia 0); every number finite; speed ≤ 40 m/s, |ω| ≤ 40 rad/s |
| `PhysicsWorld` (schema 1) | schema, settings, bodies (≤ 48, ids unique and ascending), tick ≥ 0, nextId > every id, paused, timeScaleIndex 0…3, remainder 0…7 quarter ticks | `validate()` names each problem |
| `Material` | id, name, fill and edge colours, density 0.1…10, restitution 0…1, friction 0…1, author, license ∈ {"MIT"} | refusals missing-license, unsupported-license, out-of-range, invalid-number, duplicate-id |
| `PlaygroundState` (snapshot schema 1) | world, generator state | JSON with sorted keys; damaged or newer refused |
| Diagnostics | kinetic energy ½mv² + ½Iω², potential energy m·g·y, momentum Σ m·v | pure functions; dynamic bodies only |
