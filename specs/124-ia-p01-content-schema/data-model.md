# Data model: A17-P01 (feature 124)

| Entity | Fields | Rules |
|---|---|---|
| `AnatomyRegion` | schema 1, id `region.knee.right`, systems, convention (cm, +Y superior, +Z anterior, +X lateral), bounds (min, max Vec3), contentVersion 1, meshes, structures, manifest | bounds finite, min < max |
| `ProceduralMeshDeclaration` | id `mesh.<structure>.<part>`, kind ∈ {revolution, tube, extrusion, sphere} | id unique; belongs to exactly one structure |
| `AnatomicalStructure` | id `knee.<name>`, standardName (TA), englishName, synonyms, layer ∈ {bones, cartilage, ligaments} (nil only for the root), parent?, neighbours, meshIDs (1–3; root 0), description, sourceRefs (≥ 1) | non-empty names and description; refs resolve; no parent cycle; synonyms do not collide across structures |
| `ContentManifest` | textLicense `original`, geometryLicense `original`, review {status `not-reviewed`, reviewer nil, date nil}, citations [{id, title, edition, section, license ∈ {public-domain, original, facts}}] | sentence "Not reviewed by a clinician." while not reviewed |
| `AnatomyLabel` | structureID, text (englishName), anchorMeshID | resolves to a structure and its first mesh; the root has no label |
| `ContentRefusal` | reason ∈ {damaged, newer-version, too-large, missing-reference, duplicate-id, parent-cycle, empty-text, unsourced, bad-license, non-finite, colliding-synonym, clinical-text}, sentence | the first problem found; nothing crashes. `empty-text` also covers a description outside 1–3 sentences or over 400 characters; `missing-reference` also covers a part without meshes, a mesh owned by no structure and a part without a layer; a mesh owned twice is `duplicate-id` |
