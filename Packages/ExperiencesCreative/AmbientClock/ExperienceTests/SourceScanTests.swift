// SourceScanTests — feature 134 (A18-P04) T-A18-406 (FR-A18-402, FR-A18-407; G-AWAKE/G-NIGHT; clarification Q4;
// contracts/power.md "Brightness", "Keep-awake"). A scan of every Swift source of
// `Packages/ExperiencesCreative/AmbientClock` (found from this file's path): the application's idle-timer property is
// named only in `Experience/KeepAwake.swift`, and no file writes a brightness. The needles are assembled from pieces,
// so this file does not match itself.
import Foundation
import Testing

@Suite struct SourceScanTests {
    /// The AmbientClock folder: two levels above this file (`ExperienceTests/SourceScanTests.swift`).
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Every Swift source under `root`, as (path relative to `root`, text).
    private func sources() throws -> [(String, String)] {
        let rootPath = Self.root.standardizedFileURL.path
        let enumerator = try #require(FileManager.default.enumerator(at: Self.root, includingPropertiesForKeys: nil))
        var found: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let path = url.standardizedFileURL.path
            let relative = path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : path
            found.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return found.sorted { $0.0 < $1.0 }
    }

    @Test func theScanSeesTheExperienceSources() throws {
        let paths = try sources().map(\.0)
        #expect(Self.root.lastPathComponent == "AmbientClock")
        #expect(paths.contains("Experience/KeepAwake.swift"))
        #expect(paths.contains("Experience/AmbientPresenter.swift"))
        #expect(paths.contains("Core/ScreenCare.swift"))
        #expect(paths.contains("ExperienceTests/SourceScanTests.swift"))
        #expect(paths.count > 20)
    }

    @Test func theIdleTimerIsNamedOnlyInKeepAwake() throws {
        let needle = "isIdle" + "TimerDisabled"
        let naming = try sources().filter { $0.1.contains(needle) }.map(\.0)
        #expect(naming == ["Experience/KeepAwake.swift"])
    }

    @Test func noSourceWritesABrightness() throws {
        let needles = ["brightness" + " =", ".brightness" + "="]
        for (path, text) in try sources() {
            for needle in needles {
                #expect(!text.contains(needle), "\(path) contains \(needle)")
            }
        }
    }
}
