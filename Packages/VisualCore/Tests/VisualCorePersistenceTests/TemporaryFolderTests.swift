// TemporaryFolderTests — feature 024 T-A02-601 (FR-A02-605, SC-A02-603; contract release-contract.md).
import Foundation
import Testing
@testable import VisualCorePersistence

private func base() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("vc-tmpfolder-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func namesAreSanitized() {
    let b = base()
    #expect(TemporaryFolder(name: "Captures", base: b).url.path == b.appendingPathComponent("Captures").path)
    for bad in ["", ".", "..", "a/b", "../x"] {
        #expect(TemporaryFolder(name: bad, base: b).url.path == b.appendingPathComponent("Temporary").path, "\(bad)")
    }
}

@Test func makeFileURLCreatesTheFolderAndUniqueNames() throws {
    let folder = TemporaryFolder(name: "Captures", base: base())
    #expect(!FileManager.default.fileExists(atPath: folder.url.path))
    let a = try folder.makeFileURL(prefix: "FluidArt", extension: "png")
    let b = try folder.makeFileURL(prefix: "FluidArt", extension: "png")
    #expect(FileManager.default.fileExists(atPath: folder.url.path))
    #expect(a != b)
    #expect(a.deletingLastPathComponent().path == folder.url.path)
    #expect(a.lastPathComponent.hasPrefix("FluidArt-") && a.pathExtension == "png")
    let odd = try folder.makeFileURL(prefix: "../x/y", extension: "p/ng")
    #expect(odd.deletingLastPathComponent().path == folder.url.path, "sanitized names stay inside the folder")
}

@Test func removeAllCountsAndRemoves() throws {
    let folder = TemporaryFolder(name: "Captures", base: base())
    for _ in 0..<3 { try Data([1, 2, 3]).write(to: folder.makeFileURL(prefix: "c", extension: "png")) }
    #expect(folder.fileCount == 3)
    #expect(folder.removeAll() == 3)
    #expect(folder.fileCount == 0)
    #expect(!FileManager.default.fileExists(atPath: folder.url.path))
}

@Test func removeAllOnMissingFolderReturnsZero() {
    let folder = TemporaryFolder(name: "Nothing", base: base())
    #expect(folder.removeAll() == 0)
    #expect(folder.fileCount == 0)
}

@Test func filesOutsideTheFolderAreUntouched() throws {
    let b = base()
    let outside = b.appendingPathComponent("keep.txt")
    try Data("keep".utf8).write(to: outside)
    let sibling = TemporaryFolder(name: "Other", base: b)
    try Data([0]).write(to: sibling.makeFileURL(prefix: "o", extension: "bin"))
    let folder = TemporaryFolder(name: "Captures", base: b)
    try Data([0]).write(to: folder.makeFileURL(prefix: "c", extension: "png"))
    #expect(folder.removeAll() == 1)
    #expect(FileManager.default.fileExists(atPath: outside.path))
    #expect(sibling.fileCount == 1)
}

@Test func fileCountIgnoresSubfolders() throws {
    let folder = TemporaryFolder(name: "Captures", base: base())
    try Data([0]).write(to: folder.makeFileURL(prefix: "c", extension: "png"))
    try FileManager.default.createDirectory(at: folder.url.appendingPathComponent("sub"), withIntermediateDirectories: true)
    #expect(folder.fileCount == 1)
    #expect(folder.removeAll() == 1, "the folder and its subfolder go; only regular files are counted")
    #expect(!FileManager.default.fileExists(atPath: folder.url.path))
}
