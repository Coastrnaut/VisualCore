# Implementation Plan: Shader Studio — Phase 03 Uniform inspector/persistence

**Branch**: `161-ss-p03-editor-inspector` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-EDITOR, G-INSPECTOR and G-TEXTURES:
- **Editor:** `StudioEditor` shows the document with a numbered, marked gutter and syntax colours, plus a diagnostics
  list that jumps to lines. Edits go through `setSource`, and Run sends `shader.run`.
- **Inspector:** `StudioInspector` shows bounded uniforms with title, value, unit, range and Reset.
- **Textures:** `TextureRecipes` makes three textures in code. A `TexturedPreview` draws projects with texture inputs
  through `FieldPass`. The fourth template, `texture-mix`, samples two inputs.
- **Snapshot:** `StudioCore` gains the texture choices (schema 1, optional field) and `texture.set`.
- **Fixture:** an oversized project is refused with zero compiles.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/editor.md](contracts/editor.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI (iOS 26 `TextEditor` with `AttributedString`).
- **Dependencies:** unchanged. The experience uses VisualCore's `FieldPass`, `FieldUniform`, `RenderTarget`,
  `ResourceRegistry.makeRenderTarget` and `.compileCount`, all public and tested.
- **Testing:**
  - core and experience tests on sim-27.2;
  - the app build and unit tests;
  - a new interface chunk `d3` (`SSEditorUITests`) on the iOS 27.2 phone, each test under 60 s;
  - the runner.
- **Constraints:**
  - no GL call outside VisualCore types;
  - no compile from a control.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: drawing through `FieldPass` and `FullScreenShaderScene` in the host's context |
| II | PASS: reuses `FieldPass`, render targets, the A22-P01 editor model; nothing copied |
| IV | PASS: `TextureRecipes`, `SyntaxPalette`, core actions are pure and tested |
| IX | PASS: spoken labels, Dynamic Type, keyboard shortcut; colour not the only cue |
| XIII | PASS: textures and the fourth template written in code; licences recorded |
| A22 (2.18.1) | PASS: caps before compile (fixture), queued compiles, no sandbox claim |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/ShaderStudio/Core/{ShaderTemplates,TextureRecipes}.swift      modify/new  texture-mix; recipes
Packages/ExperiencesCreative/ShaderStudio/CoreTests/{TemplateCompileTests,TextureRecipeTests}.swift   modify/new
Packages/ExperiencesCreative/ShaderStudio/Experience/Adapter/{StudioCore,StudioManifest}.swift       modify  textures, texture.set, fixtures
Packages/ExperiencesCreative/ShaderStudio/Experience/{PreviewPipeline,StudioPresenter,StudioControls}.swift   modify
Packages/ExperiencesCreative/ShaderStudio/Experience/{StudioEditor,StudioInspector,SyntaxPalette,TexturedPreview}.swift new
Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/{OversizedProjectTests,TextureInputTests,InspectorTests,
  EditorModelTests}.swift                                                                  new
Packages/ExperiencesCreative/ShaderStudio/scenario-manifest.json                            regenerate
Apps/VisualCore/Tests/UI/ShaderStudio/{SSSupport,SSEditorUITests}.swift; scripts/release_check.py (chunk d3)   new/modify
docs/apps/shader-studio/{licenses.md,visualcore-contract.json}                              modify
```

- **Dependency direction:** unchanged (app → experience → core → VisualCore).
- **Lifecycle:**
  - texture targets are made in the presenter's setup, filled from `TextureRecipes`, rebuilt after a context loss
    and released in teardown;
  - the `FieldPass` is rebuilt per live project.
- **Migration:** schema 1 with an optional field (old snapshots read `[0, 1]`). **Rollback:** revert the commits.

## Parallel work

- **Agent X:** core changes (templates, recipes and their tests).
- **Agent E:** experience changes (core adapter, pipeline, editor, inspector, textures and their tests), after X.
- **Agent U:** the interface tests.
- **Lead:** release_check.py, licenses, contract, runs, commits.
