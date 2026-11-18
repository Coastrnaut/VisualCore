# Data Model: A22-P05 (feature 163)

- **StudioCore** (schema 1):
  - adds `shape: [uniforms 0…16, inputs 0…2]`, optional in the payload; when absent, it is the template's counts;
  - adds the action `document.shape [0…16, 0…2]`, both whole (`a22.not-whole`);
  - `uniform.set k` requires k < `shape[0]`, else `a22.no-uniform`;
  - `texture.set i` requires i < `shape[1]`, else `a22.no-texture`;
  - `template.select` sets the shape to the template's counts;
  - values are kept by position;
  - the digest covers `shape`.
- **Resource level:** `ResourceRegistry.stats.liveCount` for every `ResourceKind`, plus `totalBytes`.
- **Stress cycle:** a new source that compiles (a unique constant per cycle), a source that fails to compile, and a
  refused source (a `#version` line), each run and drawn once.
- **Device row:** `SS-D<n>` × {D1, D2, D3}, with steps, the expected result and the state `pending`.
