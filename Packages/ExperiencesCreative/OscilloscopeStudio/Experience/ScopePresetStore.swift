// ScopePresetStore — feature 064 (A08-P04) T-A08-404 (FR-A08-410, FR-A08-430; SC-A08-404; story 3; clarification 4;
// research D4; data-model "ScopePreset"). The scope presets of Oscilloscope Studio: the three read-only built-ins of
// `ScopePreset.builtIns` first, then one file `scope-<lowercased uuid>.json` per user preset in the experience's own
// storage, sorted by name ignoring case (ties by the id's `uuidString`). Modelled on Audio Odyssey's
// `JourneyPresetStore` (the rules are copied, not shared: they belong to another experience): unreadable and newer
// files are counted and never deleted or rewritten, the last failure is kept as a plain message with the storage error
// code, and writes go through `ExperienceStorage.write`, which replaces a file atomically and enforces the storage
// quota, so a refused save or rename leaves every file as it was and nothing half-written.
//
// File content (format 1, coded by `ScopePreset.fileData()` / `ScopePreset.decode(_:)`): sorted keys `display`,
// `format`, `frequency`, `gain`, `id`, `level`, `mode`, `name`, `savedAt`, `slope`, `timebase`, `waveform`; the `id`
// must match the file name. A greater `format` is counted in `newer`; any other file that does not decode, whose
// content id differs from the id in its name, or that claims a built-in's id, is counted in `unreadable`. Names are
// trimmed and must then be 1…40 characters (`ScopePreset.validName`); unlike journeys, duplicate names are allowed
// (clarification 4: presets are told apart by id). Presets hold settings only — never the source, the freeze, the
// cursors or any audio; nothing leaves the device.
import Foundation
import Observation
import OscilloscopeStudioCore
import VisualCoreExperience

/// The scope presets of Oscilloscope Studio: the built-ins, then the user presets saved in the experience's storage.
@MainActor
@Observable
final class ScopePresetStore {
    /// The experience's storage.
    let storage: ExperienceStorage
    /// The built-in presets first (in their fixed order), then the user presets sorted by name ignoring case.
    private(set) var entries: [ScopePreset] = []
    /// Preset files that could not be read (shown as a count, never deleted or rewritten).
    private(set) var unreadable = 0
    /// Preset files made by a newer version of the app (shown as a count, never deleted or rewritten).
    private(set) var newer = 0
    /// The last failure, for the person; nil after a success.
    private(set) var lastMessage: String?

    /// A store over `storage`; lists the presets at once.
    /// - Parameter storage: The experience's own storage.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    /// Re-reads the storage: every file whose name is a preset file name (`ScopePreset.id(fromFileName:)`) and that
    /// decodes with the id of its name becomes an entry; newer files are counted in `newer`, every other one in
    /// `unreadable`, and all are left in place. A file that claims a built-in's identifier is counted as unreadable.
    func reload() {
        let builtInIDs = Set(ScopePreset.builtIns.map(\.id))
        var found: [ScopePreset] = []
        var bad = 0, newerFound = 0
        for name in storage.list() {
            guard let id = ScopePreset.id(fromFileName: name) else { continue }
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
        entries = ScopePreset.builtIns + found
        unreadable = bad
        newer = newerFound
    }

    /// The preset `id` among the entries, or nil.
    /// - Parameter id: The preset's identifier.
    func preset(_ id: UUID) -> ScopePreset? {
        entries.first { $0.id == id }
    }

    /// The index of the built-in `preset` in `ScopePreset.builtIns` (the `preset.apply` value), or nil for a user
    /// preset.
    /// - Parameter preset: The preset.
    static func builtInIndex(of preset: ScopePreset) -> Int? {
        ScopePreset.builtIns.firstIndex { $0.id == preset.id }
    }

    /// Saves the settings of `state` (waveform, frequency, gain, timebase, trigger and display; never the source, the
    /// freeze or the cursors) as a new user preset named `name` (trimmed; duplicates allowed). Returns the new preset,
    /// or nil with `lastMessage` set when the trimmed name is not 1…40 characters ("Couldn't save the preset: …") or the
    /// storage refuses (for example when it is full); the entries and every file are unchanged then.
    /// - Parameters:
    ///   - name: The name as typed.
    ///   - state: The scope state to capture.
    ///   - now: The saved time.
    @discardableResult
    func save(name: String, from state: ScopeState, now: Date = Date()) -> ScopePreset? {
        guard let preset = ScopePreset.from(state: state, name: name, id: UUID(), now: now) else {
            lastMessage = "Couldn't save the preset: " + Self.nameRule + "."
            return nil
        }
        guard write(preset, failure: "Couldn't save the preset") else { return nil }
        return preset
    }

    /// Renames the user preset `id` (trimmed, 1…40 characters; duplicates allowed); the saved time and every setting
    /// are kept. Returns false with `lastMessage` set for a built-in, for a name that breaks the rule, or when the file
    /// cannot be read (a newer file is refused and never rewritten) or written.
    /// - Parameters:
    ///   - id: The preset's identifier.
    ///   - name: The new name as typed.
    @discardableResult
    func rename(_ id: UUID, to name: String) -> Bool {
        if ScopePreset.builtIns.contains(where: { $0.id == id }) {
            lastMessage = "Built-in presets can't be renamed."
            return false
        }
        let current: ScopePreset
        switch load(id) {
        case .success(let preset):
            current = preset
        case .failure(let error):
            lastMessage = "Couldn't rename the preset: " + Self.reason(error) + "."
            reload()
            return false
        }
        guard let renamed = ScopePreset(id: current.id, name: name, savedAt: current.savedAt,
                                        settings: current.settings) else {
            lastMessage = "Couldn't rename the preset: " + Self.nameRule + "."
            return false
        }
        return write(renamed, failure: "Couldn't rename the preset")
    }

    /// Deletes the file of the user preset `id`. Returns false with `lastMessage` set for a built-in or when the
    /// storage refuses (for example when the file is already gone).
    /// - Parameter id: The preset's identifier.
    @discardableResult
    func delete(_ id: UUID) -> Bool {
        if ScopePreset.builtIns.contains(where: { $0.id == id }) {
            lastMessage = "Built-in presets can't be deleted."
            return false
        }
        defer { reload() }
        do {
            try storage.remove(ScopePreset.fileName(for: id))
            lastMessage = nil
            return true
        } catch {
            lastMessage = "Couldn't delete the preset: " + Self.reason(error) + "."
            return false
        }
    }

    // MARK: Helpers

    /// The name rule in words.
    static let nameRule = "the name needs 1 to \(ScopePreset.nameLimit) characters"

    /// Why a preset file could not be loaded.
    private enum LoadError: Error {
        /// The file was made by a newer version.
        case newer
        /// The file is damaged or does not match its name.
        case malformed
        /// The storage refused the read.
        case storage(StorageError)
    }

    /// Reads and decodes the file of `id`; a content id that differs from `id` is malformed.
    private func load(_ id: UUID) -> Result<ScopePreset, LoadError> {
        let data: Data
        do {
            data = try storage.read(ScopePreset.fileName(for: id))
        } catch {
            return .failure(.storage(error))
        }
        do {
            let preset = try ScopePreset.decode(data)
            guard preset.id == id else { return .failure(.malformed) }
            return .success(preset)
        } catch .newer {
            return .failure(.newer)
        } catch {
            return .failure(.malformed)
        }
    }

    /// Writes `preset` atomically; on success clears the message and reloads, on failure sets the message and leaves
    /// the entries as they were.
    private func write(_ preset: ScopePreset, failure: String) -> Bool {
        do {
            try storage.write(try preset.fileData(), to: ScopePreset.fileName(for: preset.id))
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
