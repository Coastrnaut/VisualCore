// LibraryModel.swift — the app's saved compositions (feature 014 T-A01-304; FR-A01-301–FR-A01-305, FR-A01-310).
// Stored in Application Support/Compositions; DEBUG builds accept `-gasLibraryDir <path>` so UI tests use an isolated folder.
import Foundation
import GenerativeArtStudioCore
import Observation
import VisualCorePersistence

@MainActor
@Observable
final class LibraryModel {
    private(set) var library: CompositionLibrary
    /// The last failed operation, shown as an alert.
    var errorMessage: String?

    init(directory: URL = LibraryModel.directory) {
        library = CompositionLibrary(directory: directory)
        library.reload()
    }

    static var directory: URL {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "gasLibraryDir"), !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        #endif
        return CompositionLibrary.defaultDirectory()
    }

    var entries: [LibraryEntry] { library.entries }
    var problemCount: Int { library.problems.count }

    func reload() { library.reload() }

    /// Saves (new when `id` is nil, in place otherwise); returns the entry or nil after reporting the error.
    @discardableResult
    func save(_ document: ArtDocument, name: String, id: UUID?) -> LibraryEntry? {
        do { return try library.save(document: document, name: name, id: id) } catch {
            errorMessage = "Couldn’t save: \(error)"
            return nil
        }
    }

    func duplicate(_ id: UUID) { perform { try $0.duplicate(id) } }
    func rename(_ id: UUID, to name: String) { perform { try $0.rename(id, to: name) } }
    func toggleFavorite(_ id: UUID) {
        guard let e = library.entry(id) else { return }
        perform { try $0.setFavorite(id, !e.favorite) }
    }
    func delete(_ id: UUID) { perform { try $0.delete(id) } }

    private func perform(_ body: (inout CompositionLibrary) throws -> Void) {
        do { try body(&library) } catch { errorMessage = "\(error)" }
    }
}
