# VisualCore — one-time App Store name and bundle reservation

**Status: submitted** (2026-11-18: VisualCore 1.0, build 1, Waiting for Review; see the record below). Owner request of 2026-11-14: after Digital Aquarium (A09) is complete, release one
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

## Early App Store release after A22 (owner request of 2026-11-18)

The owner asked on 2026-11-18, during A22-P04: "after a22 is done lets release on the app store to reserve the name and
get feedback", then "skip testlight, go directly to app store". X-A22 was recorded on 2026-11-18. This request
supersedes step 6 above for this one early release: the build **is** submitted for review and released on the App
Store, **without TestFlight**. Every step needs the owner's Apple account, so the agent does none of them (CLAUDE.md
rule 6). The agent's own device testing still waits for `ImplementationLock-100` (rule 5); the public release is the
owner's action.

### What the early release contains (agent, 2026-11-18)

| Item | State | Evidence |
|---|---|---|
| Experiences | 22 free experiences, A01–A22, each through its X gate | `python3 scripts/migration_ledger.py status`; `Catalog/experiences.json` (22 available) |
| Premium experiences | none built yet; the launcher shows only integrated experiences, so no premium tile appears | `ShellModelTests.realCatalogShowsOnlyTheIntegratedExperiences` |
| In-app purchase | none in this release; create the USD 1.99 non-consumable only when premium experiences exist | ADR-0009 D-03 |
| Version | `CFBundleShortVersionString` 1.0.0, `CFBundleVersion` 1 (`project.yml`) | `project.yml` |
| Release build, generic iOS device | `xcodebuild build -scheme VisualCore -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` succeeds | run on 2026-11-18 at the X-A22 record (`99f05833`) |
| Release checks | release build, symbols, privacy manifest, no tracking, licences, usage descriptions, A22 experience release and copy claims pass | `.autonomy/checks/A22-P06.release-checks.json` |
| Encryption | `ITSAppUsesNonExemptEncryption` false | `project.yml` |
| App Privacy answers | Tracking: No; Data Not Collected (inputs; not yet proven on devices) | [metadata-inputs.json](metadata-inputs.json) |
| Store text | per experience, every claim names a test, for example [Shader Studio](../apps/shader-studio/store-listing.md) and [Aurora](../apps/aurora/store-listing.md) | `docs/apps/*/store-listing.md` |
| Known limitations | [known-limitations.md](known-limitations.md) | — |

### Owner steps (BLOCKED_OWNER_ACTION), in order

1. **Bundle identifier.** Decide it (step 1 above). It is permanent after the first upload; tell the agent if it is
   not `dev.visualcore.VisualCore`, and the agent changes `project.yml` and reruns the release checks first.
2. **Signing.** Xcode › Settings › Accounts with the developer account; `Configs/Signing.local.xcconfig` holds
   `DEVELOPMENT_TEAM` and is never committed.
3. **App ID.** Register the bundle identifier in the developer portal (step 3 above).
4. **App Store Connect record.** Apps › + › New App with the name "VisualCore" (or the name chosen if it is taken);
   accept the agreements App Store Connect requires. This record reserves the name.
5. **Archive and upload.** `xcodegen generate --spec project.yml`; open `VisualCore.xcodeproj`, scheme `VisualCore`,
   "Any iOS Device (arm64)", Product › Archive; in the Organizer, Validate App, then Distribute App › App Store
   Connect › Upload.
6. **Listing.** Name, subtitle, description (from the experiences' store texts; no claim without a test, no measured
   number, no "sandbox" claim for Shader Studio), keywords, support URL, privacy policy URL, age rating, category,
   price Free, and screenshots at the sizes App Store Connect asks for (taken by the owner from the simulator or a
   device; the agent may prepare simulator screenshots on request).
7. **App Privacy.** Tracking: No; Data Not Collected.
8. **Submit for review and release.** Attach the build, add review notes (no account needed; everything works offline;
   no purchase in this version), submit, and release when approved.
9. **Tell the agent** the name, the bundle identifier, the build number and the review outcome; the agent records them
   here, in [build-and-archive.md](build-and-archive.md) and in the README.

### Review risks to know before submitting

- **App Review 4.2 (minimum functionality) and 2.1 (completeness):** 22 complete experiences ship; nothing in the app
  says "coming soon".
- **Shader Studio:** it runs the person's own GPU code. The copy says GPU code is not a sandbox, and the watchdog
  stops slow previews (A22-P04). It downloads no code.
- **Device behaviour:** no experience has been measured on a device yet (the device campaign follows
  `ImplementationLock-100`). Feedback from the public release is not device evidence for the ledgers.

## Record

| Date | Step | Result |
|---|---|---|
| 2026-11-14 | Preparation by the agent | done (table above) |
| — | Owner steps 1–7 | `BLOCKED_OWNER_ACTION` |
| 2026-11-18 | Early-release preparation by the agent after X-A22 (owner request: direct App Store release, no TestFlight) | done (section above) |
| 2026-11-18 | Owner asked the agent to do the upload by computer control | the agent did the steps below with the owner signed in |
| 2026-11-18 | Bundle identifier | kept `dev.visualcore.VisualCore` (owner: "everything looks good") |
| 2026-11-18 | App ID | registered in the developer portal (explicit, `dev.visualcore.VisualCore`) |
| 2026-11-18 | App Store Connect record | created: name VisualCore, iOS, English (U.S.), SKU `visualcore-ios`, full access (the name is reserved) |
| 2026-11-18 | App icon | added, drawn in code by `scripts/make_app_icon.py` (the first upload was refused for a missing icon) |
| 2026-11-18 | Build | 1.0.0 (1) archived and uploaded with `xcodebuild -exportArchive` (method app-store-connect, automatic signing) |
| 2026-11-18 | Listing | promotional text, description, keywords, copyright, review notes, subtitle and categories (Entertainment, Graphics & Design) entered; "Sign-in required" off |
| 2026-11-18 | Age rating | answered by the owner (4+, with Apple's regional exceptions) |
| 2026-11-18 | Screenshots | six iPhone 6.9" and four iPad 13" simulator captures uploaded to the Asset Library (in Chrome) |
| 2026-11-18 | Build selection | build 1 attached to version 1.0; App Store Connect shows the code-drawn icon in its included assets |
| 2026-11-18 | Pricing and availability | Free, all 175 countries or regions |
| 2026-11-18 | Content rights | yes, with the necessary rights (public-domain molecule records in Molecular Explorer) |
| 2026-11-18 | App Privacy | Data Not Collected, published; privacy policy URL https://github.com/Coastrnaut/VisualCore/blob/main/docs/privacy-policy.md (as projectm-ios does) |
| 2026-11-18 | Support URL | https://github.com/Coastrnaut/VisualCore/issues (as projectm-ios does) |
| 2026-11-18 | App Review contact | copied from the projectM-iOS record at the owner's request |
| 2026-11-18 | Screenshots on the product page | Media Manager: six iPhone screenshots resized to 1206 × 2622 (the required 6.1"/6.3" slot) and four iPad 13" (2064 × 2752) |
| 2026-11-18 | Release option | automatic release after approval (owner) |
| 2026-11-18 | Sign-in required | unticked again (it had reverted); the app has no sign-in |
| 2026-11-18 | China mainland | removed from availability at the owner's request (174 countries or regions): a new app needs a Security Assessment and an AIGC services declaration for China mainland; it can be added back once those exist |
| 2026-11-18 | Submitted for review | VisualCore 1.0, build 1.0.0 (1), at the owner's request; status Waiting for Review (Apple: up to 48 hours) |
| — | Review outcome | pending |
