// TemporaryFolder.swift — an app-owned folder of short-lived files (exports, captures) that is emptied at launch for
// crash recovery (feature 024 T-A02-601; FR-A02-605; research R1). Foundation only (rule R2).
import Foundation

/// A named folder under a base directory (default: the app's temporary directory) for files that never outlive a
/// session. Each file gets a unique name; `removeAll()` deletes the folder, so a launch can clear what a killed
/// session left behind. Nothing outside `url` is ever touched.
public struct TemporaryFolder: Sendable, Equatable {
    /// The folder.
    public let url: URL

    /// `name` must be a single path component; an empty name, `.`, `..` or a name containing `/` becomes
    /// `Temporary`, so the folder always stays directly inside `base`.
    public init(name: String, base: URL = FileManager.default.temporaryDirectory) {
        url = base.appendingPathComponent(Self.folderName(name), isDirectory: true)
    }

    /// Creates the folder if needed and returns `<prefix>-<UUID>.<extension>` inside it; never an existing file.
    /// Prefix and extension are sanitized like folder names (fallbacks `file` and `tmp`).
    public func makeFileURL(prefix: String, extension ext: String) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let name = "\(Self.component(prefix, fallback: "file"))-\(UUID().uuidString).\(Self.component(ext, fallback: "tmp"))"
        return url.appendingPathComponent(name, isDirectory: false)
    }

    /// Regular files directly in the folder (0 when the folder is missing or unreadable).
    public var fileCount: Int {
        let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey])) ?? []
        return items.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.count
    }

    /// Deletes the folder and everything in it; returns how many regular files it held. Errors are ignored (a
    /// missing folder returns 0).
    @discardableResult
    public func removeAll() -> Int {
        let count = fileCount
        try? FileManager.default.removeItem(at: url)
        return count
    }

    /// Folder names are strict: anything that is not a single plain component becomes `fallback`.
    private static func folderName(_ raw: String) -> String {
        raw.isEmpty || raw == "." || raw == ".." || raw.contains("/") ? "Temporary" : raw
    }

    /// File-name parts are repaired: `/` becomes `_`; an empty, `.` or `..` result becomes `fallback`.
    private static func component(_ raw: String, fallback: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "/", with: "_")
        return cleaned.isEmpty || cleaned == "." || cleaned == ".." ? fallback : cleaned
    }
}
