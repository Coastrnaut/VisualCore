# Research: R02-G01-03

- **R1 iOS-only target in a host-tested package.** Decision: conditional dependencies (`.when(platforms: [.iOS])`) for
  VisualCoreRendering, VisualCoreExperienceHost, VisualCoreEffects and VisualCoreUI, and `#if os(iOS)` around the
  Experience sources and tests. Rationale: a probe package (2026-11-20, deleted afterwards) with exactly this shape ran
  `swift test` on the macOS host with the Core tests passing; the ANGLE frameworks have no macOS slice. Alternatives: a
  separate iOS-only package (two packages per round, more app links), or CI testing only filtered targets (fragile).
- **R2 Adapter in the Core.** Decision: `AuroraLoomExperienceCore` lives in `AuroraLoomCore` with VisualCoreExperience.
  Rationale: the conformance run (`ExperienceConformance`) and purity tests run on the host in seconds; the presenter only
  reads snapshots. Alternatives: A21's layout (adapter in the Experience target, simulator-only tests).
- **R3 Phase picture.** Decision: height = H · sin(2π θ / 4,096) along the loom, lanes in depth, gate rings with target
  markers (clarification Q1). Rationale: the drawn quantity is the judged quantity; Double is used only for drawing, never
  for judging.
- **R4 Geometry.** Decision: sample each ribbon's centre line as a `CatmullRomSpline` through 4 · segments points, frame it
  with `CurveFrames.parallelTransport` and build `Mesh.ribbon` sheets offset in depth per layer. Rationale: R02-F08 is the
  shared ribbon renderer; bevel shading uses the across coordinate u in the fragment shader.
- **R5 Shaders.** Decision: one ribbon program (vertex: wave displacement along the normal with amplitude by layer;
  fragment: bevel from u, interference from two travelling phases, palette mix by layer and lit state), one gate program
  and the shared emissive/bloom passes for glow. Sources are Swift strings checked on the host for uniform names and
  `#version 300 es`. Fallback: the shared unlit `MeshRenderer` with the palette colours.
- **R6 Frame checks.** Decision: 96 × 64 offscreen frames; tolerances of clarification Q3. Rationale: small, fast and
  stable on the simulator; exact pixels are not compared (golden images come in R02-G01-08).
- **R7 Registration.** Decision: follow the A25-P02 candidate registration. Rationale: `check_experience_packages.py`
  exempts a Core only while no Experience target exists; registration keeps every script check green.
- **R8 Custom-program mesh draws (implementation, 2026-11-20).** Decision: add the public `ShaderMeshRenderer` to
  VisualCoreRendering (position and normal interleaved, uv in its own stream, caller-set uniforms, opaque, premultiplied
  or additive blending), tested on the simulator; glow is drawn as additive halo passes of the ribbon program
  (`u_glowGain`), one per glow pass of the tier, instead of the post-process bloom graph. Rationale: `MeshRenderer`
  shades with a fixed Lambert model and the GL attribute helpers are internal, so no public type could draw the
  shader-computed materials FR-R02G0103-002 requires; the addition is small, generic and reusable by later games.
  Alternatives: per-vertex colours through `MeshRenderer` (loses fragment interference and bevel), the bloom effect graph
  (an effect-graph scene per frame for three ribbons is disproportionate).
