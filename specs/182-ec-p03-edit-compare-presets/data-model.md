# Data Model: A25-P03

- **Preset file** `preset-<n>.json`: `{"body": {"chain": {...}, "name", "order"}, "kind": "a25.preset", "version": 1}`,
  ≤ 69,632 bytes; n never reused while the index or a higher file exists.
- **Index** `presets.json`: `{"body": {"entries": [{"file", "name", "order"}], "next"}, "kind": "a25.preset-library",
  "version": 1}`; damaged → rebuilt by the next change; newer → read only.
- **Caps:** 24 presets (unreadable files count); names 1…40 characters, unique ignoring case.
- **ChainEdit.replace(EffectChain):** inverse `replace(previous)`.
- **Compare:** `view.compare` on/off in the core, not stored.
