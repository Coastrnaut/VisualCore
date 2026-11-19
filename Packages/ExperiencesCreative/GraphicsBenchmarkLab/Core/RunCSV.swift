// RunCSV — feature 176 (A24-P04) T-A24-403 (FR-A24-404; clarification Q4; data-model.md "CSV"); version 2 by
// feature 177 (A24-P05) T-A24-504 (FR-A24-502; clarification Q2). The CSV export of a run, format
// `a24.benchmark-run.csv` version 2, in two parts separated by one empty line:
//
// 1. `key,value` rows (no header), in this order: `format`, `format_version`, `case_id`, `case_version`,
//    `case_fingerprint`, `workload`, each configuration setting present in the order `layers`, `texture_size`,
//    `iterations`, `particles`, `resolution_scale`, then `warm_up_seconds`, `measure_seconds`, `cool_down_seconds`,
//    `state`, `qualification` (valid, qualified or invalid; ``RunQualification``), `qualification_reasons` (the
//    reason codes joined by `;`, empty when there is none); when the run has a report: `device_model`,
//    `os_version`, `app_version`, `app_build`, `renderer`, `gl_version`, `quality_tier`, `thermal_start`,
//    `thermal_end`, `low_power_start`, `low_power_end`, `timing_interval`, `timing_cpu`, `timing_gpu`,
//    `report_flags`; then the summary: `interval_p50`, `interval_p95`, `interval_p99`, `cpu_p50`, `cpu_p95`,
//    `cpu_p99`, `gpu_p50`, `gpu_p95`, `gpu_p99`, `measured`,
//    `warm_up_excluded`, `cool_down_excluded`, `dropped`, `flags`.
// 2. The header `frame_index,phase,interval_ms,cpu_ms,gpu_ms,dropped` and one row per sample in frame order.
//
// Values: an Int in decimal; a Double in Swift's shortest round-trip description (`"\(value)"`, for example `16.5`
// or `1.0`); a Bool as `true` or `false`; a phase, state or workload as its raw value; a list (report flags,
// summary flags) joined by `;`; an absent value (a percentile, a GPU time, a first frame's interval, a GPU timing
// source) as an empty field, never 0. Every line, the last included, ends with CRLF. A field holding a comma, a
// double quote, a CR or an LF is enclosed in double quotes with each double quote doubled (RFC 4180). The text is a
// pure function of the run: the same run gives the same bytes. Pure Foundation; no UI, GPU, file or clock.
import Foundation

/// The CSV export of a run (format ``format``, version ``version``).
public enum RunCSV {
    /// The format name written in the `format` row.
    public static let format = "a24.benchmark-run.csv"
    /// The format version written in the `format_version` row.
    /// Version 2 (A24-P05) added the `qualification` and `qualification_reasons` rows after `state`.
    public static let version = 2
    /// The header of the sample table.
    public static let sampleHeader = ["frame_index", "phase", "interval_ms", "cpu_ms", "gpu_ms", "dropped"]
    /// The line end of every line: CR LF.
    public static let lineEnd = "\r\n"

    /// The CSV text of `run`: the `key,value` part, an empty line and the sample table, each line ending in CRLF.
    public static func text(of run: BenchmarkRun) -> String {
        var rows: [[String]] = []
        for (key, value) in keyValues(of: run) { rows.append([key, value]) }
        rows.append([])
        rows.append(sampleHeader)
        for sample in run.samples {
            rows.append([String(sample.frameIndex), sample.phase.rawValue, number(sample.intervalMs),
                         number(sample.cpuMs), number(sample.gpuMs), String(sample.dropped)])
        }
        var text = ""
        for row in rows {
            var fields: [String] = []
            for field in row { fields.append(escaped(field)) }
            text += fields.joined(separator: ",")
            text += lineEnd
        }
        return text
    }

    /// The `key,value` pairs of `run`, in the order of the format (see the file header).
    static func keyValues(of run: BenchmarkRun) -> [(String, String)] {
        let benchmarkCase = run.benchmarkCase
        let config = benchmarkCase.config
        var pairs: [(String, String)] = [
            ("format", format), ("format_version", String(version)), ("case_id", benchmarkCase.id),
            ("case_version", String(benchmarkCase.version)), ("case_fingerprint", run.caseFingerprint),
            ("workload", benchmarkCase.workload.rawValue),
        ]
        let settings: [(String, Int?)] = [
            ("layers", config.layers), ("texture_size", config.textureSize), ("iterations", config.iterations),
            ("particles", config.particles),
        ]
        for (key, value) in settings {
            if let value { pairs.append((key, String(value))) }
        }
        pairs.append(("resolution_scale", number(config.resolutionScale)))
        pairs.append(("warm_up_seconds", String(benchmarkCase.plan.warmUpSeconds)))
        pairs.append(("measure_seconds", String(benchmarkCase.plan.measureSeconds)))
        pairs.append(("cool_down_seconds", String(benchmarkCase.plan.coolDownSeconds)))
        pairs.append(("state", run.state.rawValue))
        let qualification = RunQualification.qualify(run)
        pairs.append(("qualification", qualification.class.rawValue))
        pairs.append(("qualification_reasons", qualification.reasonCodes))
        if let report = run.report {
            pairs.append(("device_model", report.deviceModel))
            pairs.append(("os_version", report.osVersion))
            pairs.append(("app_version", report.appVersion))
            pairs.append(("app_build", report.appBuild))
            pairs.append(("renderer", report.renderer))
            pairs.append(("gl_version", report.glVersion))
            pairs.append(("quality_tier", report.qualityTier))
            pairs.append(("thermal_start", report.thermalStart))
            pairs.append(("thermal_end", report.thermalEnd))
            pairs.append(("low_power_start", String(report.lowPowerStart)))
            pairs.append(("low_power_end", String(report.lowPowerEnd)))
            pairs.append(("timing_interval", report.timingSources.interval))
            pairs.append(("timing_cpu", report.timingSources.cpu))
            pairs.append(("timing_gpu", report.timingSources.gpu ?? ""))
            pairs.append(("report_flags", report.flags.joined(separator: ";")))
        }
        let summary = run.summary
        let distributions: [(String, Distribution?)] = [
            ("interval", summary.interval), ("cpu", summary.cpu), ("gpu", summary.gpu),
        ]
        for (name, distribution) in distributions {
            pairs.append(("\(name)_p50", number(distribution?.p50)))
            pairs.append(("\(name)_p95", number(distribution?.p95)))
            pairs.append(("\(name)_p99", number(distribution?.p99)))
        }
        pairs.append(("measured", String(summary.measured)))
        pairs.append(("warm_up_excluded", String(summary.warmUpExcluded)))
        pairs.append(("cool_down_excluded", String(summary.coolDownExcluded)))
        pairs.append(("dropped", String(summary.dropped)))
        var flags: [String] = []
        for flag in summary.flags { flags.append(flag.rawValue) }
        pairs.append(("flags", flags.joined(separator: ";")))
        return pairs
    }

    /// `value` in Swift's shortest round-trip description, or the empty string when absent.
    static func number(_ value: Double?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    /// `field` as a CSV field: enclosed in double quotes with each double quote doubled when it holds a comma, a
    /// double quote, a CR or an LF (checked by Unicode scalar, so a CR LF pair is found too); otherwise unchanged.
    public static func escaped(_ field: String) -> String {
        var needsQuotes = false
        for scalar in field.unicodeScalars where scalar == "," || scalar == "\"" || scalar == "\r" || scalar == "\n" {
            needsQuotes = true
        }
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
