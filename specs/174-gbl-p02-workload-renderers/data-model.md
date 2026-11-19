# Data Model: A24-P02 (feature 174)

- **RunTimeline** (core): `plan`, `start` (seconds); `phase(at:) -> RunPhase?` (nil when finished); `endTime`.
- **ParticleField** (core): `count`, `instance(index:frame:viewSize:) -> (x, y, size, rgba)` pure; positions wrap in
  the view.
- **BenchCore** (experience adapter): `selectedCase` 0…2, `startRequests`, `stopRequests`; snapshot schema 1 (all
  three), digest `a24.graphics-benchmark-lab.v1` over the selected case; actions `case.select [0…2]`, `run.start []`,
  `run.stop []`; rule ids `a24.not-whole`, `a24.unknown-case`.
- **RunRecorder** (presenter): `state` (idle, running, finished, stopped, interrupted), `timeline`, `samples`,
  `summary`; `record(frameTime:)`, `stop()`, `interrupt()`.
- **Workload** (presenter): one of three, built from a `BenchmarkCase`; `frame` (n); `setup`, `draw`, `release`.
