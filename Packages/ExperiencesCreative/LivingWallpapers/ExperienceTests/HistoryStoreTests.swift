// HistoryStoreTests — feature 141 (A19-P04) T-A19-407 (FR-A19-404; SC-A19-403; clarification Q3; contracts/save.md
// "History"). The stored export history over a temporary `ExperienceStorage` (its own folder and defaults suite,
// removed at the end) with a `FixedClock`, short runs only (a flat renderer, no host; no sleep, no wall clock):
//   - a written export records one entry with the fixed clock's time, and the file `history.json` holds it;
//   - newest first, and the bound of 20 holds;
//   - clear empties the history and removes the file;
//   - a damaged and a newer file are reported once each, with an empty history;
//   - a round trip across two store instances on the same storage;
//   - the controls' lines and labels of the newest five entries and "Clear history".
import Foundation
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// A temporary storage of Living Wallpapers: its own folder and defaults suite.
@MainActor
struct TemporaryWallpaperStorage {
    /// The folder that holds the namespace folder.
    let root: URL
    /// The defaults suite name.
    let suite: String
    /// The storage handle.
    let storage: ExperienceStorage

    /// A new empty storage named `name`.
    init(_ name: String) throws {
        suite = "a19.history-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: WallpaperTest.id, root: root, defaults: defaults)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

@MainActor
@Suite(.serialized) struct HistoryStoreTests {
    /// The fixed instant of the tests: 2026-11-17 12:00:00 UTC.
    static let instant = Date(timeIntervalSince1970: 1_794_916_800)

    /// An entry of `scene` made at `madeAt`.
    static func entry(_ scene: String = "ink-flow", madeAt: Double) -> ExportHistory.Entry {
        ExportHistory.Entry(scene: scene, template: "iphone-16-pro", orientation: .portrait, format: .png,
                            width: 1206, height: 2622, madeAt: madeAt)
    }

    @Test func aWrittenExportRecordsAnEntryAtTheFixedTime() async throws {
        let temporary = try TemporaryWallpaperStorage("written")
        defer { temporary.remove() }
        let store = HistoryStore(storage: temporary.storage, clock: FixedClock(Self.instant))
        #expect(store.history.entries.isEmpty && store.problem == nil)
        let job = SaveTest.job("history-written", history: store)
        defer { job.export.folder.removeAll() }

        await job.start(project: SaveTest.smallProject(.jpeg), maxEdge: 4096, render: SaveTest.flatRender)
        #expect(job.output != nil, "\(job.state)")
        let expected = ExportHistory.Entry(scene: "aurora-bands", template: "iphone-se-3", orientation: .portrait,
                                           format: .jpeg, width: 750, height: 1334,
                                           madeAt: Self.instant.timeIntervalSince1970)
        #expect(store.history.entries == [expected])
        #expect(temporary.storage.exists(HistoryStore.fileName))
        let stored = try temporary.storage.read(HistoryStore.fileName)
        #expect(ExportHistory.decode(stored) == .success(store.history))

        await job.start(project: SaveTest.smallProject(), maxEdge: 4096, render: SaveTest.flatRender,
                        cancelAfter: .write)
        #expect(store.history.entries.count == 1, "a cancelled export records nothing")
        await job.start(project: SaveTest.smallProject(), maxEdge: 512, render: SaveTest.flatRender)
        #expect(store.history.entries.count == 1, "a refused export records nothing")
    }

    @Test func entriesAreNewestFirstAndBounded() throws {
        let temporary = try TemporaryWallpaperStorage("bound")
        defer { temporary.remove() }
        let clock = FixedClock(Self.instant)
        let store = HistoryStore(storage: temporary.storage, clock: clock)
        let plan = ExportPlan(format: .png, width: 750, height: 1334, fallback: false)
        let project = SaveTest.smallProject()
        for _ in 0..<(ExportHistory.bound + 5) {
            store.record(plan: plan, project: project)
            clock.advance(by: 60)
        }
        let times = store.history.entries.map(\.madeAt)
        #expect(times.count == ExportHistory.bound)
        #expect(times == times.sorted(by: >), "newest first")
        let newest = Self.instant.timeIntervalSince1970 + Double(ExportHistory.bound + 4) * 60
        #expect(times.first == newest)
        #expect(store.shown.count == HistoryStore.shownCount)
        #expect(store.shown == Array(store.history.entries.prefix(HistoryStore.shownCount)))
    }

    @Test func clearEmptiesTheHistoryAndRemovesTheFile() throws {
        let temporary = try TemporaryWallpaperStorage("clear")
        defer { temporary.remove() }
        let store = HistoryStore(storage: temporary.storage, clock: FixedClock(Self.instant))
        store.record(plan: ExportPlan(format: .png, width: 750, height: 1334, fallback: false),
                     project: SaveTest.smallProject())
        #expect(temporary.storage.exists(HistoryStore.fileName))
        store.clear()
        #expect(store.history.entries.isEmpty && store.shown.isEmpty)
        #expect(!temporary.storage.exists(HistoryStore.fileName))
        #expect(store.storageError == nil)
        store.clear()
        #expect(store.storageError == nil, "clearing an empty history is fine")
        let reopened = HistoryStore(storage: temporary.storage, clock: FixedClock(Self.instant))
        #expect(reopened.history.entries.isEmpty && reopened.problem == nil)
    }

    @Test func damagedAndNewerFilesAreReportedWithAnEmptyHistory() throws {
        let temporary = try TemporaryWallpaperStorage("refused")
        defer { temporary.remove() }
        let newer = Data(#"{"entries":[],"kind":"a19.export-history","schemaVersion":2}"#.utf8)
        let cases: [(Data, HistoryRefusal)] = [(Data("not json".utf8), .damaged), (newer, .newerVersion(2))]
        for (data, refusal) in cases {
            try temporary.storage.write(data, to: HistoryStore.fileName)
            let store = HistoryStore(storage: temporary.storage, clock: FixedClock(Self.instant))
            #expect(store.problem == refusal, "\(refusal.code)")
            #expect(store.history.entries.isEmpty, "\(refusal.code)")
            #expect(!(store.problem?.sentence.isEmpty ?? true), "\(refusal.code)")
        }
    }

    @Test func aRoundTripAcrossTwoStoresOnTheSameStorage() throws {
        let temporary = try TemporaryWallpaperStorage("round-trip")
        defer { temporary.remove() }
        let clock = FixedClock(Self.instant)
        let first = HistoryStore(storage: temporary.storage, clock: clock)
        var project = SaveTest.smallProject(.heic)
        project.scene = "ink-flow"
        project.orientation = .landscape
        first.record(plan: ExportPlan(format: .heic, width: 1334, height: 750, fallback: false), project: project)
        clock.advance(by: 90)
        first.record(plan: ExportPlan(format: .png, width: 600, height: 338, fallback: true), project: project)
        let second = HistoryStore(storage: temporary.storage, clock: clock)
        #expect(second.problem == nil)
        #expect(second.history == first.history, "exact round trip")
        #expect(second.history.entries.count == 2)
        #expect(second.history.entries.first?.madeAt == Self.instant.timeIntervalSince1970 + 90)
    }

    @Test func theControlsListTheNewestEntriesWithLabels() {
        let line = EditorModel.historyLine(Self.entry(madeAt: 0))
        #expect(line == "Ink Flow, iPhone 16 Pro, portrait, PNG 1206 × 2622")
        var entries: [ExportHistory.Entry] = []
        for index in 0..<HistoryStore.shownCount {
            entries.append(Self.entry(madeAt: Double(index)))
        }
        let labels = EditorModel.saveLabels(progress: 0.4, canRetry: true, shareName: "a.png", history: entries)
        let byName = Dictionary(uniqueKeysWithValues: labels.map { ($0.name, $0.text) })
        #expect(byName["export-progress"] == "Export progress, 40 percent")
        #expect(byName["export-cancel"] != nil && byName["export-retry"] != nil)
        #expect(byName["share"] == "Share, a.png")
        #expect(byName["history-0"] == "Recent export 1, " + line)
        #expect(byName["history-4"] != nil && byName["history-5"] == nil)
        #expect(byName["clear-history"] == "Clear history, 5 entries shown")
        for label in labels {
            #expect(!label.title.isEmpty && !label.value.isEmpty, "\(label.name)")
        }
        #expect(EditorModel.saveLabels(progress: nil, canRetry: false, shareName: nil, history: []).isEmpty)
    }
}
