# VisualCore — new Mac setup and session handoff

This guide moves the VisualCore build machine, and the autonomous Claude Desktop session, onto a Mac Studio with a fresh
macOS install. Follow it from top to bottom.

- **Written:** 2026-11-11, on the current project Mac (Apple M5 Pro, macOS 27.2).
- **The exact checkpoint to resume from:** §9.

**Steps marked 👤 are owner-only.** Claude must never do them: Apple ID, GitHub sign-in, Xcode licence, signing,
device pairing. Every other step is a plain terminal command.

## 1. Reference toolchain (must match)

`scripts/verify_environment.py` checks these pins and must print `PASS` before any work.

| Tool | Version on the old Mac | How it is checked |
|---|---|---|
| macOS | 27.2 | `sw_vers` |
| Xcode | **27.2 (27B52)** | `xcodebuild -version` |
| iOS SDK | 27.2 | `xcrun --sdk iphoneos --show-sdk-version` |
| Swift | **6.4.2** | `swift --version` |
| XcodeGen | **2.46.0** | `xcodegen --version` |
| CMake | **4.4.5** | `cmake --version` |
| Python | 3.15.2 (Homebrew `python@3.15`; ≥ 3.10 required) | `python3 --version` |
| iOS simulator runtimes | **iOS 27.2** and **iOS 26.5 (23F77)** | `xcrun simctl list runtimes` |
| Git | 2.54.0 (Apple Git-157, from the Command Line Tools) | `git --version` |
| Git LFS | Homebrew `git-lfs` | `git lfs version` |
| GitHub CLI | 2.103.3 | `gh --version` |
| uv | 0.13.7 | `uv --version` |
| Spec Kit CLI (`specify`) | 1.4.1.dev0 (a uv tool; optional, the skills are committed) | `specify version` |
| Homebrew | 7.0.13 | `brew --version` |

Homebrew packages installed on the old Mac (`brew leaves`): `cmake gh git-lfs python@3.15 uv xcodegen`.

Do not "upgrade to latest" by habit. If Homebrew offers a newer XcodeGen or CMake than the pin, install the pinned
version (§3.3) or record the difference before continuing (CLAUDE.md §8).

## 2. Accounts and apps (👤 owner)

1. Sign in to macOS with the owner's Apple ID.
2. Install **Xcode 27.2 (27B52)** from the Mac App Store or developer.apple.com. Then:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

   ```bash
   sudo xcodebuild -license accept
   ```

   ```bash
   xcodebuild -runFirstLaunch
   ```

3. Install **Claude Desktop**, sign in, and open the **Code** tab. Optionally install Google Chrome.
4. In Xcode, Settings → Accounts, add the Apple developer account. This is only needed for the later device campaign;
   simulator work is unsigned.
5. Keep the Mac awake while sessions run: System Settings → Energy, "Prevent automatic sleeping".

## 3. Command-line tools

### 3.1 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile && eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 3.2 Packages

```bash
brew install python@3.15 uv gh git-lfs cmake xcodegen
```

```bash
git lfs install
```

Make sure `python3` resolves to Homebrew's 3.15 (`/opt/homebrew/bin/python3`):

```bash
which python3 && python3 --version
```

### 3.3 Pin XcodeGen 2.46.0 and CMake 4.4.5 if Homebrew installed other versions

```bash
xcodegen --version; cmake --version | head -1
```

If XcodeGen is not 2.46.0, install the release binary instead:

```bash
brew uninstall xcodegen; curl -fsSL -o /tmp/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip && unzip -o /tmp/xcodegen.zip -d /tmp/xcodegen && sudo /tmp/xcodegen/xcodegen/install.sh
```

If CMake is not 4.4.5, use the official 4.4.5 macOS installer from cmake.org, or `uv tool install cmake==4.4.5`, and
put it first on `PATH`.

### 3.4 Spec Kit CLI (optional)

The Spec Kit skills are committed in `.claude/skills/speckit-*`, and `.specify/` is committed too, so the CLI is only
needed to inspect or upgrade. **Never re-run `specify init`** in this repo (CLAUDE.md §7).

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile
```

### 3.5 GitHub sign-in (👤 owner)

Pushing to `Coastrnaut/VisualCore` requires the owner's GitHub credentials. Claude never signs in.

```bash
gh auth login
```

```bash
gh auth setup-git
```

```bash
git config --global user.name "Coastrnaut"
```

```bash
git config --global user.email "<the owner's normal git email>"
```

```bash
git config --global core.autocrlf input
```

The repo enforces LF through `.gitattributes`. Commits use the owner's normal email and no co-author trailers.

## 4. Simulator runtimes

```bash
xcodebuild -downloadPlatform iOS
```

This gives iOS 27.2 with Xcode 27.2. Then add iOS 26.5:

```bash
xcodebuild -downloadPlatform iOS -buildVersion 26.5
```

Confirm both:

```bash
xcrun simctl list runtimes | grep iOS
```

The old Mac also had a second iOS 27.2 runtime (`24B91016s`, iPhone19-4); it is not needed.

**Simulator UDIDs are machine-specific.** The repo's scripts choose simulators by runtime, never by UDID:
`xcodebuild_package.py --destination sim-27.2`, `release_check.py` and `run_reference_baseline.py`. For direct
`xcodebuild test` commands, look up the UDIDs again and use those:

```bash
xcrun simctl list devices available | grep -E "iOS 2[67]|iPhone" | head -20
```

The old Mac used iPhone simulators `19108E51-…` (27.2) and `EC7498FF-…` (26.5). Those IDs are invalid on the new Mac.

## 5. Clone the repository and its submodules

```bash
mkdir -p ~/Documents/GIT && cd ~/Documents/GIT && git clone https://github.com/Coastrnaut/VisualCore.git && cd VisualCore
```

The reference app is a **read-only, pinned** submodule (`External/projectm-ios` at `d93edd1`). Inside it, the engine
fork is at `c88894e`, the ANGLE fork at `29d1823`, and there are five shallow preset packs.

Do **not** use `--recursive` at the top level: ANGLE's nested dependencies come from `gclient`, not git submodules.

```bash
git submodule update --init External/projectm-ios
```

```bash
git -C External/projectm-ios submodule update --init --depth 1 Vendor/projectM Vendor/angle
```

```bash
git -C External/projectm-ios submodule update --init --depth 1 Vendor/presets/cream-of-the-crop Vendor/presets/projectm-classic Vendor/presets/milkdrop-original Vendor/presets/en-d Vendor/presets/milkdrop-texture-pack
```

Check the pins: `d93edd1…`, `c88894e…` and `29d1823…`.

```bash
git submodule status && git -C External/projectm-ios submodule status
```

## 6. Build the reference engine binaries (one time, network, about 12 GB, roughly an hour)

The ProjectM reference regression (run after every VisualCore change) needs these artifacts. Run them inside the
reference checkout with its own scripts (CLAUDE.md §4).

The ANGLE build clones Chromium `depot_tools` (pinned `c4cdaee…`) into `External/projectm-ios/Build/depot_tools`. It
then runs `gclient sync`, which places about 12 GB inside `Vendor/angle`, all gitignored. **Never move, delete or clean
`Vendor/angle`.** Outputs go only to `External/projectm-ios/Build/ANGLEFrameworks` and `Build/ProjectM.xcframework`.

```bash
cd ~/Documents/GIT/VisualCore/External/projectm-ios && python3 scripts/build_angle_xcframework.py
```

```bash
cd ~/Documents/GIT/VisualCore/External/projectm-ios && python3 scripts/build_projectm_xcframework.py
```

```bash
cd ~/Documents/GIT/VisualCore
```

On the old Mac these existed as `External/projectm-ios/Build/ANGLEFrameworks/` (`libEGL` and `libGLESv2`
xcframeworks with `ios-arm64`, `ios-sim-arm64` and `ios-sim-x64` slices) and `Build/ProjectM.xcframework`.

## 7. Recreate the local ledger state

These paths are gitignored and do not travel: `.autonomy/context/`, `logs/`, `xcresults/`, `private/` and
`desktop.lock`. The ledger itself is committed: `.autonomy/state.json`, `.autonomy/evidence/` and
`.autonomy/checks/`. `bootstrap` re-extracts the hash-verified source archive (the 25 app manuals and the original
README) from `README.md` into `.autonomy/context/`, and never overwrites `state.json`.

```bash
python3 Tools/python/desktop_runbook.py bootstrap
```

```bash
python3 Tools/python/desktop_runbook.py validate
```

```bash
python3 Tools/python/desktop_runbook.py status
```

Expected: `STATE {'pass': 33, 'pending': 230, 'blocked': 0, 'fail': 0}; next=A04-P02 [pending]`.

The Spec Kit scripts need the active feature in the gitignored `.specify/feature.json`:

```bash
printf '{\n  "feature_directory": "specs/034-pu-p02-render-loop"\n}\n' > .specify/feature.json
```

Logs and `.xcresult` bundles from earlier gates stay on the old Mac. Their SHA-256 hashes are in the committed
attestations. Copy `~/Documents/GIT/VisualCore/.autonomy/logs` and `.autonomy/xcresults` over only if the full audit
trail is wanted on the new machine; doing so is optional.

## 8. Verify the machine before any work

All three must pass. The second and third take about 2 minutes.

```bash
python3 scripts/verify_environment.py
```

```bash
python3 scripts/release_check.py --only docs app-contracts compliance dependencies public-api licenses script-tests host-visualcore host-particle-universe-core
```

```bash
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
```

Then, as the simulator baseline:

```bash
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
```

Expected results are 3/3 and 4/4. `projectm-reference-ios27`'s SC-F702 check is measured against the engine's own
noise floor and can fail rarely; rerun it unchanged once, and record the retry (as `A04-P01/t113-reference-b`).

## 9. Exact resume point (checkpoint 2026-11-11)

- **Last commit:** `b588b00` "speckit-clarify: feature 034, five decisions (forces and bounds, budget and live limit,
  placed force, ParticleLayerScene, UI seams)", then the handoff commit that adds this file. The tree is clean.
- **Ledger:** 33 gates passed: F00–F09, A01-P00…P06, A02-P00…P06, A03-P00…P06, A04-P00 and A04-P01. The next gate is
  **A04-P02**. No A04-P02 `run-check` exists yet.
- **Feature in progress:** `specs/034-pu-p02-render-loop/`, Particle Universe Phase 02 "One emitter and one force in
  the render loop".
  - Done and committed: **specify** (spec and `checklists/requirements.md` 16/16) and **clarify** (5 decisions in the
    spec's Clarifications section).
  - **Next command: `/speckit-plan`.** It was started on the old Mac but produced nothing; only the blank template was
    copied, and that was removed. Pass the verbatim archive prompt (`python3 scripts/speckit_prompts.py --feature
    034`, item 3).
  - Then run checklist → tasks → analyze → implement → converge (loop) → seal and record A04-P02.
- **Plan inputs already decided in the spec's clarifications:**
  - VisualCoreSimulation: new `ParticleForce` cases `.repulsor`, `.gravityWell`, `.wind` and `.vortex`, with bounds
    and `clamped()`; the existing cases stay bit-identical (the Phase 01 fixture `replay-v1.json` and A01 must not
    change).
  - VisualCoreSimulation: `ParticleSystem.liveLimit`.
  - VisualCoreDiagnostics: `ParticleBudget` (shares 1/0.6/0.35/0.2, minimum 100) and `DeviceConditions.current()`.
  - VisualCoreRendering: a generic `ParticleLayerScene` RenderScene, pixel-tested offscreen in package tests on both
    simulators.
  - App: `PlacedForce` (kind, position, strength multiplier 0.1…2) and `SceneSimulation.setPlacedForce`; the
    GPU-hosted sandbox with the CPU preview as fallback; `QualityPolicy(tierCount: 4, lowPowerCeiling: 1)`; DEBUG-only
    UI seams `-uitestThermal` and `-uitestLowPower`.
  - IDs: FR-A04-2##, SC-A04-2##, T-A04-2##; run-checks under stage `A04-P02`.
- **After A04-P02:** A04-P03…P06 (features 035–038), then A05…A25 (features 039–185), the full-suite audit,
  IMPLEMENTATION-LOCK, and the device campaign D1 → D2 → D3.

## 10. Start the Claude Desktop session on the Mac Studio

1. Claude Desktop → **Code** → open the local folder `~/Documents/GIT/VisualCore`, using a local session on this Mac.
   Choose Auto permission mode if offered.
2. Paste this as the first message:

   > Continue the complete VisualCore suite on this Mac Studio. First read CLAUDE.md (including §0 "Session handoff"),
   > then setup.md §9. Run `python3 scripts/verify_environment.py` and `python3 Tools/python/desktop_runbook.py
   > status`, write `.specify/feature.json` for `specs/034-pu-p02-render-loop`, and resume gate A04-P02 at
   > `/speckit-plan` with the verbatim prompt from `python3 scripts/speckit_prompts.py --feature 034`. Follow every
   > owner rule in CLAUDE.md: work autonomously, never stop at milestones, commit and push after every task or skill,
   > and maximize VisualCore reuse.

3. Optional resilience: create one local scheduled task named `visualcore-continue` from the Desktop UI, as described
   in CLAUDE.md §2.

## 11. Things that do not move automatically

- **Claude's per-machine memory** (`~/.claude/projects/<repo path>/memory/`) does not sync between Macs. Its five
  standing owner rules are copied into **CLAUDE.md §0**, so the new session reads them.
- **`Configs/Signing.local.xcconfig`:** it did not exist on the old Mac either. Simulator work is unsigned. 👤 The
  owner creates it before the device campaign, with `DEVELOPMENT_TEAM = <team ID>`.
- **Devices D1/D2/D3:** pairing and Developer Mode are per Mac. 👤 Pair them with the Mac Studio before the device
  campaign, which comes after IMPLEMENTATION-LOCK. **Never update D3 from iPadOS 26.5.**
- **`.claude/settings.local.json`** (local permission allow-lists) is gitignored. The new session asks again, or Auto
  mode covers it.
