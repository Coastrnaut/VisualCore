# Quickstart: R02-G15-01

`swift test --package-path Packages/ExperiencesRound02 --filter VoxelOrigami` — poses after every turn, collision and
sweep decisions, canonical hashes and covered counts agree with an independent recomputation; wins on the exact turn;
`collision` and `sweep` failures named with the hinge, the cubes and the cell; budget failure on the exact action (one
action either side), a cube one cell clear of another and inside it, a sweep that just clears and just touches a cube;
refusals with reason codes (unknown hinge, leaf hinge, wrong step, stage, stale); undo (including from failed), redo
and replay fingerprints; stored-form refusals and the invariant tests; each test under 10 s.
