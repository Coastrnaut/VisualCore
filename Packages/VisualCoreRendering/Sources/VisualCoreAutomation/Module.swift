// VisualCoreAutomation — VisualCore iOS module (package map: specs/002-architecture-contracts/contracts/package-map.md).
// The whole module compiles only under DEBUG || VISUALCORE_AUTOMATION (CLAUDE.md §9): a shipping Release build contains
// no automation code or symbols (feature 010 T-F903/T-F904, FR-F914).
#if DEBUG || VISUALCORE_AUTOMATION
/// Module version (semantic versioning).
public enum AutomationInfo {
    /// Semantic version of the VisualCoreAutomation module.
    public static let version = "0.1.0"
}
#endif
