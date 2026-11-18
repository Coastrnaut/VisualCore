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
- **PreviewStatus:** `.waiting`, `.compiled([MappedDiagnostic])` (warnings only), `.failed([MappedDiagnostic])` or
  `.refused([ValidationIssue])`. The status line reads "Waiting", "Compiled" ("Compiled, N warnings" when there are
  warnings), "Failed: N errors" (N being the error-severity diagnostics) or "Refused:
  <first issue code>".
- **PreviewPipeline** (presenter-owned):
  - `pending: ShaderProject?`;
  - `live: FullScreenShaderScene` with its `liveProject`;
  - `compileCount`;
  - `submit(_:)`, which replaces any pending request;
  - `drawFrame(context)`, which compiles the pending request at most once and swaps scenes on success;
  - `rebuild(context)`.
- **As built (A22-P02):**
  - **Warnings:** a linked program's warnings are not available from VisualCore: `ResourceRegistry.program` returns no
    log on success. So `.compiled` carries none in practice. The "Compiled, N warnings" text and the warnings ordering
    are tested with built `MappedDiagnostic` values.
  - **Probe program:** it is not released after a success, because the registry's program cache is shared and has no
    reference counts. A run whose files equal the live scene's keeps the live scene and only updates `liveProject`.
    Otherwise the new scene is set up; it reuses the cached program, and the probe is released only when that setup
    compiled a program of its own. The rebuild tests record no leak.
  - **Pending requests:** a teardown, including the one the host makes before a context rebuild, drops a pending
    request. The live scene is rebuilt from `liveProject`.
  - **Failures:** an expansion error (`ShaderError.source`), or a scene that fails to build, is `.failed` with one
    diagnostic in file `unknown`.
  - **Additions:**
    - the frame probe `warm-corner` (red at x 0.95 and y 0.05 from the top, for the opening template only), needed
      by the runner's launch-first-frame check (`ProbeTests`);
    - the fifth fixture `fixture-repeated-runs` (manual fixture 5; the content-count audit requires five);
    - `PreviewPipeline.setupCount`, and the internal `ShaderStudioExperience.make(id:)` for tests.
