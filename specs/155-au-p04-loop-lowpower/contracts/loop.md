# Contract: VisualCore ambient loop (A21-P04)

- `AmbientLoopSynth.render` is deterministic, finite, within the gain, and seamless at the wrap (data-model rule).
- `AmbientLoopPlayer` uses `.ambient`, clamps `volume`, ignores non-finite values, starts on `play()`, stops on
  interruption, media-services reset and backgrounding, and never touches the input.
- Both types are in `docs/api/visualcore-public-api.txt` and in the module rows of the two package READMEs.
