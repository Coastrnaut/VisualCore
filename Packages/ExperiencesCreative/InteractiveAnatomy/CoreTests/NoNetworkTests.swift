// NoNetworkTests — feature 127 (A17-P04) T-A17-404 (FR-A17-408; SC-A17-404; clarification Q5). Interactive Anatomy
// uses no network: no Swift source under InteractiveAnatomy/Core or InteractiveAnatomy/Experience, found through
// `#filePath`, contains a networking type, a Network import or an http literal. The needles are built from parts so
// that this file does not contain them.
import Foundation
import Testing

/// The forbidden texts, each assembled from two parts.
private let noNetworkNeedles: [String] = [
    "URL" + "Session", "URL" + "Request", "NW" + "Connection", "import " + "Network", "http" + "://", "https" + "://",
]

/// Every `.swift` file under `folder`.
private func noNetworkSwiftFiles(_ folder: URL) -> [URL] {
    let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
    return (walker?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
}

@Suite struct NoNetworkTests {
    @Test func noInteractiveAnatomySourceUsesTheNetwork() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var scanned = 0
        var findings: [String] = []
        for folder in ["Core", "Experience"] {
            for file in noNetworkSwiftFiles(root.appendingPathComponent(folder)) {
                let text = try String(contentsOf: file, encoding: .utf8)
                scanned += 1
                for needle in noNetworkNeedles where text.contains(needle) {
                    findings.append("\(file.lastPathComponent): \(needle)")
                }
            }
        }
        #expect(scanned > 10, "the sources were found")
        #expect(findings.isEmpty, "\(findings)")
    }
}
