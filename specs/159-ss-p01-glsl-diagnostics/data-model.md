# Data Model: A22-P01 (feature 159)

- **ShaderLimits:** `maxSourceBytes` 16,384, `maxLines` 400, `maxUniforms` 16, `maxTextureInputs` 2; hard ceiling
  `ShaderLibrary.maxExpandedBytes` (64 KiB). A project's limits may be lower, never higher.
- **UniformDeclaration:** a `ParameterDefinition` (name matching `^[a-zA-Z][a-zA-Z0-9_]{0,31}$`, title, finite range
  min < max, default inside). Reserved names: `u_time`, `u_resolution`. Float only in 0.1.
- **ShaderProject** (schema 1, kind `a22.shader-project`, ≤ 65,536 bytes encoded, canonical JSON with sorted keys):
  `name` (1…40 characters), `source`, `uniforms` (in order), `limits`, `textureInputs` (0…2 names). Refusal codes:
  `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`.
- **ValidationIssue:** `source-too-large(bytes)`, `too-many-lines(n)`, `too-many-uniforms(n)`,
  `too-many-texture-inputs(n)`, `no-main`, `version-line(line)`, `reserved-name(name)`, `duplicate-name(name)`,
  `undeclared-in-source(name)`, `undeclared-in-project(name)` (both for float uniforms and for `sampler2D` texture
  inputs).
- **ShaderAssembly:** files `ss/prelude.glsl`, `ss/shader.frag` (the person's source), `ss/main.frag` (entry);
  `personFile` = `ss/shader.frag`.
- **MappedDiagnostic:** `line` (Int? — nil when outside the person's file), `file`, `severity`, `message`, `stage`.
- **Token:** `kind` ∈ {comment, preprocessor, number, keyword, type, builtinFunction, builtinVariable, identifier,
  operator, punctuation, whitespace}, `range` (UTF-8 offsets within its line).
- **EditorLine:** `number` (1-based), `text`, `tokens`, `diagnostics`. **EditorDocument:** `lines`, `outside`
  (diagnostics not in the person's file or with no line).
- **ShaderTemplate:** `id` (`gradient`, `noise-flow`, `rings`), `title`, `source`, `uniforms`, `licence`.
- **As built (A22-P01):**
  - **`MappedDiagnostic.line`:** nil only for `unknown`, `<generated>` or line 0. A diagnostic of any other file keeps
    that file's line, and the editor sends every file other than `ss/shader.frag` outside
    (`DiagnosticMapper.isInPersonSource`).
  - **Additions:**
    - `ShaderLimits.isAcceptable`: bytes and lines 1…standard, uniforms and inputs 0…standard, bytes ≤ the ceiling;
    - `EditorDocument.markedLines`: the line numbers that carry a diagnostic;
    - `GLSLTokenizer.tokens(of:)`: one line, starting outside any comment;
    - `ShaderTemplates.template(id:)`.
  - **Line counts:** the validator counts lines without a final empty line (a trailing newline adds none), while the
    editor shows one (each terminator starts a line, as an editor shows it). Line numbers agree, so a diagnostic's
    line is the same in both.
  - **Templates:** built with `try?` and no `try!` (the isolation check refuses `try!` on stored data); the tests
    require all three.
  - **Tests:** the test compile scene (`AssemblyCompileScene`) compiles and draws nothing, and templates are drawn
    through `FullScreenShaderScene` with `ShaderBundle(files:)`. So no GL call is made outside VisualCore.
