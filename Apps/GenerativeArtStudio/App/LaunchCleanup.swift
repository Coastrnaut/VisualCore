// LaunchCleanup.swift — crash recovery at launch (feature 017 T-A01-607; FR-A01-607). A session killed with the export
// sheet open leaves PNGs in tmp/Exports; they are removed at the next launch. Saved compositions are never touched (the
// store already removes its own interrupted temporary files when it loads, and keeps the previous file).
import Foundation

@MainActor
enum LaunchCleanup {
    /// Removes the export folder; returns how many files it held.
    @discardableResult
    static func run(fileManager: FileManager = .default, exports: URL = ExportRunner.directory) -> Int {
        let count = (try? fileManager.contentsOfDirectory(atPath: exports.path).count) ?? 0
        try? fileManager.removeItem(at: exports)
        return count
    }
}
