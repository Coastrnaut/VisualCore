// RunReportTests — feature 175 (A24-P03) T-A24-306 (clarification Q5). A valid report validates and round-trips
// through JSON; each invalid field is refused by name (empty and 129-character strings, an unknown thermal state, a
// timing source outside the fixed set, a case version of 0, a fingerprint in upper case or of the wrong length);
// 128 characters are accepted; `thermal-changed` is set exactly when the thermal states differ, and stored flags that
// differ from the derived ones are refused. Synthetic values only.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabCore

/// A synthetic, valid run report shared by the core tests.
enum SyntheticReport {
    /// A synthetic 64-digit lower-case fingerprint.
    static let fingerprint = String(repeating: "0123456789abcdef", count: 4)

    /// A valid report with the given thermal states and GPU source.
    static func make(thermalStart: String = "nominal", thermalEnd: String = "nominal",
                     gpuMeasured: Bool = true) -> RunReport {
        RunReport(deviceModel: "iPhone99,1", osVersion: "27.2", appVersion: "1.0", appBuild: "1",
                  renderer: "Synthetic Renderer", glVersion: "OpenGL ES 3.0 (synthetic)", qualityTier: "level-0",
                  thermalStart: thermalStart, thermalEnd: thermalEnd, lowPowerStart: false, lowPowerEnd: true,
                  timingSources: .standard(gpuMeasured: gpuMeasured), caseID: "quads", caseVersion: 1,
                  caseFingerprint: fingerprint)
    }
}

@Suite struct RunReportTests {
    /// The field `report` is refused for, or nil when it validates.
    private static func invalidField(_ report: RunReport) -> String? {
        do {
            try report.validate()
            return nil
        } catch {
            switch error {
            case let .invalid(field): return field
            }
        }
    }

    @Test func validReportValidatesAndRoundTrips() throws {
        let reports = [SyntheticReport.make(), SyntheticReport.make(gpuMeasured: false)]
        for report in reports {
            let field = Self.invalidField(report)
            #expect(field == nil)
            let data = try JSONEncoder().encode(report)
            let decoded = try JSONDecoder().decode(RunReport.self, from: data)
            #expect(decoded == report)
        }
        let sources = TimingSources.standard(gpuMeasured: true)
        #expect(sources == TimingSources(interval: "frame time", cpu: "presenter CPU time", gpu: "GPU timer"))
        let withoutGPU = TimingSources.standard(gpuMeasured: false)
        #expect(withoutGPU.gpu == nil)
    }

    @Test func everyStringFieldIsBounded() {
        let paths: [(String, WritableKeyPath<RunReport, String>)] = [
            ("deviceModel", \.deviceModel), ("osVersion", \.osVersion), ("appVersion", \.appVersion),
            ("appBuild", \.appBuild), ("renderer", \.renderer), ("glVersion", \.glVersion),
            ("qualityTier", \.qualityTier), ("caseID", \.caseID),
        ]
        let longest = String(repeating: "a", count: 128)
        let tooLong = String(repeating: "a", count: 129)
        for (name, path) in paths {
            var report = SyntheticReport.make()
            report[keyPath: path] = ""
            let empty = Self.invalidField(report)
            #expect(empty == name)
            report[keyPath: path] = tooLong
            let long = Self.invalidField(report)
            #expect(long == name)
            report[keyPath: path] = longest
            let accepted = Self.invalidField(report)
            #expect(accepted == nil, "\(name) at 128 characters")
        }
    }

    @Test func thermalStatesFromTheFixedNames() {
        for state in ["nominal", "fair", "serious", "critical"] {
            let report = SyntheticReport.make(thermalStart: state, thermalEnd: state)
            let field = Self.invalidField(report)
            #expect(field == nil)
        }
        var start = SyntheticReport.make()
        start.thermalStart = "hot"
        let startField = Self.invalidField(start)
        #expect(startField == "thermalStart")
        var end = SyntheticReport.make()
        end.thermalEnd = "Nominal"
        let endField = Self.invalidField(end)
        #expect(endField == "thermalEnd")
    }

    @Test func timingSourcesFromTheFixedSet() {
        let cases: [(TimingSources, String)] = [
            (TimingSources(interval: "display link", cpu: "presenter CPU time", gpu: nil), "timingSources.interval"),
            (TimingSources(interval: "frame time", cpu: "wall clock", gpu: nil), "timingSources.cpu"),
            (TimingSources(interval: "frame time", cpu: "presenter CPU time", gpu: "estimate"), "timingSources.gpu"),
            (TimingSources(interval: "frame time", cpu: "presenter CPU time", gpu: ""), "timingSources.gpu"),
        ]
        for (sources, expected) in cases {
            var report = SyntheticReport.make()
            report.timingSources = sources
            let field = Self.invalidField(report)
            #expect(field == expected)
        }
    }

    @Test func caseVersionAndFingerprint() {
        var version = SyntheticReport.make()
        version.caseVersion = 0
        let versionField = Self.invalidField(version)
        #expect(versionField == "caseVersion")
        let fingerprints = [SyntheticReport.fingerprint.uppercased(), String(SyntheticReport.fingerprint.dropLast()),
                            SyntheticReport.fingerprint + "0", String(repeating: "g", count: 64)]
        for fingerprint in fingerprints {
            var report = SyntheticReport.make()
            report.caseFingerprint = fingerprint
            let field = Self.invalidField(report)
            #expect(field == "caseFingerprint")
        }
    }

    @Test func thermalChangedFlag() throws {
        let steady = SyntheticReport.make(thermalStart: "fair", thermalEnd: "fair")
        #expect(steady.flags.isEmpty)
        let changed = SyntheticReport.make(thermalStart: "nominal", thermalEnd: "serious")
        #expect(changed.flags == ["thermal-changed"])
        let changedField = Self.invalidField(changed)
        #expect(changedField == nil)
        var edited = steady
        edited.thermalEnd = "critical"
        let stale = Self.invalidField(edited)
        #expect(stale == "flags")
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(steady))
            as? [String: Any])
        object["flags"] = ["thermal-changed"]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let decoded = try JSONDecoder().decode(RunReport.self, from: data)
        let forged = Self.invalidField(decoded)
        #expect(forged == "flags")
    }
}
