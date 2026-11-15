// AquariumLibrary — feature 072 (A09-P05) T-A09-505 (FR-A09-501, 502; SC-A09-501; clarification 1; research D1;
// data-model "Library file"). The saved aquariums of Digital Aquarium: one file `aquarium-<lowercased uuid>.json` per
// `AquariumConfiguration` in the experience's own storage, at most 12, sorted by name ignoring case (ties by the id's
// `uuidString`). Modelled on Oscilloscope Studio's `ScopePresetStore` (the rules are copied, not shared: they belong to
// another experience): unreadable and newer files are counted and never deleted or rewritten, the last failure is kept
// as a plain message with the storage error code, and writes go through `ExperienceStorage.write`, which replaces a
// file atomically and enforces the storage quota, so a refused save leaves every file as it was.
//
// A file counts as unreadable when its content does not decode, when the id inside differs from the id in its name, or
// when the configuration fails `validate(catalog:)`; a greater format counts as newer. Names are cleaned by
// `AquariumConfiguration.cleanedName` (empty → "My aquarium", cut to 40 characters) and need not be unique. Opening a
// configuration sends its `actions(catalog:)` one by one through the experience's action port, so the engine checks
// every value; the first refusal stops the opening (the actions already carried out stay, as any control change does).
import Foundation
import Observation
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// The saved aquariums of Digital Aquarium, kept as files in the experience's storage.
@MainActor
@Observable
final class AquariumLibrary {
    /// The most saved aquariums the library keeps.
    static let maxEntries = 12

    /// The experience's storage.
    let storage: ExperienceStorage
    /// The catalog configurations are validated against and rebuilt with.
    let catalog: SpeciesCatalog
    /// The readable saved aquariums, sorted by name ignoring case, ties by the id's `uuidString`.
    private(set) var entries: [AquariumConfiguration] = []
    /// Saved files that could not be read (shown as a count, never deleted or rewritten).
    private(set) var unreadable = 0
    /// Saved files made by a newer version of the app (shown as a count, never deleted or rewritten).
    private(set) var newer = 0
    /// The last failure, for the person; nil after a success.
    private(set) var lastFailure: String?

    /// A library over `storage` validated against `catalog` (default: the core's catalog); lists the files at once.
    /// - Parameters:
    ///   - storage: The experience's own storage.
    ///   - catalog: The species catalog.
    init(storage: ExperienceStorage, catalog: SpeciesCatalog = AquariumCore.catalog) {
        self.storage = storage
        self.catalog = catalog
        reload()
    }

    /// The file name of the configuration `id`: `aquarium-<lowercased uuid>.json`.
    /// - Parameter id: The configuration's identity.
    static func fileName(for id: UUID) -> String { "aquarium-\(id.uuidString.lowercased()).json" }

    /// The id encoded in a file name made by ``fileName(for:)``, or nil for any other name.
    /// - Parameter fileName: A storage file name.
    static func id(fromFileName fileName: String) -> UUID? {
        let prefix = "aquarium-", suffix = ".json"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else { return nil }
        let core = fileName.dropFirst(prefix.count).dropLast(suffix.count)
        guard core.count == 36, core == core.lowercased() else { return nil }
        return UUID(uuidString: String(core))
    }

    /// Re-reads the storage: every library file that decodes, carries the id of its name and validates becomes an
    /// entry; newer files are counted in `newer`, every other library file in `unreadable`, and all are left in place.
    func reload() {
        var found: [AquariumConfiguration] = []
        var bad = 0, newerFound = 0
        for name in storage.list() {
            guard let id = Self.id(fromFileName: name) else { continue }
            switch load(id) {
            case .success(let configuration): found.append(configuration)
            case .failure(.newer): newerFound += 1
            case .failure: bad += 1
            }
        }
        found.sort {
            let order = $0.name.caseInsensitiveCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
        entries = found
        unreadable = bad
        newer = newerFound
    }

    /// The saved aquarium `id` among the entries, or nil.
    /// - Parameter id: The configuration's identity.
    func entry(_ id: UUID) -> AquariumConfiguration? {
        entries.first { $0.id == id }
    }

    /// Saves the arrangement of `core` (habitat, decor with transforms, lighting, decoration kind, ambient) under
    /// `name` (cleaned: empty → "My aquarium", cut to 40 characters; duplicates allowed) as a new file. Returns false
    /// with `lastFailure` set when the library already holds 12 aquariums or the storage refuses (the message names the
    /// storage error code); no file changes then.
    /// - Parameters:
    ///   - name: The name as typed.
    ///   - core: The aquarium to capture.
    ///   - now: The saved time.
    ///   - id: The new configuration's identity.
    @discardableResult
    func save(name: String, core: AquariumCore, now: Date = Date(), id: UUID = UUID()) -> Bool {
        reload()
        guard entries.count < Self.maxEntries else {
            lastFailure = "Couldn't save the aquarium: the library already holds \(Self.maxEntries) aquariums."
            return false
        }
        let state = core.state
        let configuration = AquariumConfiguration.make(document: state.document, decorKind: state.decorKind,
                                                       ambient: state.ambient, name: name, id: id, savedAt: now)
        let problems = configuration.validate(catalog: catalog)
        guard problems.isEmpty else {
            lastFailure = "Couldn't save the aquarium: " + problems.joined(separator: "; ") + "."
            return false
        }
        guard !storage.exists(Self.fileName(for: id)) else {
            lastFailure = "Couldn't save the aquarium: an aquarium with this identity already exists."
            return false
        }
        do {
            try storage.write(try configuration.fileData(), to: Self.fileName(for: id))
        } catch {
            lastFailure = "Couldn't save the aquarium: " + Self.reason(error) + "."
            return false
        }
        lastFailure = nil
        reload()
        return true
    }

    /// Rebuilds `configuration` by sending its actions through `port`. Returns false with `lastFailure` set when the
    /// configuration does not validate (nothing is sent) or at the first action the experience refuses (the rest are
    /// not sent).
    /// - Parameters:
    ///   - configuration: A saved aquarium.
    ///   - port: The experience's action port.
    @discardableResult
    func open(_ configuration: AquariumConfiguration, port: ExperienceActionPort) -> Bool {
        let problems = configuration.validate(catalog: catalog)
        guard problems.isEmpty else {
            lastFailure = "Couldn't open the aquarium: " + problems.joined(separator: "; ") + "."
            return false
        }
        for action in configuration.actions(catalog: catalog) {
            let result = port.send(action.control, action.values)
            guard result.isAccepted else {
                lastFailure = "Couldn't open the aquarium: \(action.control) was refused (\(result.code))."
                return false
            }
        }
        lastFailure = nil
        return true
    }

    /// Deletes the file of the saved aquarium `id`. Returns false with `lastFailure` set when the storage refuses
    /// (for example when the file is already gone).
    /// - Parameter id: The configuration's identity.
    @discardableResult
    func delete(_ id: UUID) -> Bool {
        defer { reload() }
        do {
            try storage.remove(Self.fileName(for: id))
            lastFailure = nil
            return true
        } catch {
            lastFailure = "Couldn't delete the aquarium: " + Self.reason(error) + "."
            return false
        }
    }

    // MARK: Helpers

    /// Why a library file could not be loaded.
    private enum LoadError: Error {
        /// The file was made by a newer version.
        case newer
        /// The file is damaged, does not match its name or does not validate.
        case malformed
        /// The storage refused the read.
        case storage(StorageError)
    }

    /// Reads, decodes and validates the file of `id`; a content id that differs from `id` is malformed.
    private func load(_ id: UUID) -> Result<AquariumConfiguration, LoadError> {
        let data: Data
        do {
            data = try storage.read(Self.fileName(for: id))
        } catch {
            return .failure(.storage(error))
        }
        do {
            let configuration = try AquariumConfiguration.decode(data)
            guard configuration.id == id, configuration.validate(catalog: catalog).isEmpty else {
                return .failure(.malformed)
            }
            return .success(configuration)
        } catch .newer {
            return .failure(.newer)
        } catch {
            return .failure(.malformed)
        }
    }

    /// A plain reason for `error`, with the storage error code where there is one.
    private static func reason(_ error: Error) -> String {
        switch error {
        case let storage as StorageError:
            switch storage {
            case .quotaExceeded: return "the storage is full (\(storage.code))"
            case .notFound: return "it no longer exists (\(storage.code))"
            default: return "the storage refused it (\(storage.code))"
            }
        default: return "\(error)"
        }
    }
}
