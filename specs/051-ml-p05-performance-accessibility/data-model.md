# Data model: A06-P05

- **AnalysisQuality** (VisualCore): levels 0…2 → (1,024, 16), (512, 16), (256, 8); clamped.
- **MetricText** (Core): inputs rmsDB (Float), regionEnergies ([Float] × 4), beat (Float); output String per spec
  clarification 2.
- **AnnouncementGate** (Core): minimumInterval 2 s, lastText String?, lastTime Double?; `shouldAnnounce(text:at:)`.
- **MusicLabPalette** (Core): index 0 Aurora, 1 Ember, 2 Mono; colours bar, wave, level, peak, beat, sphere, cube (RGBA
  0…1).
- **MusicLabState** (schema 3): + `palette` (0…2), persisted and in the digest.
- **MusicPreset** (format 2): + `palette` (0…2); format 1 decoded with palette 0; `actionValues` 8 numbers.
