# Data Model: A08-P05

- **StereoMicrophoneAudioSource** (VisualCoreAudio): `sampleRate`, `channelCount` (1 or 2, from the route), `state`
  (`AudioSourceState`), `start(into: StereoSampleBuffer)`, `stop()`, `awaitsResume`, `resume()`.
- **ScopeQuality**: levels [(columnShare 1, analysisInterval 1), (0.5, 2), (0.25, 4)]; `level(tier:forced:)` clamps.
- **ScopeAnnouncer**: interval 1.5 s; `announce(_ text:, at time:) -> Bool`; only while VoiceOver runs.
- **AccuracyReport**: cases [(name, expected, measured, tolerance, pass)]; `allPass`.
