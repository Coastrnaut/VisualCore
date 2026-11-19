# Contract: Graphics Benchmark Lab core (A24-P01)

Module `GraphicsBenchmarkLabCore` (pure; imports Foundation, VisualCoreExperience, VisualCorePersistence only).

- `enum Workload: String, Codable, CaseIterable, Sendable { case quads, alu, particles }`
- `struct WorkloadConfig: Codable, Equatable, Sendable` — `layers: Int?`, `textureSize: Int?`, `iterations: Int?`,
  `particles: Int?`, `resolutionScale: Double`.
- `struct RunPlan: Codable, Equatable, Sendable` — `warmUpSeconds`, `measureSeconds`, `coolDownSeconds: Int`;
  `totalSeconds`.
- `struct BenchmarkCase: Codable, Equatable, Sendable` — `id: String`, `version: Int`, `workload`, `config`, `plan`;
  `func validate() throws(CaseError)`; `func fingerprint() throws(CaseError) -> StateDigest`;
  `static let builtIn: [BenchmarkCase]` (`quads`, `alu`, `particles`).
- `enum CaseError: Error, Equatable, Sendable` — `.outOfRange(field: String)`, `.notFinite(field: String)`,
  `.wrongWorkloadFields(field: String)`.
- `enum CaseLimits` — the caps of data-model.md as static ranges.
- `enum RunPhase: String, Codable, Comparable, Sendable { case warmUp, measure, coolDown }`
- `struct FrameSample: Codable, Equatable, Sendable` — the fields of data-model.md.
- `enum SampleLimits` — `maxDurationMs = 1_000`, `maxSamples = 20_000`.
- `enum SampleError: Error, Equatable, Sendable` — `.notFinite(frame:field:)`, `.outOfRange(frame:field:)`,
  `.outOfOrder(frame:)`, `.tooManySamples(count:)`.
- `enum SampleSet { static func validate(_ samples: [FrameSample]) throws(SampleError) }`
- `enum Percentiles { static func nearestRank(_ p: Int, of sortedValues: [Double]) -> Double?; static let minimumCount:
  [Int: Int] }` (50 → 1, 95 → 20, 99 → 100).
- `struct Distribution: Codable, Equatable, Sendable` — `p50`, `p95`, `p99: Double?`, `count: Int`.
- `enum QualityFlag: String, Codable, Comparable, Sendable` — the five flags.
- `struct Summary: Codable, Equatable, Sendable` — the fields of data-model.md;
  `static func make(_ samples: [FrameSample]) throws(SampleError) -> Summary`.
- `enum RunState: String, Codable, Sendable { case completed, stopped, interrupted }`
- `struct BenchmarkRun: Codable, Equatable, Sendable` — `caseID`, `caseVersion`, `caseFingerprint`, `samples`,
  `summary`, `state`.
- `enum RunDocument` — `kind = "a24.benchmark-run"`, `schemaVersion = 1`, `maxBytes = 2_097_152`,
  `static func encode(_ run: BenchmarkRun) throws -> Data` (sorted keys), `static func decode(_ data: Data,
  migrations: MigrationChain = …) -> Result<BenchmarkRun, RunRefusal>`.
- `enum RunRefusal: Error, Equatable, Sendable` — `.damaged`, `.newerVersion`, `.tooLarge`, `.notFinite`,
  `.outOfRange(field: String)`, `.outOfOrder`, `.tooManySamples`; `code: String` (`damaged`, `newer-version`, …).

Every public declaration carries `///` documentation.
