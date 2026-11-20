# Data model: R02-F14

- **EventLog<Command: Sendable & Equatable>**: entries `(step: Int, command: Command)` sorted by step, stable within a
  step; `maxStep = 10_000_000`, `maxEntries = 1_048_576`; `insert(_:at:)` (appends within the step), `remove(at:index:)`,
  `replace(at:index:with:)`, `commands(at:)`, `count`, `steps`.
- **SnapshotRing<State>**: `capacity` 1…1,024 (default 32); `interval` 1…65,536 (default 64); stored
  `(step, state, hash)` oldest first; `store`, `latest(atOrBefore:)`, `drop(after:)`.
- **ReplayHash**: `bytes: [UInt8]` (32); `start(checksum:)`, `next(step:checksum:)`, `hex`.
- **ReversibleTimeline<Simulation: FixedStepSimulation & Sendable, Command: Sendable & Equatable>**: `start`, `state`,
  `step`, `log`, `ring`, `hash`, `dt` (default 1/120), `apply`; `init(start:dt:interval:capacity:apply:) throws`,
  `advance(steps:)`, `seek(to:) throws`, `insert/remove/replace` (edit the log and recompute), `hash(at:) throws`.
- **TimelineRunDocument<State: Codable & FixedStepSimulation & Sendable, Command: Codable & Sendable & Equatable>** in
  VisualCoreExperience: schema 1; `start`, `log`, `step`, `hash`; `encode`, `decode(_:apply:)` (replays and verifies),
  migration from schema 0.
- **TimelineError**: `negativeStep`, `stepLimit(Int)`, `logLimit`, `noSuchCommand(step:index:)`, `ringSize(Int)`,
  `interval(Int)`, `hashMismatch`, `newerSchema(Int)`, `malformed(String)`; `reasonCode` `r2-f14.*`.
