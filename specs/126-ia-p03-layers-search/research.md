# Research: A17-P03 (feature 126)

- **D1 Translucency inside the depth pass** (Q2, G-GHOST). The stage is additive: opaque items first, then
  translucent items back to front with blending and without depth writes. That is the standard order for correct
  occlusion of ghosts by solid parts. Sorting by one point per item is exact for convex, non-overlapping meshes and
  stable for the knee's parts. *Alternatives:* order-independent transparency (rejected: needs float targets and a
  second pass, far beyond one consumer); a second renderer (forbidden).
- **D2 Premultiplied blend** (Q2). `MeshRenderer` already writes `rgb × a`, so ONE, ONE_MINUS_SRC_ALPHA is correct and
  needs no shader change.
- **D3 Search by fold and word prefix** (Q1). `CatalogSearch.fold` gives device-independent matching. Word prefixes
  catch "ten" for "tendon" and "acl" for "ACL" without fuzzy matching, which is harder to test.
- **D4 The view file through ExperienceStorage** (Q4). `DocumentStore` needs a directory URL, which the storage handle
  does not expose, so the experience follows Simulation Lab's preset store: an envelope in one named file.
- **D5 Isolate overrides the toggles** (Q3). The learner asked to see that set, so it is shown even when its layer is
  off. "Show all" returns to the toggles.
- **D6 `view.apply`** (converge 2026-11-16). The presenter opens the stored view through the action `view.apply`, so
  that state still changes only by actions and replays stay deterministic (constitution IV). The action takes 11
  values: turn, tilt and zoom; the three layer switches; the selection and framing indices (−1 for none); and the
  isolate kind, index and mode. It replaces the whole view after every value is validated, and anything out of range
  is refused with `a17.invalid-choice`. The presenter sends it once, on the first frame, when the core is at the
  opening view and `view.json` holds another view. A restored snapshot therefore wins over the file.
