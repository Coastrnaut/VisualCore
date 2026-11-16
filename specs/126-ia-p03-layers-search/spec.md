# Feature Specification: Interactive Anatomy — Phase 03 Layers, search and descriptions

**Feature Branch**: `126-ia-p03-layers-search` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A17-P03 (legacy ledger) · ID namespace FR-A17-3##, SC-A17-3##, T-A17-3##

**Input**: User description: archived manual `apps/17-interactive-anatomy.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: selection highlighting, labels and searchable metadata;
  - regression fixture: search synonyms resolve to the intended structure;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** of `docs/apps/interactive-anatomy/visualcore-contract.json`:
  - G-LAYERS: isolate, the never-hidden selection and the state round trip; the layer toggles came in A17-P02;
  - G-GHOST: translucent ghosts, an additive stage of VisualCore's depth pass, assessed here;
  - G-SEARCH: the structure search;
  - G-TEXT: the description panel with its citations and the generated sources document;
  - G-VIEW: the saved view.

  "Labels" in this phase means the names shown in the panel, the list and the search results. In-scene labels drawn
  over the model are A17-P04 (G-LABELS).
- **One app, visuals are code, no network.** A change to VisualCore is additive, documented, tested and recorded in
  the public API baseline. The reference regression runs at X-A17.
- Follow `specs/112-me-p03-selection` and `specs/125-ia-p02-scene-selection`.

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `CatalogSearch.fold` (`VisualCoreExperience`) and `DocumentEnvelope` and `MigrationChain` (`VisualCorePersistence`)
  are pure Foundation, so the core may use them.
- `ExperienceStorage` writes, reads and lists named files but exposes no directory, so `DocumentStore`, which needs one,
  does not fit. Simulation Lab's preset store writes enveloped JSON through `ExperienceStorage` instead.
- `MeshRenderer`'s fragment shader writes premultiplied colour (`rgb × a`, `a`).
- `DepthMeshPass.draw` disables blending, enables depth testing with `LESS` and depth writing, draws the items in
  order and blits.

- Q: How does search match and rank? → A:
  - **Index:** each part's English name, standard name and synonyms, each folded with `CatalogSearch.fold`.
  - **Query:** folded and trimmed. It matches a field when it equals the field or when the field's text, from the start of one of
    its words, begins with the query (so multi-word queries such as "patellar ten" match).
  - **Ranks:** an exact name (English or standard) 0; a name word prefix 1; an exact synonym 2; a synonym word prefix
    3; a description word prefix 4, only for queries of 3 or more characters.
  - **Order:** by rank, then inventory order, at most 14 results, each part once at its best rank. An empty query lists
    the 14 parts in inventory order.
  - **Content version 2** adds the synonyms "Thigh bone" (femur), "Shin bone" (tibia), "Calf bone" (fibula) and
    "Kneecap" (patella), still validated against collisions.
- Q: What exactly is the additive translucent stage in VisualCore? → A: All of it is in `VisualCoreRendering`:
  - **API:** `DepthMeshPass.Item` gets `center: Vec3`, a model-space sort point that defaults to the origin. A new
    `draw(_ opaque:translucent:view:projection:fog:context:)` takes both lists.
  - **Existing calls:** the existing `draw` overloads forward with no translucent items, and that path runs exactly
    the code it runs today, so its output is bit-identical.
  - **Translucent items:** drawn after the opaque ones, sorted back to front by the view-space depth of
    `model × center`, with equal depths kept in submission order. Blending is ONE, ONE_MINUS_SRC_ALPHA, because the
    shader output is premultiplied. Depth testing stays on with `LESS`, depth writing is off, and the state is restored
    afterwards.
  - **Ghost style:** a ghost is its layer's material at alpha 0.25.
  - **Failure:** if the translucent draw throws, the presenter falls back to the hide mode. The panel then says "Ghosts
    are off." and the fallback is counted.
- Q: What are the isolate actions and rules? → A:
  - **Actions:** `isolate.part [0…13]`, `isolate.layer [0…2]`, `isolate.mode [0 hide / 1 ghost]` (ghost by default),
    and `isolate.clear` ("Show all").
  - **Solid set:** the isolated set plus the selection. Isolate shows its set even when the set's layer is toggled off.
  - **Ghost set:** in the ghost mode, every other part whose layer is shown; in the hide mode, nothing.
  - **Picking and selecting:** only solid parts are picked, and the list selects solid parts only (refused with
    `a17.hidden-structure` otherwise).
  - **Without isolate:** the A17-P02 rules hold.
- Q: How is the view saved? → A: As one file `view.json` in the experience's storage, written atomically through
  `ExperienceStorage`. It holds a `DocumentEnvelope` of kind `a17.view` with the view state's schema 2 payload:
  - **Payload:** the schema 1 fields plus `isolate` (optional: kind `part` or `layer`, its id, the mode).
  - **Migration:** a `MigrationChain` step 1 → 2 adds no isolate. A file larger than 65,536 bytes is refused as
  too large. The same chain serves the session snapshot.
  - **Unknown ids:** a selection, framing or isolate id that does not resolve is dropped, and the drop is reported in
    a list of reasons.
  - **When:** the presenter writes the file after each accepted action that changes the view. The experience opens
    from the file when the host gives no snapshot.
  - **Refused data:** damaged or newer files are refused, with the reason recorded, and the opening view is used.
- Q: What do the panel and the sources document show? → A:
  - **Panel:** a native section below the list. It shows the English name as its heading, the standard name, the layer
    in words, the description, and each citation as "Title, edition, section (license)". Then comes "Not reviewed by a
    clinician." With nothing selected it says "Select a structure to read about it."
  - **Panel text:** built in the core by `AnatomyPanel` from the content, so it is tested without a GPU.
  - **Sources document:** `docs/apps/interactive-anatomy/content-sources.md` gets a generated table between
    `<!-- BEGIN GENERATED -->` and `<!-- END GENERATED -->`: part, standard name, citations and licenses. It is
    written by a core test under `UPDATE_DATA_SOURCES=1`, and the test fails when the committed table differs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find a structure by name (Priority: P1) 🎯

A learner types a name, a common name or a synonym, for example "ACL", "kneecap" or "shin bone", and sees the
matching structures. Choosing one selects it and frames it.

**Why this priority**: the phase's regression fixture and the searchable metadata of the MVP.

**Independent Test**: search for every structure's names and synonyms; read the first result.

**Acceptance Scenarios**:

1. **Given** a query equal to a structure's English name, standard name or synonym, ignoring case and accents,
   **Then** that structure is the first result.
2. **Given** an empty query, **Then** every part is listed in inventory order.
3. **Given** a query that matches nothing, **Then** the results say so, and the selection is unchanged.

---

### User Story 2 - Read what a structure is (Priority: P1)

With a structure selected, the learner reads a panel: its English and standard names, its layer, its plain-language
description, its sources (work, edition and section) and the sentence "Not reviewed by a clinician."

**Why this priority**: the descriptions and the panel half of the MVP.

**Independent Test**: select each part; read the panel.

**Acceptance Scenarios**:

1. **Given** a selected part, **Then** the panel shows its names, its layer in words, its description and at least
   one citation with edition and section.
2. **Given** nothing is selected, **Then** the panel invites a selection and shows the review sentence.

---

### User Story 3 - Isolate and ghost (Priority: P1)

The learner isolates one structure or one layer. Everything else is either hidden or drawn as a faint translucent
ghost, and the isolated set stays solid. The selection is never hidden: isolating something else keeps the selected
structure visible.

**Why this priority**: the remaining layer behaviour (G-LAYERS) and the ghost renderer (G-GHOST).

**Independent Test**: isolate each layer and a structure with both modes; read the draw list and the frame.

**Acceptance Scenarios**:

1. **Given** isolate on a layer with the ghost mode, **Then** that layer is solid and every other shown structure is
   drawn translucent behind or in front of it, with correct depth against the solid ones.
2. **Given** isolate with the hide mode, **Then** only the isolated set is drawn.
3. **Given** a selection outside the isolated set, **Then** the selection stays drawn solid.
4. **Given** a ghosted structure under a tap, **Then** it is not picked; the solid structure behind it may be.
5. **Given** "Show all", **Then** the isolate ends, the layers return to their toggles, and the selection is kept.

---

### User Story 4 - Come back to the same view (Priority: P2)

The learner leaves and returns. The camera, layers, isolate, ghost mode and selection come back as they were, and an
older saved view still opens.

**Why this priority**: G-VIEW and the manual's versioned schemas.

**Independent Test**: save, reopen, compare; feed an older, damaged, newer or unknown-id view.

**Acceptance Scenarios**:

1. **Given** a saved view, **When** the experience reopens, **Then** the same view is restored.
2. **Given** a schema-1 view (A17-P02), **Then** it migrates with no isolate and the ghost mode off.
3. **Given** damaged or newer data, **Then** it is refused without a crash, and the opening view is used.
4. **Given** an unknown structure id, **Then** that id is dropped with a stated reason, and the rest is kept.

### Edge Cases

- **Isolating the only visible structure of a hidden layer:** isolating shows it. Isolate overrides the layer toggles
  for its set until "Show all".
- **The ghost renderer is unavailable or fails:** the hide mode is used, and the panel says ghosts are off.
- **Search with diacritics or extra spaces** ("Ménisque", "  acl "): it matches after folding and trimming.
- **Two structures sharing a word** ("collateral"): both are listed, the name match first and then by inventory order.
- **A saved view that isolates a structure no longer present:** the isolate is dropped with a reason.
- **The view file cannot be written** (storage full or refused): the session goes on unchanged, the failure is
  counted, and the next view change writes again.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A17-301**: Search MUST match English names, standard names and synonyms, ignoring case, accents and
  surrounding spaces. Results MUST be ranked name before synonym before description, then by inventory order. An empty
  query MUST list every part in inventory order. The same query MUST always give the same results.
- **FR-A17-302**: Choosing a result MUST equal selecting that structure (selection and framing).
- **FR-A17-303**: The panel MUST show, for the selected part, its English and standard names, its layer in words, its
  description, every citation with work, edition and section, and the review sentence. Every part MUST have at least
  one citation with an edition and a section.
- **FR-A17-304**: Isolate MUST apply to one structure or one layer, with a mode of ghost or hide. "Show all" MUST end
  it. The selected structure MUST always be drawn solid.
- **FR-A17-305**: In the ghost mode, the non-isolated shown structures MUST be drawn translucent after the solid ones,
  back to front, with depth testing against the solid structures. Ghosts MUST NOT be picked.
- **FR-A17-306**: The translucent drawing MUST be an additive capability of VisualCore's depth pass. With no
  translucent items, its output MUST be bit-identical to today's. It MUST be documented, tested and recorded in the
  public API baseline. No second renderer.
- **FR-A17-307**: The view (camera, layers, isolate, ghost mode, selection, framing) MUST be saved in the
  experience's storage as a versioned document. A schema-1 view MUST migrate. Damaged or newer data MUST be refused.
  Unknown ids MUST be dropped with a reason.
- **FR-A17-308**: A sources document MUST be generated from the content, listing every structure's citations and
  licenses. A test MUST fail when the committed document differs.

### Key Entities

- **Search index**: folded names, standard names and synonyms per part, with the kind of match.
- **Isolate**: a target (a part or a layer) and a mode (ghost or hide).
- **Saved view**: schema 2 of the view state, in a document with migrations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A17-301**: For 100 % of the parts, each of their names and synonyms finds that part as the first result.
- **SC-A17-302**: For 100 % of the parts, the panel shows a description and at least one citation with edition and
  section.
- **SC-A17-303**: With no translucent items, the depth pass's output equals today's pixel for pixel. A translucent
  item in front of a solid one blends, and behind it is hidden.
- **SC-A17-304**: Under every isolate, for each target and mode, the selection is drawn solid, and the draw list holds
  exactly the solid and ghost sets the rule gives.
- **SC-A17-305**: A saved view round-trips exactly, and a schema-1 view migrates. Damaged and newer data is refused.
  Every test runs in under 10 s.

## Assumptions

- The content of A17-P01 gets the synonyms that search needs ("Kneecap", "Shin bone", "Thigh bone"). This is a new
  content version 2 of the same schema, and the content-sources document is regenerated.
- In-scene labels and their overlap policy are A17-P04 (G-LABELS), as is the accessibility review (G-A11Y).

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 deliverable: layers, search and descriptions | FR-A17-301, 303, 304 |
| MVP: selection highlighting, labels and searchable metadata | FR-A17-301–303 |
| Regression fixture: synonyms resolve to the intended structure | FR-A17-301, SC-A17-301 |
| Context ownership in the host | FR-A17-306 |
| Contract G-LAYERS, G-GHOST | FR-A17-304–306 |
| Contract G-SEARCH | FR-A17-301, 302 |
| Contract G-TEXT | FR-A17-303, 308 |
| Contract G-VIEW | FR-A17-307 |

## Negative Requirements

- No second renderer and no graphics code in the experience; the translucent stage lives in VisualCore.
- No network, no asset, no medical claim, no unsourced text.
- No in-scene labels, no announcements and no accessibility audit in this phase.
