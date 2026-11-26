# Research: R02-G19-02

- **R1 Sites make the proof whole.** Decision: catalog levels list 3 … 6 well sites; placements elsewhere are refused.
  Rationale: without sites a level's move space reaches about 9,100 placements per slot (feature 481's research R10),
  so no minimality proof could cover it within any test budget; with sites the space is at most 8 options per site, and
  the proof covers every move the player has. "Place magnetic pole" in the manifest's emphases reads naturally as
  choosing a site. Alternatives: proving minimality only over candidate cells while the player may place anywhere
  (rejected: not a proof of what the player can do); no proof (rejected: FR-R02G1902-002).
- **R2 Search by wells placed.** Decision: the solver searches sets of wells on distinct sites by size, depth 0, 1, 2.
  Rationale: a report depends only on the set of wells (each curl is added independently), and from a start with no
  well every set of at most d wells is reachable in d placements, while a removal or change never helps reach a
  smaller set; the first win at the smallest depth is minimal, and exhausting every smaller depth proves it.
- **R3 Fixed order, loss at the last depth.** Decision: sets are enumerated by site, then strength, then sense; the last
  depth is ordered by the shape loss of each set's prefix judged one depth earlier (ties keep the fixed order). Rationale:
  deterministic; the loss ("lit cells off the stencil plus stencil cells unlit") is the source's shape-loss evaluation
  and only changes how soon the first win is met, never which depth is minimal; it cut the prototype's catalog work from
  62,823 to 11,343 sets.
- **R4 Constructive generator; ranges measured first.** Decision: draw a swarm and sites, swim winning wells, take the
  largest lit group as the stencil, then let the solver confirm the band's plan length. Rationale: building from a
  winning swim guarantees a win exists; on the real manifest the prototype certified every entry within candidate index
  11 and the band means did not fall (1, 1, 2, 2, 2) — the lesson of R02-G10-02 (simulate a generator's filters before
  writing them down). A three-well band 5 cost up to 11.5 s per level and was rejected for two wells over six sites.
- **R5 Witness order.** Decision: the plan places its wells in slots 0, 1, … in site order. Rationale: distinct sites, so
  no placement lands on an occupied cell; every intermediate setting is a subset the proof already judged.
- **R6 Neighbour rule.** Decision: skip a candidate whose stencil equals the previous level's. Rationale: the manifest asks
  for a genuinely different puzzle from adjacent seeds.
- **R7 State digest.** Decision: 16 hex characters of the SHA-256 of the wells and the actions spent after each action,
  in a canonical text. Rationale: compact, detects any change in the rules.
- **R8 Counterexample.** Decision: the depth one below the plan, the number of sets at that depth (none winning) and the
  nearest miss. Rationale: a concrete, re-checkable proof of minimality; the nearest miss says how close the failed
  attempts came.
- **R9 Groups of five.** Decision: certification tests in 20 groups of 5 levels. Rationale: the slowest band-5 level took
  1.64 s in a debug build; five per group keeps each test under 10 s with room for skipped candidates.
