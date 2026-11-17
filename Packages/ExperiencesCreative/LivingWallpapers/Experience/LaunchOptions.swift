// LaunchOptions — feature 142 (A19-P05) T-A19-502 (FR-A19-501; clarification Q2; contracts/interface.md). Reads the
// automation-only launch argument `-lwExportLimit <n>`, which lowers the export edge limit so that an interface test
// on the simulator can reach the "does not fit" notice and the offered smaller size:
//
//   - `exportLimit(from:)` returns n when the flag is followed by a positive integer, else nil (missing flag,
//     missing value, a value that is not an integer, or n ≤ 0);
//   - `cappedLimit(context:arguments:)` returns min(context limit, n) when a limit is given, else the context limit.
//
// The pure functions are always compiled so that the unit tests cover them in every configuration; only the
// presenter's use of them is under `DEBUG || VISUALCORE_AUTOMATION`, so a shipping build always uses the context's
// limit unchanged.
import Foundation

/// The Living Wallpapers launch arguments used by the automation (``WallpaperPresenter`` reads them in debug and
/// automation builds only).
enum LaunchOptions {
    /// The launch argument that lowers the export edge limit: `-lwExportLimit <n>`.
    static let exportLimitFlag = "-lwExportLimit"

    /// The export edge limit in `arguments`: the positive integer that follows the first `-lwExportLimit`, or nil
    /// when the flag is missing, has no value, or its value is not a positive integer.
    static func exportLimit(from arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: exportLimitFlag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex, let value = Int(arguments[valueIndex]), value > 0 else { return nil }
        return value
    }

    /// The edge limit to use: min(`context`, n) when `arguments` give a limit n, else `context`.
    static func cappedLimit(context: Int, arguments: [String]) -> Int {
        guard let limit = exportLimit(from: arguments) else { return context }
        return min(context, limit)
    }
}
