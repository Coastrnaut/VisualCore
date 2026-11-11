# Research: A01-P02

- **R1 Clock semantics.** Decision: `SceneClock` is a value type.
  - `advance(by:)` caps a delta at 0.25 s and adds delta × speed × (reducedMotion ? 0.5 : 1) while playing.
  - Time wraps modulo `duration` (120 s).
  - `scrub(to:)` clamps to 0…duration; speed clamps to 0…4.
  - Non-finite input is ignored.

  Rationale: deterministic and host-testable; the cap prevents background jumps. Alternative: wall-clock based,
  rejected because it is not deterministic and is hard to test.
- **R2 Editor model.** `ParameterEditor` (value type) holds the schema, `values` and `baseline`:
  - `set(_:to:)` clamps a finite value and rejects non-finite values;
  - `set(_:normalized:)` clamps the position to 0…1 (non-finite counts as 0);
  - `reset(_:)` and `resetAll()` return to the baseline; `isModified(_:)` and `rebase(_:)` replace the baseline;
  - `formatted(_:)` gives value plus unit with 3 significant digits.

  Rationale: one tested place for the slider rules every app needs.
- **R3 Panel.** `ParameterPanel(editor: Binding<ParameterEditor>, onReset:)` renders a `Form` section. Each row has a
  title, a value text with unit, a `Slider` over the normalized 0…1 position (logarithmic handled by the editor) and
  a reset button shown when the value is modified, plus a "Reset all" button. Accessibility:
  - the slider label is the title;
  - `accessibilityValue` is the formatted value;
  - adjustable increment and decrement step by 5% of the position.

  Identifiers are `vc.param.<name>`, `vc.param.<name>.reset` and `vc.param.resetAll`.
- **R4 Classification of opened data.** `CompositionEditor.open(_ data: Data)` returns one of:
  - `.opened(notes)`, from `ArtDocument.decode` with warnings;
  - `.failed(.corrupt | .unsupportedVersion(n) | .unknownFamily)`, keeping the previous composition.

  A recoverable message maps each case to user text. "Use default" loads the family's default preset.
- **R5 Particles updates.** A seed, palette or parameter change for the particles family creates a new
  `ParticleReplayCursor` from the new composition. The next frame replays to the clock time (≤ 7,200 steps), and the
  result equals a fresh render.
- **R6 Launch data.** `LaunchComposition` reads `-gasComposition` (base64) only under `#if DEBUG`. It rejects more than
  64 KiB and invalid base64 as corrupt, and the scene screen opens for the decoded family (gradient noise when the
  family is unknown or the data is corrupt).
