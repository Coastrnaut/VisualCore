// SimulationPresetStore — feature 120 (A16-P04) T-A16-408 (FR-A16-430; SC-A16-403; Clarification Q4). The saved
// experiments of Simulation Lab: one file per preset, `preset-<uuid>.json`, in the experience's own
// `ExperienceStorage`, the Fractal Explorer bookmarks pattern (`FractalBookmarks`). The library holds at most 24
// files; damaged, newer (schema ≥ 2) and refused files are reported in `problems` and skipped, never deleted.
//
// The cap counts the preset files on disk (contract: "≤ 24 files"), so a damaged file also takes a place; replacing
// a preset under an existing id never counts as a new file.
import Foundation
import Observation
import SimulationLabCore
import VisualCoreExperience

/// One saved experiment: its file id and its preset.
struct SimulationPresetEntry: Equatable, Identifiable, Sendable {
    /// The id in the file name `preset-<id>.json` (lowercased there).
    var id: UUID
    /// The decoded, valid preset.
    var preset: ExperimentPreset
}

/// The library of saved experiments, sorted by name and then by id.
@MainActor
@Observable
final class SimulationPresetStore {
    /// The most preset files the library holds.
    static let cap = 24
    /// The prefix of every preset file name.
    static let filePrefix = "preset-"
    /// The extension of every preset file name.
    static let fileExtension = ".json"
    /// The sentence of a save refused at the cap.
    static let fullSentence = "The library holds 24 experiments; delete one first."
    /// The sentence of a save the storage refused.
    static let saveFailedSentence = "The experiment could not be saved."

    /// The experience's storage handle.
    let storage: ExperienceStorage
    /// The readable presets, sorted by name and then by id.
    private(set) var entries: [SimulationPresetEntry] = []
    /// One line per skipped file, `<file name>: <refusal>` (`damaged`, `newer-version` or `invalid`), by file name.
    private(set) var problems: [String] = []

    /// A library over `storage`; reads the files at once.
    init(storage: ExperienceStorage) {
        self.storage = storage
        reload()
    }

    /// The file name of the preset `id`: `preset-<lowercased uuid>.json`.
    static func fileName(for id: UUID) -> String { filePrefix + id.uuidString.lowercased() + fileExtension }

    /// The preset file names in the storage, sorted.
    private var presetFileNames: [String] {
        storage.list().filter { $0.hasPrefix(Self.filePrefix) && $0.hasSuffix(Self.fileExtension) }
    }

    /// Reads every preset file again. A file whose name holds no UUID or whose content `ExperimentPreset.decode`
    /// refuses becomes a line in `problems` and is skipped.
    func reload() {
        var found: [SimulationPresetEntry] = []
        var skipped: [String] = []
        for name in presetFileNames {
            let idText = String(name.dropFirst(Self.filePrefix.count).dropLast(Self.fileExtension.count))
            guard let id = UUID(uuidString: idText) else {
                skipped.append("\(name): \(ExperimentPreset.PresetRefusal.damaged.rawValue)")
                continue
            }
            let data: Data
            do {
                data = try storage.read(name)
            } catch {
                skipped.append("\(name): \(ExperimentPreset.PresetRefusal.damaged.rawValue)")
                continue
            }
            switch ExperimentPreset.decode(data) {
            case .success(let preset): found.append(SimulationPresetEntry(id: id, preset: preset))
            case .failure(let refusal): skipped.append("\(name): \(refusal.rawValue)")
            }
        }
        entries = found.sorted {
            let order = $0.preset.name.localizedStandardCompare($1.preset.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
        problems = skipped
    }

    /// Saves `preset` as `preset-<id>.json` and reloads. Returns nil on success, the preset's `problem()` sentence
    /// for an invalid preset, `fullSentence` when a new file would exceed `cap`, and `saveFailedSentence` when the
    /// storage refuses. A refused save changes nothing.
    @discardableResult
    func save(_ preset: ExperimentPreset, id: UUID = UUID()) -> String? {
        if let problem = preset.problem() { return problem }
        let name = Self.fileName(for: id)
        let files = presetFileNames
        guard files.contains(name) || files.count < Self.cap else { return Self.fullSentence }
        do {
            try storage.write(preset.encoded(), to: name)
        } catch {
            reload()
            return Self.saveFailedSentence
        }
        reload()
        return nil
    }

    /// Removes the preset `id` (nothing happens when there is no such file) and reloads.
    func delete(_ id: UUID) {
        try? storage.remove(Self.fileName(for: id))
        reload()
    }
}
