# Data model: A07-P01

- **JourneyState** (schema 1, Codable): `world` (tunnel 0 | landscape 1 | starCorridor 2), `distance` (Double ≥ 0,
  finite, unwrapped), `speedChoice` (slow 0 | medium 1 | fast 2), `speed` (Double, current, ≥ 0), `seed` (UInt64),
  `paused` (Bool). Digest: all fields (speed rounded to 1e-6). Invalid decoded values (NaN, negative distance, unknown
  world) are refused.
- **Actions**: `world.select [0…2]`, `speed.select [0…2]`, `flight.pause` (refused with the rule
  `a07.already-paused` while paused), `flight.resume` (refused with `a07.not-paused` while flying), `journey.reseed`,
  and `comfort.reduce-motion [0…1]`: Reduce Motion is a host setting, which the presenter mirrors into the core with
  this action because a core is built from a seed alone (as A06's `permission.mirror`); it selects
  `ComfortLimits.reducedMotion` and is in neither the digest nor the snapshot (convergence T-A07-116).
- **CameraRail**: control points (≥ 4, closed), length, pose(at distance) → position, direction, right, up.
- **ComfortLimits**: maxSpeed, maxAcceleration, maxTurnRate (rad/s), swayAmplitude, maxRoll; `.standard`, `.reducedMotion`.
- **RailFlight**: distance, speed, targetSpeed, paused; `advance(by dt, limits)`; dt capped at 0.1 s.
- **OriginRebase**: threshold 1,024; origin(for position); local(position).
- **Piece**: world, index (Int ≥ 0), mesh (≤ 4,096 vertices), start and end edge.
