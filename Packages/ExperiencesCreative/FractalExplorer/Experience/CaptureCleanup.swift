// CaptureCleanup — feature 193 (UA-F07) T-U07-025. The launch cleanup of the standalone app's capture folder
// (feature 031 T-A03-602), kept when the app's `@main` type was retired so that the moved tests and the standalone
// screens keep their behaviour; the one app's capture writes no file.
import VisualCoreRendering

/// Removes the captures a killed session left behind.
enum CaptureCleanup {
    /// Empties `tmp/<ExplorerModel.captureFolderName>`; returns the number of files removed.
    @discardableResult
    static func run() -> Int { StillCapture.folder(named: ExplorerModel.captureFolderName).removeAll() }
}
