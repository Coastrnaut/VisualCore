# Feature Specification: Digital Zen Garden — Phase 02 Sand and rake renderer

**Feature Branch**: `146-zg-p02-sand-renderer` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P02 (legacy ledger) · ID namespace FR-A20-2##, SC-A20-2##, T-A20-2##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: continuous multi-sample touch strokes and a brush preview;
  - regression fixture: fast drags have no gaps after resampling;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-SAND, G-RELIEF and G-PREVIEW of `docs/apps/digital-zen-garden/visualcore-contract.json`. The
  experience target is added in `Packages/ExperiencesCreative/DigitalZenGarden/Experience` and registered as a
  candidate (not available until X-A20).
- **Experience A20 inside the one app.** Follow `specs/139-lw-p02-still-renderer`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `FieldUniform` (VisualCoreRendering) carries a float, vec2, vec4 or int, with no arrays. A GPU stamp pass would
  therefore cost one full-target pass per sample: a full replay of 400 strokes of 512 points is about 200,000 passes.
- `RenderTarget.upload(rgbaFloats:)` replaces a target's colour with floats. `.rgba16f` keeps half precision and
  `.rgba8` stores n/255. `FloatRenderSupport.storageFormat(forceFallback:)` picks `rgba16f` or the `rgba8` fallback.
- `ExperienceControl` validates that the number of values equals the number of declared ranges, at most 24.
  `GestureAlternatives.missing(gesture:native:)` requires every gesture action to be a native action too.
- The canvas overlay (`makeCanvasOverlay`) takes no touches and is hidden from accessibility; presenter pointer events
  arrive in view points with the view size (`pointer(_:viewSize:port:)`).
- At A20-P01, a fine rake's tine period is about 1.9 cells of the 160 × 120 reference field, too coarse to draw.

- Q: How is the sand height field made and drawn? → A: On the CPU, then uploaded:
  - **Field:** `SandField` gains a size (columns × rows; the default stays 160 × 120). The drawn field is 480 × 360,
    where the fine rake's period is about 5.8 cells.
  - **Strokes:** the committed strokes are stamped once into a base field. The stroke in progress is stamped over a
    copy of the base field as its points arrive, and on commit it is stamped into the base field itself.
  - **Upload and draw:** the field is uploaded to one render target (`rgba16f`, or `rgba8` holding height × 0.5 + 0.5)
    whenever it changes. A full-screen relief shader draws it: normals from height differences, one light from the
    upper left, `vc_fbm` grain and the sand tone colour, inside a 4:3 tray fitted to the view.
  - **Rebuild:** after undo, redo, restore, resize or a lost context, the field is replayed from the core's strokes.
  - **Why:** this replaces the GPU stamp pass of the P00 contract clarification, which costs a pass per sample
    (recorded in the contract). The GPU's role is the drawing; the field stays exact and testable.
  - **Tolerance:** a drawn target read back with `readFloatPixels` matches the CPU field within 1/1024 for `rgba16f`
    and 1/255 for `rgba8`.
- Q: How does a drag reach the core? → A: Three actions:
  - `stroke.begin`, with values x, y and rake (0 or 1);
  - `stroke.add`, with exactly 24 values, 12 points of x and y in 0…1; unused pairs repeat the last point, and the
    resampler drops repeats;
  - `stroke.end`, with no values.

  View points map into the fitted tray and are clamped while raking. The core keeps the raw points of the stroke in
  progress (at most 2,048) and resamples them with `StrokeResampler`. `stroke.end` commits them through
  `GardenHistory.rake(_:rake:)`; a stroke refused at the stroke cap leaves the garden unchanged with its refusal as
  the outcome. A drag ending outside the tray still ends the stroke. A second finger is ignored.
- Q: What do the native controls do? → A:
  - **Rake:** `rake.style` (0 fine, 1 wide).
  - **Undo and redo:** `edit.undo` and `edit.redo`, each with no values and disabled when the history cannot go that
    way.
  - **Patterns:** four native "rake a pattern" buttons (rows, circle, wave, spiral). They send the same
    `stroke.begin`, `stroke.add` and `stroke.end` actions with points made by the experience, so every gesture action
    has a native alternative (`GestureAlternatives`).
  - **Tone:** `sand.tone` (0…2).
- Q: What is the brush preview? → A: While a finger is down, a native overlay draws the rake's outline at the touch:
  a rectangle of the rake's width across the drag direction, with one line per tine, scaled to the fitted tray. It
  disappears when the finger lifts or the pointers are cancelled, and it never changes the state.
- Q: What is registered and saved? → A:
  - **Snapshot:** the core's snapshot is schema 1: the garden document only. A stroke in progress is not saved; the
    undo history restarts after a restore.
  - **Registration:** the experience is registered as a candidate `a20.digital-zen-garden` with quality levels
    `level-0` (no grain) and `level-1`, permissions none, and a scenario manifest of the nine standard scenarios plus
    fixtures for a raked garden, both rake styles, undo, redo and the tone. The app's synthetic candidate test id
    moves to `a21`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Rake the sand by dragging (Priority: P1) 🎯

A person opens Digital Zen Garden and sees a tray of softly lit sand. Dragging a finger rakes grooves along the path,
however fast the finger moves; lifting the finger finishes the stroke. Undo and redo controls remove and restore the
last stroke.

**Why this priority**: the manual's MVP and its regression fixture.

**Independent Test**: send a fast, sparse drag through the experience; the stroke the core stores has no gap larger
than the spacing, and the drawn sand changes along the whole path.

**Acceptance Scenarios**:

1. **Given** a fresh garden, **When** a drag crosses the tray in a few far-apart events, **Then** the stored stroke has
   evenly spaced points and the drawn grooves follow the whole path.
2. **Given** a raked garden, **When** undo is used, **Then** the last stroke disappears from the sand; redo restores it.

---

### User Story 2 - See where the rake will touch (Priority: P1)

While a finger rests or moves on the tray, a preview outline shows the rake's width and its tines at the finger, in the
chosen rake style.

**Why this priority**: the manual's MVP brush preview.

**Independent Test**: start a drag; the preview appears at the finger with the style's width; lifting the finger
removes it.

**Acceptance Scenarios**:

1. **Given** a touch on the tray, **Then** the preview shows the rake's width and tine count at the touch.
2. **Given** the other rake style chosen, **Then** the preview changes to its width and tine count.

---

### User Story 3 - The sand stays when the screen changes (Priority: P2)

The sand is rebuilt from the garden after a size change, a rotation or a lost graphics context, and it looks the same.

**Why this priority**: the constitution's rebuild rule; the picture is never the only copy of the garden.

**Independent Test**: rake, resize or recreate the context, compare the drawn sand with a fresh replay.

**Acceptance Scenarios**:

1. **Given** a raked garden, **When** the drawing context is recreated, **Then** the sand matches the garden's replay.

### Edge Cases

- **A touch outside the tray:** ignored until it enters the tray; positions are clamped to the tray edge while
  raking.
- **A second finger:** ignored while one finger rakes.
- **A stroke at its point cap:** it ends there; the next drag starts a new stroke.
- **The garden at its stroke cap:** a new drag is refused, the garden is unchanged and a short message says so.
- **No half-float drawing support:** the sand uses the 8-bit fallback and still draws.
- **Reduce Motion:** nothing animates on its own; raking is direct.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-201**: The experience MUST turn a drag into a stroke whose points are evenly spaced within the spacing, sent
  to the core in pieces, and commit it when the finger lifts.
- **FR-A20-202**: The sand MUST be drawn as lit relief from a height field into which the strokes are raked in order,
  with the two rake styles' grooves.
- **FR-A20-203**: The sand MUST be rebuilt from the garden after undo, redo, restore, resize and a lost context, and the
  rebuilt sand MUST match the core's reference field within a stated tolerance.
- **FR-A20-204**: A brush preview MUST show the chosen rake's width and tines at the touch while a finger is down.
- **FR-A20-205**: Native controls MUST choose the rake style and undo and redo, each with a spoken label.
- **FR-A20-207**: When nothing changes, the sand MUST be drawn once and reused (the manual's frame idling when
  still), with the experience's frame rate capped at 30 frames per second; a change of the field or the size draws
  it again.
- **FR-A20-206**: The experience MUST be registered as a candidate with its scenarios, and make no GL call outside the
  host's scenes, no network request and no clock read in its core.

### Key Entities

- **Stroke in progress**: the points received so far and the rake style.
- **Sand target**: the drawn height field, rebuilt from the garden.
- **Brush preview**: the rake outline at the touch.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-201**: A drag of at least three far-apart events gives a stored stroke with 0 gaps larger than the spacing.
- **SC-A20-202**: The drawn height field matches the core's reference field within the stated tolerance.
- **SC-A20-203**: After a context recreation, the drawn sand is identical to the drawing before it.
- **SC-A20-204**: Every test takes under 10 seconds; the verification runner passes on iOS 27.

## Assumptions

- Stones, their shadows and selection come in A20-P03; named gardens and accessibility in A20-P04.
- The tolerance and the target size are those of clarification Q1.

## Traceability

| Source | Requirement |
|---|---|
| MVP: continuous multi-sample touch strokes and brush preview | FR-A20-201, 204 |
| Regression fixture: fast drags have no gaps after resampling | FR-A20-201, SC-A20-201 |
| Manual §6 render sequence stages 1–2 (replay, process touch, update height) | FR-A20-202, 203 |
| Manual §6 rendering lifecycle (rebuild after context loss and resize) | FR-A20-203 |
| Contract G-SAND, G-RELIEF, G-PREVIEW | FR-A20-201–204 |

## Negative Requirements

- No second renderer or EGL path, no GL call in the core, no texture snapshot for undo, no image asset, no network.
