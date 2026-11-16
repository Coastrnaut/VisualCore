# Data model: A17-P01 (feature 124)

| Entity | Fields | Rules |
|---|---|---|
| `AnatomyRegion` | schema 1, id `region.knee.right`, systems, convention (cm, +Y superior, +Z anterior, +X lateral), bounds (min, max Vec3), contentVersion 1, meshes, structures, manifest | bounds finite, min < max |
| `ProceduralMeshDeclaration` | id `mesh.<structure>.<part>`, kind ∈ {revolution, tube, extrusion, sphere} | id unique; belongs to exactly one structure |
| `AnatomicalStructure` | id `knee.<name>`, standardName (TA), englishName, synonyms, layer ∈ {bones, cartilage, ligaments}, parent?, neighbours, meshIDs (1–3; root 0), description, sourceRefs (≥ 1) | non-empty names and description; refs resolve; no parent cycle; synonyms do not collide across structures |
| `ContentManifest` | textLicense `original`, geometryLicense `original`, review {status `not-reviewed`, reviewer nil, date nil}, citations [{id, title, edition, section, license ∈ {public-domain, original, facts}}] | sentence "Not reviewed by a clinician." while not reviewed |
| `AnatomyLabel` | structureID, text (englishName), anchorMeshID | resolves to a structure and its first mesh |
| `ContentRefusal` | reason ∈ {damaged, newer-version, too-large, missing-reference, duplicate-id, parent-cycle, empty-text, unsourced, bad-license, non-finite, colliding-synonym}, sentence | the first problem found; nothing crashes |
