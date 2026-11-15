# VisualCore — one-time App Store name and bundle reservation

**Status: `BLOCKED_OWNER_ACTION`.** Owner request of 2026-11-14: after Digital Aquarium (A09) is complete, release one
store app version to reserve the app's name and bundle identifier — only this one time. X-A09 was recorded on
2026-11-14, so the reservation is due now. Every step below needs the owner's Apple account, so the agent does none of
them (CLAUDE.md rule 6). Nothing here changes the device-testing order: no device install or TestFlight test before
`ImplementationLock-100`, then D1 → D2 → D3, and D3 is never updated from iPadOS 26.5.

## What is ready (agent, 2026-11-14)

| Item | State | Evidence |
|---|---|---|
| App version | `CFBundleShortVersionString` 1.0.0, `CFBundleVersion` 1 (`project.yml`) | `project.yml` |
| Release build, simulator | passes unsigned, with the symbol, privacy-manifest, no-tracking, licence and usage-string checks | `.autonomy/checks/A09-P06.release-checks.json` |
| Release build, generic iOS device | `xcodebuild build -scheme VisualCore -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` succeeds | run on 2026-11-14 at the X-A09 follow-through commit |
| Experiences in the app | A01–A09 (nine); the launch scope is 100 | `python3 scripts/migration_ledger.py status` |
| App Privacy answers | Tracking: No; Data Not Collected (inputs, not yet proven on devices) | [metadata-inputs.json](metadata-inputs.json) |
| Name availability | **not checked** — only App Store Connect can tell | — |
| Bundle identifier | **placeholder** `dev.visualcore.VisualCore` (ADR-0009 OD-02) | `project.yml` |

## Owner steps

1. **Decide the bundle identifier.** It is permanent once a build is uploaded. Keep `dev.visualcore.VisualCore` only if
   you own the `visualcore.dev` domain or are content with that prefix; otherwise choose your own reverse-DNS
   identifier (for example `com.<your domain>.visualcore`). If it changes, tell the agent: it updates
   `PRODUCT_BUNDLE_IDENTIFIER` and `bundleIdPrefix` in `project.yml` (and the test targets'), regenerates the project
   and reruns the release checks. Decide the in-app purchase product identifier at the same time (placeholder
   `dev.visualcore.VisualCore.premium`); it is created later, not now.
2. **Signing.** In Xcode › Settings › Accounts sign in with the developer account; keep the gitignored
   `Configs/Signing.local.xcconfig` with your `DEVELOPMENT_TEAM` (it already exists on this Mac and is never committed).
3. **Register the App ID.** In the Apple Developer portal (Certificates, Identifiers & Profiles › Identifiers ›
   +, App IDs, App), register the bundle identifier from step 1 with the In-App Purchase capability.
4. **Reserve the name.** In App Store Connect › Apps › + › New App: platform iOS, name "VisualCore" (or the name you
   choose if it is taken), primary language, the bundle identifier from step 3, a SKU (for example `visualcore-ios`),
   full access. Creating this record is what reserves the name; accept any agreement App Store Connect requires.
5. **Upload one build (optional for the reservation, requested by the owner).** `xcodegen generate --spec project.yml`,
   open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive, then in
   the Organizer: Validate App, Distribute App › App Store Connect › Upload. The build appears in App Store Connect
   after processing.
6. **Do not submit for review and do not release.** The first release contains all 100 experiences (ADR-0009); nine
   exist today. Do not add internal or external TestFlight testers before `ImplementationLock-100`.
7. **Tell the agent** the final name, the bundle identifier and whether the upload was made; the agent records them in
   this document, in [build-and-archive.md](build-and-archive.md) and in the README, and keeps the placeholders out of
   the code.

## Record

| Date | Step | Result |
|---|---|---|
| 2026-11-14 | Preparation by the agent | done (table above) |
| — | Owner steps 1–7 | `BLOCKED_OWNER_ACTION` |
