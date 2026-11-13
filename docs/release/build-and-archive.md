# VisualCore — build and archive

The build, test and release-check commands of the one VisualCore app (ADR-0009: one app target, scheme `VisualCore`,
placeholder bundle identifier `dev.visualcore.VisualCore`). Feature 038 (A04-P06), FR-A04-620. Experience documents
link here and do not repeat these commands.

The agent runs only unsigned simulator and generic builds. Every signed, archive, upload and App Store Connect step is
an owner step (section 5) and is recorded as `BLOCKED_OWNER_ACTION` until the owner has done it. No install, launch or
test of the app on a physical device happens before the gate `ImplementationLock-100` is recorded
(`python3 scripts/migration_ledger.py guard-device` exits 0 only then); after it the order is D1, D2, D3, and D3 stays
on iPadOS 26.5.

All commands run from the repository root. No single command may run longer than 10 minutes: split
`release_check.py` with `--only` and `--skip`.

## 1. Prerequisites

The pinned tools and their versions are in [setup.md](../../setup.md) (Xcode 27.2 27B52, XcodeGen 2.46.0, the
iOS 27.2 and iOS 26.5 simulator runtimes, the ANGLE frameworks of setup.md section 6).

```bash
python3 scripts/verify_environment.py            # prints PASS when this Mac matches the pins
xcodegen generate --spec project.yml             # VisualCore.xcodeproj; again after adding a source file
python3 scripts/release_check.py --list          # every release step with its exact command
```

The `app-release-*` steps do not generate the project themselves (setup.md 8.2), so generate it first.

## 2. Package tests (simulators)

```bash
swift test --package-path Packages/VisualCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-26.5 --action test
```

Simulators are chosen by runtime (`sim-27.2`, `sim-26.5`), never by an identifier copied from a log.

## 3. App tests (simulators, unsigned)

The app is built once for testing, then run in chunks of whole test classes. `scripts/xcodebuild_app.py` (called by
these steps) stops a run after `--max-seconds` (default 540), names the test it was on and refuses a busy simulator.

```bash
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/release_check.py --only app-ui-ios27-a
python3 scripts/release_check.py --only app-ui-ios27-b app-ui-ios27-d
python3 scripts/release_check.py --only app-ui-ios27-e app-ui-ios27-f
python3 scripts/release_check.py --only app-ui-ios27-g2 app-ui-ios27-g3
python3 scripts/release_check.py --only app-ui-ios27-h2 app-ui-ios27-i2
python3 scripts/release_check.py --only app-ui-ios27-j2     # Particle Universe: PUSandboxUITests
python3 scripts/release_check.py --only app-ui-ios27-j3     # PUEmitterUITests, PUForceUITests, PUTrailUITests
python3 scripts/release_check.py --only app-ui-ios27-j4     # PUSceneLibraryUITests
python3 scripts/release_check.py --only verify-a04.particle-universe-ios27 verify-a04.particle-universe-ios26
```

The other experiences have their own `verify-<id>-ios27` and `verify-<id>-ios26` steps (see `--list`). A gate's
interface evidence is one pass on the iOS 27.x phone simulator. The system accessibility audits
(`VC_RUN_AUDITS=1`, for example `PUAccessibilityAuditUITests`) wait for the device campaign. Simulator results are
never device evidence.

## 4. Release build and checks (unsigned)

```bash
python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
```

| Step | What it does |
|---|---|
| `app-release-build` | `xcodebuild build` of scheme `VisualCore`, configuration `Release`, `generic/platform=iOS Simulator`, `CODE_SIGNING_ALLOWED=NO` |
| `app-release-symbols` | `check_release_symbols.py`: none of the debug and scenario symbols (`DebugLaunch`, `DebugExperience`, `ScenarioLaunch`, …) is in the Release binary |
| `app-privacy-manifest` | `check_privacy_manifest.py`: `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` matches the required-reason APIs found in the built app |
| `app-no-tracking` | `check_no_tracking.py`: none of the advertising, analytics, attribution or tracking frameworks, symbols and libraries of `Configs/tracking-denylist.json` in the built app |
| `app-licenses` | `check_licenses.py`: the app's `Licenses` folder equals the bundle made from `docs/legal/third-party.json` |
| `app-usage-descriptions` | `check_usage_descriptions.py`: the built app's usage strings match the permissions declared in `Catalog/registrations.json` (today only `NSPhotoLibraryAddUsageDescription`, A01) |

Related app-wide steps: `app-projectm-audit` (no ProjectM in the app), `metadata-inputs` (the store inputs in
[metadata-inputs.json](metadata-inputs.json)), `licenses`, `usage-descriptions`, `script-tests`.

Experience release documents are checked per experience, for example:

```bash
python3 scripts/check_experience_release.py --config docs/apps/particle-universe/release.json
```

## 5. Owner steps (BLOCKED_OWNER_ACTION)

The agent never performs these steps (CLAUDE.md rule 6, setup.md section 10). Each stays `BLOCKED_OWNER_ACTION` in the
release records until the owner has done it.

1. **Team and signing.** Create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM = <team ID>`;
   `Configs/Signing.xcconfig` includes it when it exists. It is never committed. Certificates and provisioning
   profiles are managed in Xcode (Settings › Accounts) with the owner's Apple account.
2. **Identifiers.** Decide the final bundle identifier and product identifier before the first upload (ADR-0009
   OD-02; placeholders `dev.visualcore.VisualCore` and `dev.visualcore.VisualCore.premium`). A bundle identifier is
   permanent once uploaded.
3. **Archive.** In Xcode, open `VisualCore.xcodeproj` (generated in section 1), select the scheme `VisualCore` and the
   destination "Any iOS Device (arm64)", then Product › Archive.
4. **Validate and upload.** In the Organizer, select the archive, choose Validate App, then Distribute App › App Store
   Connect › Upload.
5. **App Store Connect record.** Create the app record with the chosen name and bundle identifier; accept the
   agreements that App Store Connect requires.
6. **App Privacy answers.** Tracking: No. Data collected: none ("Data Not Collected"). These answers are recorded in
   [metadata-inputs.json](metadata-inputs.json) (`privacy_answers`) with the reports that prove them. Enter the privacy
   policy URL.
7. **In-app purchase.** Create exactly one non-consumable in-app purchase at the USD 1.99 base price that unlocks every
   premium experience, present and future (ADR-0009 D-03), with the product identifier chosen in step 2. No other
   product, no subscription, no consumable.
8. **Store text and screenshots.** Enter the listing text (the experience inputs, for example
   [Particle Universe](../apps/particle-universe/store-listing.md)), the age rating and the support URL; capture and
   upload screenshots at the sizes App Store Connect asks for.
9. **Review submission.** Attach the build (the app declares `ITSAppUsesNonExemptEncryption` false in `project.yml`)
   and submit for review.

No device install or TestFlight test of the app happens before `ImplementationLock-100`; the device campaign follows
it in the order D1, D2, D3, and D3 is never updated from iPadOS 26.5.
