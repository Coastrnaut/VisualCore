# Contract: A08-P05 public API (VisualCore) and experience

## VisualCoreAudio (new, public)

- `@MainActor public final class StereoMicrophoneAudioSource: StereoAudioSource` — `init(permission: any MicrophonePermission)`;
  `sampleRate`, `channelCount`, `state`, `start(into: StereoSampleBuffer) throws`, `stop()`, `awaitsResume`, `resume()`;
  internal test init with a capture factory and an optional notification center.
- Also public, as on the mono source: `handle(_ event: AudioSessionEvent)`; and `handleNewRoute()`, which rebuilds a
  running capture when a new input device appears (the shared `AudioSessionEvent` maps only a lost route), so the
  channel count follows a plugged-in headset or interface.

## Experience

- `ScopeCore.qualityTiers = 3`; registration `quality_tiers` ["level-0", "level-1", "level-2"].
- Announcements: view change, freeze/unfreeze, trigger lost/regained, clipping start/end, channel count after a route
  change; at most one per 1.5 s; only while VoiceOver runs.
- No action or schema change.
