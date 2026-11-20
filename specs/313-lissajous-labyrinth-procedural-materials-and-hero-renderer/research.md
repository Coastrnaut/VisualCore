# Research: R02-G02-03

- **R1 Thread geometry.** Decision: a camera-facing strip through the drawn samples (each sample offset ± w/2 along
  normalize(tangent × view)), with per-vertex lap fraction and side for the shader. Rationale: the design's "adaptive
  curve tessellation with tangent-space width"; cheap; exact sample positions at every tier. Alternatives: a tube with
  parallel-transport frames (more triangles, little gain at this width).
- **R2 Checkpoints and obstacles.** Decision: rings (torus-like flat annuli facing the camera) for checkpoints and
  subdivided icospheres (2 levels, 320 triangles) for obstacles, both from `MeshBuilder`. Rationale: generated meshes;
  readable at small sizes.
- **R3 Tracer head and trail.** Decision: the head tick is presentation time × 60 mod 4,096 (0 under Reduce Motion); the
  shader brightens samples whose lap fraction lies within the tier's trail behind the head (uniforms only, no rebuild).
- **R4 Camera.** Decision: a fixed authored direction, distance fitted to the bounding sphere of path, checkpoints and
  obstacles for the aspect (0.4 … 2.5) with a 5 % margin. Rationale: the same CPU projection serves the frame checks.
- **R5 Reuse of R02-G01-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Aurora Loom's shapes so the shared checks apply unchanged; the digest is the level number and
  the play fingerprint (the INV-05 lesson of R02-G01-04).
