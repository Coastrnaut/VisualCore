# Data Model: A24-P01 (feature 173)

- **Workload:** `quads`, `alu`, `particles`.
- **WorkloadConfig:** `layers` 1…64 and `textureSize` 64…1,024 (power of two) for quads; `iterations` 1…1,024 for alu;
  `particles` 1…100,000 for particles; `resolutionScale` 0.25…1.0 for all.
- **RunPlan:** `warmUpSeconds` 1…30, `measureSeconds` 1…60, `coolDownSeconds` 0…120 (integers).
- **BenchmarkCase:** `id`, `version` (≥ 1), `workload`, `config`, `plan`; `fingerprint` (StateDigest, domain
  `a24.benchmark-case.v1`); built-ins `quads` v1 (8 layers, 256), `alu` v1 (64), `particles` v1 (5,000), each
  resolution 1.0 and plan 3/10/5.
- **RunPhase:** `warmUp`, `measure`, `coolDown`, in that order.
- **FrameSample:** `frameIndex` (Int ≥ 0, strictly increasing), `phase`, `intervalMs` (Double?, 0…1,000), `cpuMs`
  (Double, 0…1,000), `gpuMs` (Double?, 0…1,000), `dropped` (Bool).
- **Distribution:** `p50`, `p95`, `p99` (Double?), `count`.
- **QualityFlag:** `noSamples`, `tooFewForP95`, `tooFewForP99`, `droppedFrames`, `gpuTimeNotAvailable`.
- **Summary:** `interval`, `cpu` (Distribution), `gpu` (Distribution?), `measured`, `warmUpExcluded`, `coolDownExcluded`,
  `dropped`, `flags` (sorted set).
- **BenchmarkRun:** `case` (id, version, fingerprint hex), `samples` (≤ 20,000), `summary`, `state` (completed,
  stopped, interrupted).
- **Run file:** envelope `{"body", "kind": "a24.benchmark-run", "version": 1}`, ≤ 2,097,152 bytes; refusals `damaged`,
  `newer-version`, `too-large`, `not-finite`, `out-of-range` (field), `out-of-order`, `too-many-samples`.
