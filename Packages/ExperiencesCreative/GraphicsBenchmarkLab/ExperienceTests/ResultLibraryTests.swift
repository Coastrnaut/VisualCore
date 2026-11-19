// ResultLibraryTests — feature 176 (A24-P04) T-A24-405 (FR-A24-401, FR-A24-402, FR-A24-403, FR-A24-405; SC-A24-401,
// SC-A24-402; clarifications Q2, Q3; User Stories 1, 2; Edge Cases "Storage full", "A result saved by a newer app
// version", "Saving with no ended run", "Opening a result of a case version the app no longer has"). The saved results
// over a temporary storage (`BenchStoragePlace`, removed after), with synthetic runs only (`ResultTest`):
//   - a saved run opens in a new library (and a new presenter) over the same storage equal to the original: case
//     settings, version, samples, summary and report; the file names every setting and plan length;
//   - the 13th save is refused with "The library holds 12 results." (an unreadable file counts) and nothing changes;
//   - damaged, truncated, newer (the file's envelope and the embedded run's), oversized and non-finite files are
//     listed with their reasons, refused on open and stay byte-identical; only an explicit removal removes one;
//   - a full byte quota (a filler file) refuses with "There is not enough space to save this result." and writes
//     nothing;
//   - a removal deletes only the chosen file, and the counter is never reused;
//   - a second save of the same ended run is refused with "This result is already saved.";
//   - a result of `quads` version 9 with its own settings (a case version the app does not build in) opens and shows
//     its stored settings;
//   - a newer index makes the library read only (never overwritten); a damaged index is rebuilt only by a change.
// Short runs: no clock, no sleep, no host.
import Foundation
import Testing
import VisualCoreExperience
import VisualCorePersistence
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

/// A temporary experience storage for one test, removed afterwards.
struct BenchStoragePlace {
    /// The defaults suite and folder name.
    let suite: String
    /// The root folder.
    let root: URL
    /// The handle.
    let storage: ExperienceStorage

    /// A fresh place named `name`.
    @MainActor
    init(_ name: String) throws {
        suite = "a24.result-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: BenchTest.id, root: root, defaults: defaults)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    /// Every file of the storage with its bytes.
    func contents() throws -> [String: Data] {
        var files: [String: Data] = [:]
        for name in storage.list() { files[name] = try storage.read(name) }
        return files
    }
}

/// Synthetic runs and helpers of the result tests.
@MainActor
enum ResultTest {
    /// A synthetic sample set: 3 warm-up, `measured` measurement and 2 cool-down frames; the first has no interval,
    /// the others 16.5 ms plus a quarter step; CPU 1.5 ms; GPU 4.25 ms on measured frames when `gpu`.
    static func samples(measured: Int = 24, gpu: Bool = false, offset: Int = 0) -> [FrameSample] {
        var samples: [FrameSample] = []
        var index = 0
        let phases: [(RunPhase, Int)] = [(.warmUp, 3), (.measure, measured), (.coolDown, 2)]
        for (phase, count) in phases {
            for _ in 0..<count {
                let interval: Double? = index == 0 ? nil : 16.5 + Double((index + offset) % 5) * 0.25
                let gpuMs: Double? = gpu && phase == .measure ? 4.25 : nil
                samples.append(FrameSample(frameIndex: index, phase: phase, intervalMs: interval, cpuMs: 1.5,
                                           gpuMs: gpuMs, dropped: false))
                index += 1
            }
        }
        return samples
    }

    /// A synthetic report of `benchmarkCase` (fingerprint `fingerprint`), thermal state nominal to fair.
    static func report(_ benchmarkCase: BenchmarkCase, fingerprint: String, gpu: Bool) -> RunReport {
        RunReport(deviceModel: "iPhone17,1", osVersion: "27.2.0", appVersion: "1.0", appBuild: "7",
                  renderer: "Synthetic GPU", glVersion: "OpenGL ES 3.0 Synthetic", qualityTier: "level-0",
                  thermalStart: "nominal", thermalEnd: "fair", lowPowerStart: false, lowPowerEnd: true,
                  timingSources: .standard(gpuMeasured: gpu), caseID: benchmarkCase.id,
                  caseVersion: benchmarkCase.version, caseFingerprint: fingerprint)
    }

    /// A synthetic run of `benchmarkCase` ending as `state`, with a report.
    static func run(_ benchmarkCase: BenchmarkCase = .quads, state: RunState = .completed, measured: Int = 24,
                    gpu: Bool = false, offset: Int = 0) throws -> BenchmarkRun {
        let samples = samples(measured: measured, gpu: gpu, offset: offset)
        let summary = try Summary.make(samples)
        let fingerprint = try benchmarkCase.fingerprint().hex
        return BenchmarkRun(benchmarkCase: benchmarkCase, caseFingerprint: fingerprint, samples: samples,
                            summary: summary, state: state,
                            report: report(benchmarkCase, fingerprint: fingerprint, gpu: gpu))
    }

    /// The value of `result`, recording an issue for a failure.
    static func value<T>(_ result: Result<T, ResultLibraryFailure>,
                         sourceLocation: SourceLocation = #_sourceLocation) -> T? {
        switch result {
        case .success(let value): return value
        case .failure(let failure):
            Issue.record("refused: \(failure.code)", sourceLocation: sourceLocation)
            return nil
        }
    }

    /// The failure of `result`; nil for a success.
    static func failure<T>(_ result: Result<T, ResultLibraryFailure>) -> ResultLibraryFailure? {
        if case .failure(let failure) = result { return failure }
        return nil
    }

    /// The text of the saved result file of `run` with `order`.
    static func text(order: Int = 1, run: BenchmarkRun) throws -> String {
        try #require(String(data: try ResultLibrary.encode(order: order, run: run), encoding: .utf8))
    }

    /// An exporter over a fresh private folder named `name` (emptied first).
    static func exporter(_ name: String) -> ResultExporter {
        let exporter = ResultExporter(folder: TemporaryFolder(name: "GraphicsBenchmarkLab-Test-" + name))
        exporter.clear()
        return exporter
    }

    /// The refusal codes of `entries`, "readable" for a readable one.
    static func codes(_ entries: [ResultLibraryEntry]) -> [String] {
        var codes: [String] = []
        for entry in entries { codes.append(entry.refusal ?? "readable") }
        return codes
    }
}

@MainActor
@Suite(.serialized) struct ResultLibraryTests {
    @Test func aSavedRunOpensInANewLibraryEqualToTheOriginal() throws {
        let place = try BenchStoragePlace("round-trip")
        defer { place.remove() }
        let library = ResultLibrary(storage: place.storage)
        let empty = library.entries.isEmpty && library.next == 1 && !library.isReadOnly
        #expect(empty)
        let run = try ResultTest.run(.alu, gpu: true)
        let n = try #require(ResultTest.value(library.save(run)))
        #expect(n == 1)
        let entry = try #require(library.entry(file: "result-1.json"))
        let info = try #require(entry.info)
        #expect(entry.order == 1 && entry.number == 1)
        #expect(info.caseTitle == "Shader ALU" && info.state == .completed && info.gpuTimed)
        #expect(info.intervalP50 == run.summary.interval.p50 && info.intervalP95 == run.summary.interval.p95)
        #expect(place.storage.exists(ResultLibrary.indexFile))
        let label = ResultsView.rowLabel(entry)
        let expectedLabel = "Shader ALU, Finished, p50 "
            + BenchPresenter.milliseconds(text: run.summary.interval.p50) + ", p95 "
            + BenchPresenter.milliseconds(text: run.summary.interval.p95) + ", GPU timed"
        #expect(label == expectedLabel)
        #expect(ResultsView.identifierNames(entry) == ["result-row-1", "result-open-1", "result-remove-1"])

        // The file names every setting and plan length, not only the identifier.
        let text = try #require(String(data: try place.storage.read("result-1.json"), encoding: .utf8))
        let names = ["\"kind\":\"a24.saved-result\"", "\"kind\":\"a24.benchmark-run\"", "\"iterations\":64",
                     "\"resolutionScale\":1", "\"warmUpSeconds\":3", "\"measureSeconds\":10",
                     "\"coolDownSeconds\":5", "\"workload\":\"alu\"", "\"order\":1"]
        for name in names { #expect(text.contains(name), "\(name)") }

        // A new library over the same storage reads the same list, counter and run.
        let again = ResultLibrary(storage: place.storage)
        #expect(again.entries == library.entries && again.next == 2)
        let opened = try #require(ResultTest.value(again.open(file: "result-1.json")))
        let same = opened.run == run
        #expect(same, "case settings, version, samples, summary and report")
        #expect(opened.run.benchmarkCase == .alu && opened.run.report == run.report)
        #expect(try RunDocument.encode(opened.run) == RunDocument.encode(run))
        #expect(ResultTest.failure(again.open(file: "result-9.json")) == .missing)
    }

    @Test func thePresenterSavesTheEndedRunOnceAndANewPresenterOpensIt() async throws {
        let place = try BenchStoragePlace("presenter")
        defer { place.remove() }
        let exporter = ResultTest.exporter("presenter")
        defer { exporter.clear() }
        let shell = GraphicsBenchmarkLabExperience.make(id: BenchTest.id, storage: place.storage, exporter: exporter)
        try await shell.prepare(seed: 1)
        try shell.activate()
        let presenter = shell.presenter
        let core = try BenchTest.core(shell)
        #expect(ResultTest.failure(presenter.saveResult()) == .noRun)
        #expect(presenter.mirror.resultMessage == "There is no ended run to save.")
        presenter.recorder.start(case: .quads, at: 0)
        presenter.recorder.record(frameTime: 0, cpuMs: 1.5)
        presenter.follow(core)
        #expect(!presenter.mirror.canSave, "no save control while a run is running")
        for time in BenchTest.times(from: 0.25, step: 0.25, count: 72) {
            presenter.recorder.record(frameTime: time, cpuMs: 1.5)
        }
        presenter.follow(core)
        #expect(presenter.mirror.canSave, "the save control after the run ends")
        let ended = try #require(presenter.recorder.runRecord())
        #expect(ResultTest.value(presenter.saveResult()) == 1)
        #expect(presenter.mirror.resultMessage == "Saved result 1.")
        let repeated = ResultTest.failure(presenter.saveResult())
        #expect(repeated == .alreadySaved && repeated?.message == "This result is already saved.")
        #expect(presenter.mirror.resultMessage == "This result is already saved.")
        #expect(place.storage.list().sorted() == ["result-1.json", "results.json"], "saved once")

        let other = BenchPresenter(storage: place.storage, exporter: exporter)
        other.showResults()
        #expect(other.mirror.showingResults && other.mirror.resultEntries.map(\.file) == ["result-1.json"])
        let opened = try #require(ResultTest.value(other.openResult(file: "result-1.json")))
        let same = opened.run == ended
        #expect(same)
        #expect(other.mirror.openedResult == opened && other.mirror.resultMessage == "Opened result 1.")
        let summary = ResultsView.summaryLines(opened.run)
        #expect(summary.first == "Textured quads, Finished")
        let report = ResultsView.reportLines(opened.run.report)
        #expect(report == ["No report was recorded with this run."], "the recorder alone attaches no report")
        other.hideResults()
        #expect(!other.mirror.showingResults && other.mirror.openedResult == nil)
        let without = BenchPresenter(exporter: exporter)
        #expect(ResultTest.failure(without.saveResult()) == .unavailable)
    }

    @Test func theThirteenthSaveIsRefusedAndNothingChanges() throws {
        let place = try BenchStoragePlace("cap")
        defer { place.remove() }
        let storage = place.storage
        // An unreadable file counts towards the 12.
        try storage.write(Data("{\"kind\":\"a24.saved-result\"".utf8), to: "result-1.json")
        let library = ResultLibrary(storage: storage)
        for k in 1..<ResultLibrary.maxResults {
            _ = ResultTest.value(library.save(try ResultTest.run(offset: k)))
        }
        let count = library.entries.count
        #expect(count == 12)
        let before = try place.contents()
        let full = ResultTest.failure(library.save(try ResultTest.run(offset: 99)))
        #expect(full == .full && full?.message == "The library holds 12 results.")
        #expect(try place.contents() == before, "nothing is removed or written")
        // The newest is first; the unreadable file (no remembered order) is last.
        #expect(library.entries.first?.file == "result-12.json" && library.entries.last?.file == "result-1.json")
    }

    @Test func unreadableFilesAreListedWithTheirReasonAndKept() throws {
        let place = try BenchStoragePlace("unreadable")
        defer { place.remove() }
        let storage = place.storage
        let good = try ResultTest.text(run: try ResultTest.run())
        let truncated = String(good.prefix(good.count / 2))
        try storage.write(Data(truncated.utf8), to: "result-1.json")
        let newer = good.replacingOccurrences(of: "\"kind\":\"a24.saved-result\",\"version\":1",
                                              with: "\"kind\":\"a24.saved-result\",\"version\":2")
        #expect(newer != good)
        try storage.write(Data(newer.utf8), to: "result-2.json")
        let padded = Data(good.utf8) + Data(repeating: 0x20, count: ResultLibrary.maxFileBytes + 1 - good.utf8.count)
        try storage.write(padded, to: "result-3.json")
        let newerRun = good.replacingOccurrences(of: "\"kind\":\"a24.benchmark-run\",\"version\":3",
                                                 with: "\"kind\":\"a24.benchmark-run\",\"version\":4")
        #expect(newerRun != good)
        try storage.write(Data(newerRun.utf8), to: "result-4.json")
        let notFinite = good.replacingOccurrences(of: "\"cpuMs\":1.5", with: "\"cpuMs\":\"NaN\"")
        #expect(notFinite != good)
        try storage.write(Data(notFinite.utf8), to: "result-5.json")
        try storage.write(Data("{\"body\":{},\"kind\":\"a24.other\",\"version\":1}".utf8), to: "result-6.json")
        // At the size bound exactly, a padded file still reads.
        let atBound = Data(good.utf8) + Data(repeating: 0x20, count: ResultLibrary.maxFileBytes - good.utf8.count)
        try storage.write(atBound, to: "result-7.json")
        let before = try place.contents()

        let library = ResultLibrary(storage: storage)
        let codes = ResultTest.codes(library.entries)
        #expect(codes == ["readable", "damaged", "not-finite", "newer-version", "too-large", "newer-version",
                          "damaged"])
        for entry in library.entries where !entry.isReadable {
            let code = entry.refusal ?? ""
            let opened = ResultTest.failure(library.open(file: entry.file))
            #expect(opened == .unreadable(code), "\(entry.file)")
            #expect(opened?.message == "This saved result cannot be opened (\(code)).")
            #expect(ResultsView.rowLabel(entry) == entry.file + ", unreadable: " + code)
            #expect(ResultsView.identifierNames(entry).count == 2)
        }
        #expect(try place.contents() == before, "nothing is rewritten or removed by reading")
        #expect(ResultLibrary(storage: storage).entries == library.entries)

        // A good result still saves after the highest file; the unreadable files stay; one is removed on request.
        #expect(ResultTest.value(library.save(try ResultTest.run(offset: 3))) == 8)
        for (name, data) in before { #expect(try storage.read(name) == data, "\(name) kept") }
        #expect(ResultTest.failure(library.remove(file: "result-1.json")) == nil)
        let left = library.entries.count
        #expect(!storage.exists("result-1.json") && left == 7)
    }

    @Test func aFullStorageRefusesWithTheMessageAndWritesNothing() throws {
        let place = try BenchStoragePlace("quota")
        defer { place.remove() }
        let storage = place.storage
        let library = ResultLibrary(storage: storage)
        _ = ResultTest.value(library.save(try ResultTest.run()))
        var used = 0
        for data in try place.contents().values { used += data.count }
        try storage.write(Data(count: StorageQuota.maxBytes - used - 8), to: "filler.bin")
        let before = try place.contents()
        let refused = ResultTest.failure(library.save(try ResultTest.run(offset: 1)))
        #expect(refused == .noSpace && refused?.message == "There is not enough space to save this result.")
        #expect(!storage.exists("result-2.json"))
        #expect(try place.contents() == before, "nothing is half-written")
        #expect(library.entries.count == 1)
    }

    @Test func aRemovalDeletesOnlyTheChosenFile() throws {
        let place = try BenchStoragePlace("remove")
        defer { place.remove() }
        let storage = place.storage
        let library = ResultLibrary(storage: storage)
        for k in 0..<3 { _ = ResultTest.value(library.save(try ResultTest.run(offset: k))) }
        let first = try storage.read("result-1.json")
        let third = try storage.read("result-3.json")
        let removed = try #require(ResultTest.value(library.remove(file: "result-2.json")))
        #expect(removed.file == "result-2.json")
        #expect(!storage.exists("result-2.json"))
        #expect(try storage.read("result-1.json") == first && storage.read("result-3.json") == third)
        #expect(library.entries.map(\.file) == ["result-3.json", "result-1.json"])
        #expect(ResultTest.failure(library.remove(file: "result-2.json")) == .missing)
        // The counter is not reused after a removal, also in a new library.
        let again = ResultLibrary(storage: storage)
        #expect(ResultTest.value(again.save(try ResultTest.run(offset: 7))) == 4)
    }

    @Test func aResultOfACaseVersionTheAppDoesNotBuildInOpensWithItsSettings() throws {
        let place = try BenchStoragePlace("case-version")
        defer { place.remove() }
        let custom = BenchmarkCase(id: "quads", version: 9, workload: .quads,
                                   config: WorkloadConfig(layers: 3, textureSize: 128, resolutionScale: 0.5),
                                   plan: RunPlan(warmUpSeconds: 2, measureSeconds: 5, coolDownSeconds: 1))
        let samples = ResultTest.samples()
        let run = try BenchmarkRun(benchmarkCase: custom, samples: samples, summary: try Summary.make(samples),
                                   state: .stopped)
        let library = ResultLibrary(storage: place.storage)
        #expect(ResultTest.value(library.save(run)) == 1)
        let exporter = ResultTest.exporter("case-version")
        defer { exporter.clear() }
        let presenter = BenchPresenter(storage: place.storage, exporter: exporter)
        presenter.showResults()
        let entry = try #require(presenter.mirror.resultEntries.first)
        #expect(entry.info?.caseTitle == "Textured quads" && entry.info?.state == .stopped)
        let opened = try #require(ResultTest.value(presenter.openResult(file: entry.file)))
        #expect(opened.run.benchmarkCase == custom && opened.run.caseVersion == 9)
        let lines = ResultsView.settingsLines(opened.run.benchmarkCase)
        #expect(lines == ["Case quads version 9", "Workload quads",
                          "Settings: layers 3, texture size 128, resolution scale 0.5",
                          "Plan: warm-up 2 s, measurement 5 s, cool-down 1 s"])
        #expect(ResultsView.summaryLines(opened.run).first == "Textured quads, Stopped")
        #expect(ResultsView.reportLines(opened.run.report) == ["No report was recorded with this run."])
    }

    @Test func aNewerIndexIsReadOnlyAndADamagedIndexIsRebuiltOnlyByAChange() throws {
        let place = try BenchStoragePlace("index")
        defer { place.remove() }
        let storage = place.storage
        let library = ResultLibrary(storage: storage)
        _ = ResultTest.value(library.save(try ResultTest.run()))
        let newerIndex = Data("{\"body\":{\"entries\":[],\"next\":5},\"kind\":\"a24.result-library\",\"version\":2}".utf8)
        try storage.write(newerIndex, to: ResultLibrary.indexFile)
        let readOnly = ResultLibrary(storage: storage)
        #expect(readOnly.isReadOnly && readOnly.indexProblem == "newer-version")
        #expect(ResultTest.failure(readOnly.save(try ResultTest.run(offset: 1))) == .readOnly)
        #expect(ResultTest.failure(readOnly.remove(file: "result-1.json")) == .readOnly)
        #expect(ResultTest.value(readOnly.open(file: "result-1.json")) != nil, "opening still works")
        #expect(try storage.read(ResultLibrary.indexFile) == newerIndex, "a newer index is never overwritten")

        let damaged = Data("{\"kind\":\"a24.result-library\"".utf8)
        try storage.write(damaged, to: ResultLibrary.indexFile)
        let reading = ResultLibrary(storage: storage)
        #expect(!reading.isReadOnly && reading.indexProblem == "damaged" && reading.entries.count == 1)
        _ = reading.list()
        #expect(try storage.read(ResultLibrary.indexFile) == damaged, "reading never rebuilds the index")
        #expect(ResultTest.value(reading.save(try ResultTest.run(offset: 2))) == 2)
        let rebuilt = try storage.read(ResultLibrary.indexFile)
        let index = ResultLibrary.decodeIndex(rebuilt)
        #expect((try? index.get())?.next == 3 && (try? index.get())?.entries.count == 2, "rebuilt by the change")
    }
}
