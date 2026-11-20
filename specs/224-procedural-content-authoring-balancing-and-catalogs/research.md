# Research: R02-F24

- **R1 Catalogs built by code, pinned by digest.** Decision: the builder makes the catalog from a plan and a seed; tests
  rebuild it and compare a pinned digest. Rationale: "build-time" generation without a second tool or a generated file
  to keep in step; any change of rules, generator or plan changes the digest and fails the test. Alternatives: a script
  writing JSON resources (needs a byte-identical canonical JSON in two languages).
- **R2 Global seed index.** Decision: level candidates use `SeedDerivation.derive(seed, index: n)` for a global n.
  Rationale: stages are independent of each other's sizes only up to their order, and every level is reproducible from
  the plan alone.
- **R3 Difficulty from the certificate.** Decision: shortest solution length, then states explored. Rationale: both come
  from the R02-F23 certification, need no play data and are the same on every device.
- **R4 Neighbour progression.** Decision: bounded drop and jump between neighbours' shortest lengths. Rationale: simple to
  explain and check; stages already order by difficulty, the rule guards the seams between stages.
- **R5 Data-only tutorial conditions.** Decision: a closed set of conditions over three events. Rationale: deterministic,
  stored as data, testable without UI; text stays a key for localisation.
