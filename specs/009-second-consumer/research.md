# Research: Phase 8

- **R1 Demo choice** — Decision: a calm tap-to-plant / harvest garden (game-like + generative). Rationale: exercises
  every capability area the prompt names (rendering, resources, shaders, effects, input) with tiny, testable rules.
  Alternatives: a generative-art tool (no win condition, harder to smoke-test), a reflex game (timing-sensitive tests).
- **R2 GardenKit package** — Decision: local SwiftPM package under the harness, depending on VisualCoreMath and
  VisualCoreSimulation; host `swift test`. Rationale: constitution IV and the pattern the 25 apps will reuse.
- **R3 Documented-API check** — Decision: regex scan of `public (final )?(class|struct|enum|protocol|actor|func|typealias) Name`
  in `Packages/*/Sources`; consumer references = word-boundary matches in consumer Swift sources (excluding comments
  and strings is approximated by stripping `//` comments and string literals); docs corpus = package READMEs +
  `specs/*/contracts/*.md`. Output lists used/undocumented names; exit 1 on undocumented. Member-level documentation is
  covered by the type's contract entry. Alternatives: Swift symbol graphs (`swift-symbolgraph-extract`) — heavier and
  iOS-only for the rendering package; kept as a possible F09 improvement.
- **R4 Audit reuse** — Decision: resolve `packages:` paths relative to the spec file's directory (root specs are
  unaffected); add a post-build phase to the game target like the Showcase.
- **R5 Rendering** — Background: full-screen shader (`field.vert/.frag`, slow aurora gradient, bundled) drawn first;
  flowers: `PrimitiveRenderer` circles + polygon petals scaled by growth; particles: `ParticleRenderer`; whole frame
  inside `EffectScene` with a bloom pass (glow); Reduce Motion lowers particle rate and disables bursts.
