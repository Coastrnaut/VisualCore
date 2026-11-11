# Fluid Art Playground — build and archive

All commands run from the repository root on the project Mac (Xcode 27.2 27B52, `scripts/verify_environment.py`).
The agent runs only unsigned builds. Signing, archive upload and store submission are owner actions.

## 1. Prerequisites

```bash
python3 scripts/verify_environment.py
xcodegen generate --spec project.yml
```

The ANGLE frameworks come from the pinned reference (`External/projectm-ios/Build/ANGLEFrameworks`). Build them there
with its own scripts if they are missing.

## 2. Tests (simulators)

```bash
swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundCore
xcodebuild test -project VisualCore.xcodeproj -scheme FluidArtPlayground \
  -destination "platform=iOS Simulator,id=<iOS 27.2 or 26.5 UDID>" -derivedDataPath Build/DerivedData/FluidArtPlayground \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 300 CODE_SIGNING_ALLOWED=NO
python3 scripts/check_test_enumeration.py --sources Apps/FluidArtPlayground/Tests --log <xcodebuild log>
```

## 3. Release build and checks (unsigned)

```bash
python3 scripts/release_check.py --only app-release-fluid-art-playground
```

This builds `Release` for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO`, then runs:
- `check_release_symbols.py`: 0 automation symbols;
- `check_privacy_manifest.py`: the manifest equals the scan;
- `check_app_release.py`: icon, version, encryption key, usage strings, licenses, documents, checklist.

## 4. Automation rehearsal (simulators)

The modes, keys and report fields are in [device-campaign.md](device-campaign.md). A simulator run is rehearsal,
never device evidence.

```bash
xcodebuild build -project VisualCore.xcodeproj -scheme FluidArtPlayground -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath Build/DerivedData/FluidArtPlayground CODE_SIGNING_ALLOWED=NO
python3 scripts/run_automation_sim.py --app Build/DerivedData/FluidArtPlayground/Build/Products/Debug-iphonesimulator/FluidArtPlayground.app \
  --runtime 27.2 --mode smoke --seed 7 --out .autonomy/logs/fap-automation
```

## 5. Owner-only steps (never performed by the agent)

1. Create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM = <team ID>` (the OU of the "Apple
   Development" certificate), or set the team in Xcode.
2. Choose the store name and the final bundle ID before the first upload. The bundle ID is permanent once uploaded.
3. In Xcode: Product → Archive (scheme FluidArtPlayground, "Any iOS Device"), then Distribute App → App Store
   Connect → Upload.
4. In App Store Connect: create the app record, enter the privacy policy URL, answer App Privacy ("Data Not
   Collected"), add screenshots and the listing text, and submit for review.
