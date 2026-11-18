# Data Model: A22-P04 (feature 162)

- **Guidance** (core, pure): `Guidance.forIssue(_ issue: ShaderIssue) -> String` gives one sentence per code, with
  the line where the issue has one. `Guidance.forDiagnostic(message:) -> String` covers:
  - "undeclared identifier" → "Declare <name> before it is used, for example `uniform float <name>;`."
  - "syntax error" → "A semicolon or bracket is missing on or just before this line."
  - "cannot convert" / "wrong operand types" / "no matching overloaded function" → "The types do not match: write
    1.0 for a float, and match vec sizes."
  - otherwise → "Check this line for a typing mistake."

  Distinct sentences per refusal code.
- **FrameWatchdog** (core, pure):
  - Configuration: `limit` 0.25 s and `window` 8.
  - State: `watching` or `stopped`, plus the count of consecutive slow intervals.
  - Operations:
    - `record(_ interval:) -> State` ignores non-finite and non-positive intervals and skips one after `rearm()`;
    - `rearm()` is called at setup, resize, Run and Reset;
    - `reset()` returns to `watching`.
  - It is stopped when 8 consecutive recorded intervals are each above 0.25 s.
- **StudioCore** (schema 1): adds `resets` (optional in the payload, default 0) and the action `preview.reset [1…1]`.
  The digest covers `resets`.
- **Saved project** `project-<n>.json`:
  - the envelope `{"body", "kind": "a22.saved-project", "version": 1}`, at most 131,072 bytes;
  - the body `{name, order, project, values[16], textures[2]}`, where `project` is the `ShaderProject` encoding;
  - refusals `damaged`, `newer-version`, `too-large`, or the `ShaderProjectRefusal` code.
- **Library index** `library.json`: the envelope `{"body", "kind": "a22.project-library", "version": 1}` with the
  body `{next, entries: [{file, name, order}]}`. A newer index makes the library read-only.
- **Caps and messages:**
  - 24 projects, counting unreadable files: "The library holds 24 projects.";
  - names trimmed to 1…40 characters, and names that differ only in case are the same: "A name has 1 to 40
    characters.";
  - an existing name: "A project is already called <name>.";
  - a failed write keeps the previous file.
- **Order:** newest first, then the unreadable files by number.
