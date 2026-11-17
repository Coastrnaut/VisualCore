# Data Model: A22-P02 (feature 160)

- **StudioCore** (snapshot schema 1, digest `a22.shader-studio.v1` over template and values):
  - `template` (0…2, integer);
  - `values` (16 entries, 0…1; entries past the template's uniform count are ignored and kept at 0);
  - `runs` (an integer, in the snapshot, not in the digest).
- **Actions:**
  - `template.select [0…2]`: it sets the template, the defaults' normalized values, and runs += 1;
  - `uniform.set [0…15, 0…1]`: the index must be whole and below the template's uniform count;
  - `shader.run [1…1]`: runs += 1.
- **Refusal rules:** `a22.not-whole`, `a22.no-uniform`.
- **Document** (presenter): a `ShaderProject`. It is the template's project when a template is selected; set by
  `setSource(_:)` it keeps the template's uniforms.
- **PreviewStatus:** `.waiting`, `.compiled`, `.failed([MappedDiagnostic])` or `.refused([ValidationIssue])`. The
  status line reads "Waiting", "Compiled", "Failed: N errors" (N being the error-severity diagnostics) or "Refused:
  <first issue code>".
- **PreviewPipeline** (presenter-owned):
  - `pending: ShaderProject?`;
  - `live: FullScreenShaderScene` with its `liveProject`;
  - `compileCount`;
  - `submit(_:)`, which replaces any pending request;
  - `drawFrame(context)`, which compiles the pending request at most once and swaps scenes on success;
  - `rebuild(context)`.
