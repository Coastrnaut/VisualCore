# Data model: Phase 4

- **EffectGraphDescription** (Codable): `version = 1`, `passes: [EffectPassDescription]`, `output: String` (an output name).
- **EffectPassDescription**: `id` (unique), `type` ∈ {copy, colorMatrix, blur, bloom, distort, composite, feedback, flashLimit},
  `inputs: [String: String]` (input slot → `scene` or another pass's output), `output` (unique), `scale` (0 < s ≤ 1, default 1), `params: [String: [Double]]`.
- **ValidatedGraph**: `order: [String]` (pass ids), `estimatedBytes: Int`, `warnings: [String]`.
- **EffectGraphError**: `unsupportedVersion(Int)`, `tooManyPasses(Int)`, `duplicateID(String)`, `duplicateOutput(String)`,
  `unknownType(String, pass:)`, `missingInput(pass:, input:, source:)`, `cycle([String])`, `invalidScale(pass:, Double)`,
  `missingOutput(String)`, `overQuota(bytes:, quota:)`, `missingSlot(pass:, slot:)`.
- **PassSchema**: per type: required input slots, param keys with default and clamp range.
- **FlashLimiterModel**: `limitPerSecond` (default 0.3), `adapted: Double?`; `step(measured:dt:) -> (displayed, gain)`.
