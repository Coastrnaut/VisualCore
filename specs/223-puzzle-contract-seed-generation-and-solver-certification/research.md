# Research: R02-F23

- **R1 Home.** Decision: VisualCoreSimulation, beside the R02-F16 solvers. Rationale: the same precedent as R02-F16
  and R02-F05; section 13.2's VisualCorePuzzle would add a target, app dependency audit and project changes for no gain.
  Alternatives: a new module (needs a build-time measurement and an ADR per section 13.2).
- **R2 Content identity.** Decision: SHA-256 hex (`StableHash`) of the canonical JSON with sorted keys, the identity
  field excluded. Rationale: the same bytes on every device; any change of content changes the identity; reuses UA-F02.
- **R3 Breadth-first certification.** Decision: one breadth-first search from the start to the maximum length, states
  deduplicated, moves in the rules' order; it yields the shortest length, the branching seen, the solved states and the
  number of shortest paths (counted with saturation at 2). Rationale: polynomial in the states explored and exact;
  counting all solution sequences would be exponential.
- **R4 Unproven is not unique.** Decision: a search that hits its node budget makes the verdict `unproven`. Rationale:
  a level must never be called unique without proof.
- **R5 Derived attempt seeds.** Decision: attempt i uses `SeedDerivation.derive(seed, index: i)`. Rationale: attempts are
  independent and reproducible; the level records the winning attempt's derived seed, which regenerates its candidate.
