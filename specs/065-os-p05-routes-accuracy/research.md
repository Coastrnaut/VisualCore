# Research: A08-P05 (feature 065)

## 0. Verified facts (2026-11-14)

- `MicrophoneAudioSource` uses the internal `MicrophoneCapture` seam, `AudioSessionEventMonitor` and
  `MicrophonePermission`; it mixes to mono into a `SampleRingBuffer`.
- `AnnouncementSink` (VisualCoreUI) and A07's `JourneyAnnouncer` (1.5 s) exist; the presenter can be given a sink and a
  VoiceOver flag as A07's is.
- The host passes the governor's tier to `draw(_:tier:context:frame:)`; `qualityTiers` defaults to 1 unless declared.

## 1. Decisions

- **D1 New stereo microphone source beside the mono one** (clarification 1): no risk to A06/A07, which use the mono
  source; the seam pattern is reused. Rejected: a channel-count option on the mono source (changes a shared type's
  behaviour).
- **D2 Audit through the real path** (clarification 2): the audit drives a `StereoSampleBuffer` with the demo generator
  and uses `ScopeAcquisition`, `SpectrumAnalyzer`, `SpectrumReadout` and `ScopeReadout`, so a regression anywhere fails it.
- **D3 Levels by columns and analysis interval** (clarification 3): the two costs that scale with the screen and the
  FFT; samples and state are untouched, so digests stay equal.
- **D4 Device-only items** (clarification 5): stereo routes, input latency, 44.1 kHz routes and thermal behaviour are
  recorded as pending device measurements.
