# Feature Specification: Interactive Anatomy — Phase 04 Accessibility and offline content

**Feature Branch**: `127-ia-p04-accessibility-pack` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A17-P04 (legacy ledger) · ID namespace FR-A17-4##, SC-A17-4##, T-A17-4##

**Input**: User description: archived manual `apps/17-interactive-anatomy.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: camera orbit and zoom, and the isolation and ghost controls;
  - regression fixture: asset provenance records license and review status;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here** (contract `docs/apps/interactive-anatomy/visualcore-contract.json`):
  - G-LABELS: in-scene labels with overlap handling. Interactive Anatomy is the third consumer of an anchored-label
    layout, so a generic layout is assessed for promotion to VisualCoreMath. Solar System Explorer and Molecular
    Explorer stay unchanged.
  - G-A11Y: layer signs that do not rely on colour, the accessible list, rate-limited announcements, Reduce Motion.
  - G-PACK: the offline content pack, with its envelope, migration, refusals and digest.

  The camera gestures (drag to orbit, pinch to zoom) are the MVP's touch half. The stepped controls came in A17-P02,
  and the isolate controls in A17-P03.
- **One app, visuals are code, no network.** A VisualCore addition is documented, tested and recorded in the API
  baseline. The reference regression runs at X-A17.
- Follow `specs/112-me-p03-selection` and `specs/126-ia-p03-layers-search`.

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- Molecular Explorer's `MoleculeGestures` drives drag, pinch and tap through VisualCore's `GestureArbiter`, with 0.3°
  per point, a step per turn or tilt angle, pinch steps at the zoom factor and at most 64 steps per event.
- `LabelLayout` lives in A14 (internal) and A15 (public in its core), with 24 × 18 boxes offset by 6 points, cull and
  overlap rules.
- `VisualCoreSimulation` has `AnnouncementPlanner(minimumInterval:)` with `submit` and `flush(now:)`,
  `StateSign(id:colorHex:sign:)`, `stateSignProblems(_:)` and `transitionDuration(_:reduceMotion:)`.
- `StableHash.sha256Hex` is in `VisualCoreMath`.

- Q: How do drags and pinches map to camera steps? → A: As in Molecular Explorer:
  - **Drag:** begins after 10 points and counts 0.3° per point, accumulated. Every 15° (50 points) across sends
    `camera.turn` (+1 to the right), and every 10° (about 33 points) up or down sends `camera.tilt` (+1 upward).
  - **Pinch:** each time the scale since the last step passes 1 / 0.85 it sends `camera.zoom +1`; past 0.85 it sends
    `−1`.
  - **Arbitration:** at most 64 steps per event, with priorities pinch 3, drag 2, tap 1 through `GestureArbiter`.
  - **Limits:** a refused step is shown and spoken as "The camera is at its limit."
- Q: What is the generic label layout? → A: `AnchoredLabelLayout` in `VisualCoreMath`:
  - **Call:** `place(_ candidates:camera:aspect:canvas:budget:) -> [Placement]`.
  - **Candidate:** id, model-space anchor, box size in points, priority.
  - **Projection:** each anchor is projected with the camera. One behind the camera, or outside clip depth, is culled.
  - **Box:** placed 6 points up and right of the anchor, and dropped if it crosses the canvas edge.
  - **Order:** candidates are taken by priority, then id. A box that overlaps a placed one by a positive area is
    skipped. At most `budget` boxes are placed.

  The experience's candidates are the solid parts:
  - **Anchor:** the sphere centre.
  - **Box:** 7 points per character plus 8, by 18.
  - **Priority:** 0 for the selection, then 1 + the inventory index.

  The labels are drawn by the host's canvas overlay, with hit testing off. Solar System Explorer and Molecular
  Explorer keep their own layouts.
- Q: What are the layer signs, and how are changes announced? → A:
  - **Signs:** bones "●", cartilage and menisci "◆", ligaments and tendons "▲", each with its material colour. They
    must give `stateSignProblems == []`.
  - **List rows:** "<sign> <English name>", spoken as "<English name>, <layer words>".
  - **Announcements:** selection changes go to an `AnnouncementPlanner` with a minimum interval of 0.5 s, timed by the
    host's step clock: "<English name> selected." or "Selection cleared." The presenter flushes it on later frames, so
    the last change is always announced. They go through an injectable sink (Solar System Explorer's precedent). The production sink posts only while
    VoiceOver is running, so nothing is spoken otherwise.
  - **Reduce Motion:** framing and every camera change are immediate in every mode; nothing is animated, and
    `transitionDuration(_:reduceMotion:)` gives 0 when Reduce Motion is on.
- Q: What is the content pack? → A: The bundled resource becomes `Core/Content/knee-right.pack.json`:
  - **Envelope:** a `DocumentEnvelope` of kind `a17.content-pack` at schema 2, whose payload is the region.
  - **Schema 1:** the bare region file of A17-P01. It migrates by wrapping.
  - **Cap:** 262,144 bytes.
  - **Digest:** `StableHash.sha256Hex` of the region encoded with sorted keys.
  - **Refusals:** damaged, too large and newer, as `ContentRefusal` reasons.

  The bare `knee-right.json` is removed, and `AnatomyContent.bundledRightKnee()` reads the pack.
- Q: What does provenance contain, and how is "no network" checked? → A:
  - **Provenance:** `AnatomyProvenance` is built from the manifest. It holds the text and geometry licenses, each
    citation with its license, and the review status with its sentence. Its check refuses an empty license, a license
    outside the allowed set or a missing review sentence.
  - **No network:** a core test scans the Interactive Anatomy Core and Experience sources for `URLSession`,
    `URLRequest`, `NWConnection`, `Network` imports and `http` literals, and finds none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn and zoom by touch (Priority: P1) 🎯

The learner drags on the model to turn and tilt it, and pinches to zoom. The steps and limits are the same as the
buttons'.

**Why this priority**: the phase's MVP.

**Independent Test**: play drags and pinches on the canvas; read the camera steps.

**Acceptance Scenarios**:

1. **Given** a horizontal drag of a stated length, **Then** the camera turns by the matching number of steps; a
   vertical drag tilts it.
2. **Given** a pinch out past the step ratio, **Then** the camera zooms in one step; past a limit nothing changes, and
   the limit is said.
3. **Given** a single short tap, **Then** it still picks (A17-P02).

---

### User Story 2 - See names on the model (Priority: P1)

The learner sees the names of the parts on the model, anchored to them. No two names cover each other, the selected
part is always named when it is on the canvas, and hidden or off-canvas parts carry no name.

**Why this priority**: G-LABELS and the manual's label-overlap risk (risk 3).

**Independent Test**: lay out the labels for many cameras; check overlaps and the selection.

**Acceptance Scenarios**:

1. **Given** any camera, **Then** no two placed labels overlap by a positive area.
2. **Given** a selected part on the canvas, **Then** its label is placed first.
3. **Given** a part behind the camera, outside the canvas or not solid, **Then** it has no label.

---

### User Story 3 - Use it without sight or colour (Priority: P1)

A VoiceOver user explores through the list, where every part says its name and its layer with a sign that does not
rely on colour. Selection changes are announced, never more often than a stated rate. With Reduce Motion on, nothing
in the view moves on its own.

**Why this priority**: G-A11Y.

**Independent Test**: read the list entries and their signs; select quickly several times; read the announcements.

**Acceptance Scenarios**:

1. **Given** the list, **Then** every part has its name, its layer in words and its layer sign.
2. **Given** layer signs, **Then** no two layers share a sign, and every sign is more than a colour.
3. **Given** five selections within one second, **Then** at most the rate-limited number of announcements is made,
   and the last selection is always announced.

---

### User Story 4 - Content that works offline and says where it comes from (Priority: P2)

The content ships inside the app as a versioned pack. It opens with no network, and it states its licenses and its
review status.

**Why this priority**: G-PACK and the phase's regression fixture.

**Independent Test**: load the bundled pack; feed an older, damaged, oversized or newer pack; read the provenance.

**Acceptance Scenarios**:

1. **Given** the bundled pack, **Then** it loads, validates, and gives the same digest every time.
2. **Given** a pack of the older format (the A17-P01 resource), **Then** it migrates.
3. **Given** a damaged, oversized or newer pack, **Then** it is refused with a typed reason, and nothing crashes.
4. **Given** the pack, **Then** its provenance records the text and geometry licenses, every citation's license, and
   the review status with its sentence.

### Edge Cases

- **A drag that starts as a tap:** below the drag threshold it is a tap. Above it, no tap is sent.
- **Pinch and drag at once:** the pinch wins. The two never both step the camera from one gesture.
- **Many parts crowded in one corner:** labels are skipped until none overlap. The selection is never skipped while
  it is on the canvas.
- **Labels at the canvas edge:** a label whose box would cross the canvas edge is not placed.
- **A pack that names a mesh the scene cannot build:** refused when the scene is built (A17-P02).
- **Any network API in the experience:** a check fails.
- **The canvas is smaller than one label box:** no label is placed; the list still names every part.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A17-401**: Dragging MUST turn the camera horizontally and tilt it vertically, and pinching MUST zoom it, in
  the same steps and limits as the buttons. A refused step MUST be said. A tap MUST still pick.
- **FR-A17-402**: In-scene labels MUST be placed deterministically: the selection first, then by a stated priority.
  No two labels may overlap by a positive area. No label may be placed for a part behind the camera, outside the
  canvas or not solid. At most the level's label budget may be placed (16).
- **FR-A17-403**: The label layout MUST be generic and live in VisualCoreMath as its third consumer, with docs, tests
  and an API baseline entry. Solar System Explorer and Molecular Explorer MUST stay unchanged.
- **FR-A17-404**: Every list entry MUST give the part's name, its layer in words and a layer sign. The signs MUST
  pass VisualCore's sign check (distinct, not colour alone).
- **FR-A17-405**: Selection changes MUST be announced through VisualCore's announcement planner, rate-limited, with
  the last change always announced.
- **FR-A17-406**: With Reduce Motion on, no camera change MAY be animated. Framing stays immediate.
- **FR-A17-407**: The content MUST ship as a versioned pack inside the app. The older format MUST migrate. Damaged,
  oversized or newer packs MUST be refused with a typed reason. The digest MUST be stable. No network API may be
  used.
- **FR-A17-408**: The pack's provenance MUST record the text license, the geometry license, every citation's license
  and the review status with its sentence. A test MUST fail when any is missing.

### Key Entities

- **Anchored label**: part, text, anchor point on the canvas, box.
- **Layer sign**: per layer, a symbol and its words.
- **Content pack**: envelope (kind, schema version), payload (the region), digest, provenance.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A17-401**: Every drag and pinch length in a test table gives the stated camera steps, and limits are refused.
- **SC-A17-402**: For 100 cameras (turn × tilt × zoom samples) and two canvas aspects, no two labels overlap, the
  selection is labelled whenever on the canvas, and at most 16 labels are placed.
- **SC-A17-403**: The layer signs pass the sign check, and the list has 14 entries with signs.
- **SC-A17-404**: The bundled pack loads with a stable digest. The older format migrates. The three refusals are
  typed. The provenance check passes.
- **SC-A17-405**: Every test runs in under 10 s, and the standard scenarios pass on iOS 27.

## Assumptions

- The sign check and the announcement planner are VisualCore's (`VisualCoreSimulation`), which the core may use as a
  pure module.
- The clinical review remains an owner action. The review record (G-REVIEW) is A17-P05.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 deliverable: accessibility and offline content | FR-A17-404–408 |
| MVP: camera orbit/zoom and isolation/ghost controls | FR-A17-401 (isolate controls of A17-P03) |
| Regression fixture: asset provenance records license and review status | FR-A17-408, SC-A17-404 |
| Context ownership in the host | FR-A17-402 (overlay, no GL) |
| Contract G-LABELS | FR-A17-402, 403 |
| Contract G-A11Y | FR-A17-404–406 |
| Contract G-PACK | FR-A17-407, 408 |
| Manual risk 3 (labels overlap) | FR-A17-402, 404 |

## Negative Requirements

- No network, no download, no asset; no change to A14 or A15; no second renderer; no medical claim.
- No accessibility audit run here (device campaign); announcements are tested through the planner, not VoiceOver.
