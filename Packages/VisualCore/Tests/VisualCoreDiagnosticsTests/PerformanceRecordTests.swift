// PerformanceRecordTests — feature 192 T-U06-011 (UA-F06; FR-U06-040 to FR-U06-042; SC-U06-007; data-model
// section 5).
import Foundation
import Testing
@testable import VisualCoreDiagnostics

/// A record with only the required fields.
private func requiredOnlyRecord() -> PerformanceRecord {
    PerformanceRecord(experience: "A01", presented: true, qualityLevel: 1, qualityPinned: false, qualityLevels: 4,
                      stepsDown: 2, stepsUp: 1, thermal: .fair, lowPower: false, frameCapFPS: 60,
                      renderScale: 0.75,
                      pacing: PacingSummary(samples: 600, onTime: 590, missed: 12, invalid: 1,
                                            medianMs: 16.75, p95Ms: 17.25, p99Ms: 33.5),
                      gpuBytes: 12_582_912, gpuPeakBytes: 16_777_216, lateCompilations: 0, rebuilds: 1,
                      memoryEvents: 0)
}

/// A record with every field set.
private func fullRecord() -> PerformanceRecord {
    var record = requiredOnlyRecord()
    record.launchMs = 412.5
    record.firstLaunch = true
    record.prepareMs = 3.25
    record.setupMs = 88.5
    record.firstPresentMs = 120.75
    record.programsCompiled = 7
    record.memoryFootprintBytes = 104_857_600
    return record
}

/// The encoded text of the record, or empty data (with a recorded failure) when it cannot be written.
private func text(of record: PerformanceRecord) -> Data {
    do {
        return try record.encoded()
    } catch {
        Issue.record("the record could not be written: \(error.code)")
        return Data()
    }
}

/// The top-level JSON object of the text.
private func object(of data: Data) -> [String: Any] {
    guard let parsed = try? JSONSerialization.jsonObject(with: data),
          let dictionary = parsed as? [String: Any] else {
        Issue.record("the text is not a JSON object")
        return [:]
    }
    return dictionary
}

/// The JSON text of a dictionary.
private func json(_ dictionary: [String: Any]) -> Data {
    guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]) else {
        Issue.record("the dictionary could not be written")
        return Data()
    }
    return data
}

/// The text of the full record after a change to its top-level object.
private func changed(_ change: (inout [String: Any]) -> Void) -> Data {
    var dictionary = object(of: text(of: fullRecord()))
    change(&dictionary)
    return json(dictionary)
}

/// The text of the full record after a change to its pacing object.
private func changedPacing(_ change: (inout [String: Any]) -> Void) -> Data {
    changed { dictionary in
        var pacing = dictionary["pacing"] as? [String: Any] ?? [:]
        change(&pacing)
        dictionary["pacing"] = pacing
    }
}

/// The error reading the text gives, or `nil` when it reads.
private func refusal(_ data: Data) -> PerformanceRecordError? {
    do {
        _ = try PerformanceRecord(data: data)
        return nil
    } catch {
        return error
    }
}

/// The record the text reads as, or `nil` when it is refused.
private func read(_ data: Data) -> PerformanceRecord? {
    do {
        return try PerformanceRecord(data: data)
    } catch {
        return nil
    }
}

/// The error writing the record gives, or `nil` when it writes.
private func writeRefusal(_ record: PerformanceRecord) -> PerformanceRecordError? {
    do {
        _ = try record.encoded()
        return nil
    } catch {
        return error
    }
}

@Test func performanceRecordConstantsAndKeyTable() {
    #expect(PerformanceRecord.version == 1)
    #expect(PerformanceRecord.maxBytes == 65_536)
    // Data-model section 5, without `version`.
    #expect(PerformanceRecord.requiredKeys == [
        "experience", "gpu_bytes", "gpu_peak_bytes", "late_compilations", "low_power",
        "memory_events", "pacing", "presented", "quality_level", "quality_levels", "quality_pinned", "rebuilds",
        "steps_down", "steps_up", "thermal",
    ])
    // The frame-rate cap and the render scale exist only with a render host (convergence, T-U06-047).
    #expect(PerformanceRecord.optionalKeys == [
        "first_launch", "first_present_ms", "frame_cap_fps", "launch_ms", "memory_footprint_bytes", "prepare_ms",
        "programs_compiled", "render_scale", "setup_ms",
    ])
    #expect(PerformanceRecord.requiredKeys == PerformanceRecord.requiredKeys.sorted())
    #expect(PerformanceRecord.optionalKeys == PerformanceRecord.optionalKeys.sorted())
}

@Test func performanceRecordFullRoundTrip() {
    let record = fullRecord()
    let data = text(of: record)
    #expect(refusal(data) == nil)
    let decoded = read(data)
    #expect(decoded == record)
    // Writing again gives the same bytes.
    if let decoded { #expect(text(of: decoded) == data) }
    #expect(data.count <= PerformanceRecord.maxBytes)
}

@Test func performanceRecordWritesExactlyTheKeysOfTheTableSorted() {
    // FR-U06-042, SC-U06-007: the full record writes the keys of data-model section 5 and nothing else.
    let data = text(of: fullRecord())
    let expected = (PerformanceRecord.requiredKeys + PerformanceRecord.optionalKeys + ["version"]).sorted()
    let dictionary = object(of: data)
    #expect(dictionary.keys.sorted() == expected)
    #expect((dictionary["version"] as? Int) == 1)
    #expect((dictionary["thermal"] as? String) == "fair")
    let pacing = dictionary["pacing"] as? [String: Any] ?? [:]
    #expect(pacing.keys.sorted() == ["invalid", "median_ms", "missed", "on_time", "p95_ms", "p99_ms", "samples"])

    // The keys appear in the text in sorted order: each top-level key is found after the one before it.
    let string = String(decoding: data, as: UTF8.self)
    #expect(string.hasPrefix("{\"experience\":"))
    var searchStart = string.startIndex
    for key in expected where key != "pacing" {
        // `"key":` at the top level; the pacing object's own keys (`samples`, `on_time`, …) do not collide with
        // top-level names.
        guard let range = string.range(of: "\"\(key)\":", range: searchStart..<string.endIndex) else {
            Issue.record("the key \(key) is missing or out of order")
            continue
        }
        searchStart = range.upperBound
    }
}

@Test func performanceRecordWritesEveryThermalName() {
    let names = ["nominal", "fair", "serious", "critical"]
    for (thermal, name) in zip(FramePacing.Thermal.allCases, names) {
        var record = requiredOnlyRecord()
        record.thermal = thermal
        let data = text(of: record)
        #expect((object(of: data)["thermal"] as? String) == name)
        #expect(read(data)?.thermal == thermal)
    }
}

@Test func performanceRecordWithoutMeasurementsHasNoOptionalKey() {
    var record = requiredOnlyRecord()
    record.frameCapFPS = nil   // no render host existed
    record.renderScale = nil
    let data = text(of: record)
    let dictionary = object(of: data)
    #expect(dictionary.keys.sorted() == (PerformanceRecord.requiredKeys + ["version"]).sorted())
    for key in PerformanceRecord.optionalKeys { #expect(dictionary[key] == nil, "\(key) must be absent") }
    #expect(read(data) == record)

    // A pacing summary without samples has no percentile keys.
    var empty = requiredOnlyRecord()
    empty.pacing = PacingSummary()
    let emptyData = text(of: empty)
    let pacing = object(of: emptyData)["pacing"] as? [String: Any] ?? [:]
    #expect(pacing.keys.sorted() == ["invalid", "missed", "on_time", "samples"])
    #expect(read(emptyData) == empty)
}

@Test func performanceRecordFirstLaunchWithoutLaunchTimeIsAllowed() {
    let data = changed { $0["launch_ms"] = nil }
    #expect(refusal(data) == nil)
    let decoded = read(data)
    #expect(decoded?.firstLaunch == true && decoded?.launchMs == nil)
}

@Test func performanceRecordRefusedTexts() {
    let table: [(name: String, text: Data, code: String)] = [
        ("not JSON", Data("not json".utf8), "performance.corrupt"),
        ("empty", Data(), "performance.corrupt"),
        ("an array", Data("[1,2,3]".utf8), "performance.corrupt"),
        ("version 2", changed { $0["version"] = 2 }, "performance.newer-version"),
        ("version 0", changed { $0["version"] = 0 }, "performance.unknown-version"),
        ("no version", changed { $0["version"] = nil }, "performance.missing-field"),
        ("version as text", changed { $0["version"] = "1" }, "performance.invalid-value"),
        ("missing gpu_bytes", changed { $0["gpu_bytes"] = nil }, "performance.missing-field"),
        ("unknown key", changed { $0["device_name"] = "someone's phone" }, "performance.unknown-field"),
        ("number for a boolean", changed { $0["presented"] = 1 }, "performance.invalid-value"),
        ("boolean for an integer", changed { $0["steps_up"] = true }, "performance.invalid-value"),
        ("negative number", changed { $0["gpu_bytes"] = -1 }, "performance.invalid-value"),
        ("fraction in an integer", changed { $0["steps_down"] = 1.5 }, "performance.invalid-value"),
        ("unknown thermal name", changed { $0["thermal"] = "hot" }, "performance.invalid-value"),
        ("thermal as a number", changed { $0["thermal"] = 1 }, "performance.invalid-value"),
        ("no quality levels", changed { $0["quality_levels"] = 0 }, "performance.invalid-value"),
        ("nine quality levels", changed { $0["quality_levels"] = 9 }, "performance.invalid-value"),
        ("level outside the profile", changed { $0["quality_level"] = 4 }, "performance.invalid-value"),
        ("render scale zero", changed { $0["render_scale"] = 0 }, "performance.invalid-value"),
        ("render scale above one", changed { $0["render_scale"] = 1.5 }, "performance.invalid-value"),
        ("negative optional time", changed { $0["launch_ms"] = -1.0 }, "performance.invalid-value"),
        ("too large", changed { $0["padding"] = String(repeating: "x", count: 70_000) }, "performance.too-large"),
        ("pacing not an object", changed { $0["pacing"] = 3 }, "performance.invalid-value"),
        ("pacing without samples", changedPacing { $0["samples"] = nil }, "performance.missing-field"),
        ("pacing with an unknown key", changedPacing { $0["frames"] = 3 }, "performance.unknown-field"),
        ("pacing with a negative time", changedPacing { $0["p95_ms"] = -2.0 }, "performance.invalid-value"),
    ]
    #expect(table.count >= 8)
    for row in table {
        #expect(!row.text.isEmpty || row.name == "empty", "\(row.name): the broken text was not built")
        #expect(refusal(row.text)?.code == row.code, "\(row.name)")
    }
}

@Test func performanceRecordRefusalsNameTheField() {
    #expect(refusal(changed { $0["version"] = 2 }) == .newerVersion(2))
    #expect(refusal(changed { $0["version"] = 0 }) == .unknownVersion(0))
    #expect(refusal(changed { $0["version"] = -3 }) == .unknownVersion(-3))
    #expect(refusal(changed { $0["version"] = nil }) == .missingField("version"))
    #expect(refusal(changed { $0["version"] = true }) == .invalidValue("version"))
    #expect(refusal(changed { $0["gpu_bytes"] = nil }) == .missingField("gpu_bytes"))
    #expect(refusal(changed { $0["device_name"] = "x" }) == .unknownField("device_name"))
    #expect(refusal(changed { $0["presented"] = 1 }) == .invalidValue("presented"))
    #expect(refusal(changed { $0["gpu_bytes"] = -1 }) == .invalidValue("gpu_bytes"))
    #expect(refusal(changed { $0["steps_down"] = 1.5 }) == .invalidValue("steps_down"))
    #expect(refusal(changed { $0["thermal"] = "hot" }) == .invalidValue("thermal"))
    #expect(refusal(changed { $0["quality_level"] = 4 }) == .invalidValue("quality_level"))
    #expect(refusal(changed { $0["render_scale"] = 1.5 }) == .invalidValue("render_scale"))
    #expect(refusal(changedPacing { $0["samples"] = nil }) == .missingField("pacing.samples"))
    #expect(refusal(changedPacing { $0["frames"] = 3 }) == .unknownField("pacing.frames"))
    #expect(refusal(changedPacing { $0["on_time"] = false }) == .invalidValue("pacing.on_time"))

    // The alphabetically first key is reported, and unknown keys come before missing ones.
    #expect(refusal(changed { $0["zeta"] = 1; $0["alpha"] = 2 }) == .unknownField("alpha"))
    #expect(refusal(changed { $0["rebuilds"] = nil; $0["experience"] = nil }) == .missingField("experience"))
    #expect(refusal(changed { $0["rebuilds"] = nil; $0["zeta"] = 1 }) == .unknownField("zeta"))
    // The version is judged before the keys.
    #expect(refusal(changed { $0["version"] = 2; $0["zeta"] = 1 }) == .newerVersion(2))

    // The size is checked first: the padded text is refused as too large, not for its unknown key.
    let padded = changed { $0["padding"] = String(repeating: "x", count: 70_000) }
    #expect(refusal(padded) == .tooLarge(bytes: padded.count))
}

@Test func performanceRecordErrorCodes() {
    #expect(PerformanceRecordError.tooLarge(bytes: 1).code == "performance.too-large")
    #expect(PerformanceRecordError.corrupt(reason: "x").code == "performance.corrupt")
    #expect(PerformanceRecordError.newerVersion(2).code == "performance.newer-version")
    #expect(PerformanceRecordError.unknownVersion(0).code == "performance.unknown-version")
    #expect(PerformanceRecordError.missingField("x").code == "performance.missing-field")
    #expect(PerformanceRecordError.unknownField("x").code == "performance.unknown-field")
    #expect(PerformanceRecordError.invalidValue("x").code == "performance.invalid-value")
}

@Test func performanceRecordPassesOnlyWithoutLateCompilations() {
    var record = fullRecord()
    #expect(record.passes)
    record.lateCompilations = 1
    #expect(!record.passes)
    // The verdict survives the round trip.
    #expect(read(text(of: record))?.passes == false)
}

@Test func performanceRecordRefusesToWriteNonFiniteNumbers() {
    var record = fullRecord()
    record.renderScale = .nan
    #expect(writeRefusal(record) == .invalidValue("render_scale"))
    record = fullRecord()
    record.launchMs = .infinity
    #expect(writeRefusal(record) == .invalidValue("launch_ms"))
    record = fullRecord()
    record.pacing.p99Ms = -.infinity
    #expect(writeRefusal(record) == .invalidValue("pacing.p99_ms"))
}

@Test func performanceRecordRefusesToWriteMoreThanTheLimit() {
    var record = fullRecord()
    record.experience = String(repeating: "x", count: 70_000)
    #expect(writeRefusal(record)?.code == "performance.too-large")
}

@Test func launchTimingHoldsItsValues() {
    let timing = LaunchTiming(milliseconds: 412.5, firstLaunch: true)
    #expect(timing.milliseconds == 412.5 && timing.firstLaunch)
    #expect(timing == LaunchTiming(milliseconds: 412.5, firstLaunch: true))
    #expect(timing != LaunchTiming(milliseconds: 412.5, firstLaunch: false))
}

// Found by the app's tests (feature 192): a measured time such as 0.0007909999999999998 ms must read back as
// exactly the same value.
@Test func performanceRecordNumbersReadBackExactly() throws {
    let awkward: [Double] = [0.0007909999999999998, 0.1 + 0.2, 1e-7, 123_456.789012345, 16.75, 1.0 / 3.0,
                             1e-100, 1e100, 0, 2.5e-5, 99.99999999999999, 4.9e-7, 600_000.123]
    // 2,000 more values of the sizes a record holds, from a fixed generator: fractions of a millisecond up to
    // minutes in milliseconds.
    var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    var values = awkward
    for index in 0..<2_000 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = Double(state >> 11) / Double(1 << 53)
        values.append(unit * [1e-3, 1.0, 1e3, 6e5][index % 4])
    }
    #expect(values.count == awkward.count + 2_000)
    for value in values {
        var record = PerformanceRecord(
            experience: "a99.contract-sample", presented: true, qualityLevel: 0, qualityPinned: false,
            qualityLevels: 1, stepsDown: 0, stepsUp: 0, thermal: .nominal, lowPower: false, frameCapFPS: 60,
            renderScale: 1, pacing: PacingSummary(samples: 1, onTime: 1, medianMs: value, p95Ms: value, p99Ms: value),
            gpuBytes: 0, gpuPeakBytes: 0, lateCompilations: 0, rebuilds: 0, memoryEvents: 0)
        record.launchMs = value
        record.prepareMs = value
        record.setupMs = value
        record.firstPresentMs = value
        let text = try record.encoded()
        let back = try PerformanceRecord(data: text)
        #expect(back == record, "value \(value) did not read back: \(String(decoding: text, as: UTF8.self))")
    }
}

@Test func performanceRecordRefusesMagnitudesNoMeasurementHas() {
    for value in [5e-324, 1e-101, 1.1e100, 1.7976931348623157e308] {
        var record = PerformanceRecord(
            experience: "a99.contract-sample", presented: false, qualityLevel: 0, qualityPinned: false,
            qualityLevels: 1, stepsDown: 0, stepsUp: 0, thermal: .nominal, lowPower: false, frameCapFPS: 60,
            renderScale: 1, pacing: PacingSummary(), gpuBytes: 0, gpuPeakBytes: 0, lateCompilations: 0, rebuilds: 0,
            memoryEvents: 0)
        record.prepareMs = value
        var refusal: PerformanceRecordError?
        do {
            _ = try record.encoded()
        } catch {
            refusal = error
        }
        #expect(refusal == .invalidValue("prepare_ms"), "value \(value)")
    }
}

// Convergence T-U06-049: what cannot be read is not written.
@Test func performanceRecordIsNotWrittenWithValuesReadingRefuses() {
    let broken: [(String, (inout PerformanceRecord) -> Void)] = [
        ("quality_levels", { $0.qualityLevels = 0 }),
        ("quality_levels", { $0.qualityLevels = 9 }),
        ("quality_level", { $0.qualityLevel = $0.qualityLevels }),
        ("quality_level", { $0.qualityLevel = -1 }),
        ("steps_down", { $0.stepsDown = -1 }),
        ("gpu_bytes", { $0.gpuBytes = -1 }),
        ("late_compilations", { $0.lateCompilations = -2 }),
        ("frame_cap_fps", { $0.frameCapFPS = -30 }),
        ("render_scale", { $0.renderScale = 0 }),
        ("render_scale", { $0.renderScale = 1.5 }),
        ("prepare_ms", { $0.prepareMs = -0.5 }),
        ("pacing.samples", { $0.pacing.samples = -1 }),
        ("pacing.median_ms", { $0.pacing.medianMs = -1 }),
        ("memory_footprint_bytes", { $0.memoryFootprintBytes = -1 }),
    ]
    for (key, change) in broken {
        var record = fullRecord()
        change(&record)
        var refusal: PerformanceRecordError?
        do {
            _ = try record.encoded()
        } catch {
            refusal = error
        }
        #expect(refusal == .invalidValue(key), "\(key)")
    }
    // The untouched record is still written and read.
    let good = fullRecord()
    #expect(read(text(of: good)) == good)
}

