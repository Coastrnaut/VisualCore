# Grammar-grown vegetation

Feature 219 (R02-F19). Spec: [specs/219-organic-grammar-compact-vegetation-generator](../../specs/219-organic-grammar-compact-vegetation-generator/spec.md).

## The rule

Plants come from a small grammar, a seed and formulas: no image and no hand-made model. The same grammar and seed give
the same plant, and the same scatter seed gives the same garden, on every device; every mesh stays within its budget.

## Parts (VisualCoreScenes)

- `PlantGrammar`: a start word, up to 64 rules that replace one character by one of up to eight weighted successor
  words, 0 … 12 generations, the turn angle, step, radius, radius factor and seed (`Codable`, schema 1).
- `LSystem.derive` rewrites the word generation by generation with one seeded stream, one draw per weighted symbol in
  reading order; a word of more than 1,048,576 symbols is refused.
- `PlantTurtle.interpret` reads the word with the bracketed turtle of Prusinkiewicz and Lindenmayer (1990): F draws a
  `PlantBranch`, f moves, + − & ^ \ / | turn, [ ] push and pop, ! thins, P C L place petal, cap and leaf `PlantMarker`s
  with their frames. The frame is re-orthonormalised after every turn; more than 65,536 branches are refused.
- `PetalShape`, `CapShape` and `StemShape` build a curled petal (a thin closed lens), a closed mushroom cap of revolution and a
  closed tapered, bent stem from their parameters.
- `PlantMesh.build` draws each branch with the existing `Mesh.tube`, places petals, caps and leaves at their
  markers and merges everything with `Mesh.merged`. Every part is a valid closed mesh; touching parts share
  positions, so the merged mesh is drawn as a whole but is not one manifold.
- `PlantScatter.scatter` throws seeded darts over a rectangle with a minimum spacing (checked through a grid) and gives
  each `PlantInstance` a seeded scale, yaw and variant with its model matrix, ready for `MeshInstance` and
  `InstancedMeshRenderer` in VisualCoreRendering.

## Failures

`PlantError` reason codes: `r2-f19.generations`, `r2-f19.word-limit`, `r2-f19.rule`, `r2-f19.weight`, `r2-f19.brackets`,
`r2-f19.turtle-parameter`, `r2-f19.shape-parameter`, `r2-f19.branch-limit`, `r2-f19.scatter-area`,
`r2-f19.scatter-parameter`, `r2-f19.newer-schema`, `r2-f19.malformed`; the experience that reports one adds its id,
seed and tick.

## Limits

Plants are stylised, not botanically accurate: no growth over time, no light competition.

## Sources

L-systems and their turtle interpretation (Lindenmayer 1968; Prusinkiewicz and Lindenmayer, *The Algorithmic Beauty of
Plants*, 1990) and dart-throwing sampling are published methods, re-implemented here. All code is original to
VisualCore.
