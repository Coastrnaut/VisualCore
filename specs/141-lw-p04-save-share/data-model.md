# Data model: A19-P04 (feature 141)

- **`WallpaperExportFile: Transferable`:** `url`, `format`; a `FileRepresentation` with exported content type `.png`,
  `.jpeg` or `.heic`. The file name is "<Scene> <Device> <W>x<H>.<ext>".
- **`ExportJob` (`@MainActor`, observable):**
  - state: idle, running(step, progress), done(Output), cancelled, failed(reason);
  - progress: 0.2 after plan, 0.4 after render, 0.7 after encode, 0.85 after verify, 1.0 after write;
  - `start(project:maxEdge:render:)`, `cancel()`, `retry()`;
  - encode and verify run in a detached task;
  - a cancel is honoured at the next step boundary;
  - a cancelled or failed job removes its file.
- **`ExportHistory` (core):**
  - schema 1, kind `a19.export-history`, at most 16,384 bytes;
  - `entries: [Entry]`, newest first, bounded to 20;
  - `Entry` holds `scene`, `template`, `orientation`, `format`, `width`, `height` and `madeAt` (seconds since 1970,
    finite);
  - `adding(_:)` and `cleared()`;
  - `HistoryRefusal` is damaged, newerVersion(Int) or tooLarge(Int), each with a code and a sentence.
- **`HistoryStore` (experience):** reads and writes `history.json` through `ExperienceStorage`, with
  `problem: HistoryRefusal?` after a read and an injected `ClockSource`.
