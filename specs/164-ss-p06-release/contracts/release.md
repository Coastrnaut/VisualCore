# Contract: Shader Studio release (A22-P06)

- **Privacy page:**
  - stored data and its removal;
  - "nothing is sent";
  - "no permission is asked";
  - "GPU code is not a sandbox";
  - the licences.
- **Source scan:** 0 refused uses in `Packages/ExperiencesCreative/ShaderStudio`.
- **Claims scan:** 0 refused words in the store text and the interface Swift; "not a sandbox" is present; every named
  test exists.
- **Release checklist:** every row has a status and evidence; device rows name SS-D1 … SS-D6.
- **Release steps:** `experience-release-a22` and `copy-claims-a22` pass; the release build passes unsigned.
- **Recovery:** a failed draw ends the session with a message; storage is byte-identical; a new session lists and
  opens the projects.
- **Samples:** as in data-model.md.
- **Interface (`d3`, `SSReleaseUITests`):**
  - the status is "Compiled";
  - there is no `diagnostic-0`;
  - `uniform-0` is present and `uniform-1` is absent;
  - there is no `project-0`.
