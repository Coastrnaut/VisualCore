// GenerativeArtLibrary — feature 193 (UA-F07) T-U07-009 (FR-U07-002, FR-U07-020; feature 191 FR-U05-001). The saved
// compositions of Generative Art Studio inside the one app: one file per composition in the experience's own
// storage, never a folder of its own. The documents are the app's `ArtDocument` in its canonical JSON, so a saved
// composition carries the same seed, palette, values and time as in the standalone app.
//
// Difference from the standalone app (FR-U07-003): `CompositionLibrary` keeps its files in Application Support;
// here they go through `ExperienceStorage`, whose quota (64 files) bounds the library. Favourites and duplication
// stay in the standalone app until its retirement; the test map records them.
import Foundation
import GenerativeArtStudioCore
import Observation
import VisualCoreExperience

/// One saved composition.
struct GenerativeArtEntry: Codable, Equatable, Identifiable, Sendable {
    /// The entry's id; part of its file name.
    var id: UUID
    /// The name the person gave it.
    var name: String
    /// The composition.
    var document: ArtDocument
}

/// The saved compositions, newest first.
@MainActor
@Observable
final class GenerativeArtLibrary {
    /// The prefix and the extension of a composition file.
    static let filePrefix = "composition-"
    static let fileExtension = ".json"
    /// The longest name kept.
    static let maxNameLength = 60

    /// The experience's storage.
    let storage: ExperienceStorage
    /// The entries, newest first by file order.
    private(set) var entries: [GenerativeArtEntry] = []
    /// Files that could not be read (shown as a count, never deleted).
    private(set) var unreadable = 0
    /// The last failure, for the person; nil after a success.
    var errorMessage: String?

    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    /// The file name of the entry `id`.
    static func fileName(for id: UUID) -> String {
        filePrefix + id.uuidString.lowercased() + fileExtension
    }

    /// Reads every composition file again.
    func reload() {
        var found: [GenerativeArtEntry] = []
        var bad = 0
        for name in storage.list() where name.hasPrefix(Self.filePrefix) && name.hasSuffix(Self.fileExtension) {
            guard let data = try? storage.read(name),
                  let entry = try? JSONDecoder().decode(GenerativeArtEntry.self, from: data),
                  let valid = try? entry.document.validated().document else {
                bad += 1
                continue
            }
            found.append(GenerativeArtEntry(id: entry.id, name: entry.name, document: valid))
        }
        entries = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        unreadable = bad
    }

    /// Saves `document` under `name`: a new entry when `id` is nil, in place otherwise. Returns the entry, or nil
    /// with `errorMessage` set.
    @discardableResult
    func save(_ document: ArtDocument, name: String, id: UUID? = nil) -> GenerativeArtEntry? {
        let entry = GenerativeArtEntry(id: id ?? UUID(), name: Self.clean(name), document: document)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try storage.write(try encoder.encode(entry), to: Self.fileName(for: entry.id))
        } catch {
            errorMessage = "The composition could not be saved (\(Self.reason(error)))."
            return nil
        }
        errorMessage = nil
        reload()
        return entry
    }

    /// Renames the entry `id`.
    func rename(_ id: UUID, to name: String) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        save(entry.document, name: name, id: id)
    }

    /// Removes the entry `id`.
    func remove(_ id: UUID) {
        do {
            try storage.remove(Self.fileName(for: id))
            errorMessage = nil
        } catch {
            errorMessage = "The composition could not be removed (\(Self.reason(error)))."
        }
        reload()
    }

    /// A name without surrounding spaces, at most `maxNameLength` characters; "Untitled" when empty.
    static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(maxNameLength))
    }

    private static func reason(_ error: Error) -> String {
        (error as? StorageError)?.code ?? "\(error)"
    }
}
