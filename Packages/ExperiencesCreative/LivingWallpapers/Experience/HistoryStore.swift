// HistoryStore — feature 141 (A19-P04) T-A19-407 (FR-A19-404; SC-A19-403; clarification Q3; data-model.md
// "HistoryStore"; contracts/save.md "History"). The stored history of written exports: `history.json` in the
// experience's own storage (`ExperienceStorage`), read once when the experience opens and written atomically
// (`storage.write`) after each written export, with the time of the injected `ClockSource` (`SystemClock` in the
// app, `FixedClock` in tests). A refused file (damaged, newer version, too large) gives an empty history and one
// problem; a missing file gives an empty history and no problem. `clear()` empties the history and removes the file.
// The controls list the newest `shownCount` entries and offer "Clear history".
import Foundation
import LivingWallpapersCore
import Observation
import VisualCoreExperience

/// The stored history of written exports (see the file header).
@MainActor
@Observable
final class HistoryStore {
    /// The file the history is stored in.
    static let fileName = "history.json"
    /// The most entries the controls list.
    static let shownCount = 5

    /// The experience's storage.
    let storage: ExperienceStorage
    /// The source of each entry's time.
    let clock: any ClockSource
    /// The history, newest first.
    private(set) var history: ExportHistory
    /// Why the stored file was refused when it was read; nil when it was read or there was none.
    private(set) var problem: HistoryRefusal?
    /// Why the last write or removal failed; nil after a successful one.
    private(set) var storageError: StorageError?

    /// A store over `storage` with `clock`; reads `history.json` once.
    init(storage: ExperienceStorage, clock: any ClockSource) {
        self.storage = storage
        self.clock = clock
        let read = Self.read(storage)
        history = read.history
        problem = read.problem
    }

    /// The history stored in `storage` and the refusal of its file: empty with no problem when there is no file,
    /// empty with the refusal when the file is refused.
    static func read(_ storage: ExperienceStorage) -> (history: ExportHistory, problem: HistoryRefusal?) {
        let data: Data
        do {
            data = try storage.read(fileName)
        } catch {
            return (ExportHistory(), nil)
        }
        switch ExportHistory.decode(data) {
        case .success(let history): return (history, nil)
        case .failure(let refusal): return (ExportHistory(), refusal)
        }
    }

    /// The newest entries the controls list, at most ``shownCount``.
    var shown: [ExportHistory.Entry] { Array(history.entries.prefix(Self.shownCount)) }

    /// Records the written export of `plan` made from `project` at the clock's time as the newest entry and writes
    /// the history; returns the entry.
    @discardableResult
    func record(plan: ExportPlan, project: WallpaperProject) -> ExportHistory.Entry {
        let entry = ExportHistory.Entry(scene: project.scene, template: project.template,
                                        orientation: project.orientation, format: plan.format, width: plan.width,
                                        height: plan.height, madeAt: clock.now.timeIntervalSince1970)
        history = history.adding(entry)
        save()
        return entry
    }

    /// Empties the history and removes its file.
    func clear() {
        history = history.cleared()
        problem = nil
        guard storage.exists(Self.fileName) else {
            storageError = nil
            return
        }
        do {
            try storage.remove(Self.fileName)
            storageError = nil
        } catch {
            storageError = error
        }
    }

    /// Writes the history atomically through the storage.
    private func save() {
        guard let data = try? history.encoded() else {
            storageError = .writeFailed("the history could not be encoded")
            return
        }
        do {
            try storage.write(data, to: Self.fileName)
            storageError = nil
        } catch {
            storageError = error
        }
    }
}
