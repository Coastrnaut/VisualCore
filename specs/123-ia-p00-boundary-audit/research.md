# Research: A17-P00 (feature 123)

## Facts (verified in code, 2026-11-16)

Products used by later phases:
- `VisualCoreMath`: `OrbitCamera` (`projection`, `project`, `ray(ndc:aspect:)`), `CameraBounds` and `RayIntersection`
  (triangles, spheres, boxes).
- `VisualCoreScenes`: `Mesh` with `plane`, `cube` and `uvSphere`, and the gesture recognizers.
- `VisualCoreRendering`: `MeshRenderer` (lit, back faces culled, premultiplied-alpha colour, optional fog; depth
  testing left to the caller) and `ResourceRegistry`.
- `VisualCorePersistence` (`DocumentStore`, `MigrationChain`), `VisualCoreExperience` (experience storage, quality
  tiers, scenario manifests) and `VisualCoreExperienceHost` (session, shell, canvas overlay).

Elsewhere:
- Solar System Explorer keeps a pure label-overlap layout, `LabelLayout` (A14-P04). Molecular Explorer keeps atom
  picking and overlay labels. Both are app-local.
- `VisualCoreScenes/MeshShapes.swift` has the tested `Mesh.revolution`, `tube`, `surface` and `extrusion` (a
  capsule is a revolved profile). No blended, depth-sorted translucency exists: `DepthMeshPass` disables blending
  (corrected at T-A17-012).

## Decisions

- **D1 Scope:** audit only (clarification 1); the one app is the shell.
- **D2 Matrix scope:** the five brainstorm capabilities (3D model rendering, textures and materials, camera controls,
  lighting, labels and overlays) and the six version 0.1 features:
  - one reviewed region;
  - layered mesh groups and an accessible structure list;
  - selection highlighting, labels and searchable metadata;
  - camera orbit and zoom with isolate and ghost;
  - factual text with citations and provenance;
  - a download-free offline content pack.

  Cross-cutting rows cover context loss and resize, quality tiers, accessibility, persistence with migration, bounded
  resources and truthful labels.
- **D3 Availability rule:** clarification 2.
- **D4 Gap owners (the manual's phases):**
  - the content inventory, the structure graph and its schema → app-local (A17-P01);
  - the procedural region scene, picking and selection → A17-P02;
  - layers, isolate and ghost, search and descriptions → A17-P03;
  - accessibility, label overlap and the offline content pack → A17-P04;
  - the content review record and validation → A17-P05;
  - release → A17-P06.

  Two generic pieces are assessed for VisualCore ownership in their phase. Ghost translucency (an additive blended,
  depth-sorted stage) goes to `VisualCoreRendering` in A17-P03. `LabelLayout` goes to `VisualCoreMath` in A17-P04,
  since A14, A15 and A17 would be three consumers. The shapes reuse `MeshShapes` and stay app-local content
  (G-SCENE).
- **D5 Region and content:** clarification 5.
- **Alternatives considered:** bundling a licensed mesh set (rejected: visuals are code, and the manual's risk 2);
  modelling the whole body (rejected: the manual's non-goal).
