# Contract: Fractal Explorer release artifacts

| Artifact | Check |
|---|---|
| Privacy manifest | `check_privacy_manifest.py --app <Release app>` PASS; `PrivacyTests` |
| Usage descriptions | exactly NSPhotoLibraryAddUsageDescription (`check_app_release.py`, `PrivacyTests`) |
| Icon | `IconRenderTests` provenance; compiled icon in the bundle (`check_app_release.py`) |
| Licenses | bundled `Licenses/licenses.json` (`AcknowledgementsUITests`, `check_licenses`) |
| Release documents | 4 documents and checklist rows (`check_app_release.py`) |
| Automation | 0 symbols in Release (`check_release_symbols.py`) |
| Networking | `check_app_isolation.py` PASS |
| Data | `MigrationTests` (v1 fixture), `CrashRecoveryTests` |
| Copy | `CopyTests` |

UI identifiers: `fe.home.acknowledgements`, `fe.acknowledgements.*` (VisualCoreUI).
