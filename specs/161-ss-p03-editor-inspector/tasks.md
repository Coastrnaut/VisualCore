# Tasks: Shader Studio — Phase 03 Uniform inspector/persistence

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/editor.md](contracts/editor.md), [quickstart.md](quickstart.md). Gate A22-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A22-P03 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/160-ss-p02-compile-preview/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A22-301 Baseline: cite the A22-P02 evidence (`.autonomy/checks/A22-P02.{ss-ios27-4,app-unit-2,verify-27-3}.json`) — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P02.{ss-ios27-4,app-unit-2,verify-27-3}.json exit 0 at b0bef4c6; Packages, Apps, project.yml unchanged since
  on the tree recorded at A22-P02 (`b0bef4c6`), whose Packages, Apps and project.yml are unchanged since (owner ruling
  of 2026-11-14)

## Phase 2: Foundational — textures and the fourth template (core)

- [X] T-A22-302 [P] Create `Packages/ExperiencesCreative/ShaderStudio/Core/TextureRecipes.swift` per data-model.md — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-core-editor.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 43 on sim-27.2)
  ("64 × 64 RGBA floats (0…1, rows bottom-up)"; `checker` "8 × 8 cells, 0.85 and 0.25 grey"; `ramp` "(0.05, 0.10,
  0.40) to (0.95, 0.55, 0.20)"; `noise` "value noise of an integer hash over an 8 × 8 lattice") and add the template
  `texture-mix` to `Core/ShaderTemplates.swift` (inputs `u_texture0`, `u_texture1`; uniform `u_blend` 0…1, default
  0.5); `///` on every declaration (FR-A22-304)
- [X] T-A22-303 [P] Write `CoreTests/TextureRecipeTests.swift` (sizes, ranges, determinism, the three recipes — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-core-editor.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 43 on sim-27.2)
  differ) and update `CoreTests/TemplateCompileTests.swift` (four templates; active sampler uniforms equal the declared
  texture inputs and float uniforms equal the declared uniforms; `texture-mix` validates and compiles) (SC-A22-304)

## Phase 3: Story 1 — edit and see where it fails (P1) 🎯

- [X] T-A22-304 [US1] Create `Experience/{SyntaxPalette,StudioEditor}.swift` per clarification Q1 and — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-core-editor.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 43 on sim-27.2)
  contracts/editor.md, and wire them into `StudioControls.swift` and `StudioPresenter.swift` (FR-A22-301, 306):
  - `StudioEditor` is a monospaced iOS 26 `TextEditor` over an `AttributedString`, recoloured from `EditorDocument`;
  - a gutter shows the line numbers and the markers;
  - a diagnostics list jumps to a line by setting the selection;
  - edits call `setSource` and never compile; Run and ⌘R send `shader.run`;
  - the identifiers are `editor`, `gutter`, `diagnostics` and `diagnostic-<k>`, with spoken labels.
- [X] T-A22-305 [US1] Write `ExperienceTests/EditorModelTests.swift`: — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-core-editor.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 43 on sim-27.2)
  - the palette maps every token kind, and weights differ from colours;
  - a broken run marks exactly its lines;
  - outside-source entries come first;
  - a fix clears the marks;
  - choosing a diagnostic gives its line's start offset (a pure `EditorDocument` helper, `lineStart(_:)`), covering
    US1/AC3.

## Phase 4: Story 2 — too big never reaches the driver (P1)

- [X] T-A22-306 [US2] Write `ExperienceTests/OversizedProjectTests.swift` (SC-A22-301): — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-core-editor.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 43 on sim-27.2)
  - a 16,385-byte source, a 17-uniform project (a test seam on the presenter) and an empty source;
  - each is refused with its code;
  - the pipeline's `compileCount` and `ResourceRegistry.compileCount` are unchanged;
  - the read-back preview is byte-identical.

## Phase 5: Story 3 — the inspector (P1)

- [X] T-A22-307 [US3] Create `Experience/StudioInspector.swift` per clarification Q3 and write — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-core-editor.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 43 on sim-27.2)
  `ExperienceTests/InspectorTests.swift` (FR-A22-303, 305; SC-A22-303):
  - **Inspector:** rows of title, value with unit and range; sliders send normalized values clamped by the
    presenter; Reset sends the defaults; identifiers `uniform-<k>` and `reset`.
  - **Tests:** the rows match the live project; a value past either end stays at the end; Reset restores the
    defaults; nothing compiles.

## Phase 6: Story 4 — textures made in code (P2)

- [X] T-A22-308 [US4] Change the core adapter and add the textured preview (FR-A22-304, 305): — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-textures.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 48 on sim-27.2)
  - `Experience/Adapter/StudioCore.swift`: `textures [2]` (an optional payload field, default [0, 1]), `texture.set
    [0…1, 0…2]` with the rule `a22.no-texture`, `template.select [0…3]`, and the digest over the template, values and
    textures;
  - `Experience/TexturedPreview.swift`: render targets from `TextureRecipes` and a `FieldPass` into the context's
    framebuffer with the active float uniforms; rebuilt after a context loss, released in teardown;
  - `PreviewPipeline` uses it for projects with texture inputs.
- [X] T-A22-309 [US4] Write `ExperienceTests/TextureInputTests.swift` (SC-A22-303, 304): — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-textures.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 48 on sim-27.2)
  - three choices give three pairwise different pictures for `texture-mix`;
  - after `recreateContext` the picture is the same and nothing leaks;
  - an A22-P02 snapshot without `textures` restores as [0, 1];
  - a snapshot round trip keeps the values and textures;
  - an out-of-range input index is refused.

## Phase 7: Interface and evidence

- [X] T-A22-310 [P] Update `Experience/Adapter/StudioManifest.swift` and `ExperienceTests/StudioManifestTests.swift`: — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A22-P03.ss-textures.json exit 0 (ShaderStudioCoreTests 59, ShaderStudioExperienceTests 48 on sim-27.2)
  - the fixtures add `fixture-texture-mix` and `fixture-textures`;
  - regenerate `scenario-manifest.json`;
  - the manifest's content requirement stays at the planning catalog's 5 fixtures (more fixtures are allowed).
- [ ] T-A22-311 [P] Write the interface tests (FR-A22-307):
  - `Apps/VisualCore/Tests/UI/ShaderStudio/{SSSupport,SSEditorUITests}.swift`, after `AUSupport` with `-vcCandidates`;
  - type a broken line, Run, read the gutter marker and the list, fix, Run, and the marker is gone;
  - move a uniform slider in the inspector;
  - each test under 60 s;
  - the serial chunk `"d3": ["SSEditorUITests"]` in `scripts/release_check.py` and `SERIAL_CHUNKS` (lead).
- [X] T-A22-312 [P] Add the textures and `texture-mix` to `docs/apps/shader-studio/licenses.md`. — Verified 2026-11-18: 2026-11-18: docs/apps/shader-studio/licenses.md lists texture-mix and the three code-made textures; validate_docs passes
- [ ] T-A22-313 Review checkpoint:
  - Shader Studio tests on sim-27.2 (`--name ss-ios27`);
  - the documented API, isolation and core purity.
- [ ] T-A22-314 Contract: G-EDITOR, G-INSPECTOR and G-TEXTURES closed by "A22-P03"; rows whose gaps are all closed
  become available with evidence (`--name contract`)
- [ ] T-A22-315 The catalog, app and runner checks, with the packages and script tests:
  - the catalog (`--name catalog`);
  - `xcodegen generate --spec project.yml`;
  - `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-d3`;
  - the runner (`--name verify-27`).
- [ ] T-A22-316 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A22-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

301 → {302, 303} → 304 → {305, 306, 307} → 308 → 309 → {310, 311, 312} → 313 → 314 → 315 → 316.
- **Shared files:** 304, 307 and 308 touch the presenter and controls, so they run in sequence.
- **Independent files:** 311 (app interface) and 312 (licences) touch their own files.

## Parallel examples

- **Agent X:** 302 and 303 (core).
- **Agent E:** 304–310 (experience, in sequence).
- **Agent U:** 311 (interface tests, after 304's identifiers).
- **Lead:** 312, `release_check.py`, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the editor and the oversized fixture (304–306).
- **Then:** the inspector (307), the textures (302, 308, 309), and the interface and evidence.
- **Review checkpoint:** at 313.
- **Commits:** one per task.
