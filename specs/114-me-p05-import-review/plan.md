# Implementation Plan: Molecular Explorer — Phase 05 Import fuzz/error and scientific review

**Branch**: `114-me-p05-import-review` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-IMPORT and G-REVIEW with no VisualCore change.
- **Core.** `MoleculeImport` turns a picked file into actions: a size check from the file's size, the existing
  `XYZParser`, fixed refusal sentences, a sanitized title, and the action list `import.begin`, `import.atom` × n,
  `import.end`. `MoleculeState` moves to schema 4 and holds the imported molecule; schemas 1–3 migrate with no import.
- **Review.** `MoleculeReview` generates `docs/apps/molecular-explorer/data-review.md` and scans the shown sentences for
  claim words.
- **Experience.** `MoleculeCore` accepts the three import actions and `molecule.select [5]`. `MoleculeImporter` reads
  a security-scoped picked URL, stores `import.xyz` and sends the actions through the port, stopping at the first
  refusal, as `AquariumLibrary.open` does. The presenter adds the imported entry to the recent list and the inferred-bond
  line to the panel, and the controls get an Import button with the system document picker.
- **Tests.** A 2,000-file seeded fuzz corpus and a leak fixture over `ResourceLedger`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/import.md](contracts/import.md).

## Technical Context

- **Language:** Swift 6.
- **Dependencies** (verified in code on 2026-11-16):
  - `XYZParser.parse(_: Data)`, with `maxBytes = 65_536` and the twelve `XYZRefusal.Reason` cases;
  - `Elements.element(symbol:)` and the ten elements, atomic numbers 1, 6, 7, 8, 9, 15, 16, 17, 35 and 53;
  - `BondInference`;
  - `ExperienceStorage.write(_:to:)`, `read(_:)` and `exists(_:)`;
  - `ExperienceSnapshot.maxBytes = 1_048_576`;
  - `ResourceLedger.Snapshot` `liveCount` and `liveBytes`, as already used in `MoleculeSessionTests`;
  - SwiftUI `fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)`, as used in
    `MusicLabControls`;
  - `URL.startAccessingSecurityScopedResource()`, as used in `MusicLabPresenter.chooseFile`;
  - `URL.resourceValues(forKeys: [.fileSizeKey])`;
  - `UTType(filenameExtension:)` and `UTType.plainText`;
  - `scripts/check_copy_claims.py`.
- **Storage:** `import.xyz` (≤ 65,536 bytes) in the experience's folder.
- **Testing:**
  - core and experience tests in ExperiencesCreative on sim-27.2;
  - the scenario manifest is regenerated, because the state JSON gains `"schema": 4`;
  - app build and unit tests; the runner on iOS 27; packages; contract; documented API; script tests; copy claims.
- **Performance:** the import of at most 500 atoms is 502 actions; the fuzz corpus of 2,000 files runs well under 10 s.
- **Constraints:** no prompt, no network, iOS 27 only. No NEEDS CLARIFICATION remains.

## Constitution Check

- **I:** PASS.
- **II:** PASS. Parser, storage, picker pattern and action replay are reused; no upstream change.
- **III:** PASS (deterministic engine; the import is actions).
- **IV:** PASS. Import, fuzz and review are tested without a GPU.
- **V:** PASS. Schema 4, with migration from 1–3 tested.
- **VI:** PASS.
- **VII:** PASS. The Import button has a label, value and hint.
- **VIII:** PASS. The file is chosen by the person, read once and copied into the experience's own folder only; no
  usage description is added.
- **IX:** PASS (size checked before reading; parser caps).
- **X–XIII:** PASS.
- **A15 rules:** PASS. Offline-first and private; data with provenance (the review); bounded; no medical claims.

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/MolecularExplorer/Core/{MoleculeImport,ImportedMolecule,MoleculeReview}.swift        new
Packages/ExperiencesCreative/MolecularExplorer/Core/MoleculeState.swift (schema 4)                               modify
Packages/ExperiencesCreative/MolecularExplorer/CoreTests/{MoleculeImportTests,ImportFuzzTests,
  MoleculeStateSchema4Tests,MoleculeReviewTests}.swift                                                           new
Packages/ExperiencesCreative/MolecularExplorer/Experience/MoleculeImporter.swift                                 new
Packages/ExperiencesCreative/MolecularExplorer/Experience/Adapter/MoleculeCore.swift (import actions, select 5)   modify
Packages/ExperiencesCreative/MolecularExplorer/Experience/{MoleculePresenter,MoleculeControls,RecentStore}.swift  modify
Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/{MoleculeImportSessionTests,MoleculeLeakTests,
  MoleculeWordsTests}.swift                                                                                      new
Packages/ExperiencesCreative/MolecularExplorer/scenario-manifest.json (regenerated)                               modify
docs/apps/molecular-explorer/data-review.md (generated)                                                          new
docs/apps/molecular-explorer/visualcore-contract.json (G-IMPORT, G-REVIEW closed)                                 modify
```

**Dependency direction:** Experience → Core → VisualCoreMath and Foundation. The importer depends on
`VisualCoreExperience` storage and the action port. Nothing in VisualCore depends on the experience.

**Lifecycle:** the person taps Import, and the system picker returns a URL (a cancel does nothing). The importer then:
1. starts security-scoped access;
2. reads the file size, and refuses above 65,536 bytes without reading;
3. reads the bytes and stops the access;
4. parses the bytes, and on a refusal shows its sentence with no state change;
5. writes `import.xyz`, and on a failed write shows a message but still imports, since the engine state holds the
   molecule;
6. sends the actions, stopping at the first refusal.

The presenter then records `imported` in the recent list. At reopening, the saved state (schema 4) brings the import
back. Choosing `imported` from the recent list while the engine has no import replays the stored file.

**Migration:** state schemas 1, 2 and 3 migrate to 4 with no import; `MigrationChain` gains the step 3 → 4. Digests of
the standard scenarios change only through the schema number, so the manifest is regenerated and reviewed.

**Rollback:** revert the commits. A schema-4 snapshot is then refused as newer, and the experience opens its initial
state, with the saved-state store's quarantine keeping the file.

## Parallel work

- **Agent A:** core import, state schema 4, review and core tests.
- **Agent B, after A:** adapter, importer, presenter, controls and experience tests.
- **Lead:** manifest, review document, contract, runs and commits.
