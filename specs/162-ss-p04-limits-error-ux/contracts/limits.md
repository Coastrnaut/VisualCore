# Contract: Shader Studio limits, guidance, watchdog and library (A22-P04)

- **Guidance:**
  - every refusal shows "Refused: <code>" and its own sentence;
  - each diagnostic in the list carries its guidance;
  - a `#version` line and a uniform used without a declaration have specific sentences;
  - identifier `guidance` (the sentence under the status).
- **Watchdog:**
  - 8 consecutive drawn frames above 0.25 s stop the preview;
  - the stopped preview draws a flat dark frame;
  - the status is "Stopped: frames took longer than 0.25 s" with `preview-reset`;
  - normal frames never stop it;
  - the first interval after a setup, resize, Run or Reset is skipped.
- **Reset:**
  - `preview.reset [1]` swaps back the previous live shader the watchdog had not stopped, with no compile;
  - with no fallback, it queues the template's starter;
  - editing continues; no relaunch.
- **Library:**
  - save (current document, values and textures, under a name), list, open (queues a Run), rename, remove;
  - caps and messages as in data-model.md;
  - unreadable files are listed with their code and never deleted automatically;
  - identifiers `library`, `save`, `project-<k>`, `open`, `rename`, `remove`.
- **Snapshot:** `resets` is optional; an A22-P03 snapshot restores with 0.
- **Interface (`d3`):** `SSLibraryUITests` covers the guidance of a `#version` line, and saving "Waves" then opening
  it, which gives the same source.
