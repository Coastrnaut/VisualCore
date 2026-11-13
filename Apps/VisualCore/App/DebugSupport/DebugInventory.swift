// DebugInventory — feature 191 T-U05-022 (UA-F05, US6; FR-U05-060 to FR-U05-063, FR-U05-073; research R8). The
// allow-list of everything that may exist in the app's container and in its defaults domain, and the reader that
// lists what really exists. The settings diagnostics show the result (`vc.inventory`), where an interface test
// reads it. The whole file is inside `#if DEBUG`: a release build contains neither the list nor the reader.
#if DEBUG
import Foundation
import VisualCoreExperience

/// The inventory of the app's container in builds made for testing.
enum DebugInventory {
    private static let namespace = "[a-z0-9][a-z0-9.-]*"
    private static let name = "[A-Za-z0-9_-][A-Za-z0-9._-]{0,127}"
    private static let experiences = "Library/Application Support/Experiences/" + namespace + "/"

    /// The rules. A file path is relative to the container; a key is a key of the app's defaults domain.
    /// System rules name files and keys the system writes on its own, each with the observation behind it.
    static let rules: [InventoryRule] = [
        InventoryRule(kind: .file, pattern: experiences + "state\\.json", writer: "the app: the saved state"),
        InventoryRule(kind: .file, pattern: experiences + "quarantine-[0-9]+\\.json",
                      writer: "the app: quarantined copies of a saved state that could not be read"),
        InventoryRule(kind: .file, pattern: experiences + name,
                      writer: "an experience, through its storage handle"),
        InventoryRule(kind: .file, pattern: "Documents/visualcore-evidence/[A-Za-z0-9-]+/[a-z0-9.-]+\\.json",
                      writer: "the scenario runner of builds made for testing: evidence records (feature 195)"),
        InventoryRule(kind: .key, pattern: "vc\\.shell\\.preferences", writer: "the app: the session state"),
        InventoryRule(kind: .key, pattern: "vc\\.shell\\.preferences\\.unreadable",
                      writer: "the app: the copy of an unreadable session state"),
        InventoryRule(kind: .key, pattern: "exp\\." + namespace + "\\." + name,
                      writer: "an experience, through its storage handle"),
    ] + systemRules

    /// What the system writes on its own. Each rule was added after the item was seen in an inventory run on
    /// the simulators; `origin` says where and why it is the system's.
    static let systemRules: [InventoryRule] = [
        InventoryRule(kind: .file, pattern: "Library/Preferences/" + bundle + "\\.plist",
                      writer: "the system: the property list of a defaults domain", system: true,
                      origin: "written by cfprefsd for the app's own defaults domain; seen on the iOS 27.2 and 26.5 simulators"),
        InventoryRule(kind: .file, pattern: "Library/Caches/" + bundle + "/com\\.apple\\.metal/.+",
                      writer: "the system: the Metal library cache", system: true,
                      origin: "written by Metal when the renderer (OpenGL ES through ANGLE on Metal) compiles "
                          + "its shaders: libraries.data and libraries.list; seen after the first frame"),
        InventoryRule(kind: .file, pattern: "Library/Caches/" + bundle + "/com\\.apple\\.metalfe/.+",
                      writer: "the system: the Metal front-end module cache", system: true,
                      origin: "written by the Metal shader compiler: modules.timestamp and one folder with "
                          + "modules.idx and monolithic_metal.pcm; seen after the first frame"),
        InventoryRule(kind: .file, pattern: "Library/SplashBoard/Snapshots/.+",
                      writer: "the system: pictures of the launch screen", system: true,
                      origin: "written by SplashBoard for the launch screen, one .ktx picture per size and "
                          + "appearance; seen after the first start"),
        InventoryRule(kind: .file, pattern: "Library/Saved Application State/" + bundle + "\\.savedState/.+",
                      writer: "the system: the scene sessions of UIKit", system: true,
                      origin: "written by UIKit when the app goes to the background: KnownSceneSessions and "
                          + "one folder per scene; the app stores nothing there itself"),
        InventoryRule(kind: .key, pattern: "com\\.apple\\.UIKit\\.UISplitViewController\\.[A-Za-z0-9._-]+",
                      writer: "the system: the column state of the split view", system: true,
                      origin: "written by UIKit for the NavigationSplitView of the root view; seen as "
                          + "com.apple.UIKit.UISplitViewController.Root after the first start"),
    ]

    /// The app's own bundle identifier as a pattern: the system rules allow the app's files, not those of
    /// any identifier.
    private static let bundle = NSRegularExpression.escapedPattern(for: Bundle.main.bundleIdentifier ?? "-")

    /// The files below `Documents`, `Library` and `tmp` of the container at `home`, as relative paths, sorted.
    /// Folders are not listed; a file the reader cannot classify is listed, never skipped.
    static func files(home: URL) -> [String] {
        var found: [String] = []
        let base = home.standardizedFileURL.path
        for top in ["Documents", "Library", "tmp"] {
            let folder = home.appendingPathComponent(top, isDirectory: true)
            guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                                              options: []) else { continue }
            for case let url as URL in walker {
                let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isFolder { continue }
                let path = url.standardizedFileURL.path
                found.append(path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : path)
            }
        }
        return found.sorted()
    }

    /// The keys of the persistent defaults domain `domain`, sorted.
    static func keys(defaults: UserDefaults, domain: String) -> [String] {
        (defaults.persistentDomain(forName: domain) ?? [:]).keys.sorted()
    }

    /// The inventory as one line: `inventory: <n> files, <m> keys; unlisted: <items or none>`.
    static func text(files: [String], keys: [String]) -> String {
        guard let inventory = try? ContainerInventory(rules: rules) else { return "inventory: invalid rules" }
        let unlisted = inventory.unlisted(files: files, keys: keys)
        return "inventory: \(files.count) files, \(keys.count) keys; unlisted: "
            + (unlisted.isEmpty ? "none" : unlisted.joined(separator: ", "))
    }

    /// The inventory of the running app: its container and the defaults domain of its bundle identifier.
    static func current() -> String {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return text(files: files(home: home),
                    keys: keys(defaults: .standard, domain: Bundle.main.bundleIdentifier ?? ""))
    }
}
#endif
