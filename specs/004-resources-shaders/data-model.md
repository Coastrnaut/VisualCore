# Data model: Phase 3

- **ShaderSource**: `name` (unique in library), `text`.
- **ExpandedShader**: `text`, `lineMap: [(file, line)]`, `defines: [String: String]` (sorted for hashing).
- **ShaderDiagnostic**: `file`, `line` (0 = unknown), `stage ∈ {vertex, fragment, link}`, `severity ∈ {error, warning}`, `message`.
- **ShaderSourceError**: `tooLarge(bytes)`, `tooDeep(depth)`, `cycle([names])`, `unknownInclude(name, file, line)`, `unsupportedVersion(file, line)`.
- **ResourceKind**: `texture, buffer, framebuffer, renderbuffer, program, shader, vertexArray`.
- **ResourceBudget**: `total` (default 256 MiB), `perKind: [ResourceKind: Int]`.
- **ResourceLedger**: per-kind `liveCount`, `liveBytes`, `peakBytes`, `staleRejected`, `leaked`, `shaderFailures`, `warnings: [String]` (deduplicated).
- **GPUHandle**: `id` (unique), `kind`, `name: UInt32`, `bytes`, `generation`, `label`.
- **RenderTarget**: framebuffer + color texture handles, `width`, `height`, `format`.
- **ShaderProgram**: GL name, `uniforms: [name: (location, type)]`, cache key (SHA-256 hex), generation.
