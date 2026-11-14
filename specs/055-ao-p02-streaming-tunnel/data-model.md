# Data model: A07-P02

- **JourneyState** schema 2: schema-1 fields + `source` (demo 0 | microphone 1 | file 2). Schema 1 decodes as demo.
  Digest adds the source. Samples, features and the file URL are never state.
- **Actions** (added): `source.demo`, `source.microphone` (refused with `a07.permission-denied` while the mirrored
  permission is denied or restricted), `source.file` (sent by the presenter after opening the file),
  `permission.mirror [0…3]` (not in digest or snapshot).
- **TunnelResponse**: ripple ∈ [0, 0.35] (rest 0.08), ambient ∈ [0.30, 0.70] (rest 0.35); step limits 0.02 / 0.03 per
  frame; reduceMotion halves the ripple range; reduceFlashing halves the ambient range and step.
- **SegmentWindow**: behind, ahead, capacity, maxBuildsPerStep = 2; live indices; step → toBuild, toRetire.
- **SlotPool<Element>**: capacity; acquire() -> slot?; release(slot).
- **MeshFog**: start, end (> start), colour (Vec4).
