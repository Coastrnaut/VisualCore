# Research: A22-P01 (feature 159)

- **D1 Assembly (clarification Q1):** three named files in one `ShaderLibrary`, so `InfoLogParser`'s origin mapping
  names `ss/shader.frag` and the authored line without any offset arithmetic. Alternatives considered:
  - concatenating the prelude with the source and subtracting the prelude's line count (rejected: fragile when the
    prelude changes, and it breaks for errors inside includes);
  - `#line` directives (rejected: `ShaderLibrary` emits none, and drivers differ in how they report them).
- **D2 Limits (Q2):** 16,384 bytes, 400 lines, 16 float uniforms and 2 texture inputs, all well under the 64 KiB
  expansion ceiling. A source that large still expands below the ceiling with the prelude and the `vc/` includes.
- **D3 Envelope (Q3):** an app-local versioned envelope (kind, version, body), as Digital Zen Garden's is. It is
  stored through `ExperienceStorage` later (A22-P04). `VisualCorePersistence.DocumentEnvelope` is not used, because
  the storage there is a raw directory. So the core depends only on `VisualCoreShaderSource` and
  `VisualCoreParameters`.
- **D4 Tokens (Q4):** a single linear pass with ordered rules. Word lists are static sets taken from the GLSL ES 3.00
  specification's keyword and built-in function names, which are facts, written here.
- **D5 Proof (Q5):** the compile tests use `RenderHost(scene:)` with a scene that calls
  `context.resources.program(...)`, the path `FullScreenShaderScene` uses, and read `ShaderError.compile`
  diagnostics. Drawing one frame confirms that a valid template links and renders.
