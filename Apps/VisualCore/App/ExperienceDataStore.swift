// ExperienceDataStore — feature 190 T-U04-011 (FR-U04-052; research R4; data-model section 4). The folders that
// hold the data of the experiences: one folder per storage namespace below one root. The store creates, lists and
// removes folders and reports what it removed; it never reads what an experience wrote.
import Foundation

/// One folder per storage namespace below `root`.
struct ExperienceDataStore {
    /// The folder that holds the namespace folders.
    let root: URL

    /// Creates a store below `root`. Nothing is created on disk until `ensure(namespace:)` is called.
    init(root: URL) {
        self.root = root
    }

    /// `Application Support/Experiences` of the app; a folder in the temporary directory when the system names
    /// no Application Support directory.
    static func defaultRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Experiences", isDirectory: true)
    }

    /// The folder of `namespace`. A namespace is one path component; anything else maps to a name that cannot
    /// leave `root`.
    func folder(for namespace: String) -> URL {
        root.appendingPathComponent(Self.component(namespace), isDirectory: true)
    }

    /// Creates the folder of `namespace` (and the root) when it does not exist.
    func ensure(namespace: String) throws {
        try FileManager.default.createDirectory(at: folder(for: namespace), withIntermediateDirectories: true)
    }

    /// The namespaces that have a folder, sorted.
    func existing() -> [String] {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let items = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys,
                                                                       options: [.skipsHiddenFiles]) else {
            return []
        }
        return items.filter { (try? $0.resourceValues(forKeys: Set(keys)).isDirectory) == true }
            .map(\.lastPathComponent)
            .sorted()
    }

    /// Removes the folders of `namespaces` and returns the namespaces whose folder was removed, sorted.
    @discardableResult
    func remove(namespaces: [String]) -> [String] {
        var removed: [String] = []
        for namespace in Set(namespaces) {
            let url = folder(for: namespace)
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard exists, isDirectory.boolValue else { continue }
            do {
                try FileManager.default.removeItem(at: url)
                removed.append(namespace)
            } catch {
                continue
            }
        }
        return removed.sorted()
    }

    /// A namespace as one safe path component: path separators become `_`, and the names `.` and `..` and the
    /// empty name become `_`.
    private static func component(_ namespace: String) -> String {
        let cleaned = namespace.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        return cleaned.isEmpty || cleaned == "." || cleaned == ".." ? "_" : cleaned
    }
}
