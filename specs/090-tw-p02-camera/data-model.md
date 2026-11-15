# Data Model: A12-P02

- **Ray3** (VisualCore): origin `Vec3`, direction unit `Vec3`; non-finite or zero direction refused.
- **RayHit3** (VisualCore): distance ≥ 0, point, unit normal facing against the ray.
- **Colour stream** (VisualCore): `[Vec4]` RGBA 0…1, count = vertex count.
- **CameraLimits** (experience): pitch 10°…75°, distance 10…30 m, target (0, 0.3, 0), clearance 0.5 m.
- **DetailLevel** (experience): 0, 1, 2 → cells = recipe ÷ 1, 2, 4.
- **WorldState**: unchanged (schema 1); the saved view is always policy-valid.
