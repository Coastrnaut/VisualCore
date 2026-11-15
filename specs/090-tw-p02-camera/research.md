# Research: A12-P02 (feature 090)

Facts verified on 2026-11-15 (clarification session): `MeshRenderer` program (attributes 0 and 1, uniform colour, light,
ambient, fog) and rebuild after context recreation; `DepthMeshPass.Item`; `Vec4`; `OrbitCamera.ray`;
`GestureAlternatives.missing`; `HeightField.height(atX:z:)`; no ray intersection in any framework product.

## D1 — Colour stream (VisualCoreRendering, G-MATERIALS)

- **Decision**: `MeshRenderer.init(mesh:colors:registry:)` with `colors: [Vec4]?` (nil keeps today's behaviour; the
  existing `init(mesh:registry:)` forwards with nil); attribute `a_color` at location 2 in a separate buffer; disabled
  attribute with constant (1, 1, 1, 1) when nil; fragment colour = u_color × v_color before lighting. Refusal
  (`MeshError.invalidInput`) for a count ≠ positions count, non-finite or outside 0…1.
- **Rationale**: a constant attribute of 1 multiplies exactly, so existing pixels are identical (`MeshRendererTests`,
  `DepthMeshPassTests` unchanged); one shader, no variant explosion.
- **Alternatives**: a colour field on `Mesh` (changes `Mesh`, digests and every generator); one draw per colour band
  (more draws, visible seams).

## D2 — Ray intersection (VisualCoreMath, G-PICKING)

- **Decision**: `Ray3`, `RayHit3`; slab method for boxes; quadratic with the nearer non-negative root for spheres;
  Möller–Trumbore two-sided for triangles; inside starts hit at 0 with normal −direction; nearest-of-many helper;
  tolerance 1e-12.
- **Alternatives**: a BVH (not needed for ≤ dozens of shapes); GPU picking (forbidden read-back of state).

## D3 — Camera policy (app-local, G-CAMERA)

- **Decision**: `CameraPolicy.clamp(view:world:)` applies the limits and raises pitch in 1° steps until the eye is
  0.5 m above the 9-sample neighbourhood maximum (to 75°); applied in `WorldsCore` after every view action and on
  restore. Gestures: drag 0.3°/pt, pinch factor 1/scale clamped 0.5…2, as `view.orbit`/`view.zoom`. Easing 0.35 s
  smoothstep in the presenter; Reduce Motion direct; announcements rate-limited to 1/s.

## D4 — Colouring and detail levels (app-local)

- **Decision**: `TerrainColoring.colors(heights:palette:preset:)` per the clarified bands; `TerrainDetail.field(preset:
  seed:level:)` builds the height field at the recipe resolution ÷ 2^level from the same function; quality tiers 3;
  fixtures: 27 meshes validated; terrain digests (level 0) unchanged.

## D5 — Ground pick (app-local)

- **Decision**: `GroundPick.hit(ray:field:)`: intersect the world box (y −1…1.6, x and z ±6) with `Ray3`, march in
  steps of half a cell, bisect 40 times; result point or nil.

## As built (2026-11-15, recorded at convergence T-A12-214)

- **D3 policy:** `WorldsCore` applies `CameraPolicy.clamp` after every accepted action — the view actions and also
  `world.preset` and `world.seed`, because a new terrain can rise under the eye — and whenever a core is built from a
  state (prepare, restore, reset), so every saved view is policy-valid (`WorldsCoreTests
  .testRestoredAndActedViewsKeepTheCameraPolicy`). Level-0 height fields are memoised per preset and seed (at most 16;
  generation is pure, so a cached field equals a regenerated one).
- **D3 motion and speech:** `WorldsMotion.swift` holds `ViewEasing` (0.35 s smoothstep on frame time, yaw the shorter
  way, direct under Reduce Motion even mid-ease) and `ViewAnnouncer` (at most one announcement per second, the latest
  text kept), covered by `WorldsRenderTests`.
- **D3 gestures:** `GestureArbiter` decides which recognizer owns a touch but reports only state changes for
  continuous gestures, so `WorldsGestures` measures each drag and pinch step from the finger positions itself
  (`WorldsGestureTests`).
- **SC-A12-201 coverage:** over the 768-view sweep per preset the bundled worlds never need a pitch raise (the eye's
  ground point stays beyond the high ground even at 10° and 10 m); the raise itself is proven on synthetic fields — a
  flat 1.6 m field lifts 10° to 11°, a 50 m field stops at 75° (`CameraPolicyTests`).
