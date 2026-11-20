# Signed-distance shapes and CPU proxies

Feature 211 (R02-F11). Spec: [specs/211-sdf-and-constructive-geometry-proxy-library](../../specs/211-sdf-and-constructive-geometry-proxy-library/spec.md).

## The rule

An experience describes a shape once, as an `SDFShape` (VisualCoreScenes), and both draws it (the generated shader
function) and decides with it (hits, containment, contacts on the CPU). It never decides from pixels.

## Description

Primitives: plane (n · p = h, n of unit length), sphere, box, rounded box, capsule, torus around y. Operations: union
(min), intersection (max), subtraction (max(a, −b)), smooth union (polynomial smooth minimum with radius k ≥ 0, equal to
the union at k = 0 and never above it). Transforms: translation, rotation by a unit quaternion, uniform scale s > 0
(distance × s). Non-uniform scale is not representable, so every description is a distance bound (|∇d| ≤ 1), which is
what makes the march safe. Limits: 256 nodes, depth 32, 1…32 children per union or intersection; sizes finite and
positive. A description is built only through validating makers; refusals throw `SDFError` with a reason code
`r2-f11.*`.

## March

`SDFMarch.march(_:ray:options:)` sphere-traces a `Ray3`. Conservative mode steps by the distance; fast mode over-relaxes
by 1.6 and steps back when two consecutive spheres do not overlap (Keinert et al. 2014), so neither skips a surface.
Defaults (`SDFMarchOptions.standard`): 128 steps (at most 4,096), maximum distance 100, hit when d < 1e-7 · max(1, t). A
ray that starts inside hits at 0 with `startedInside`. Outcomes: hit, miss, budget exhausted (never a false miss).

## Volume

`SDFVolume.sample` evaluates the cell centres of an n³ grid (1 ≤ n ≤ 256) over given bounds, counts inside cells,
estimates volume = count × cell volume and digests the inside mask with 64-bit FNV-1a, so results replay exactly.

## Stored form

`SDFDocument` writes `{"schema":1,"shape":{…}}` with a `kind` tag per node; reading re-validates every node. A newer
schema, an unknown kind or malformed data is refused, never trapped.

## Shader

`SDFShape.glslFunction(name:)` emits a straight-line GLSL ES 3.00 function `float vc_sdfShape(vec3 p)` that needs
`#include "vc/sdf.glsl"` and `#include "vc/sdfshape.glsl"` (plane, rounded box, capsule, set operations, smooth union).
Parity tests on the iOS 27.2 and 26.5 simulators compare a distance slice within 2/255 of the range ±4 and the marched
hit mask away from silhouettes.

## Sources and licences

- Distance functions and the polynomial smooth minimum: Inigo Quilez, "3D distance functions" and "smooth minimum"
  (iquilezles.org), code under the MIT licence.
- Sphere tracing: J. C. Hart, "Sphere tracing: a geometric method for the antialiased ray tracing of implicit surfaces",
  The Visual Computer 12, 1996.
- Over-relaxation with fallback: B. Keinert, H. Schäfer, J. Korndörfer, U. Ganse, M. Stamminger, "Enhanced Sphere
  Tracing", Smart Tools and Apps for Graphics, Eurographics 2014.

All code is original to VisualCore.
