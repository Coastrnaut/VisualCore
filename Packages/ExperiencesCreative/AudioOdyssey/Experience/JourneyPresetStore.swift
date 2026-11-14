// JourneyPresetStore — feature 057 (A07-P04) T-A07-403 (FR-A07-401, FR-A07-403, FR-A07-404; SC-A07-401–403; US1;
// research D1, D3; data-model "JourneyPresetStore"; clarification 1). The journeys of Audio Odyssey: the three
// read-only built-ins of `JourneyPreset.builtIns` first, then one file `journey-<lowercased uuid>.json` per user journey
// in the experience's own storage, sorted by name ignoring case (ties by the id's `uuidString`). Modelled on A06's
// `MusicLabPresetStore` (the rules are copied, not shared: they belong to another experience): unreadable and newer
// files are counted and never deleted or rewritten, the last failure is kept as a plain message with the storage error
// code, and writes go through `ExperienceStorage.write`, which replaces a file atomically and enforces the storage
// quota, so a refused save or rename leaves every file as it was.
//
// File content (format 1, coded by `JourneyPreset.fileData()` / `JourneyPreset.decode(_:fileID:)`): sorted keys
// `calm`, `easing`, `format`, `id`, `mappings`, `name`, `saved`, `speedTarget`, `world`; the `id` must match the file
// name. A greater `format` is counted in `newer`; any other file that does not decode, and any file that claims a
// built-in's id, is counted in `unreadable`. Names are cleaned by `JourneyPreset.clean` (trimmed, at most 60
// characters, empty → "Untitled") and made unique ignoring case among every entry, built-ins included, by
// `JourneyPreset.uniqueName` (" 2", " 3", …), on save and on rename, so nothing is replaced silently. No audio is ever
// stored; nothing leaves the device.
import Foundation
import Observation
import AudioOdysseyCore
import VisualCoreExperience

/// The journeys of Audio Odyssey: the built-ins, then the user journeys saved in the experience's storage.
@MainActor
@Observable
final class JourneyPresetStore {
    /// The experience's storage.
    let storage: ExperienceStorage
    /// The built-in journeys first (in their fixed order), then the user journeys sorted by name ignoring case.
    private(set) var entries: [JourneyPreset] = []
    /// Journey files that could not be read (shown as a count, never deleted or rewritten).
    private(set) var unreadable = 0
    /// Journey files made by a newer version of the app (shown as a count, never deleted or rewritten).
    private(set) var newer = 0
    /// The last failure, for the person; nil after a success.
    private(set) var lastMessage: String?

    /// A store over `storage`; lists the journeys at once.
    /// - Parameter storage: The experience's own storage.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    /// Re-reads the storage: every file whose name is a journey file name (`JourneyPreset.id(fromFileName:)`) and that
    /// decodes becomes an entry; newer files are counted in `newer`, every other one in `unreadable`, and all are left
    /// in place. A file that claims a built-in's identifier is counted as unreadable.
    func reload() {
        let builtInIDs = Set(JourneyPreset.builtIns.map(\.id))
        var found: [JourneyPreset] = []
        var bad = 0, newerFound = 0
        for name in storage.list() {
            guard let id = JourneyPreset.id(fromFileName: name) else { continue }
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
        entries = JourneyPreset.builtIns + found
        unreadable = bad
        newer = newerFound
    }

    /// The journey `id` among the entries, or nil.
    /// - Parameter id: The journey's identifier.
    func preset(_ id: UUID) -> JourneyPreset? {
        entries.first { $0.id == id }
    }

    /// Saves the journey fields of `state` (world, mappings, speed target, easing, calm motion) as a new user journey.
    /// The name is cleaned and, when an entry (built-ins included) already has it ignoring case, given the next free
    /// suffix; nothing is overwritten. Returns the new journey, or nil with `lastMessage` set ("Couldn't save the
    /// journey: …") when the storage refuses (for example when it is full); the entries and every file are unchanged
    /// then.
    /// - Parameters:
    ///   - name: The name as typed.
    ///   - state: The journey state to capture.
    ///   - now: The saved time.
    @discardableResult
    func save(name: String, from state: JourneyState, now: Date = Date()) -> JourneyPreset? {
        let unique = JourneyPreset.uniqueName(JourneyPreset.clean(name), among: entries.map(\.name))
        let preset = JourneyPreset(from: state, id: UUID(), name: unique, saved: now)
        guard write(preset, failure: "Couldn't save the journey") else { return nil }
        return preset
    }

    /// Renames the user journey `id`. The name is cleaned and given the next free suffix when another entry (built-ins
    /// included) has it ignoring case; the saved time and every journey field are kept. Returns false with
    /// `lastMessage` set for a built-in, or when the file cannot be read (a newer file is refused and never rewritten)
    /// or written.
    /// - Parameters:
    ///   - id: The journey's identifier.
    ///   - name: The new name as typed.
    @discardableResult
    func rename(_ id: UUID, to name: String) -> Bool {
        if JourneyPreset.builtIns.contains(where: { $0.id == id }) {
            lastMessage = "Built-in journeys can't be renamed."
            return false
        }
        let current: JourneyPreset
        switch load(id) {
        case .success(let preset):
            current = preset
        case .failure(let error):
            lastMessage = "Couldn't rename the journey: " + Self.reason(error) + "."
            reload()
            return false
        }
        let others = entries.filter { $0.id != id }.map(\.name)
        let unique = JourneyPreset.uniqueName(JourneyPreset.clean(name), among: others)
        guard let renamed = JourneyPreset(
            id: current.id, name: unique, saved: current.saved, world: current.world, mappings: current.mappings,
            speedTarget: current.speedTarget, easing: current.easing, calmMotion: current.calmMotion)
        else {
            lastMessage = "Couldn't rename the journey: it can't be read."
            return false
        }
        return write(renamed, failure: "Couldn't rename the journey")
    }

    /// Deletes the file of the user journey `id`. Returns false with `lastMessage` set for a built-in or when the
    /// storage refuses (for example when the file is already gone).
    /// - Parameter id: The journey's identifier.
    @discardableResult
    func delete(_ id: UUID) -> Bool {
        if JourneyPreset.builtIns.contains(where: { $0.id == id }) {
            lastMessage = "Built-in journeys can't be deleted."
            return false
        }
        defer { reload() }
        do {
            try storage.remove(JourneyPreset.fileName(for: id))
            lastMessage = nil
            return true
        } catch {
            lastMessage = "Couldn't delete the journey: " + Self.reason(error) + "."
            return false
        }
    }

    // MARK: Helpers

    /// Why a journey file could not be loaded.
    private enum LoadError: Error {
        /// The file was made by a newer version.
        case newer
        /// The file is damaged or does not match its name.
        case malformed
        /// The storage refused the read.
        case storage(StorageError)
    }

    /// Reads and decodes the file of `id`.
    private func load(_ id: UUID) -> Result<JourneyPreset, LoadError> {
        let data: Data
        do {
            data = try storage.read(JourneyPreset.fileName(for: id))
        } catch {
            return .failure(.storage(error))
        }
        do {
            return .success(try JourneyPreset.decode(data, fileID: id))
        } catch .newer {
            return .failure(.newer)
        } catch {
            return .failure(.malformed)
        }
    }

    /// Writes `preset` atomically; on success clears the message and reloads, on failure sets the message and leaves
    /// the entries as they were.
    private func write(_ preset: JourneyPreset, failure: String) -> Bool {
        do {
            try storage.write(try preset.fileData(), to: JourneyPreset.fileName(for: preset.id))
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
