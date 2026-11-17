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
- [X] T-A22-102 Add two targets to `Packages/ExperiencesCreative/Package.swift` (lead); the package check still passes — Verified 2026-11-17: 2026-11-17: ShaderStudioCore (VisualCoreShaderSource, VisualCoreParameters) and ShaderStudioCoreTests (also VisualCoreRendering) in Packages/ExperiencesCreative/Package.swift; .autonomy/checks/A22-P01.experience-packages.json exit 0 (a pending core)
  (a pending core):
  - `ShaderStudioCore` (path `ShaderStudio/Core`, dependencies `VisualCoreShaderSource` and `VisualCoreParameters`);
  - `ShaderStudioCoreTests` (path `ShaderStudio/CoreTests`, dependencies `ShaderStudioCore`, `VisualCoreShaderSource`,
    `VisualCoreParameters` and `VisualCoreRendering`).

## Phase 2: Story 1 — a bounded project (P1) 🎯

- [X] T-A22-103 [P] [US1] Create `Packages/ExperiencesCreative/ShaderStudio/Core/ShaderProject.swift` per — Verified 2026-11-17: 2026-11-17: ShaderProject.swift: ShaderLimits (16,384 bytes, 400 lines, 16 uniforms, 2 inputs; hard ceiling 64 KiB), ShaderProject (kind a22.shader-project, schema 1, at most 65,536 bytes, canonical JSON, name 1-40, float uniforms, 0-2 texture inputs) and ShaderProjectRefusal (damaged, newer-version, too-large, not-finite, out-of-range); .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0; written by an agent, retested
  data-model.md, with `///` on every public declaration (FR-A22-101, 102):
  - `ShaderLimits`: "`maxSourceBytes` 16,384, `maxLines` 400, `maxUniforms` 16, `maxTextureInputs` 2"; a project's
    limits may be lower, never higher;
  - `ShaderProject`: "schema 1, kind `a22.shader-project`, ≤ 65,536 bytes encoded, canonical JSON with sorted keys";
    `name` "1…40 characters", `source`, `uniforms` (`ParameterDefinition`, float only), `limits`, `textureInputs`
    "0…2 names";
  - refusal codes `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`.
- [X] T-A22-104 [P] [US1] Create `Packages/ExperiencesCreative/ShaderStudio/Core/ShaderValidator.swift` per — Verified 2026-11-17: 2026-11-17: ShaderValidator.swift: limits, no-main, version-line, reserved and duplicate names, undeclared in source or project for uniform float and uniform sampler2D (comments blanked first), issues in source order; .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0; written by an agent, retested
  clarification Q2 and data-model.md "ValidationIssue". It returns every issue in source order (FR-A22-103):
  - size, line, uniform and texture-input limits;
  - `no-main` and `version-line(line)`;
  - reserved names `u_time` and `u_resolution`, and duplicate names;
  - `undeclared-in-source` and `undeclared-in-project`, for both `uniform float` and `uniform sampler2D`.
- [X] T-A22-105 [P] [US1] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/{ProjectTests,ValidatorTests}.swift` — Verified 2026-11-17: 2026-11-17: ProjectTests (12) and ValidatorTests (15): byte-identical round trip, every refusal code, every limit at and past its bound, every issue, empty source; .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0; written by an agent, retested
  (SC-A22-101):
  - projects round-trip byte-identical, with one sample per refusal code;
  - each limit is tested at the limit and one past it;
  - every validation issue, plus an empty source;
  - synthetic data only.

## Phase 3: Story 3 — errors point to the authored line (P1)

- [X] T-A22-106 [P] [US3] Create `Packages/ExperiencesCreative/ShaderStudio/Core/{ShaderAssembly,DiagnosticMapper}.swift` — Verified 2026-11-17: 2026-11-17: ShaderAssembly.swift (ss/prelude.glsl, ss/shader.frag unchanged, ss/main.frag) and DiagnosticMapper.swift (MappedDiagnostic; the person's file keeps its line, other files and unknown lines go outside); .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0; written by an agent, retested
  per clarification Q1 and contracts/core.md (FR-A22-104):
  - `ShaderAssembly` gives the files `ss/prelude.glsl` (`precision highp float;`, `in vec2 v_uv;`,
    `uniform float u_time;`, `uniform vec2 u_resolution;`, `out vec4 fragColor;`, `#include "vc/noise.glsl"`,
    `#include "vc/color.glsl"`), `ss/shader.frag` (the source unchanged) and `ss/main.frag` (the two includes);
  - `DiagnosticMapper` keeps diagnostics of `ss/shader.frag` on their line and sends the others to "outside".
- [X] T-A22-107 [P] [US3] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/{AssemblyTests,LineMappingCompileTests}.swift` — Verified 2026-11-17: 2026-11-17: AssemblyTests and LineMappingCompileTests: five broken fixtures (unknown identifier line 4, type mismatch line 7, missing semicolon line 3, a vc_fbm line 5, after a block comment line 7) compiled through ResourceRegistry.program on the iOS 27.2 simulator's ANGLE each name ss/shader.frag and the authored line; a test-include error stays outside; a valid source gives none; CompileSupport compiles only (no GL call, isolation PASS); .autonomy/checks/A22-P01.ss-core-ios27-2.json and A22-P01.isolation.json exit 0; written by an agent, the GL calls removed by the lead, retested
  (SC-A22-102):
  - the assembly texts are exact;
  - the five broken-shader fixtures of clarification Q5 are compiled through `ResourceRegistry.program` with
    `FullScreenShaderScene.vertexSource` and a `ShaderLibrary` of `ShaderBundle.visualCoreLibrary` plus the assembly,
    inside a test scene on `RenderHost`; each error names `ss/shader.frag` and its authored line;
  - an error placed in a test include is outside the source;
  - a valid source gives no diagnostics.

## Phase 4: Story 4 — the editor model (P2)

- [X] T-A22-108 [P] [US4] Create `Packages/ExperiencesCreative/ShaderStudio/Core/{GLSLTokenizer,EditorDocument}.swift` — Verified 2026-11-17: 2026-11-17: GLSLTokenizer.swift (eleven token kinds, GLSL ES 3.00 word sets, one forward pass over UTF-8, lines split on LF, CRLF and CR) and EditorDocument.swift (numbered lines, tokens, diagnostics by line, outside); .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0; written by an agent, retested
  per clarification Q4 (FR-A22-105):
  - the token kinds in matching order, with GLSL ES 3.00 keyword, type and built-in sets;
  - lines split on `\n`, `\r\n` and `\r`, numbered from 1;
  - block comments are cut at line ends, and an unclosed one runs to the end of the source;
  - diagnostics are attached by line, and the rest go to `outside`.
- [X] T-A22-109 [P] [US4] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/{TokenizerTests,EditorDocumentTests}.swift` — Verified 2026-11-17: 2026-11-17: TokenizerTests (9) and EditorDocumentTests (4): tokens rebuild every line, every kind classified, line endings, comments, number forms, a 16,384-byte line, diagnostics on lines 3 and 7, the rest outside; .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0; written by an agent, retested
  (SC-A22-103):
  - tokens rebuild every line exactly, and every kind is classified;
  - CRLF and a final line with no newline;
  - an unclosed comment, and a long line whose tokenizing stays linear (a 16,384-byte line takes one pass);
  - diagnostics on lines 3 and 7, and line-less ones outside.

## Phase 5: Story 5 — starter templates (P2)

- [X] T-A22-110 [P] [US5] Create `Packages/ExperiencesCreative/ShaderStudio/Core/ShaderTemplates.swift`: `gradient`, — Verified 2026-11-17: 2026-11-17: ShaderTemplates.swift: gradient (u_speed), noise-flow (vc_fbm; u_scale, u_speed), rings (u_count, u_width), each a ShaderProject built without try! and validating with no issue; .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0; written by an agent, retested
  `noise-flow` and `rings` per clarification Q5, each a valid `ShaderProject` with its uniforms and a licence line
  (FR-A22-106)
- [X] T-A22-111 [P] [US5] Write `Packages/ExperiencesCreative/ShaderStudio/CoreTests/TemplateCompileTests.swift` — Verified 2026-11-17: 2026-11-17: TemplateCompileTests: each template validates, compiles and links with no diagnostics, its active uniforms equal its declared ones, and FullScreenShaderScene draws it at 64 x 48 with more than one colour and no error; .autonomy/checks/A22-P01.ss-core-ios27-2.json exit 0 (51 tests in 7 suites); written by an agent, drawing moved to FullScreenShaderScene by the lead, retested
  (SC-A22-104):
  - each template validates with no issue, compiles and draws one frame off screen at 64 × 48;
  - its active uniforms (`ShaderProgram.uniforms`, other than `u_time` and `u_resolution`) equal the declared ones.

## Phase 6: Records and evidence

- [X] T-A22-112 [P] Write `docs/apps/shader-studio/licenses.md` (templates and prelude written in this repository; the — Verified 2026-11-17: 2026-11-17: docs/apps/shader-studio/licenses.md (templates and prelude written here; vc/ is VisualCore's; GLSL ES 3.00 word lists are facts; no third-party asset) listed in the README; validate_docs PASS
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
