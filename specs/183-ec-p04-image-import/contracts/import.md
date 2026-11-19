# Contract: Effects Composer import (A25-P04)

- `ImageImport.decode(_ data: Data, limit: Int) -> Result<ImportedPicture, ImportRefusal>`.
- Presenter: `importPicture(data:)`, `useTestPicture()`; the status "Your picture" or the refusal's sentence.
- Identifiers: `import` (the PhotosPicker), `test-picture`.
