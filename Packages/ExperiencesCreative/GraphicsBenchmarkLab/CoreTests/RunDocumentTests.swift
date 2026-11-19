// RunDocumentTests — feature 173 (A24-P01) T-A24-109 (FR-A24-105; SC-A24-104; clarification Q4). A run round-trips
// byte-identical (decode then encode gives the same bytes); one hand-built sample per refusal code on reading:
// damaged (not JSON, the wrong kind, no body, a malformed case reference, a tampered summary), newer-version (a
// version 2 envelope), too-large (one byte past the cap), not-finite (a "NaN" duration), out-of-range with its field,
// out-of-order and too-many-samples (20,001 samples); writing refuses a run whose summary does not match its samples.
// JSON has no NaN token, so the file carries it as the string "NaN". Synthetic data only.
// Feature 175 (A24-P03) T-A24-307 (FR-A24-307): the file is version 2 with the body key `report`; a version 1 file
// (a version 2 body without `report`, enveloped by hand) opens with no report; version 2 round-trips byte-identically
// with and without a report; a version 3 file is refused as newer; an invalid report is `out-of-range` of
// `report.<field>`; a version 2 body without the `report` key is damaged.
import Foundation
import Testing
import VisualCoreExperience
@testable import GraphicsBenchmarkLabCore

@Suite struct RunDocumentTests {
    /// Warm-up, measurement and cool-down samples, the first without an interval, some with GPU times.
    private static func samples() -> [FrameSample] {
        var samples: [FrameSample] = []
        for index in 0..<12 {
            let phase: RunPhase = index < 3 ? .warmUp : (index < 10 ? .measure : .coolDown)
            let interval: Double? = index == 0 ? nil : 16.5 + Double(index % 4) * 0.25
            samples.append(FrameSample(frameIndex: index, phase: phase, intervalMs: interval,
                                       cpuMs: 2 + Double(index) * 0.125, gpuMs: 4.5, dropped: index == 7))
        }
        return samples
    }

    /// A completed run of the quads case over ``samples()``.
    private static func run() throws -> BenchmarkRun {
        let samples = samples()
        return BenchmarkRun(caseID: BenchmarkCase.quads.id, caseVersion: BenchmarkCase.quads.version,
                            caseFingerprint: try BenchmarkCase.quads.fingerprint().hex, samples: samples,
                            summary: try Summary.make(samples), state: .completed)
    }

    /// The refusal of reading `data`, or nil when it reads.
    private static func refusal(_ data: Data) -> RunRefusal? {
        switch RunDocument.decode(data) {
        case .success: nil
        case let .failure(refusal): refusal
        }
    }

    /// The JSON object of `data`.
    private static func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The envelope `object` as bytes.
    private static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The encoded run with sample `index`'s `field` set to `value`.
    private static func withSample(_ index: Int, _ field: String, _ value: Any) throws -> Data {
        var envelope = try object(RunDocument.encode(run()))
        var body = try #require(envelope["body"] as? [String: Any])
        var samples = try #require(body["samples"] as? [[String: Any]])
        samples[index][field] = value
        body["samples"] = samples
        envelope["body"] = body
        return try data(envelope)
    }

    @Test func roundTripIsByteIdentical() throws {
        let original = try Self.run()
        let encoded = try RunDocument.encode(original)
        let decoded = try RunDocument.decode(encoded).get()
        #expect(decoded == original)
        let reencoded = try RunDocument.encode(decoded)
        #expect(reencoded == encoded)
        let envelope = try Self.object(encoded)
        let kind = envelope["kind"] as? String
        let version = envelope["version"] as? Int
        #expect(kind == "a24.benchmark-run")
        #expect(version == 2)
        let body = try #require(envelope["body"] as? [String: Any])
        let keys = body.keys.sorted()
        #expect(keys == ["case", "report", "samples", "state", "summary"])
        let report = body["report"]
        #expect(report is NSNull)
    }

    @Test func everyStateRoundTrips() throws {
        let states: [RunState] = [.completed, .stopped, .interrupted]
        for state in states {
            var value = try Self.run()
            value.state = state
            let decoded = try RunDocument.decode(RunDocument.encode(value)).get()
            #expect(decoded.state == state)
        }
    }

    @Test func damagedRefused() throws {
        let notJSON = Self.refusal(Data("not json".utf8))
        #expect(notJSON == .damaged)
        var envelope = try Self.object(RunDocument.encode(Self.run()))
        envelope["kind"] = "a23.visual-graph"
        let wrongKind = Self.refusal(try Self.data(envelope))
        #expect(wrongKind == .damaged)
        envelope["kind"] = RunDocument.kind
        envelope["body"] = nil
        let noBody = Self.refusal(try Self.data(envelope))
        #expect(noBody == .damaged)
        envelope = try Self.object(RunDocument.encode(Self.run()))
        envelope["version"] = 0
        let versionZero = Self.refusal(try Self.data(envelope))
        #expect(versionZero == .damaged)
        envelope = try Self.object(RunDocument.encode(Self.run()))
        var body = try #require(envelope["body"] as? [String: Any])
        body["case"] = ["id": "quads", "version": 1, "fingerprint": "zz"]
        envelope["body"] = body
        let badFingerprint = Self.refusal(try Self.data(envelope))
        #expect(badFingerprint == .damaged)
        let badPhase = Self.refusal(try Self.withSample(4, "phase", "later"))
        #expect(badPhase == .damaged)
    }

    @Test func tamperedSummaryRefusedAsDamaged() throws {
        var other = Self.samples()
        other[5].cpuMs = 900
        other[5].dropped = true
        let otherRun = BenchmarkRun(caseID: "quads", caseVersion: 1,
                                    caseFingerprint: try BenchmarkCase.quads.fingerprint().hex, samples: other,
                                    summary: try Summary.make(other), state: .completed)
        let otherEnvelope = try Self.object(RunDocument.encode(otherRun))
        let otherBody = try #require(otherEnvelope["body"] as? [String: Any])
        var envelope = try Self.object(RunDocument.encode(Self.run()))
        var body = try #require(envelope["body"] as? [String: Any])
        body["summary"] = otherBody["summary"]
        envelope["body"] = body
        let tampered = Self.refusal(try Self.data(envelope))
        #expect(tampered == .damaged)
        var mismatched = try Self.run()
        mismatched.summary = otherRun.summary
        #expect(throws: RunRefusal.damaged) { try RunDocument.encode(mismatched) }
    }

    @Test func newerVersionRefused() throws {
        var envelope = try Self.object(RunDocument.encode(Self.run()))
        envelope["version"] = 3
        let refusal = Self.refusal(try Self.data(envelope))
        #expect(refusal == .newerVersion)
        #expect(refusal?.code == "newer-version")
    }

    @Test func tooLargeRefused() {
        let data = Data(repeating: 0x20, count: RunDocument.maxBytes + 1)
        let refusal = Self.refusal(data)
        #expect(refusal == .tooLarge)
        #expect(refusal?.code == "too-large")
    }

    @Test func notFiniteRefused() throws {
        let refusal = Self.refusal(try Self.withSample(5, "cpuMs", "NaN"))
        #expect(refusal == .notFinite)
        #expect(refusal?.code == "not-finite")
        let infinite = Self.refusal(try Self.withSample(5, "gpuMs", "Infinity"))
        #expect(infinite == .notFinite)
    }

    @Test func outOfRangeRefusedWithItsField() throws {
        let refusal = Self.refusal(try Self.withSample(5, "cpuMs", 1_500))
        #expect(refusal == .outOfRange(field: "cpuMs"))
        #expect(refusal?.code == "out-of-range")
        let negative = Self.refusal(try Self.withSample(6, "intervalMs", -1))
        #expect(negative == .outOfRange(field: "intervalMs"))
    }

    @Test func outOfOrderRefused() throws {
        let refusal = Self.refusal(try Self.withSample(6, "frameIndex", 2))
        #expect(refusal == .outOfOrder)
        #expect(refusal?.code == "out-of-order")
        let phase = Self.refusal(try Self.withSample(11, "phase", "warmUp"))
        #expect(phase == .outOfOrder)
    }

    @Test func tooManySamplesRefused() throws {
        var envelope = try Self.object(RunDocument.encode(Self.run()))
        var body = try #require(envelope["body"] as? [String: Any])
        var samples: [[String: Any]] = []
        samples.reserveCapacity(SampleLimits.maxSamples + 1)
        for index in 0...SampleLimits.maxSamples {
            var sample: [String: Any] = ["frameIndex": index, "phase": "measure", "cpuMs": 1, "dropped": false]
            if index > 0 { sample["intervalMs"] = 8 }
            samples.append(sample)
        }
        body["samples"] = samples
        envelope["body"] = body
        let data = try Self.data(envelope)
        #expect(data.count <= RunDocument.maxBytes)
        let refusal = Self.refusal(data)
        #expect(refusal == .tooManySamples)
        #expect(refusal?.code == "too-many-samples")
    }

    @Test func versionOneOpensWithoutReport() throws {
        let original = try Self.run()
        var envelope = try Self.object(RunDocument.encode(original))
        var body = try #require(envelope["body"] as? [String: Any])
        body["report"] = nil
        envelope["body"] = body
        envelope["version"] = 1
        let decoded = try RunDocument.decode(try Self.data(envelope)).get()
        #expect(decoded.report == nil)
        #expect(decoded == original)
        let reencoded = try RunDocument.encode(decoded)
        let expected = try RunDocument.encode(original)
        #expect(reencoded == expected)
    }

    @Test func versionTwoRoundTripsWithAndWithoutReport() throws {
        var withReport = try Self.run()
        withReport.report = SyntheticReport.make(thermalStart: "nominal", thermalEnd: "fair")
        let runs = [try Self.run(), withReport]
        for run in runs {
            let encoded = try RunDocument.encode(run)
            let decoded = try RunDocument.decode(encoded).get()
            #expect(decoded == run)
            let reencoded = try RunDocument.encode(decoded)
            #expect(reencoded == encoded)
        }
        let text = String(decoding: try RunDocument.encode(withReport), as: UTF8.self)
        #expect(text.contains("\"flags\":[\"thermal-changed\"]"))
        #expect(text.contains("\"gpu\":\"GPU timer\""))
    }

    @Test func invalidReportRefusedWithItsField() throws {
        var run = try Self.run()
        var report = SyntheticReport.make()
        report.osVersion = ""
        run.report = report
        #expect(throws: RunRefusal.outOfRange(field: "report.osVersion")) { try RunDocument.encode(run) }
        var envelope = try Self.object(RunDocument.encode(Self.run()))
        var body = try #require(envelope["body"] as? [String: Any])
        var stored = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(SyntheticReport.make()))
            as? [String: Any])
        stored["thermalEnd"] = "melting"
        body["report"] = stored
        envelope["body"] = body
        let refusal = Self.refusal(try Self.data(envelope))
        #expect(refusal == .outOfRange(field: "report.thermalEnd"))
    }

    @Test func versionTwoWithoutReportKeyIsDamaged() throws {
        var envelope = try Self.object(RunDocument.encode(Self.run()))
        var body = try #require(envelope["body"] as? [String: Any])
        body["report"] = nil
        envelope["body"] = body
        let refusal = Self.refusal(try Self.data(envelope))
        #expect(refusal == .damaged)
    }

    @Test func migrationChainEndsAtVersionTwo() {
        let current = RunDocument.migrations.currentVersion
        #expect(current == 2)
        #expect(RunDocument.schemaVersion == 2)
    }

    @Test func refusalCodes() {
        let refusals: [RunRefusal] = [.damaged, .newerVersion, .tooLarge, .notFinite, .outOfRange(field: "cpuMs"),
                                      .outOfOrder, .tooManySamples]
        let codes = refusals.map { $0.code }
        #expect(codes == ["damaged", "newer-version", "too-large", "not-finite", "out-of-range", "out-of-order",
                          "too-many-samples"])
    }
}
