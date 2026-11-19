// ResultExportFile — feature 176 (A24-P04) T-A24-406 (FR-A24-404; clarifications Q4, Q5; data-model.md
// "ResultExportFile"; contracts/results.md; gap G-EXPORT). A written export of a saved result handed to the system's
// share sheet, after Living Wallpapers' `WallpaperExportFile` (A19-P04): a `Transferable` file whose
// `FileRepresentation` carries the content type of its format (JSON `.json`, CSV `.commaSeparatedText`; each
// representation is offered only for its own format) and sends the written file itself.
//
// ``ResultExporter`` writes the file, only when the person taps "Export JSON" or "Export CSV" on an opened result:
// JSON is the run file itself (`RunDocument.encode`, version 3, sorted keys), CSV is `RunCSV.text(of:)` as UTF-8. The
// file is named "Benchmark <case title> <order>.json" (or `.csv`), for example "Benchmark Textured quads 3.json", in
// `TemporaryFolder(name: "GraphicsBenchmarkLab-Export")`, so the share sheet shows that name. ``ResultExporter/clear()``
// empties the folder; the presenter calls it when the session closes (`teardown`). The experience never writes an
// export by itself, and nothing leaves the device except through the share sheet the person opens.
import CoreTransferable
import Foundation
import GraphicsBenchmarkLabCore
import UniformTypeIdentifiers
import VisualCorePersistence

/// The format of an export: the run file as JSON, or the CSV of the run.
enum ResultExportFormat: String, CaseIterable, Sendable {
    /// The run file (`RunDocument.encode`).
    case json
    /// The CSV export (`RunCSV.text(of:)`).
    case csv

    /// The file extension: `json` or `csv`.
    var fileExtension: String { rawValue }

    /// The content type: `.json` or `.commaSeparatedText`.
    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        }
    }
}

/// A written export offered to the share sheet with its format's content type (see the file header).
struct ResultExportFile: Transferable, Equatable, Sendable {
    /// The written file.
    let url: URL
    /// The file's format.
    let format: ResultExportFormat

    /// The content type of this file's format.
    var contentType: UTType { format.contentType }

    /// The file name "Benchmark <case title> <order>.<ext>", for example "Benchmark Textured quads 3.json"; a `/` or
    /// `:` in the title becomes `-` so the name stays one path component.
    static func fileName(caseTitle: String, order: Int, format: ResultExportFormat) -> String {
        let name = "Benchmark \(caseTitle) \(order).\(format.fileExtension)"
        return name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    /// The written file, sent as itself with the content type of its format.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .json }
        FileRepresentation(exportedContentType: .commaSeparatedText) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .csv }
    }
}

/// Writes exports of saved results into a temporary folder and empties it (see the file header).
struct ResultExporter: Sendable {
    /// The folder name of the exports.
    static let folderName = "GraphicsBenchmarkLab-Export"

    /// The folder the exports are written to.
    let folder: TemporaryFolder

    /// An exporter over `folder` (by default `TemporaryFolder(name: "GraphicsBenchmarkLab-Export")`).
    init(folder: TemporaryFolder = TemporaryFolder(name: ResultExporter.folderName)) {
        self.folder = folder
    }

    /// The bytes of `run` in `format`: `RunDocument.encode(run)` or the UTF-8 of `RunCSV.text(of: run)`. Throws the
    /// run's `RunRefusal` for JSON.
    static func data(of run: BenchmarkRun, format: ResultExportFormat) throws -> Data {
        switch format {
        case .json: return try RunDocument.encode(run)
        case .csv: return Data(RunCSV.text(of: run).utf8)
        }
    }

    /// Writes `run` in `format` atomically into the folder as "Benchmark <case title> <order>.<ext>" (replacing an
    /// earlier export of that name) and returns its share item; nil when the run or the file could not be written,
    /// leaving no file of that name.
    func write(_ run: BenchmarkRun, order: Int, format: ResultExportFormat) -> ResultExportFile? {
        let title = BenchPresenter.title(of: run.benchmarkCase.workload)
        let name = ResultExportFile.fileName(caseTitle: title, order: order, format: format)
        let url = folder.url.appendingPathComponent(name, isDirectory: false)
        do {
            let data = try Self.data(of: run, format: format)
            try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return ResultExportFile(url: url, format: format)
    }

    /// The share item `item` while its file still exists; nil otherwise.
    static func existing(_ item: ResultExportFile?) -> ResultExportFile? {
        guard let item, FileManager.default.fileExists(atPath: item.url.path) else { return nil }
        return item
    }

    /// Empties the folder (removes it with everything in it); returns how many files it held.
    @discardableResult
    func clear() -> Int { folder.removeAll() }
}
