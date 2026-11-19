// ExportTests — feature 176 (A24-P04) T-A24-407 (FR-A24-404; SC-A24-403, SC-A24-404; clarifications Q4, Q5; User Story
// 3). The export of an opened saved result, each test over its own temporary storage (`BenchStoragePlace`) and export
// folder (`ResultTest.exporter`), synthetic runs only:
//   - no export file exists before the person's action (opening a result writes nothing);
//   - the action writes "Benchmark <case title> <order>.json" equal to `RunDocument.encode` of the run and
//     "….csv" equal to the UTF-8 of `RunCSV.text(of:)`, and only then offers the share item;
//   - the share item's content type matches its format (`.json`, `.commaSeparatedText`), and it offers only that one;
//   - closing the session (`teardown`) empties the export folder and drops the share item.
// Short runs: no clock, no sleep.
import CoreGraphics
import Foundation
import Testing
import UniformTypeIdentifiers
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

@MainActor
@Suite(.serialized) struct ExportTests {
    /// The regular files of `exporter`'s folder, by name, sorted.
    private func files(_ exporter: ResultExporter) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: exporter.folder.url.path)) ?? []
        return names.sorted()
    }

    @Test func theActionAloneWritesTheJSONAndCSVFiles() throws {
        let place = try BenchStoragePlace("export")
        defer { place.remove() }
        let exporter = ResultTest.exporter("export")
        defer { exporter.clear() }
        let run = try ResultTest.run(.particles, gpu: true)
        let library = ResultLibrary(storage: place.storage)
        #expect(ResultTest.value(library.save(try ResultTest.run(offset: 1))) == 1)
        #expect(ResultTest.value(library.save(run)) == 2)
        let presenter = BenchPresenter(storage: place.storage, exporter: exporter)
        #expect(exporter.folder.fileCount == 0, "no export file before the action")
        let refused = ResultTest.failure(presenter.exportResult(.json))
        #expect(refused == .missing && exporter.folder.fileCount == 0, "nothing to export without an opened result")
        presenter.showResults()
        let opened = try #require(ResultTest.value(presenter.openResult(file: "result-2.json")))
        #expect(exporter.folder.fileCount == 0 && presenter.mirror.exportItem == nil, "opening writes nothing")

        let json = try #require(ResultTest.value(presenter.exportResult(.json)))
        #expect(json.url.lastPathComponent == "Benchmark Particles 2.json" && json.format == .json)
        let jsonBytes = try Data(contentsOf: json.url)
        #expect(jsonBytes == (try RunDocument.encode(run)), "the run file itself")
        #expect(presenter.mirror.exportItem == json && ResultExporter.existing(presenter.mirror.exportItem) == json)
        #expect(presenter.mirror.resultMessage == "Exported Benchmark Particles 2.json.")
        #expect(opened.entry.order == 2)

        let csv = try #require(ResultTest.value(presenter.exportResult(.csv)))
        #expect(csv.url.lastPathComponent == "Benchmark Particles 2.csv" && csv.format == .csv)
        let csvBytes = try Data(contentsOf: csv.url)
        #expect(csvBytes == Data(RunCSV.text(of: run).utf8))
        #expect(presenter.mirror.exportItem == csv)
        #expect(files(exporter) == ["Benchmark Particles 2.csv", "Benchmark Particles 2.json"])
        // Exporting again replaces the file of the same name.
        _ = ResultTest.value(presenter.exportResult(.csv))
        #expect(exporter.folder.fileCount == 2)
        // Opening another result drops the share item; its files stay until the session closes.
        _ = ResultTest.value(presenter.openResult(file: "result-1.json"))
        #expect(presenter.mirror.exportItem == nil && exporter.folder.fileCount == 2)
    }

    @Test func theShareItemCarriesTheContentTypeOfItsFormat() {
        let url = URL(fileURLWithPath: "/nonexistent/none")
        let expected: [ResultExportFormat: UTType] = [.json: .json, .csv: .commaSeparatedText]
        for format in ResultExportFormat.allCases {
            let type = expected[format] ?? .data
            let file = ResultExportFile(url: url, format: format)
            #expect(file.contentType == type, "\(format)")
            let exported = file.exportedContentTypes()
            #expect(exported.contains(type), "\(format): \(exported)")
            for other in ResultExportFormat.allCases where other != format {
                let otherType = expected[other] ?? .data
                #expect(!exported.contains(otherType), "\(format) does not offer \(other)")
            }
        }
        #expect(ResultExportFile.fileName(caseTitle: "Textured quads", order: 3, format: .json)
            == "Benchmark Textured quads 3.json")
        #expect(ResultExportFile.fileName(caseTitle: "A/B:C", order: 1, format: .csv) == "Benchmark A-B-C 1.csv")
        #expect(ResultExporter.existing(ResultExportFile(url: url, format: .json)) == nil, "no item without a file")
    }

    @Test func closingTheSessionEmptiesTheExportFolder() async throws {
        let place = try BenchStoragePlace("export-close")
        defer { place.remove() }
        let exporter = ResultTest.exporter("export-close")
        defer { exporter.clear() }
        let library = ResultLibrary(storage: place.storage)
        #expect(ResultTest.value(library.save(try ResultTest.run())) == 1)
        let session = ExperienceSession()
        if session.qualityPin == nil { session.qualityPin = 0 }
        let id = BenchTest.id
        let storage = place.storage
        var made: ExperienceShell<BenchPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = GraphicsBenchmarkLabExperience.make(id: id, storage: storage, exporter: exporter)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let shell = try #require(made)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: CGSize(width: 64, height: 48))
        view.layoutIfNeeded()
        try BenchTest.draw(session, shell, at: 0)
        let presenter = shell.presenter
        presenter.showResults()
        _ = ResultTest.value(presenter.openResult(file: "result-1.json"))
        _ = ResultTest.value(presenter.exportResult(.json))
        _ = ResultTest.value(presenter.exportResult(.csv))
        #expect(exporter.folder.fileCount == 2)
        session.close()
        #expect(exporter.folder.fileCount == 0, "the folder is emptied when the session closes")
        #expect(presenter.mirror.exportItem == nil)
    }
}
