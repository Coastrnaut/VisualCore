# Conic orbits and eclipse geometry

Feature 215 (R02-F15). Spec: [specs/215-conic-orbit-and-eclipse-geometry](../../specs/215-conic-orbit-and-eclipse-geometry/spec.md).

## The rule

Bodies move on two-body conics, time advances in whole ticks, and what an observer sees is decided by exact geometry of
uniform disks: the same elements, tick and positions give the same position, phase and eclipse verdict on every device.

## Parts (VisualCoreMath)

- `KeplerSolver` solves Kepler's equation in every form. Elliptic: the existing `KeplerOrbit.eccentricAnomaly` (Newton,
  at most 32 steps), polished by at most 8 further steps while |E − e·sin E − M| > 1e-12. Hyperbolic
  (e·sinh H − H = M): Newton from H₀ = sign(M)·ln(2|M|/e + 1.8), at most 64 steps. Parabolic (|e − 1| ≤ 1e-9):
  Barker's equation in closed form. Results are always finite.
- `ConicOrbit` takes periapsis distance q, eccentricity e, inclination, ascending node, argument of periapsis (the frame
  of `KeplerOrbit`), time of periapsis tₚ and gravitational parameter μ, and gives an `OrbitState` (position, velocity,
  true anomaly) at any time. For e < 1 it is the same orbit as `KeplerOrbit` (`keplerOrbit`, and an initialiser from
  one); `KeplerOrbit` itself is unchanged.
- `PhaseStepper` keeps time as tick k with time t₀ + Double(k)·Δt (never summed, so stepping and jumping agree bit for
  bit), gives the phase ((t − tₚ)/P) mod 1 of a closed orbit and lists periapsis and apoapsis `Passage`s in half-open
  spans, so adjacent spans report each passage once.
- `DiskOverlap` gives the exact lens area of two disks and the covered fraction of the source.
- `EclipseGeometry.classify` projects a source and an occluder from an observer to angular radii asin(R/d) and the
  separation between their directions, and returns an `EclipseVerdict` with an `EclipseClass`: hidden (an optional
  ground sphere puts the whole source below the horizon), none (the occluder is not nearer, or the disks do not overlap;
  touching is none), total, annular or partial.

## Stored form

`ConicOrbit` is `Codable` as JSON schema 1 with sorted keys (`encoded()`, `decode(_:)`). Schema 1 is the first stored
form; a later schema adds a step to the consuming experience's `MigrationChain`. A newer schema or damaged data is
refused.

## Failures

`OrbitError` reason codes: `r2-f15.invalid-elements`, `r2-f15.invalid-step`, `r2-f15.tick-limit`, `r2-f15.invalid-disk`,
`r2-f15.observer-inside`, `r2-f15.span-limit`, `r2-f15.newer-schema`, `r2-f15.malformed`; the experience that reports
one adds its id, seed and tick.

## Limits

Two-body motion only (no perturbations, no n-body integration), spherical bodies and uniform disks (no limb darkening),
the planar small-angle sky model. No body data: consumers supply their own elements. Drawing orbits and disks belongs to
the consuming experiences, on the existing mesh and SDF paths.

## Sources

Kepler's equation and its hyperbolic form, Barker's equation for the parabola, and the circle–circle lens area are
standard results of celestial mechanics and plane geometry. All code is original to VisualCore.
