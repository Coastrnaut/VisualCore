# Research: A17-P04 (feature 127)

- **D1 Promote the label layout** (Q2). A17 is the third consumer, so the generic part goes to VisualCoreMath:
  projection, culling, priority order and overlap skipping. That is the constitution's reuse rule. A14 and A15 keep
  their own layouts until their gates adopt it. *Alternative:* a third copy in the experience (rejected: the rule).
- **D2 Gestures as in Molecular Explorer** (Q1). The same arbiter, thresholds and step sizes make the two 3D
  experiences feel alike, and the precedent is tested.
- **D3 Signs from VisualCore's sign check** (Q3). Three shapes (circle, diamond, triangle) are distinct without
  colour and pass `stateSignProblems`.
- **D4 The pack as an envelope around the region** (Q4). It is the same `DocumentEnvelope` as the view file, so one
  migration pattern serves both. Schema 1 is the A17-P01 bare file, which keeps that resource readable.
- **D5 No network by a source scan** (Q5). The compliance check already scans the app, and a core test scoped to the
  experience gives a fast, local failure.
