# VisualCore — setup for a fresh clone on a new Mac

This guide takes a new Mac to a checkout on which every check of section 8 passes. It covers the machine and the
contributor tools only (ADR-0009 D-10): [`README.md`](README.md) says what the repository contains,
[`Auto-Creator.md`](Auto-Creator.md) holds the design and the plan, [`CLAUDE.md`](CLAUDE.md) the rules that never
bend, and progress is in the two ledgers (section 9), never in this file. The single VisualCore app decided in
[ADR-0009](docs/decisions/ADR-0009-unified-app.md) does not exist yet, and nothing below builds it.

Steps marked **Owner only** need the owner's accounts, passwords or devices; Claude never performs them (section 10).
A `sudo` command asks for the administrator password, which only the owner types. After the clone, commands run from
the repository root. Pins last verified on 2026-11-11: `python3 scripts/verify_environment.py` printed `PASS`.

## Contents

1. [Reference toolchain](#1-reference-toolchain)
2. [Accounts and apps (owner only)](#2-accounts-and-apps-owner-only)
3. [Command-line tools](#3-command-line-tools)
4. [Simulator runtimes](#4-simulator-runtimes)
5. [Clone the repository and its submodules](#5-clone-the-repository-and-its-submodules), [5.1 Branches](#51-branches)
6. [Build the reference engine binaries](#6-build-the-reference-engine-binaries)
7. [Machine-local state that is not in Git](#7-machine-local-state-that-is-not-in-git)
8. [Verify the machine](#8-verify-the-machine)
9. [Where the state lives and how to resume](#9-where-the-state-lives-and-how-to-resume)
10. [The owner-only boundary](#10-the-owner-only-boundary)

## 1. Reference toolchain

`python3 scripts/verify_environment.py` is the acceptance check of the environment. It compares this Mac with the
pins in [`Configs/toolchain.json`](Configs/toolchain.json), installs nothing, and must print `PASS` before any work.

| Tool | Version | Checked by `verify_environment.py` | How to look it up |
|---|---|---|---|
| macOS | 27.2 | no | `sw_vers` |
| Xcode | **27.2 (27B52)** | yes, version and build | `xcodebuild -version` |
| iOS SDK | 27.2 | yes | `xcrun --sdk iphoneos --show-sdk-version` |
| Swift | **6.4.2** | yes | `swift --version` |
| XcodeGen | **2.46.0** | yes | `xcodegen --version` |
| CMake | **4.4.5** | yes | `cmake --version` |
| Python | 3.15.2 (Homebrew `python@3.15`; ≥ 3.10 required) | yes, the 3.10 minimum | `python3 --version` |
| iOS simulator runtimes | **iOS 27.2** and **iOS 26.5 (23F77)** | yes, version only | `xcrun simctl list runtimes` |
| Git | 2.54.0 (Apple Git-157, from the Command Line Tools) | no | `git --version` |
| Git LFS | Homebrew `git-lfs` | no | `git lfs version` |
| GitHub CLI | 2.103.3 | no | `gh --version` |
| uv | 0.13.7 | no | `uv --version` |
| Spec Kit CLI (`specify`) | 1.4.1.dev0 (a uv tool; optional, the skills are committed) | no | `specify version` |
| Homebrew | 7.0.13 | no | `brew --version` |

The rows marked "no" are versions of the reference host, recorded for comparison; its Homebrew packages
(`brew leaves`) were `cmake gh git-lfs python@3.15 uv xcodegen`. Runtimes are compared by version, not by build: the
reference host recorded iOS 26.5 build 23F77 ([environment record](docs/verification/environment-F00.json)), and a
second Mac with macOS 27.2.1 and iOS 26.5 build 23F73 passes. Do not upgrade by habit: if Homebrew offers a newer
XcodeGen or CMake than the pin, install the pinned version (section 3.2) or record the difference before continuing.

## 2. Accounts and apps (owner only)

1. Sign in to macOS with the owner's Apple account.
2. Install **Xcode 27.2 (27B52)** from the Mac App Store or developer.apple.com. Then select it, accept the licence
   and finish the first launch:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   xcodebuild -runFirstLaunch
   ```

3. Install **Claude Desktop**, sign in, and open the **Code** tab.
4. In Xcode, Settings → Accounts, add the developer account. Only device work needs it; simulator work is unsigned.
5. Keep the Mac awake while sessions run: System Settings → Energy, "Prevent automatic sleeping".

## 3. Command-line tools

**3.1 Homebrew, packages and Python.** The last line must print `/opt/homebrew/bin/python3` and `Python 3.15.x`.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile && eval "$(/opt/homebrew/bin/brew shellenv)"
brew install python@3.15 uv gh git-lfs cmake xcodegen
git lfs install
which python3 && python3 --version
```

`/usr/bin/python3` with `Python 3.9.x` is macOS's own Python: too old (the scripts need 3.10 or later), and never to be
removed or replaced. In that case run the first four lines below: they install and link Homebrew's Python, put Homebrew
first on `PATH` for new terminals (only if the line is missing), load it here and check again. If the check still shows
`/usr/bin/python3`, something in `~/.zshrc` puts `/usr/bin` first: run the last line too and open a new terminal.

```bash
brew install python@3.15 && brew link --overwrite python@3.15
grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)" && hash -r
which python3 && python3 --version
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
```

**3.2 Pin XcodeGen 2.46.0 and CMake 4.4.5.** The first line prints both versions. Run the second only if XcodeGen is
not 2.46.0; it replaces the Homebrew package with the release binary. If CMake is not 4.4.5, use the official 4.4.5
macOS installer from cmake.org, or `uv tool install cmake==4.4.5`, and put it first on `PATH`.

```bash
xcodegen --version; cmake --version | head -1
brew uninstall xcodegen; curl -fsSL -o /tmp/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip && unzip -o /tmp/xcodegen.zip -d /tmp/xcodegen && sudo /tmp/xcodegen/xcodegen/install.sh
```

**3.3 Spec Kit CLI (optional).** The nine Spec Kit skills are committed in `.claude/skills/speckit-*`, and `.specify/`
is committed too, so the CLI is needed only to inspect or upgrade them. **Never re-run `specify init` here**: it can
overwrite `.specify/` and `CLAUDE.md`. To install the CLI, run
`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`, then `uv tool update-shell`, which
puts uv's tool folder `~/.local/bin` on `PATH` for new terminals, and
`export PATH="$HOME/.local/bin:$PATH" && hash -r && specify version`, which loads it here and checks the CLI.

**3.4 GitHub sign-in (owner only).** Pushing to `Coastrnaut/VisualCore` needs the owner's GitHub credentials; Claude
never signs in. `.gitattributes` normalizes text files to LF. Commits carry no co-author or "Generated with" trailers.

```bash
gh auth login
gh auth setup-git
git config --global user.name "Coastrnaut"
git config --global user.email "<the owner's normal git email>"
git config --global core.autocrlf input
```

## 4. Simulator runtimes

`xcode-select -p && xcodebuild -version` must print `/Applications/Xcode.app/Contents/Developer`, `Xcode 27.2` and
`Build version 27B52`. Homebrew installs and selects the Command Line Tools, which gives the error "tool 'xcodebuild'
requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools
instance"; in that case repeat the three commands of section 2 (install Xcode first if `ls -d /Applications/Xcode*.app`
lists nothing, and use the app's actual name if it differs). Then download the runtimes and confirm both are listed:

```bash
xcodebuild -downloadPlatform iOS
xcodebuild -downloadPlatform iOS -buildVersion 26.5
xcrun simctl list runtimes | grep iOS
```

The first command gives iOS 27.2 with Xcode 27.2; the second adds iOS 26.5. A second, device-specific iOS 27.2 runtime
(`24B91016s`, iPhone19-4) may be listed as well; it is not needed, and the scripts do not select it. Simulator
identifiers are machine-specific. The scripts choose a simulator by runtime, never by identifier:
`xcodebuild_package.py --destination sim-27.2`, `release_check.py` and `run_reference_baseline.py` take the first
available iPhone simulator of the runtime. For a direct `xcodebuild test` command, look the identifier up on this Mac
with `xcrun simctl list devices available | grep -E "iOS 2[67]|iPhone" | head -20`; never copy one from an old log.

## 5. Clone the repository and its submodules

The reference app is a read-only, pinned submodule: `External/projectm-ios` at `d93edd1`. Inside it, the engine fork
is at `c88894e` and the ANGLE fork at `29d1823`, the engine has its own nested submodule `vendor/projectm-eval` at
`22fb0cf`, and there are five shallow preset packs. Do **not** use `--recursive` at the top level: ANGLE's nested
dependencies come from `gclient`, not from Git submodules.

```bash
mkdir -p ~/Documents/GIT && cd ~/Documents/GIT && git clone https://github.com/Coastrnaut/VisualCore.git && cd VisualCore
git submodule update --init External/projectm-ios
git -C External/projectm-ios submodule update --init --depth 1 Vendor/projectM Vendor/angle
git -C External/projectm-ios/Vendor/projectM submodule update --init --recursive
git -C External/projectm-ios submodule update --init --depth 1 Vendor/presets/cream-of-the-crop Vendor/presets/projectm-classic Vendor/presets/milkdrop-original Vendor/presets/en-d Vendor/presets/milkdrop-texture-pack
git submodule status && git -C External/projectm-ios submodule status
```

Without the fourth command the engine build of section 6 fails with "…/Vendor/projectM/vendor/projectm-eval does not
contain a CMakeLists.txt file". The last command must show `d93edd1…`, then `29d1823…` and `c88894e…`. It does not
print `22fb0cf…`; the `reference-clean` step (section 8.1) fails if a nested submodule has left its recorded commit.

### 5.1 Branches

- All work is on `main`, and `main` is pushed to `origin` after every commit (ADR-0009 D-13, owner ruling of
  2026-11-11). A fresh clone of `main` therefore has everything this guide describes.
- The state before the consolidation is commit `38d98eb` ([baseline](docs/migration/pre-fable-baseline.md)); the
  earlier form of this guide is archived ([copy](docs/archive/planning/root/setup-2026-11-11.md)).
- The consolidation was made on the branch `migration/unified-app-plan` ([plan](docs/migration/migration-plan.md))
  and fast-forwarded into `main`. That branch is a local record and is not used any more.
- Before any push, `python3 scripts/prepush_scan.py` must pass; `python3 scripts/prepush_scan.py --push` scans and
  pushes.

## 6. Build the reference engine binaries

Do this once per clone; it needs the network and about 12 GB of disk. `Packages/VisualCoreRendering` links the ANGLE
frameworks built here, so the rendering tests, the Showcase, the harnesses and the apps do not build without them; the
reference regression (section 8.1) also needs the engine framework. Run the reference's own scripts inside its checkout.
The ANGLE build clones Chromium `depot_tools` (pinned `c4cdaee…`) into `External/projectm-ios/Build/depot_tools` and
runs `gclient sync`, which places about 12 GB inside `Vendor/angle`, all gitignored. **Never move, delete or clean
`Vendor/angle`.** All output stays under `External/projectm-ios/Build/`: `ANGLEFrameworks/` with `libEGL.xcframework`
and `libGLESv2.xcframework` (device arm64; simulator arm64 and x86_64), and `ProjectM.xcframework`.

```bash
cd ~/Documents/GIT/VisualCore/External/projectm-ios && python3 scripts/build_angle_xcframework.py
cd ~/Documents/GIT/VisualCore/External/projectm-ios && python3 scripts/build_projectm_xcframework.py
cd ~/Documents/GIT/VisualCore
```

## 7. Machine-local state that is not in Git

A fresh clone does not have the following. Every path inside the repository is gitignored.

| Path | Content | How it comes back |
|---|---|---|
| `.autonomy/context/` | the 33 source documents (25 app manuals, 8 sources) extracted from the archived specification | `python3 Tools/python/desktop_runbook.py bootstrap` (section 9) |
| `.autonomy/logs/`, `.autonomy/xcresults/` | command logs and Xcode result bundles | new runs write new ones; earlier ones exist only on the Mac that produced them |
| `External/projectm-ios/Build/` | `depot_tools`, the ANGLE frameworks, `ProjectM.xcframework` | section 6 |
| `Build/`, `*.xcodeproj`, generated `Info.plist` files | DerivedData and XcodeGen output | any build; `xcodegen generate` (section 8.2) |
| `.specify/feature.json` | the directory of the Spec Kit feature in progress | written when a feature starts; see below |
| `Configs/Signing.local.xcconfig` | the owner's signing team | **Owner only**, section 10 |
| `.claude/settings.local.json` | local permission allow-lists | the session asks again, or Auto mode covers it |
| `.autonomy/private/`, `.autonomy/reports/`, `.autonomy/desktop.lock/` | raw device inventories, reports, the session lock | created when needed; never committed |
| `~/.claude/projects/<repo path>/memory/` | Claude's per-machine memory | it does not move; the standing rules are in `CLAUDE.md`, so a new session reads them from the repository |

`python3 Tools/python/desktop_runbook.py validate` re-checks the 33 embedded documents against their recorded hashes.
`bootstrap` never overwrites `.autonomy/state.json` and is safe to repeat. Run both from the repository root.

Each tracked attestation of a check records the SHA-256 of its log, so a log can be matched but not regenerated on
another Mac. Logs of sealed gates are not needed for new work; copy `.autonomy/logs` and `.autonomy/xcresults` from
the Mac that produced them only if the full audit trail is wanted. Sealing re-hashes the log of every passing check
of the gate, so change Macs at a gate boundary or copy the logs of the gate in progress.

The Spec Kit scripts read the active feature from `.specify/feature.json`. To continue a feature that was started on
another Mac, write the file with that feature's directory:
`printf '{\n  "feature_directory": "specs/<feature directory>"\n}\n' > .specify/feature.json`.

## 8. Verify the machine

**8.1 Acceptance check, fast checks and reference regression.** All four commands must pass before any work.
Simulator results are development evidence only, never device evidence.

```bash
python3 scripts/verify_environment.py
python3 scripts/release_check.py --only docs app-contracts compliance dependencies public-api licenses script-tests host-visualcore host-particle-universe-core
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
```

Expected: `PASS`, then 9/9, 3/3 and 4/4 steps passed. A `FAIL` line of the first command names every tool or runtime
that is missing or differs from its pin. The second runs the static checks, the script tests and two host test suites,
without a simulator. The third and fourth are the seven-step ProjectM reference regression that follows every
framework change; the fourth uses both simulator runtimes. The SC-F702 check of `projectm-reference-ios27` is measured
against the engine's own noise floor and can fail rarely: rerun that step unchanged once and record the retry.

**8.2 Generated Xcode projects.** No generated project is in Git: `VisualCore.xcodeproj`, the harness projects such
as `Harnesses/ProjectMReference/ProjectMReference.xcodeproj` and the reference's `ProjectM-iOS.xcodeproj` come from the
XcodeGen spec next to them. A `release_check.py` step that names a project on its command line, and each build step of
the reference baseline, generates a missing project first. The three `app-release-*` steps do not: generate everything
up front (first line of 8.3) before running one alone. Generate again after adding a source file; a file added later
is otherwise not compiled. The builds also need the ANGLE frameworks (section 6) and the five preset packs (section 5).

**8.3 Single commands.** Project generation, the host tests of the pure package, the rendering package tests on the
iOS 27.2 simulator (`--destination sim-26.5` selects the other runtime), and the list of all release steps:

```bash
xcodegen generate --spec project.yml && for y in Harnesses/*/*.yml; do xcodegen generate --spec "$y"; done
swift test --package-path Packages/VisualCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/release_check.py --list
```

Without options, `python3 scripts/release_check.py` runs every step; split it with `--only` and `--skip` so that no
command runs longer than 10 minutes. See also [`simulator-test-lessons.md`](docs/testing/simulator-test-lessons.md)
(earlier simulator pitfalls) and [`getting-started.md`](docs/getting-started.md) (using the framework in code).

## 9. Where the state lives and how to resume

Progress is in Git and in two ledgers, never in a document or in the memory of a session. The unified-app gates are in
`.autonomy/migration/ledger.json`, written only by `scripts/migration_ledger.py`. The legacy gates F00 to A25-P06 are
in `.autonomy/state.json` with `.autonomy/evidence/` and `.autonomy/checks/`, written only by
`Tools/python/desktop_runbook.py`. `Auto-Creator.md` section 25 describes the ledgers and recovery. Run these commands
on `main`, in this order:

| Command | What it does |
|---|---|
| `git status --short --branch` | Shows the current branch and every uncommitted or untracked file. |
| `python3 scripts/migration_ledger.py status` | Prints the unified-app gates by kind and state, the next legacy gate and, under `NEXT`, the gates that are ready; the first of them is the next action. |
| `python3 Tools/python/desktop_runbook.py bootstrap` | Needed once per clone because `.autonomy/context/` is not tracked: it extracts the source documents that the legacy gates read. |
| `python3 Tools/python/desktop_runbook.py status` | Prints how many legacy gates pass and which one is next. |
| `python3 scripts/validate_autocreator.py` | Checks that the steering documents, the catalog, the archive and the ledgers are consistent. |
| `python3 scripts/migration_baseline.py verify` | Proves that the planning documents and the legacy evidence still have the content captured before the consolidation and that no gate passed at that time has been reset. |
| `python3 scripts/planning_archive.py verify` | Proves that every document of the [planning archive](docs/archive/planning/README.md) is byte-identical to that baseline and that the extracted copies match. |
| `python3 scripts/planning_index.py verify` | Re-parses the archive and confirms that the catalog and the feature index in `docs/catalog/` are up to date. |

The prompt that continues the work is the last section of [`Auto-Creator.md`](Auto-Creator.md) (section 28). Open the
repository folder in Claude Desktop → **Code** as a local session on this Mac, choose Auto permission mode if it is
offered, and paste the prompt as the first message. It goes into a Claude Desktop Code session, never the Claude CLI.

## 10. The owner-only boundary

Claude never does any of the following. Work that reaches one of them is recorded as `BLOCKED_OWNER_ACTION` with the
exact steps, and other work continues (`CLAUDE.md` section 3).

- **Accounts and credentials.** Signing in to macOS, the Apple account, Xcode (Settings → Accounts), GitHub
  (`gh auth login`) or Claude Desktop; typing the administrator password; accepting licences and legal agreements.
- **Signing.** `Configs/Signing.local.xcconfig` is created by the owner and never committed; it is gitignored. It holds
  `DEVELOPMENT_TEAM = <team ID>`, and `Configs/Signing.xcconfig` includes it when it exists. Simulator and generic
  builds are unsigned (`CODE_SIGNING_ALLOWED=NO`). Certificates and profiles are the owner's.
- **Devices.** Pairing (per Mac), trust prompts, Developer Mode, unlocking and operating-system updates. The devices are
  D1 (iPhone 15), D2 (iPad Pro 13-inch M5) and D3 (iPad A16). **D3 must stay on iPadOS 26.5 and is never updated.**
- **App Store Connect and publishing.** The app record, the agreements, the in-app product, the sandbox tester and
  every submission (ADR-0009 OD-06).

No install, launch or test of the unified app on a physical device is allowed before the gate
`ImplementationLock-100` is recorded (ADR-0009 D-07). `python3 scripts/migration_ledger.py guard-device` exits 0 only
after that; then the order is D1, D2, D3 (ADR-0009 D-08).

Device identifiers (UDID, ECID, serial number), team identifiers, account names and secrets are never written into a
tracked file. Raw device inventories stay in the gitignored `.autonomy/private/`.
