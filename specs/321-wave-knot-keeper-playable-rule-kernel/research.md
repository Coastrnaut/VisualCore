# Research: R02-G03-01

- **R1 Polygon, not spline, for the rules.** Decision: the rules use the closed control polygon on an integer lattice.
  Rationale: exact integer tests, identical on every device; the drawn spline interpolates the same points. Alternatives:
  sampled splines with floating tolerances (not exact; device-dependent).
- **R2 Swept-move isotopy check.** Decision: a one-step move of P is legal when the triangles A-P-P′ and P-P′-B meet no
  non-adjacent segment (exact segment-triangle test by orientation determinants). Rationale: the two triangles are
  exactly the surface swept by the two moving segments; if no other strand meets them the move is an ambient isotopy,
  so the knot type cannot change outside gates.
- **R3 Signed crossings and writhe.** Decision: summary = (crossing count, writhe) of the xy-projection, with
  degenerate projections never winning. Rationale: the archived "projected signed crossing graph and knot invariant";
  exact and cheap; the generator (R02-G03-02) places targets reachable through gates.
- **R4 Tension as total squared length.** Decision: an integer bound on Σ|segment|². Rationale: exact, monotone with
  stretching, simple to explain ("the rope cannot stretch further").
