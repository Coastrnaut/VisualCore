// ResultsView — feature 176 (A24-P04) T-A24-406 (FR-A24-402, FR-A24-404, FR-A24-405; clarifications Q3–Q5;
// contracts/results.md "Identifiers"; Edge Cases "Saving with no ended run", "Opening a result of a case version the
// app no longer has"). The saved results of Graphics Benchmark Lab, shown inline in the controls from the `results`
// button (never a sheet, a menu or a popover over the drawing: the A23-P05 lesson). Every element is named
// `experience.a24.graphics-benchmark-lab.<name>` (`ExperienceActionPort.identifier`), n being the file's counter of
// `result-<n>.json`:
//
//   - per saved result, newest first, a row `result-row-<n>` labelled "<case title>, <state>, p50 <x> ms, p95 <y> ms"
//     (two decimals, or "not enough frames") and ", GPU timed" when the summary has a GPU distribution; an unreadable
//     file shows its file name and "unreadable: <code>"; `result-open-<n>` (readable only) and `result-remove-<n>`
//     (every file; only this explicit action removes one);
//   - the opened result: its summary text, its stored settings (case id and version, workload, every setting and the
//     plan lengths, so a case version the app does not build in still shows what was measured) and its report
//     (device, OS, app version and build, renderer and GL version, quality tier, thermal state and Low Power Mode at
//     the start and the end, timing sources); `result-export-json` ("Export JSON") and `result-export-csv` ("Export
//     CSV") write the file only on the tap, then `result-share` (a `ShareLink` of the ``ResultExportFile``) appears;
//   - `results-done` hides the list.
//
// The view stores only references (the port, the mirror and the presenter), never a closure. Every button is at least
// 44 points high; the text wraps with Dynamic Type. The presenter's result actions are the extension at the end of this
// file.
import Foundation
import GraphicsBenchmarkLabCore
import SwiftUI
import VisualCoreExperienceHost

/// The saved results, inline in the controls (see the file header).
struct ResultsView: View {
    /// The port that names the elements.
    let port: ExperienceActionPort
    /// What the controls show (entries, opened result, message, share item).
    let mirror: BenchMirror
    /// The presenter whose result actions the buttons call.
    let presenter: BenchPresenter

    /// The spoken word of how a run ended: "Finished", "Stopped" or "Interrupted".
    static func stateWord(_ state: RunState) -> String {
        switch state {
        case .completed: return "Finished"
        case .stopped: return "Stopped"
        case .interrupted: return "Interrupted"
        }
    }

    /// The label of a row (see the file header).
    static func rowLabel(_ entry: ResultLibraryEntry) -> String {
        guard let info = entry.info else { return entry.file + ", unreadable: " + (entry.refusal ?? "damaged") }
        var text = info.caseTitle + ", " + stateWord(info.state) + ", p50 "
            + BenchPresenter.milliseconds(text: info.intervalP50) + ", p95 "
            + BenchPresenter.milliseconds(text: info.intervalP95)
        if info.gpuTimed { text += ", GPU timed" }
        return text
    }

    /// The identifier names of `entry`'s row and buttons: the row, then open (readable only), then remove.
    static func identifierNames(_ entry: ResultLibraryEntry) -> [String] {
        let n = String(entry.number)
        if entry.isReadable { return ["result-row-" + n, "result-open-" + n, "result-remove-" + n] }
        return ["result-row-" + n, "result-remove-" + n]
    }

    /// The summary text of an opened `run`: "<case title>, <state>", then the summary block's lines.
    static func summaryLines(_ run: BenchmarkRun) -> [String] {
        [BenchPresenter.title(of: run.benchmarkCase.workload) + ", " + stateWord(run.state)]
            + BenchPresenter.summaryLines(run.summary)
    }

    /// The stored settings of `benchmarkCase`: id and version, workload, each setting present and the plan lengths.
    static func settingsLines(_ benchmarkCase: BenchmarkCase) -> [String] {
        let config = benchmarkCase.config
        var lines = ["Case \(benchmarkCase.id) version \(benchmarkCase.version)",
                     "Workload " + benchmarkCase.workload.rawValue]
        var settings: [String] = []
        if let layers = config.layers { settings.append("layers \(layers)") }
        if let size = config.textureSize { settings.append("texture size \(size)") }
        if let iterations = config.iterations { settings.append("iterations \(iterations)") }
        if let particles = config.particles { settings.append("particles \(particles)") }
        settings.append("resolution scale \(config.resolutionScale)")
        lines.append("Settings: " + settings.joined(separator: ", "))
        let plan = benchmarkCase.plan
        lines.append("Plan: warm-up \(plan.warmUpSeconds) s, measurement \(plan.measureSeconds) s, "
                     + "cool-down \(plan.coolDownSeconds) s")
        return lines
    }

    /// The report lines of `report`; one sentence when the run has none.
    static func reportLines(_ report: RunReport?) -> [String] {
        guard let report else { return ["No report was recorded with this run."] }
        let sources = report.timingSources
        return ["Device " + report.deviceModel,
                "OS " + report.osVersion,
                "App " + report.appVersion + " build " + report.appBuild,
                "Renderer " + report.renderer + ", " + report.glVersion,
                "Quality tier " + report.qualityTier,
                "Thermal state " + report.thermalStart + " at the start, " + report.thermalEnd + " at the end",
                "Low Power Mode " + (report.lowPowerStart ? "on" : "off") + " at the start, "
                    + (report.lowPowerEnd ? "on" : "off") + " at the end",
                "Timing: interval " + sources.interval + ", CPU " + sources.cpu + ", GPU "
                    + (sources.gpu ?? "not available")]
    }

    /// The results.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Saved results").font(.headline).accessibilityAddTraits(.isHeader)
            if mirror.resultsReadOnly {
                Text(verbatim: ResultLibraryFailure.readOnly.message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if mirror.resultEntries.isEmpty {
                Text(verbatim: "No saved results.").font(.footnote)
            }
            ForEach(mirror.resultEntries) { entry in
                row(entry)
            }
            if let opened = mirror.openedResult {
                openedView(opened)
            }
            Button {
                presenter.hideResults()
            } label: {
                Text(verbatim: "Done").frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Done with saved results"))
            .accessibilityIdentifier(port.identifier("results-done"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The row of `entry` with its buttons.
    private func row(_ entry: ResultLibraryEntry) -> some View {
        let names = Self.identifierNames(entry)
        let label = Self.rowLabel(entry)
        let n = String(entry.number)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: label)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Saved result, " + label))
                .accessibilityIdentifier(port.identifier(names[0]))
            HStack(spacing: 12) {
                if entry.isReadable {
                    Button {
                        _ = presenter.openResult(file: entry.file)
                    } label: {
                        Text(verbatim: "Open").frame(minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: "Open " + label))
                    .accessibilityIdentifier(port.identifier("result-open-" + n))
                }
                Button(role: .destructive) {
                    _ = presenter.removeResult(file: entry.file)
                } label: {
                    Text(verbatim: "Remove").frame(minHeight: 44)
                }
                .disabled(mirror.resultsReadOnly)
                .accessibilityLabel(Text(verbatim: "Remove " + label))
                .accessibilityIdentifier(port.identifier("result-remove-" + n))
            }
        }
    }

    /// The opened result: summary, settings, report, the export buttons and the share link.
    private func openedView(_ opened: OpenedResult) -> some View {
        let lines = Self.summaryLines(opened.run) + Self.settingsLines(opened.run.benchmarkCase)
            + Self.reportLines(opened.run.report)
        let share = ResultExporter.existing(mirror.exportItem)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Opened result \(opened.entry.number)").font(.subheadline)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: lines.joined(separator: ", ")))
            .accessibilityIdentifier(port.identifier("result-opened"))
            HStack(spacing: 12) {
                Button {
                    _ = presenter.exportResult(.json)
                } label: {
                    Text(verbatim: "Export JSON").frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Export JSON"))
                .accessibilityHint(Text(verbatim: "Writes the result file, then offers it to share"))
                .accessibilityIdentifier(port.identifier("result-export-json"))
                Button {
                    _ = presenter.exportResult(.csv)
                } label: {
                    Text(verbatim: "Export CSV").frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Export CSV"))
                .accessibilityHint(Text(verbatim: "Writes the frame samples as CSV, then offers them to share"))
                .accessibilityIdentifier(port.identifier("result-export-csv"))
            }
            if let share {
                ShareLink(item: share, preview: SharePreview(Text(verbatim: share.url.lastPathComponent))) {
                    Text(verbatim: "Share " + share.url.lastPathComponent).frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Share " + share.url.lastPathComponent))
                .accessibilityIdentifier(port.identifier("result-share"))
            }
        }
    }
}

/// The presenter's result actions (T-A24-406; contracts/results.md).
extension BenchPresenter {
    /// Saves the ended run once and shows "Saved result <n>." or the refusal: no ended run, "This result is already
    /// saved." for a run equal to the one saved last, or the library's refusal.
    @discardableResult
    func saveResult() -> Result<Int, ResultLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        guard let run = recorder.runRecord() else { return refuse(.noRun) }
        if let savedRun, savedRun == run { return refuse(.alreadySaved) }
        let result = library.save(run)
        switch result {
        case .success(let n):
            savedRun = run
            report("Saved result \(n).")
        case .failure(let failure):
            report(failure.message)
        }
        followLibrary()
        return result
    }

    /// Shows the inline results list, read again from the storage.
    func showResults() {
        library?.reload()
        followLibrary()
        if !mirror.showingResults { mirror.showingResults = true }
        if library == nil { report(ResultLibraryFailure.unavailable.message) }
    }

    /// Hides the results list and closes the opened result.
    func hideResults() {
        if mirror.showingResults { mirror.showingResults = false }
        closeResult()
    }

    /// Opens the saved result `file`: its summary, settings and report are shown and "Opened result <n>." or the
    /// refusal; the previous export's share item is dropped.
    @discardableResult
    func openResult(file: String) -> Result<OpenedResult, ResultLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let result = library.open(file: file)
        switch result {
        case .success(let opened):
            if mirror.openedResult != opened { mirror.openedResult = opened }
            if mirror.exportItem != nil { mirror.exportItem = nil }
            report("Opened result \(opened.entry.number).")
        case .failure(let failure):
            report(failure.message)
        }
        followLibrary()
        return result
    }

    /// Closes the opened result and drops its share item.
    func closeResult() {
        if mirror.openedResult != nil { mirror.openedResult = nil }
        if mirror.exportItem != nil { mirror.exportItem = nil }
    }

    /// Removes the saved result `file` (readable or not) and shows "Removed result <n>." or the refusal; an opened
    /// result of that file is closed.
    @discardableResult
    func removeResult(file: String) -> Result<ResultLibraryEntry, ResultLibraryFailure> {
        guard let library else { return refuse(.unavailable) }
        let result = library.remove(file: file)
        switch result {
        case .success(let entry):
            if mirror.openedResult?.entry.file == file { closeResult() }
            report("Removed result \(entry.number).")
        case .failure(let failure):
            report(failure.message)
        }
        followLibrary()
        return result
    }

    /// Writes the opened result in `format` to the export folder (only on this call) and shows its share item, or
    /// refuses when no result is open or the file could not be written.
    @discardableResult
    func exportResult(_ format: ResultExportFormat) -> Result<ResultExportFile, ResultLibraryFailure> {
        guard let opened = mirror.openedResult else { return refuse(.missing) }
        guard let item = exporter.write(opened.run, order: opened.entry.order, format: format) else {
            return refuse(.exportFailed)
        }
        if mirror.exportItem != item { mirror.exportItem = item }
        report("Exported " + item.url.lastPathComponent + ".")
        return .success(item)
    }

    /// Empties the export folder and drops the share item (the session closes).
    func clearExports() {
        exporter.clear()
        if mirror.exportItem != nil { mirror.exportItem = nil }
    }

    /// Brings the mirror's entries and read-only flag up to the library.
    private func followLibrary() {
        let entries = library?.entries ?? []
        if mirror.resultEntries != entries { mirror.resultEntries = entries }
        let readOnly = library?.isReadOnly ?? false
        if mirror.resultsReadOnly != readOnly { mirror.resultsReadOnly = readOnly }
    }

    /// Shows `failure`'s sentence and returns it.
    private func refuse<T>(_ failure: ResultLibraryFailure) -> Result<T, ResultLibraryFailure> {
        report(failure.message)
        return .failure(failure)
    }

    /// Shows `text` as the results message (spoken by its label in the controls).
    private func report(_ text: String) {
        if mirror.resultMessage != text { mirror.resultMessage = text }
    }
}
