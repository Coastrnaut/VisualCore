// SettingsStore — feature 113 (A15-P04) T-A15-404 (FR-A15-420, FR-A15-440; SC-A15-403; clarifications Q2, Q3;
// data-model "MoleculeSettings", "StoreLoad"). The visual settings of Molecular Explorer in the experience's own storage,
// one file: `settings.json` (`MoleculeSettings.fileName`), holding the label mode (all, selected, none), modelled on
// Solar System Explorer's `ViewStore`:
//   - Load, once, when the store is made: no file → `.missing`; a file the storage cannot read → `.unreadable(code)`;
//     otherwise `MoleculeSettings.decode(_:)`: `damaged`, `oversized`, `newer-version` or `out-of-range` →
//     `.refused(reason)`. Missing, refused and unreadable files give the default settings (labels for all atoms); a
//     refused or unreadable file reads "Settings could not be read (<reason>); labels are shown for all atoms."
//     Loading never writes, so a refused file stays byte for byte as it was.
//   - Change: `setLabels(_:)` changes the settings in memory and, when they changed, writes their `encoded()` bytes
//     through `ExperienceStorage.write`, which replaces the file atomically. A refused write keeps the previous file,
//     the in-memory settings still change and the message reads "Settings could not be saved (<storage code>)."; a
//     write that succeeds clears the message.
// Without storage (tests and previews) the bytes are kept in memory with the same rules. The settings sit outside the
// engine state: changing them never changes a digest or a replay; they drive the canvas overlay's labels only.
import Foundation
import MolecularExplorerCore
import VisualCoreExperience

/// The settings in their storage file (see the file header).
final class SettingsStore {
    /// The experience's storage, or nil for settings kept in memory only.
    let storage: ExperienceStorage?
    /// What loading the file gave when the store was made.
    let loadResult: StoreLoad<MoleculeSettings>
    /// The settings (the defaults when the file was missing, refused or unreadable).
    private(set) var settings: MoleculeSettings
    /// Why the file could not be read or the last change could not be saved; empty otherwise.
    private(set) var message: String
    /// The stored bytes when there is no storage.
    private var memory: Data?
    /// The number of settings written (or bytes set in memory).
    private(set) var writes = 0

    /// A store over `storage` (in memory without storage) that loads the settings once. Nothing is written here.
    init(storage: ExperienceStorage?) {
        self.storage = storage
        let result = SettingsStore.load(storage: storage, memory: nil)
        loadResult = result
        if case .loaded(let value) = result {
            settings = value
        } else {
            settings = MoleculeSettings()
        }
        message = SettingsStore.readWords(result)
    }

    /// The label mode.
    var labels: LabelMode { settings.labels }

    /// The words shown for a load: "Settings could not be read (<reason>); labels are shown for all atoms." for a
    /// refused or unreadable file, empty otherwise.
    static func readWords(_ result: StoreLoad<MoleculeSettings>) -> String {
        guard let reason = result.failureReason else { return "" }
        return "Settings could not be read (\(reason)); labels are shown for all atoms."
    }

    /// The words shown for a refused write: "Settings could not be saved (<storage code>)."
    static func saveWords(_ code: String) -> String {
        "Settings could not be saved (\(code))."
    }

    /// The settings stored in `storage` (or `memory` without storage), or why there are none. Nothing is written.
    static func load(storage: ExperienceStorage?, memory: Data?) -> StoreLoad<MoleculeSettings> {
        let data: Data
        if let storage {
            do {
                data = try storage.read(MoleculeSettings.fileName)
            } catch {
                if case .notFound = error { return .missing }
                return .unreadable(error.code)
            }
        } else {
            guard let memory else { return .missing }
            data = memory
        }
        switch MoleculeSettings.decode(data) {
        case .success(let value): return .loaded(value)
        case .failure(let refusal): return .refused(refusal)
        }
    }

    /// Reads the stored settings again, without writing (tests: what a new presenter over the same storage would see).
    func reload() -> StoreLoad<MoleculeSettings> {
        Self.load(storage: storage, memory: memory)
    }

    /// Sets the label mode to `mode`. When it changed the settings are written, replacing the file atomically; returns
    /// true when they were written. A refused write keeps the previous file and sets the message; the in-memory
    /// settings change either way.
    @discardableResult
    func setLabels(_ mode: LabelMode) -> Bool {
        guard mode != settings.labels else { return false }
        settings.labels = mode
        let data = settings.encoded()
        if let storage {
            do {
                try storage.write(data, to: MoleculeSettings.fileName)
            } catch {
                message = Self.saveWords(error.code)
                return false
            }
        } else {
            memory = data
        }
        writes += 1
        message = ""
        return true
    }
}
