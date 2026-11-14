# Research: A05-P03

## D1 — Where the depth buffer lives
- **Decision**: the pass owns a registry render target with depth (`makeRenderTarget(width:height:depth: true)`), draws
  there and copies the colour to `context.framebuffer` with `vcglBlitFramebuffer` (GL_COLOR_BUFFER_BIT, GL_NEAREST).
- **Rationale**: the window surface has no depth buffer (no `EGL_DEPTH_SIZE` in the EGL config) and the export target of
  `renderOffscreen` has none; the blit works for both destinations, so screen and export are identical.
- **Alternatives**: request a depth buffer on the EGL surface (changes every experience's surface and does not help the
  export target); draw a textured full-screen quad (needs a program; the blit is simpler).

## D2 — Rebuild trigger
- **Decision**: rebuild when the target is missing, its size differs from the context's pixel size, or its registry
  generation differs from `context.resources.generation`.
- **Rationale**: the same rule `MeshRenderer` uses for its program; covers resize, export and context recreation.

## D3 — Bounding-sphere distance rule
- **Decision**: minimum distance = max(lower bound, |target| + clearance + 2 · near), clearance = composition bounding
  radius about the origin supplied by the experience (`MeshBounds`: |centre| + radius).
- **Rationale**: keeps the eye outside the sphere containing the composition with room for the near plane at any
  orientation; closed form, host-testable.

## D4 — Pan basis
- **Decision**: right = normalize(cross(forward, worldUp)), up = cross(right, forward), forward = normalize(target − eye);
  pan moves the target by dx · right + dy · up, then the target is scaled back to |t| ≤ targetRadius.
- **Rationale**: matches `OrbitCamera.view()` (lookAt with world up), so content follows the finger in view space.

## D5 — Field of view
- **Decision**: `OrbitCamera.fovY` (radians) within `fovRange`; the experience stores degrees (30…75, default 60) and
  sends absolute values. Non-finite → unchanged.

## D6 — Occlusion probes
- **Decision**: pure red and pure green meshes; verdict by the larger channel above 0.25 (lighting cannot flip it);
  offscreen equality within 2/255 at the view's pixel size.
