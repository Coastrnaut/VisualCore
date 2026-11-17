# Tasks: Shader Studio — Phase 01 GLSL/diagnostic contract and editor shell

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A22-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A22-P01 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/152-au-p01-sky-prototype/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A22-101 Baseline: cite the A22-P00 evidence (`.autonomy/checks/A22-P00.{app-build,no-change,experience-packages}.json`) — Verified 2026-11-17: 2026-11-17: A22-P00 evidence cited: .autonomy/checks/A22-P00.app-build.json, A22-P00.no-change.json and A22-P00.experience-packages.json, all exit 0; no Packages change since the A22-P00 record commit 32523449
  on the tree recorded at A22-P00 (`32523449`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [ ] T-A22-102 Add two targets to `Packages/ExperiencesCreative/Package.swift` (lead); the package check still passes
  (a pending core):
  - `ShaderStudioCore` (path `ShaderStudio/Core`, dependencies `VisualCoreShaderSource` and `VisualCoreParameters`);
  - `ShaderStudioCoreTests` (path `ShaderStudio/CoreTests`, dependencies `ShaderStudioCore`, `VisualCoreShaderSource`,
    `VisualCoreParameters` and `VisualCoreRendering`).

## Phase 2: Story 1 — a bounded project (P1) 🎯

- [ ] T-A22-103 [P] [US1] Create `Packages/ExperiencesCreative/ShaderStudio/Core/ShaderProject.swift` per
  data-model.md, with `///` on every public declaration (FR-A22-101, 102):
  - `ShaderLimits`: "`maxSourceBytes` 16,384, `maxLines` 400, `maxUniforms` 16, `maxTextureInputs` 2"; a project's
    limits may be lower, never higher;
  - `ShaderProject`: "schema 1, kind `a22.shader-project`, ≤ 65,536 bytes encoded, canonical JSON with sorted keys";
    `name` "1…40 characters", `source`, `uniforms` (`ParameterDefinition`, float only), `limits`, `textureInputs`
    "0…2 names";
  - refusal codes `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`.
- [ ] T-A22-104 [P] [US1] Create `Packages/ExperiencesCreative/ShaderStudio/Core/ShaderValidator.swift` per
  clarification Q2 and data-model.md "ValidationIssue". It returns every issue in source order (FR-A22-103):
  - size, line, uniform and texture-input limits;
  - `no-main` and `version-line(line)`;
  - reserved names `u_time` and `u_resolution`, and duplicate names;
  - `undeclared-in-source` and `undeclared-in-project`, for both `uniform float` and `uniform sampler2D`.
- [ ] T-A22-105 [P] [US1] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/{ProjectTests,ValidatorTests}.swift`
  (SC-A22-101):
  - projects round-trip byte-identical, with one sample per refusal code;
  - each limit is tested at the limit and one past it;
  - every validation issue, plus an empty source;
  - synthetic data only.

## Phase 3: Story 3 — errors point to the authored line (P1)

- [ ] T-A22-106 [P] [US3] Create `Packages/ExperiencesCreative/ShaderStudio/Core/{ShaderAssembly,DiagnosticMapper}.swift`
  per clarification Q1 and contracts/core.md (FR-A22-104):
  - `ShaderAssembly` gives the files `ss/prelude.glsl` (`precision highp float;`, `in vec2 v_uv;`,
    `uniform float u_time;`, `uniform vec2 u_resolution;`, `out vec4 fragColor;`, `#include "vc/noise.glsl"`,
    `#include "vc/color.glsl"`), `ss/shader.frag` (the source unchanged) and `ss/main.frag` (the two includes);
  - `DiagnosticMapper` keeps diagnostics of `ss/shader.frag` on their line and sends the others to "outside".
- [ ] T-A22-107 [P] [US3] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/{AssemblyTests,LineMappingCompileTests}.swift`
  (SC-A22-102):
  - the assembly texts are exact;
  - the five broken-shader fixtures of clarification Q5 are compiled through `ResourceRegistry.program` with
    `FullScreenShaderScene.vertexSource` and a `ShaderLibrary` of `ShaderBundle.visualCoreLibrary` plus the assembly,
    inside a test scene on `RenderHost`; each error names `ss/shader.frag` and its authored line;
  - an error placed in a test include is outside the source;
  - a valid source gives no diagnostics.

## Phase 4: Story 4 — the editor model (P2)

- [ ] T-A22-108 [P] [US4] Create `Packages/ExperiencesCreative/ShaderStudio/Core/{GLSLTokenizer,EditorDocument}.swift`
  per clarification Q4 (FR-A22-105):
  - the token kinds in matching order, with GLSL ES 3.00 keyword, type and built-in sets;
  - lines split on `\n`, `\r\n` and `\r`, numbered from 1;
  - block comments are cut at line ends, and an unclosed one runs to the end of the source;
  - diagnostics are attached by line, and the rest go to `outside`.
- [ ] T-A22-109 [P] [US4] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/{TokenizerTests,EditorDocumentTests}.swift`
  (SC-A22-103):
  - tokens rebuild every line exactly, and every kind is classified;
  - CRLF and a final line with no newline;
  - an unclosed comment, and a long line whose tokenizing stays linear (a 16,384-byte line takes one pass);
  - diagnostics on lines 3 and 7, and line-less ones outside.

## Phase 5: Story 5 — starter templates (P2)

- [ ] T-A22-110 [P] [US5] Create `Packages/ExperiencesCreative/ShaderStudio/Core/ShaderTemplates.swift`: `gradient`,
  `noise-flow` and `rings` per clarification Q5, each a valid `ShaderProject` with its uniforms and a licence line
  (FR-A22-106)
- [ ] T-A22-111 [P] [US5] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/TemplateCompileTests.swift`
  (SC-A22-104):
  - each template validates with no issue, compiles and draws one frame off screen at 64 × 48;
  - its active uniforms (`ShaderProgram.uniforms`, other than `u_time` and `u_resolution`) equal the declared ones.

## Phase 6: Records and evidence

- [ ] T-A22-112 [P] Write `docs/apps/shader-studio/licenses.md` (templates and prelude written in this repository; the
  `vc/` library is VisualCore's; the GLSL word lists are facts of the GLSL ES 3.00 specification; no third-party asset)
  and list it in `docs/apps/shader-studio/README.md`
- [ ] T-A22-113 Core tests on sim-27.2, as a review checkpoint (SC-A22-105, FR-A22-107):
  - `--name ss-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
    ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing ShaderStudioCoreTests`, with each
    test under 10 s;
  - the purity scan (`--name core-purity`);
  - the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources
    Packages/ExperiencesCreative/ShaderStudio`).
- [ ] T-A22-114 Contract `docs/apps/shader-studio/visualcore-contract.json`: G-MODEL, G-VALIDATE, G-LINES and
  G-TEMPLATES are closed by "A22-P01", and rows whose gaps are all closed become available with evidence (`--name
  contract -- python3 scripts/check_app_contract.py --app shader-studio --render`)
- [ ] T-A22-115 The packages, catalog and script tests and the app build:
  - `--name experience-packages`;
  - `--name catalog -- python3 scripts/build_catalog.py --check`;
  - `--name script-tests -- python3 scripts/test_scripts.py`;
  - `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`.
- [ ] T-A22-116 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A22-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

101 → 102 → {103/104/105, 106/107, 108/109, 110/111, 112} → 113 → 114 → 115 → 116.
- **Separate files:** the stories touch different files.
- **Templates:** 110 uses 103's `ShaderProject`, and 111 uses 106's assembly.

## Parallel examples

- **Agent M:** 103, 104 and 105.
- **Agent L:** 106, 107, 110 and 111.
- **Agent T:** 108 and 109.
- **Lead:** 102, 112, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the project and validator (103–105) with the line-mapping fixture (106, 107).
- **Then:** the editor model (108, 109) and the templates (110, 111) complete the phase.
- **Review checkpoint:** at 113.
- **Commits:** one per task.
