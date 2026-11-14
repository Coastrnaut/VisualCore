# Data model: A05-P06

- **Fixtures**: `composition-00000000-0000-4000-8000-00000000a501.json` (format 1, document v1, digest of its state),
  `…a502` (format 2), `…a503` (format 1, document version 2), `…a504` (damaged JSON), `…a505` (no `format` key).
  Expected: listed / newer / newer / unreadable / unreadable.
- **release.json**: `{schema: 1, experience: "a05.infinite-geometry", requiredDocs: [...], checklist, copyCheck: {text,
  swift}}`.
