# Contract: ParticleLibrary file format (A04-P06)

Readers accept `format` absent or 1; `format > 1` → `newer` count, file kept. Writers (save, rename) always write
`format: 1`. The public behaviour of `save`, `rename`, `remove`, `document(for:)`, `entries`, `unreadable`, `newer` is
unchanged. `ParticlePresenter.failNextDraw` and `brightnessCap` are internal test seams.
