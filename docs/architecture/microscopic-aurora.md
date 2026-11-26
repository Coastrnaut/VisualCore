# Microscopic Aurora (R02-G19)

Experience `r02-g19.microscopic-aurora` (free), a puzzle of luminous swimmers in a round dish under a microscope: the
player places up to three magnetic wells, each with a strength and a turning sense, then releases the swarm for one
swim, so that the swimmers' glowing trails cover a target stencil as one connected pattern, without a swimmer leaving
the enclosure or the swarm losing its coherence. Code lives in `Packages/ExperiencesRound02/MicroscopicAurora`; this
page grows with each feature of R02-G19. The swarm is integrated in deterministic integer arithmetic and every rule is
decided exactly on integer positions; the catalog's 0.008333 s timestep is a presentation clock of later features.

## Rule kernel (feature 481, R02-G19-01)

- **Dish and swarm.** The dish is 24 × 24 cells of 256 dish units; the enclosure is the circle of radius R (6 … 11
  cells) about (3072, 3072), the rim inside. A level has 4 … 16 swimmers, each an integer position and velocity, and a
  swim of T ticks (120 … 480).
- **One tick.** Every acceleration comes from the swarm as it is (a synchronous step). Neighbours lie within ρ (2 … 6
  cells): separation sums pᵢ − pⱼ within σ (1 … ρ), coincident swimmers pushed ±1 along x by index; alignment is the
  neighbours' mean velocity minus vᵢ and cohesion their mean position minus pᵢ (zero with no neighbour). The swarm
  acceleration (wₛ·separation)/64 + (wₐ·alignment)/16 + (w_c·cohesion)/256 (weights 0 … 8) is joined by each well's
  curl sense·s·4096·(−dy, dx)/(dx² + dy² + 65536) about its cell centre; every division truncates toward zero. The
  acceleration is clamped to ±a_max (2 … 16) and the velocity to ±v_max (8 … 48) per axis, then p ← p + v.
- **Trails and the judge.** A cell's trail density counts the (swimmer, tick) pairs of ticks 1 … T in it; a cell is lit
  at the level's threshold (1 … 64). The stencil (4 … 120 cells inside the enclosure) is covered in tenths of a percent,
  rounded down, against a requirement of 500 … 1000, and its lit cells must form exactly one four-neighbour group.
  Coherence is the largest group of swimmers linked within κ (2 … 8 cells). Playing walks the ticks: the lowest-index
  swimmer outside fails `exit`, otherwise a coherence below the requirement fails `coherence`; after the swim a coverage
  below the requirement fails `coverage` and more than one group `connectedness` (naming the first cell not joined to
  the first one's group); otherwise the level is won.
- **Actions.** `place(slot, well)` puts a well (a usable cell no other well holds, strength 1 … 4, a sense) into one of
  three slots or changes it, and `remove(slot)` empties one; each spends one action (refused `r02-g19.action` when out
  of range, unchanged, on an occupied or outside cell or removing an empty slot; `r02-g19.budget` with no action
  left); `play` spends nothing and ends the level won or failed with the named failure. The swim report (densities,
  lit cells, coverage, groups, the smallest coherence and its tick, the first failure and the predicted outcome) and
  its words are reported after every action. Undo and redo are exact; undo from failed returns to playing before the
  play; a won level is final.
- **Life and stored form.** Stages loading, tutorial, playing, paused, won, failed, result; records with previous and
  next fingerprints replay a play exactly; the level's stored form is JSON schema 1 with a SHA-256 fingerprint,
  re-checked on decode (damaged, edited, newer and older forms refused; a swimmer outside, an incoherent start, a
  repeated or outside stencil cell, wells outside or sharing a cell and starting wells that already win are refused).
  The rules are an R02-F23 `PuzzleRules` (`MicroscopicAuroraPuzzle`) over well placements.

## Content pipeline (feature 482, R02-G19-02)

- **Kernel extension.** The budget range widens to 1 … 24 (the manifest's budgets reach 19), and a level may list 2 … 8
  well sites: with sites every well, starting or placed, must stand on one (the play refuses "not a site"; the puzzle
  contract lists placements on sites only, at most 3 × 8 × 8 = 192). A level without sites omits the field, so feature
  481's levels keep their stored form and fingerprints.
- **Manifest.** `MicroscopicAuroraManifest` holds the 100 planned levels of the archived design (number, planned seed,
  band 1 … 5, moves budget 8 … 19, control emphasis), 20 per band.
- **Generator.** Candidate c of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: c))`: the
  swim length, the swarm rules, a bunched swarm with a small drift, the sites (usable within radius 8), the winning
  wells on a partial shuffle of the sites and the threshold; the winning wells are swum and the stencil is the largest
  lit group, trimmed breadth-first to the band's maximum; then the coverage and coherence requirements. Band profiles
  grow from 4 … 5 swimmers, 3 sites and one well (band 1) to 8 swimmers, 6 sites and two wells over larger stencils and
  stricter coverage (band 5). Levels start with no well; adjacent levels never share their stencil; at most 64
  candidates per entry (the catalog needs at most index 11).
- **Solver.** A report depends only on the set of wells, so from no well the settings reachable in d placements are the
  sets of at most d wells on distinct sites (8 options per site). The solver judges depth 0, 1, 2 …, each depth ordered
  by the shape loss (stencil cells unlit plus cells lit outside the stencil) of each set's prefix; the first win is
  minimal and every smaller depth, judged in full, is the proof. Work is counted (at most 830 sets per level, bound
  1,200). The nearest miss is the smallest loss among the smaller depths.
- **Certificates.** `docs/games/microscopic-aurora/levels/NNN.witness.json` (schema 1) holds each level with its sites,
  its placements and the play, a state digest after every action, the play fingerprints, the terminal report (lit
  stencil cells, coverage, groups, the smallest coherence) and the counterexample; the tests rebuild all 100 byte for
  byte in 20 groups of 5 and pin the catalog digest. Witness lengths are 1, 1, 2, 2 and 2 by band, under R02-F24's
  progression rule.
