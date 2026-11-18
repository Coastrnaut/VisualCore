# Feature Specification: Shader Studio — Phase 03 Uniform inspector/persistence

**Feature Branch**: `161-ss-p03-editor-inspector` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A22-P03 (legacy ledger) · ID namespace FR-A22-3##, SC-A22-3##, T-A22-3##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: an explicit Compile and Run action with a last-known-good preview fallback. It was built in A22-P02 and is
    proved again here from the editor;
  - regression fixture: an oversized project is rejected before any GPU work;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-EDITOR, G-INSPECTOR and G-TEXTURES of `docs/apps/shader-studio/visualcore-contract.json`:
  - the editor view, with line numbers, syntax colours and a diagnostics list;
  - the inspector for bounded uniforms;
  - texture inputs generated in code and bound to the preview.
- **Persistence here:** the uniform values and texture choices kept in the session snapshot. Saving named projects is
  G-LIBRARY (A22-P04).
- **Still a candidate.** No VisualCore or ProjectM change. Follow `specs/154-au-p03-composite-prefs`.

## Clarifications

### Session 2026-11-18

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **`FieldPass`** (VisualCoreRendering, public, tested by `FieldPassTests`):
  - it compiles a fragment with `FullScreenShaderScene.vertexSource` through the registry's program cache;
  - it samples named `RenderTarget` inputs on units 0, 1, … in order;
  - it sets typed `FieldUniform`s, which must be active uniforms;
  - it draws into `.framebuffer(name:width:height:)`;
  - it validates everything before drawing.
- **Render targets from code:** `ResourceRegistry.makeRenderTarget(width:height:format:label:)` makes a render target.
  `RenderTarget.upload(rgbaFloats:)` fills an `.rgba8` target from code, clamping each value to 0…1.
- **Counts and units:** `ResourceRegistry.compileCount` counts every program compile. `ParameterDefinition.unit`
  holds a unit string.
- **Templates:** the A22-P01 templates declare no texture input.
- **Editor API:** the app's deployment target is iOS 26.0. In the iOS 27.2 SDK,
  `TextEditor(text: Binding<AttributedString>, selection: Binding<AttributedTextSelection>?)` is available from
  iOS 26.0.
- **Validated:** these answers were drafted before the clarify skill ran and checked inside it against the code and
  the SDK interface (2026-11-18).

- Q: How is the editor built? → A: `StudioEditor` (app-local SwiftUI):
  - **Editing:** a monospaced `TextEditor` over an `AttributedString` of the presenter's document source, recoloured
    from `EditorDocument` tokens on each edit by a pure `SyntaxPalette` (token kind → colour role). Colour is never
    the only cue: kinds also differ in weight (keywords bold, comments italic).
  - **Gutter:** line numbers, with a marker on each line that carries a diagnostic.
  - **Diagnostics:** a list ("Line N: message", outside-source entries first, with their file). Choosing one sets the
    editor's selection to that line's start.
  - **Edits and Run:** an edit calls `setSource(_:)` and never compiles. Run (also ⌘R on a hardware keyboard) sends
    `shader.run`.
  - **Identifiers:** `editor`, `gutter`, `diagnostics`, `diagnostic-<k>`.
- Q: How is "rejected before GPU work" proved? → A: An experience test runs a source of 16,385 bytes and a project with
  17 uniforms (built through the presenter's `setSource` and a test project seam). For each, the status is "Refused:"
  with the limit's code, the pipeline's `compileCount` is unchanged, `ResourceRegistry.compileCount` is unchanged
  and the read-back preview is byte-identical. An empty editor is refused as `no-main`.
- Q: What does the inspector show and send? → A: For each uniform of the live project:
  - **Shown:** the title, the value in its unit (two decimals) and the range ("0.00 to 4.00"), with a slider that
    sends `uniform.set [k, normalized]`. The presenter clamps before sending.
  - **Reset:** it sends the defaults.
  - **Values:** they stay in the core (normalized). Nothing compiles.
  - **Identifiers:** `uniform-<k>` (slider) and `reset`.
- Q: Which textures exist, and how are they bound? → A:
  - **Textures:** three, made in code at 64 × 64 `.rgba8` by a pure `TextureRecipes` (RGBA float arrays):
    - `checker`: 8 × 8 cells, light and dark grey;
    - `ramp`: a horizontal ramp from deep blue to warm orange;
    - `noise`: a value-noise tile from an integer hash.
  - **Fourth template:** `texture-mix` joins the starter templates. It has the texture inputs `u_texture0` and
    `u_texture1` and the uniform `u_blend` (0…1, default 0.5). A22-P01's template tests count sampler uniforms as
    texture inputs, not floats.
  - **Choices:** they are core state, `textures [2]` (0 checker, 1 ramp, 2 noise; default `[0, 1]`), set by
    `texture.set [0…1, 0…2]`, both whole. An input index at or past the project's input count is refused
    (`a22.no-texture`).
  - **Drawing:** a live project with texture inputs is drawn by a `FieldPass` into the context's framebuffer, with the
    chosen targets and the active float uniforms (`u_time`, `u_resolution` and the project's). A project without
    texture inputs keeps the A22-P02 `FullScreenShaderScene`. Targets are made in setup, rebuilt after a context loss
    and released in teardown.
- Q: What is persisted, and does the snapshot schema change? → A:
  - **Snapshot:** schema 1 stays. `textures` is added as an optional field, and a snapshot without it reads `[0, 1]`,
    so A22-P02 snapshots restore. The digest covers the template, the values and the textures. `template.select`
    widens to `[0…3]`.
  - **Not persisted here:** the edited source is not persisted in this phase (G-LIBRARY, A22-P04).
  - **Restore:** restoring a snapshot gives identical values and texture choices, tested.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit the shader and see where it fails (Priority: P1) 🎯

A person edits the shader's source in an editor that numbers its lines and colours its words. When they press Run and
the shader fails, each error appears in a list with its line, and the line is marked in the editor. The preview keeps
the last working shader.

**Why this priority**: the manual's journey 3 (see line-correlated errors, fix them) and feature 01.

**Independent Test**: type into the editor, run, read the marks and the list, fix, run again.

**Acceptance Scenarios**:

1. **Given** the editor shows a template, **Then** every line has its number and its words carry their syntax kind.
2. **Given** an edit that breaks line 4, **When** Run is pressed, **Then** line 4 is marked, the list names line 4,
   and the preview is unchanged.
3. **Given** a diagnostic in the list, **When** it is chosen, **Then** the editor moves to its line.
4. **Given** the fix, **When** Run is pressed, **Then** the marks and the list are cleared and the preview shows the
   new shader.

---

### User Story 2 - Too big never reaches the graphics driver (Priority: P1)

When the person's project is larger than the limits (too many bytes, lines or uniforms), Run explains which limit it
broke and nothing is compiled: the graphics driver never sees it.

**Why this priority**: the phase's regression fixture and manual risk 1.

**Independent Test**: run a project just past each limit; count compiles and GPU programs.

**Acceptance Scenarios**:

1. **Given** a source one byte over the size limit, **When** Run is pressed, **Then** the refusal names the limit,
   no compile happens and no new GPU program exists.
2. **Given** more uniforms than allowed, **Then** the same holds for the uniform limit.

---

### User Story 3 - Tune each uniform within its range (Priority: P1)

The inspector lists each uniform with its title, value, unit and range; the person changes a value and the preview
follows at once. Values stay inside their ranges, can be reset to the default, and survive leaving and reopening the
experience in the same session.

**Why this priority**: the manual's feature 04 (parameter inspector for bounded uniforms).

**Independent Test**: set, clamp, reset and restore values; read the preview.

**Acceptance Scenarios**:

1. **Given** a uniform, **When** its value is set, **Then** the preview changes and the inspector shows the value.
2. **Given** a value past either end, **Then** it stops at the end of the range.
3. **Given** Reset, **Then** every value returns to its default.
4. **Given** a session snapshot, **When** it is restored, **Then** the values and texture choices are the same.

---

### User Story 4 - Textures made in code (Priority: P2)

A template can sample up to two textures made in code: a checker, a gradient ramp or a noise tile. The person
chooses which one feeds each input, and the preview samples it.

**Why this priority**: the manual's feature 02 (templates with texture inputs), the contract's G-TEXTURES.

**Independent Test**: bind each texture to an input; the preview differs per texture.

**Acceptance Scenarios**:

1. **Given** a template with a texture input, **When** each of the three textures is chosen, **Then** the three
   pictures differ.
2. **Given** a context rebuild, **Then** the textures are rebuilt from code and the picture is the same.

### Edge Cases

- **An empty editor:** Run refuses with "no main" and compiles nothing.
- **A diagnostic outside the person's source** (in a shared include): listed above the source with its file, not
  marked on any line.
- **A very long line:** it scrolls; numbering stays aligned.
- **Large text size:** the editor and the inspector stay usable, and line numbers stay readable.
- **A texture input declared but not chosen:** the first texture (checker) is bound.
- **A hardware keyboard:** typing works; Run is reachable by a keyboard shortcut.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-301**: The editor MUST show the source with line numbers and syntax colours, accept edits, mark each
  diagnostic's line, and list every diagnostic with its line; choosing one MUST move to its line.
- **FR-A22-302**: Run from the editor MUST validate first; a project past any limit MUST be refused with the limit
  named and MUST cause no compile and no new GPU program.
- **FR-A22-303**: The inspector MUST list each uniform with its title, value, unit and range; values MUST be clamped
  to the range, applied without a recompile, and resettable to their defaults.
- **FR-A22-304**: Up to two texture inputs MUST be fed by textures generated in code (checker, ramp, noise),
  chosen per input, rebuilt after a context loss.
- **FR-A22-305**: The uniform values and texture choices MUST be kept in the session snapshot and restored with it.
- **FR-A22-306**: Every control MUST carry a spoken label and value, work at large text sizes, and be usable with a
  hardware keyboard.

### Key Entities

- **Editor document**: the source with its numbered lines, tokens and diagnostics (A22-P01's model).
- **Texture choice**: one of checker, ramp or noise, per texture input.
- **Studio state**: template, uniform values, texture choices, run count.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-301**: 100% of oversized samples are refused with 0 compiles and 0 new GPU programs.
- **SC-A22-302**: 100% of failing runs mark exactly the diagnostic lines; after a fix, 0 marks remain.
- **SC-A22-303**: Every inspector value stays inside its range for any input; restoring a snapshot gives identical
  values and texture choices.
- **SC-A22-304**: The three textures give three different pictures; the interface tests each finish in under 60
  seconds and unit tests in under 10 seconds.

## Assumptions

- The A22-P01 editor model and the A22-P02 preview pipeline are reused.
- Named project files come in A22-P04.

## Traceability

| Source | Requirement |
|---|---|
| MVP: explicit Compile/Run with last-known-good preview (proved from the editor) | FR-A22-301, 302 |
| Regression fixture: oversized project rejected before GPU work | FR-A22-302, SC-A22-301 |
| Version 0.1 features 01, 02, 04 | FR-A22-301, 304, 303 |
| Journey 3 (line-correlated errors) | US1 |
| Risk 2 (editor ergonomics: iPad and hardware keyboard first) | FR-A22-306 |
| Contract G-EDITOR, G-INSPECTOR, G-TEXTURES | FR-A22-301–306 |

## Negative Requirements

- No VisualCore or ProjectM change; no GL call outside VisualCore's scenes; no compile from a control's action; no
  image file; no network; not available before X-A22.
