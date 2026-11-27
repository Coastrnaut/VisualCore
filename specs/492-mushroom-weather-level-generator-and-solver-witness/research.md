# Research: R02-G20-02

- **R1 Sites make the proof whole.** Decision: catalog levels list 4 … 6 pod sites; placements elsewhere are refused.
  Rationale: without sites a level's move space reaches about a thousand actions (feature 491's puzzle), and the number
  of arrangements reachable in four or five actions is far beyond any test budget; with sites, two to three vents and
  four moonlight levels, the space up to a band-5 plan depth is 1,144 arrangements, and the proof covers every move the
  player has. "Place fungus" in the manifest's emphases reads naturally as choosing a site. Alternatives: proving
  minimality only over candidate cells while the player may place anywhere (rejected: not a proof of what the player
  can do); no proof (rejected: FR-R02G2002-002).
- **R2 Search by distance.** Decision: the solver searches arrangements by their distance from the start: pod count +
  vents toggled + one for a changed moonlight. Rationale: a report depends only on the set of pod cells, the vent states
  and the moonlight; from a start with no pod, a placement adds one pod, a toggle changes one vent and one action sets
  any moonlight, while a move or removal never reaches an arrangement sooner; so the first win at the smallest distance
  is minimal, and exhausting every smaller distance proves it. An independent breadth-first search over the puzzle's
  moves reproduced the prototype's counts per depth on ten levels.
- **R3 Fixed order, loss at the last depth.** Decision: arrangements are enumerated by pod count, then vent count, then
  pod and vent combinations in lexicographic order, then the moonlight; the last depth is ordered by the band loss of
  each arrangement's parent. Rationale: deterministic; the loss (how far the colonies end from their bands and from a
  full final run, with a large penalty for a dried or moldy run) only changes how soon the first win is met, never which
  depth is minimal.
- **R4 Constructive generator; ranges measured first.** Decision: draw a floor, colonies, vents and sites next to the
  colonies, run a winning choice, set each colony's band from that run, then let the solver confirm the band's plan
  length. Rationale: building from a winning run guarantees a win exists; on the real manifest the prototype certified
  every entry within candidate index 2 and the band means did not fall (2, 3, 3, 4, 5) — the lesson of R02-G10-02
  (simulate a generator's filters before writing them down). Vents and sites anywhere made most candidates reducible
  (a far pod or vent barely changes a colony) and needed up to candidate index 42; requiring them next to a colony fixed
  it.
- **R5 Reducible pre-filter.** Decision: skip a candidate whose winning choice still wins with any one action removed.
  Rationale: such candidates would fail the plan-length check anyway; checking at most five arrangements first saves a
  full search; the prototype's catalog was identical with and without it.
- **R6 Witness order.** Decision: the plan places its pods in slots 0, 1, … in site order, then toggles vents, then
  changes the moonlight. Rationale: distinct sites, so no placement lands on an occupied cell; every intermediate
  arrangement is one the proof already judged at a smaller depth.
- **R7 Neighbour rule.** Decision: skip a candidate whose floor and colonies equal the previous level's. Rationale: the
  manifest asks for a genuinely different puzzle from adjacent seeds.
- **R8 State digest.** Decision: 16 hex characters of the SHA-256 of the arrangement and the actions spent after each
  action, in a canonical text. Rationale: compact, detects any change in the rules.
- **R9 Counterexample.** Decision: the depth one below the plan, the number of arrangements at that depth (none
  winning) and the nearest miss. Rationale: a concrete, re-checkable proof of minimality.
- **R10 Groups of five.** Decision: certification tests in 20 groups of 5 levels. Rationale: the slowest group took
  3.53 s in a debug build; five per group keeps each test under 10 s with room for skipped candidates.
