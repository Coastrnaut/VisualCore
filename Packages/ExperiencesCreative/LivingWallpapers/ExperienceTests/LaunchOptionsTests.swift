// LaunchOptionsTests — feature 142 (A19-P05) T-A19-502 (FR-A19-501; clarification Q2). The automation-only launch
// argument `-lwExportLimit <n>`: parsing (alone and among other arguments), a missing flag, a missing value, a value
// that is not an integer, non-positive values, and the cap min(context limit, n). Pure functions, no host.
import Testing
@testable import LivingWallpapersExperience

/// `LaunchOptions.exportLimit(from:)` and `LaunchOptions.cappedLimit(context:arguments:)`.
struct LaunchOptionsTests {
    /// The flag followed by a positive integer gives that integer.
    @Test func parsesTheLimit() {
        #expect(LaunchOptions.exportLimit(from: ["-lwExportLimit", "1024"]) == 1024)
    }

    /// The flag among other arguments is found.
    @Test func parsesTheLimitAmongOtherArguments() {
        let arguments = ["/path/VisualCore", "-vcCandidates", "a19", "-lwExportLimit", "2048", "-other"]
        #expect(LaunchOptions.exportLimit(from: arguments) == 2048)
    }

    /// No flag gives nil.
    @Test func missingFlagIsNil() {
        #expect(LaunchOptions.exportLimit(from: ["-vcCandidates", "a19"]) == nil)
        #expect(LaunchOptions.exportLimit(from: []) == nil)
    }

    /// The flag as the last argument (no value) gives nil.
    @Test func missingValueIsNil() {
        #expect(LaunchOptions.exportLimit(from: ["-vcCandidates", "-lwExportLimit"]) == nil)
    }

    /// A value that is not an integer gives nil.
    @Test func nonIntegerIsNil() {
        #expect(LaunchOptions.exportLimit(from: ["-lwExportLimit", "abc"]) == nil)
    }

    /// Zero and negative values give nil.
    @Test func nonPositiveIsNil() {
        #expect(LaunchOptions.exportLimit(from: ["-lwExportLimit", "0"]) == nil)
        #expect(LaunchOptions.exportLimit(from: ["-lwExportLimit", "-5"]) == nil)
    }

    /// The cap is min(context limit, n), and the context limit without a flag.
    @Test func capsTheContextLimit() {
        let limited = ["-lwExportLimit", "1024"]
        #expect(LaunchOptions.cappedLimit(context: 16384, arguments: limited) == 1024)
        #expect(LaunchOptions.cappedLimit(context: 512, arguments: limited) == 512)
        #expect(LaunchOptions.cappedLimit(context: 16384, arguments: []) == 16384)
    }
}
