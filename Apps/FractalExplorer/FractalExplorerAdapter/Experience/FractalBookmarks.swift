// FractalBookmarks — feature 193 (UA-F07) T-U07-024 (FR-U07-002; feature 191 FR-U05-001). The saved views of Fractal
// Explorer inside the one app: one file per bookmark in the experience's own storage, holding the app's `Bookmark` in
// its stored form, so a saved view carries the same family, framing, seed, cap, radius and palette as in the
// standalone app.
//
// Difference from the standalone app (FR-U07-003): `BookmarkLibrary` (`NamedLibrary`) kept its files in Application
// Support; here they go through `ExperienceStorage`, whose quota (64 files) bounds the bookmarks. Favourites stay in
// the standalone app until its retirement; the test map records them.
import Foundation
import FractalExplorerCore
import Observation
import VisualCoreExperience

/// One saved view.
struct FractalBookmarkEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var bookmark: Bookmark
}

/// The saved views, by name.
@MainActor
@Observable
final class FractalBookmarks {
    static let filePrefix = "bookmark-"
    static let fileExtension = ".json"
    static let maxNameLength = 60

    let storage: ExperienceStorage
    private(set) var entries: [FractalBookmarkEntry] = []
    /// Files that could not be read (shown as a count, never deleted).
    private(set) var unreadable = 0
    /// The last failure, for the person; nil after a success.
    var errorMessage: String?

    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    static func fileName(for id: UUID) -> String { filePrefix + id.uuidString.lowercased() + fileExtension }

    func reload() {
        var found: [FractalBookmarkEntry] = []
        var bad = 0
        for name in storage.list() where name.hasPrefix(Self.filePrefix) && name.hasSuffix(Self.fileExtension) {
            guard let data = try? storage.read(name),
                  let entry = try? JSONDecoder().decode(FractalBookmarkEntry.self, from: data),
                  let valid = entry.bookmark.validated() else {
                bad += 1
                continue
            }
            found.append(FractalBookmarkEntry(id: entry.id, name: entry.name, bookmark: valid))
        }
        entries = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        unreadable = bad
    }

    @discardableResult
    func save(_ bookmark: Bookmark, name: String, id: UUID? = nil) -> FractalBookmarkEntry? {
        let entry = FractalBookmarkEntry(id: id ?? UUID(), name: Self.clean(name), bookmark: bookmark)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try storage.write(try encoder.encode(entry), to: Self.fileName(for: entry.id))
        } catch {
            errorMessage = "The view could not be saved (\(Self.reason(error)))."
            return nil
        }
        errorMessage = nil
        reload()
        return entry
    }

    func rename(_ id: UUID, to name: String) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        save(entry.bookmark, name: name, id: id)
    }

    func remove(_ id: UUID) {
        do {
            try storage.remove(Self.fileName(for: id))
            errorMessage = nil
        } catch {
            errorMessage = "The view could not be removed (\(Self.reason(error)))."
        }
        reload()
    }

    static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(maxNameLength))
    }

    private static func reason(_ error: Error) -> String {
        (error as? StorageError)?.code ?? "\(error)"
    }
}
