# Data model: Phase 3

- **ShaderSource**: `name` (unique in library), `text`.
- **SourceOrigin**: `file`, `line` (0 for `<generated>` lines).
- **ExpandedShader**: `text`, `origins: [SourceOrigin]` (index = expanded line − 1), `defines: [String]` (the emitted `#define` lines, sorted by name); `origin(ofExpandedLine:)`.
- **ShaderDiagnostic**: `file`, `line` (0 = unknown), `stage ∈ {vertex, fragment, link}`, `severity ∈ {error, warning}`, `message`.
- **ShaderSourceError**: `tooLarge(bytes)`, `tooDeep(depth)`, `cycle([names])`, `unknownInclude(name, file, line)`, `unsupportedVersion(file, line)`.
- **ResourceKind**: `texture, buffer, framebuffer, renderbuffer, program, shader, vertexArray`.
- **ResourceBudget**: `total` (default 256 MiB), `perKind: [ResourceKind: Int]`.
- **ResourceLedger**: per-kind `liveCount`, `liveBytes`, `peakBytes`, `staleRejected`, `leaked`, `shaderFailures`, `warnings: [String]` (deduplicated).
- **GPUHandle**: `kind`, `name: UInt32` (GL name), `bytes`, `generation`, `label`.
- **RenderTarget**: framebuffer + color texture handles, `width`, `height`, `format`.
- **ShaderProgram**: GL name, `uniforms: [name: (location, type)]`, cache key (SHA-256 hex), generation.
