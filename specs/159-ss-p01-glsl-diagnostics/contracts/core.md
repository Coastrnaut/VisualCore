# Contract: Shader Studio core (A22-P01)

- `ShaderProject.decode(_:)` / `encoded()` round-trip byte-identical; refusals per data-model.md; nothing changes on a
  refusal.
- `ShaderValidator.validate(project)` returns every issue in source order; an empty list means "may compile".
- `ShaderAssembly(project)` gives the three file texts and the entry name; adding them and
  `ShaderBundle.visualCoreLibrary` to a `ShaderLibrary` and compiling `ss/main.frag` with
  `FullScreenShaderScene.vertexSource` builds the person's shader.
- `DiagnosticMapper.map(_ diagnostics: [ShaderDiagnostic])` → `[MappedDiagnostic]`: a diagnostic whose file is
  `ss/shader.frag` keeps its line; any other file or `unknown` goes to `outside`.
- `GLSLTokenizer.tokens(of line:)` covers the line exactly; `EditorDocument(source:diagnostics:)` numbers lines from 1
  over `\n`, `\r\n` and `\r`.
- `ShaderTemplates.all` — three templates; each validates, compiles and has active uniforms equal to its declared
  ones (tests).
- No GL call, clock, network or UI framework in `ShaderStudio/Core`.
