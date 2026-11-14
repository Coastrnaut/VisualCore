# Research: A06-P03

- **D1 Mapping location.** Decision: `AudioMapping`/`AudioMapper` in `VisualCoreAudioDSP`, mapping into a plain
  `ClosedRange<Double>` so the DSP product stays free of `VisualCoreParameters`; an experience passes
  `definition.minimum...definition.maximum`. Alternative: depend on VisualCoreParameters (couples two pure products for
  one range).
- **D2 Normalisation.** Decision (clarified): dBFS window −60…0 for level/peak, −80…0 for regions (sum of four bands),
  beat as is. Rationale: matches the A06-P02 display windows (−80 for bands) and typical program levels.
- **D3 Codable and validation.** Decision: `AudioMapping` schema 1 with `schemaVersion` field; decoding validates
  feature (known kind), gain 0…4, attack/release finite in 0.001…5 s, 0 ≤ clampLow < clampHigh ≤ 1. Feature encoded as
  a string (`level`, `peak`, `beat`, `low`, `lowMid`, `highMid`, `high`).
- **D4 Scenes.** Decision: Bars — 16 bars full width, parameters `height` (gain of bar heights, 0.3…1.0) and `glow`
  (bar brightness 0.4…1.0); Rings — 5 concentric rings of the waveform, parameters `radius` (0.2…0.45 of the short
  side) and `wobble` (waveform amplitude on the ring, 0.02…0.15); Geometry — a sphere and 16 cubes on a ring, parameters
  `pulse` (sphere scale 0.6…1.2), `spin` (rad/s 0.1…2.0) and `lift` (cube height gain 0.2…1.5, cube i follows band i).
  Defaults: bars height←level, glow←beat; rings radius←level, wobble←high-mid; geometry pulse←beat, spin←level,
  lift←low. Attack/release defaults 0.02/0.25 s (beat-driven 0.01/0.2).
- **D5 State and actions.** Decision: `MusicLabState` adds `scene` (0…2) and `mappings` [[MappingChoice]] (3 scenes ×
  up to 3 slots; MappingChoice = feature index 0…6 + gain 0…4); actions `scene.select [0…2]`, `mapping.set [0…2, 0…2,
  0…6, 0…4]` (slot beyond the scene's parameter count refused as a rule), `mapping.reset [0…2]`; schema 2; migration 1→2
  inserts scene 0 and defaults; digest gains scene and every mapping choice.
- **D6 Hot-path check.** Decision: Python script scanning the three source files for `// vc:hot-path begin/end`
  regions (at least one per file, balanced), refusing a regex list of allocating constructs except on `// vc:cold`
  lines; script tests plant five constructs. Rationale: deterministic, runs on CI (Linux) and locally; runtime counters
  are unreliable (A06-P01 D6).
- **D7 Geometry rendering.** Decision: `DepthMeshPass` with one sphere renderer (`Mesh.uvSphere(segments: 24, rings:
  12)`) and one cube renderer drawn 16 times with different model matrices; `OrbitCamera` fixed at a 30° elevation.
- **D8 Contract.** Decision: G-SIGNALTEXTURE phase 3 → 5 (not needed by primitive/mesh scenes), G-AUDIOMAP closed in
  A06-P03; rows M01 and M17 become available with evidence.
