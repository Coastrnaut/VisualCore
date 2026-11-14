// MusicLabPresetStore — feature 050 (A06-P04) T-A06-404 (FR-A06-411, FR-A06-412; SC-A06-403; US2; research D5;
// data model "Preset library"; clarification 4). The presets of VisualCore Music Lab: the three read-only built-ins of
// `MusicPreset.builtIns` first, then one file `preset-<lowercased uuid>.json` per user preset in the experience's own
// storage, sorted by name ignoring case. Follows `GeometryLibrary`: unreadable and newer files are counted and never
// deleted or rewritten, the last failure is kept as a message, and writes go through `ExperienceStorage.write`, which
// replaces a file atomically and enforces the storage quota, so a refused save or rename leaves every file as it was.
//
// File content (format 1, coded by `MusicPreset.fileData()` / `MusicPreset.decode(_:fileID:)`):
// `{"choices": [{"feature": n, "gain": g}…], "format": 1, "id": "<uuid>", "name": "…", "saved": <seconds since
// 2001-01-01>, "scene": n}` with sorted keys. The `id` must match the file name. A greater `format` is counted in
// `newer`; any other file that does not decode is counted in `unreadable`. Names are cleaned by `MusicPreset.clean`
// (trimmed, at most 60 characters, empty → "Untitled") and made unique ignoring case among every entry, built-ins
// included, by `MusicPreset.uniqueName` (" 2", " 3", …), on save and on rename, so nothing is replaced silently.
import Foundation
import Observation
import VisualCoreExperience
import VisualCoreMusicLabCore

/// The presets of Music Lab: the built-ins, then the user presets saved in the experience's storage.
@MainActor
@Observable
final class MusicLabPresetStore {
    /// The experience's storage.
    let storage: ExperienceStorage
    /// The built-in presets first (in their fixed order), then the user presets sorted by name ignoring case.
    private(set) var entries: [MusicPreset] = []
    /// Preset files that could not be read (shown as a count, never deleted or rewritten).
    private(set) var unreadable = 0
    /// Preset files made by a newer version of the app (shown as a count, never deleted or rewritten).
    private(set) var newer = 0
    /// The last failure, for the person; nil after a success.
    private(set) var lastMessage: String?

    /// A library over `storage`; lists the presets at once.
    /// - Parameter storage: The experience's own storage.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    /// Re-reads the storage: every file whose name is a preset file name (`MusicPreset.id(fromFileName:)`) and that
    /// decodes becomes an entry; newer files are counted in `newer`, every other one in `unreadable`, and all are left
    /// in place. A file that claims a built-in's identifier is counted as unreadable.
    func reload() {
        let builtInIDs = Set(MusicPreset.builtIns.map(\.id))
        var found: [MusicPreset] = []
        var bad = 0, newerFound = 0
        for name in storage.list() {
            guard let id = MusicPreset.id(fromFileName: name) else { continue }
            guard !builtInIDs.contains(id) else {
                bad += 1
                continue
            }
            switch load(id) {
            case .success(let preset): found.append(preset)
            case .failure(.newer): newerFound += 1
            case .failure: bad += 1
            }
        }
        found.sort {
            let order = $0.name.caseInsensitiveCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
        entries = MusicPreset.builtIns + found
        unreadable = bad
        newer = newerFound
    }

    /// The preset `id` among the entries, or nil.
    /// - Parameter id: The preset's identifier.
    func preset(_ id: UUID) -> MusicPreset? {
        entries.first { $0.id == id }
    }

    /// Saves a new user preset. The name is cleaned and, when an entry (built-ins included) already has it ignoring
    /// case, given the next free suffix; nothing is overwritten. Returns the new preset, or nil with `lastMessage`
    /// set ("Couldn't save the preset: …") when the choices do not fit the scene or the storage refuses (for example
    /// when it is full); the entries and every file are unchanged then.
    /// - Parameters:
    ///   - name: The name as typed.
    ///   - scene: The scene of the preset.
    ///   - choices: The scene's mapping choices, one per parameter.
    ///   - now: The saved time.
    @discardableResult
    func save(name: String, scene: MusicLabScene, choices: [MappingChoice], palette: MusicLabPalette = .aurora,
              now: Date = Date()) -> MusicPreset? {
        let unique = MusicPreset.uniqueName(MusicPreset.clean(name), among: entries.map(\.name))
        guard let preset = MusicPreset(id: UUID(), name: unique, scene: scene, choices: choices, saved: now,
                                       isBuiltIn: false, palette: palette) else {
            lastMessage = "Couldn't save the preset: the mappings do not fit the scene."
            return nil
        }
        guard write(preset, failure: "Couldn't save the preset") else { return nil }
        return preset
    }

    /// Renames the user preset `id`. The name is cleaned and given the next free suffix when another entry (built-ins
    /// included) has it ignoring case; the saved time, scene and choices are kept. Returns false with `lastMessage`
    /// set for a built-in, or when the file cannot be read (a newer file is refused and never rewritten) or written.
    /// - Parameters:
    ///   - id: The preset's identifier.
    ///   - name: The new name as typed.
    @discardableResult
    func rename(_ id: UUID, to name: String) -> Bool {
        if MusicPreset.builtIns.contains(where: { $0.id == id }) {
            lastMessage = "Built-in presets can't be renamed."
            return false
        }
        let current: MusicPreset
        switch load(id) {
        case .success(let preset):
            current = preset
        case .failure(let error):
            lastMessage = "Couldn't rename the preset: " + Self.reason(error) + "."
            reload()
            return false
        }
        let others = entries.filter { $0.id != id }.map(\.name)
        let unique = MusicPreset.uniqueName(MusicPreset.clean(name), among: others)
        guard let renamed = MusicPreset(id: current.id, name: unique, scene: current.scene, choices: current.choices,
                                        saved: current.saved, isBuiltIn: false, palette: current.palette) else {
            lastMessage = "Couldn't rename the preset: it can't be read."
            return false
        }
        return write(renamed, failure: "Couldn't rename the preset")
    }

    /// Deletes the file of the user preset `id`. Returns false with `lastMessage` set for a built-in or when the
    /// storage refuses (for example when the file is already gone).
    /// - Parameter id: The preset's identifier.
    @discardableResult
    func delete(_ id: UUID) -> Bool {
        if MusicPreset.builtIns.contains(where: { $0.id == id }) {
            lastMessage = "Built-in presets can't be deleted."
            return false
        }
        defer { reload() }
        do {
            try storage.remove(MusicPreset.fileName(for: id))
            lastMessage = nil
            return true
        } catch {
            lastMessage = "Couldn't delete the preset: " + Self.reason(error) + "."
            return false
        }
    }

    // MARK: Helpers

    /// Why a preset file could not be loaded.
    private enum LoadError: Error {
        /// The file was made by a newer version.
        case newer
        /// The file is damaged or does not match its name.
        case malformed
        /// The storage refused the read.
        case storage(StorageError)
    }

    /// Reads and decodes the file of `id`.
    private func load(_ id: UUID) -> Result<MusicPreset, LoadError> {
        let data: Data
        do {
            data = try storage.read(MusicPreset.fileName(for: id))
        } catch {
            return .failure(.storage(error))
        }
        do {
            return .success(try MusicPreset.decode(data, fileID: id))
        } catch .newer {
            return .failure(.newer)
        } catch {
            return .failure(.malformed)
        }
    }

    /// Writes `preset` atomically; on success clears the message and reloads, on failure sets the message and leaves
    /// the entries as they were.
    private func write(_ preset: MusicPreset, failure: String) -> Bool {
        do {
            try storage.write(try preset.fileData(), to: MusicPreset.fileName(for: preset.id))
        } catch {
            lastMessage = failure + ": " + Self.reason(error) + "."
            return false
        }
        lastMessage = nil
        reload()
        return true
    }

    /// A plain reason for `error`, with the storage error code where there is one.
    private static func reason(_ error: Error) -> String {
        switch error {
        case LoadError.newer: return "it was made by a newer version"
        case LoadError.malformed: return "it can't be read"
        case LoadError.storage(let storage): return reason(storage)
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
