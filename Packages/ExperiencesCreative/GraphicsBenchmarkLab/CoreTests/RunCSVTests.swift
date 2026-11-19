// RunCSVTests — feature 176 (A24-P04) T-A24-403 (FR-A24-404; SC-A24-403; clarification Q4; User Story 3), CSV
// version 2 by feature 177 (A24-P05) T-A24-504 (FR-A24-502: `qualification` and `qualification_reasons` after
// `state`). The JSON
// export (the run file) and the CSV export of a fixed fixture run equal the committed golden files
// `Fixtures/golden-run.json` and `Fixtures/golden-run.csv` byte for byte; the CSV's lines end in CRLF, the renderer
// field with a comma and quotes is quoted with its quotes doubled, an absent GPU time or percentile is an empty field
// (never 0), the key rows follow the documented order, and a run without a report has no report rows. The fixture
// run is built deterministically here from synthetic values.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabCore

/// The fixture run of the golden export files.
enum GoldenRun {
    /// The renderer string of the fixture report: it holds a comma and double quotes.
    static let renderer = "ANGLE (Apple, \"Metal\")"

    /// Twelve samples of the quads case: frames 0–2 warm-up, 3–9 measured, 10–11 cool-down; the first without an
    /// interval; GPU times on frames 3–6 and 10–11 and none on 7–9; frame 7 dropped.
    static func samples() -> [FrameSample] {
        let intervals: [Double?] = [nil, 16.5, 16.75, 16.625, 17.0, 16.5, 33.25, 16.875, 16.5, 16.75, 16.6, 16.7]
        let cpuTimes: [Double] = [2.0, 2.125, 2.25, 2.5, 2.375, 2.1, 2.75, 3.0, 2.2, 2.625, 1.875, 1.5]
        let gpuTimes: [Double?] = [nil, nil, nil, 4.5, 4.75, 4.625, 5.1, nil, nil, nil, 4.25, 4.0]
        var samples: [FrameSample] = []
        for index in 0..<intervals.count {
            let phase: RunPhase = index < 3 ? .warmUp : (index < 10 ? .measure : .coolDown)
            samples.append(FrameSample(frameIndex: index, phase: phase, intervalMs: intervals[index],
                                       cpuMs: cpuTimes[index], gpuMs: gpuTimes[index], dropped: index == 7))
        }
        return samples
    }

    /// The fixture report: synthetic device and build values, the renderer ``renderer``, thermal state nominal to
    /// fair, Low Power Mode off then on, the GPU timer listed.
    static func report() throws -> RunReport {
        RunReport(deviceModel: "iPhone99,1", osVersion: "27.2", appVersion: "1.0", appBuild: "42",
                  renderer: renderer, glVersion: "OpenGL ES 3.0 (ANGLE 2.1)", qualityTier: "level-0",
                  thermalStart: "nominal", thermalEnd: "fair", lowPowerStart: false, lowPowerEnd: true,
                  timingSources: .standard(gpuMeasured: true), caseID: BenchmarkCase.quads.id,
                  caseVersion: BenchmarkCase.quads.version, caseFingerprint: try BenchmarkCase.quads.fingerprint().hex)
    }

    /// The completed fixture run of the built-in quads case over ``samples()`` with ``report()``.
    static func run() throws -> BenchmarkRun {
        let samples = samples()
        return try BenchmarkRun(benchmarkCase: .quads, samples: samples, summary: try Summary.make(samples),
                                state: .completed, report: try report())
    }

    /// The bytes of the committed golden file `name` of the bundle's `Fixtures` directory.
    static func golden(_ name: String, _ ext: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
            throw GoldenMissing(file: "\(name).\(ext)")
        }
        return try Data(contentsOf: url)
    }
}

/// A golden file that is not in the test bundle.
struct GoldenMissing: Error, CustomStringConvertible {
    /// The missing file's name with its extension.
    let file: String
    /// "golden file <file> is not in the bundle".
    var description: String { "golden file \(file) is not in the bundle" }
}

@Suite struct RunCSVTests {
    /// The CSV lines of `text`, split on CRLF, without the empty string after the last line end.
    private static func lines(_ text: String) -> [String] {
        var parts = text.components(separatedBy: "\r\n")
        if parts.last == "" { parts.removeLast() }
        return parts
    }

    /// The value of the key row `key` of the CSV `text`, or nil.
    private static func value(_ key: String, in text: String) -> String? {
        for line in lines(text) where line.hasPrefix(key + ",") {
            return String(line.dropFirst(key.count + 1))
        }
        return nil
    }

    @Test func theJSONExportEqualsItsGoldenFile() throws {
        let encoded = try RunDocument.encode(GoldenRun.run())
        let golden = try GoldenRun.golden("golden-run", "json")
        #expect(encoded == golden)
        let decoded = try RunDocument.decode(golden).get()
        let original = try GoldenRun.run()
        #expect(decoded == original)
    }

    @Test func theCSVExportEqualsItsGoldenFile() throws {
        let text = RunCSV.text(of: try GoldenRun.run())
        let bytes = Data(text.utf8)
        let golden = try GoldenRun.golden("golden-run", "csv")
        #expect(bytes == golden)
    }

    @Test func everyLineEndsInCRLF() throws {
        let text = RunCSV.text(of: try GoldenRun.run())
        let bytes = Array(text.utf8)
        var bareLineFeeds = 0
        var lineEnds = 0
        for index in 0..<bytes.count where bytes[index] == 0x0A {
            if index > 0, bytes[index - 1] == 0x0D { lineEnds += 1 } else { bareLineFeeds += 1 }
        }
        let endsInCRLF = text.hasSuffix("\r\n")
        let lineCount = Self.lines(text).count
        #expect(bareLineFeeds == 0)
        #expect(endsInCRLF)
        #expect(lineEnds == lineCount)
    }

    @Test func theRendererIsQuotedWithItsQuotesDoubled() throws {
        let text = RunCSV.text(of: try GoldenRun.run())
        let renderer = Self.value("renderer", in: text)
        #expect(renderer == "\"ANGLE (Apple, \"\"Metal\"\")\"")
        let plain = RunCSV.escaped("level-0")
        let comma = RunCSV.escaped("a,b")
        let lineBreak = RunCSV.escaped("a\r\nb")
        let feed = RunCSV.escaped("a\nb")
        #expect(plain == "level-0")
        #expect(comma == "\"a,b\"")
        #expect(lineBreak == "\"a\r\nb\"")
        #expect(feed == "\"a\nb\"")
    }

    @Test func anAbsentValueIsAnEmptyFieldNeverZero() throws {
        let text = RunCSV.text(of: try GoldenRun.run())
        let lines = Self.lines(text)
        let headerIndex = try #require(lines.firstIndex(of: RunCSV.sampleHeader.joined(separator: ",")))
        let first = lines[headerIndex + 1]
        let withoutGPU = lines[headerIndex + 1 + 8]
        let withGPU = lines[headerIndex + 1 + 3]
        #expect(first == "0,warmUp,,2.0,,false")
        #expect(withoutGPU == "8,measure,16.5,2.2,,false")
        #expect(withGPU == "3,measure,16.625,2.5,4.5,false")
        let gpuP50 = Self.value("gpu_p50", in: text)
        let intervalP95 = Self.value("interval_p95", in: text)
        #expect(gpuP50 == "")
        #expect(intervalP95 == "")
        let rowCount = lines.count - headerIndex - 1
        #expect(rowCount == GoldenRun.samples().count)
    }

    @Test func theKeyRowsFollowTheFormatOrder() throws {
        let text = RunCSV.text(of: try GoldenRun.run())
        var keys: [String] = []
        for line in Self.lines(text) {
            if line.isEmpty { break }
            keys.append(String(line.prefix { $0 != "," }))
        }
        let expected = [
            "format", "format_version", "case_id", "case_version", "case_fingerprint", "workload", "layers",
            "texture_size", "resolution_scale", "warm_up_seconds", "measure_seconds", "cool_down_seconds", "state",
            "qualification", "qualification_reasons", "device_model", "os_version", "app_version", "app_build",
            "renderer", "gl_version", "quality_tier",
            "thermal_start", "thermal_end", "low_power_start", "low_power_end", "timing_interval", "timing_cpu",
            "timing_gpu", "report_flags", "interval_p50", "interval_p95", "interval_p99", "cpu_p50", "cpu_p95",
            "cpu_p99", "gpu_p50", "gpu_p95", "gpu_p99", "measured", "warm_up_excluded", "cool_down_excluded",
            "dropped", "flags",
        ]
        #expect(keys == expected)
        let format = Self.value("format", in: text)
        let version = Self.value("format_version", in: text)
        let flags = Self.value("flags", in: text)
        let reportFlags = Self.value("report_flags", in: text)
        let qualification = Self.value("qualification", in: text)
        let reasons = Self.value("qualification_reasons", in: text)
        #expect(format == "a24.benchmark-run.csv" && version == "2")
        #expect(RunCSV.version == 2)
        #expect(qualification == "qualified")
        #expect(reasons == "thermal-changed;low-power;dropped-frames;too-few-for-p99")
        #expect(flags == "dropped-frames;gpu-time-not-available;too-few-for-p95;too-few-for-p99")
        #expect(reportFlags == "thermal-changed")
    }

    @Test func aRunWithoutAReportHasNoReportRows() throws {
        var run = try GoldenRun.run()
        run.report = nil
        let text = RunCSV.text(of: run)
        let renderer = Self.value("renderer", in: text)
        let lines = Self.lines(text)
        let stateIndex = try #require(lines.firstIndex(of: "state,completed"))
        let qualification = lines[stateIndex + 1]
        let reasons = lines[stateIndex + 2]
        let next = lines[stateIndex + 3]
        #expect(renderer == nil)
        #expect(qualification == "qualification,qualified")
        #expect(reasons == "qualification_reasons,dropped-frames;too-few-for-p99;no-report")
        #expect(next.hasPrefix("interval_p50,"))
    }

    @Test func anotherWorkloadListsOnlyItsSettings() throws {
        let samples = GoldenRun.samples()
        let run = try BenchmarkRun(benchmarkCase: .particles, samples: samples, summary: try Summary.make(samples),
                                   state: .stopped)
        let text = RunCSV.text(of: run)
        let particles = Self.value("particles", in: text)
        let layers = Self.value("layers", in: text)
        let state = Self.value("state", in: text)
        let qualification = Self.value("qualification", in: text)
        let reasons = Self.value("qualification_reasons", in: text)
        #expect(particles == "5000" && layers == nil && state == "stopped")
        #expect(qualification == "invalid" && reasons == "stopped")
    }

    @Test func aValidRunHasAnEmptyReasonsField() throws {
        let text = RunCSV.text(of: try QualificationFixture.run())
        let qualification = Self.value("qualification", in: text)
        let reasons = Self.value("qualification_reasons", in: text)
        #expect(qualification == "valid")
        #expect(reasons == "")
    }
}
