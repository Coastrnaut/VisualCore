# Research: A07-P02 (feature 055)

## 0. Verified facts (2026-11-14)

- `MeshRenderer.draw(model:camera:aspect:color:)`, `DepthMeshPass.draw(_:camera:context:)` take `OrbitCamera`; the mesh
  shader has no fog; `MeshCache` is an LRU of whole meshes.
- `FeatureExtractor`, `FeatureSmoother`, `AudioMapper`, `AudioMapping`, `AudioFeatureKind` (level, peak, beat, low,
  lowMid, highMid, high), `SampleRingBuffer`, `DemoSignal` are public in `VisualCoreAudioDSP`; `AudioSource`,
  `DemoAudioSource`, `FileAudioSource`, `MicrophoneAudioSource`, `SystemMicrophonePermission` in `VisualCoreAudio`.
- The app already declares `NSMicrophoneUsageDescription` (A06).

## 1. Decisions

- **D1 Window:** index window (behind 2, ahead 8, capacity 12 ≥ 11 live) with at most 2 builds per step, nearest first;
  retired indices returned first so the pool never grows. Alternative: reuse MeshCache (LRU by bytes, no ordering).
- **D2 Drawing:** additive overloads with `MeshFog?`; the orbit methods forward with `nil` so pixels are identical.
  Alternative: a new pass (duplication, two code paths to keep equal).
- **D3 Response:** two `AudioMapper`s (low → ripple, level → brightness) followed by a step limiter and clamps, pure in
  Core so it is testable without audio hardware.
- **D4 Ripple at draw time:** per-piece radial scale about the rail (same scale for all pieces in a frame) keeps joins
  watertight and avoids per-frame mesh rebuilds.
- **D5 Sources:** A06's source set and permission flow, reused unchanged.
