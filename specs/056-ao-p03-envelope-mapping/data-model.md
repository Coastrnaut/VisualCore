# Data model: A07-P03

- **JourneyState** schema 3: world, distance, speedTarget (0.5…7, step 0.5; schema 1/2 speedChoice slow/medium/fast →
  2/4/7), speed, seed, paused, source, easing (gentle 0 | standard 1 | brisk 2), calmMotion (Bool), mappings
  ([WorldMapping] × 3 in world order). Digest adds speedTarget, easing, calmMotion and the mappings.
- **WorldMapping**: primary (channel, sensitivity), light (channel, sensitivity); channel ∈ low 0 | mid 1 | high 2 |
  transient 3 | overall 4; sensitivity ∈ low 0 | medium 1 | high 2 (gain 0.6/1.0/1.6). Defaults: tunnel (low, overall),
  landscape (mid, overall), star corridor (transient, overall), all medium.
- **AudioEnvelope**: low, mid, high, transient, overall (mean of low/mid/high) ∈ 0…1; timestamp.
- **WorldResponse**: primary ∈ [0, max(world)] (tunnel 0.35, landscape 0.6, star 1.0; rest 0.08/0.1/0.1), light ∈
  [0.30, 0.70] (rest 0.35); steps 0.02·max/0.35 and 0.03; Reduce Motion halves primary range; Reduce Flashing halves the
  light range and step.
- **Actions** (added): `speed.set [0.5…7]`, `easing.select [0…2]`, `comfort.calm [0…1]`, `mapping.set [target 0…1,
  channel 0…4, sensitivity 0…2]` (applies to the current world), `mapping.reset`.
