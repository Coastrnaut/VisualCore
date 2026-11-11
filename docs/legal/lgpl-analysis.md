# LGPL analysis — ProjectM engine linkage (feature 010 T-F907; FR-F909)

**Scope.** libprojectM is LGPL-2.1. It reaches VisualCore only through `Harnesses/ProjectMReference`, which links the
reference `ProjectMBridge` package; its engine is the binary target `ProjectM.xcframework`, built by the reference's own
script as a **dynamic** framework.

**Findings (2026-11-10, from the repository, not assumed):**
1. No shipped VisualCore target links the engine. Rule R1 (`scripts/check_dependencies.py`) allows reference modules only
   in `Harnesses/ProjectMReference`; the Showcase and Lumen Garden builds run the four-layer dependency audit as a
   post-build phase and contain 0 ProjectM symbols, frameworks or imports.
2. In the harness the engine stays a separate, replaceable dynamic framework; VisualCore code is MIT and is linked to it
   only through the bridge's public C/Objective-C interface. No LGPL code is copied into VisualCore.
3. The harness is a tester tool and is **not distributed** (contract FR-F109). Therefore no LGPL distribution obligations
   (offering the engine source, relinking ability, notices) currently arise from VisualCore.

**If the harness or any app ever ships the engine**, the distributor must: keep it a dynamic framework, include the LGPL-2.1
text and the engine notices (`External/projectm-ios/Apps/projectM-iOS/Resources/Licenses/projectm.txt` and the five
engine-component texts), provide or offer the corresponding engine source (the `Coastrnaut/projectm@ios` fork at the
pinned commit), and not restrict reverse engineering for debugging modifications. That requires a fresh analysis and an
owner decision before release.
