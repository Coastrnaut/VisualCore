// PerformanceRecord — feature 192 T-U06-012 (UA-F06; FR-U06-040 to FR-U06-042). The performance record of one
// experience session, version 1: a JSON object with sorted keys, at most 65,536 bytes, finite numbers and no key
// for an absent measurement (data-model section 5; contract
// specs/192-ua-f06-quality-performance/contracts/performance-api.md). The key table is closed: reading refuses
// every other key, so nothing that names a person or a device can be in a record. Reading never stops the
// process: every input gives a record or a typed `PerformanceRecordError` with a stable code.
import Foundation

/// The time the app needed from the start of its code to the usable launcher.
public struct LaunchTiming: Sendable, Equatable {
    /// The launch time in milliseconds.
    public var milliseconds: Double
    /// Whether this was the first launch after the installation.
    public var firstLaunch: Bool

    /// Creates a launch timing.
    public init(milliseconds: Double, firstLaunch: Bool) {
        self.milliseconds = milliseconds
        self.firstLaunch = firstLaunch
    }
}

/// Why a performance record could not be read or written.
public enum PerformanceRecordError: Error, Sendable, Equatable {
    /// The text is larger than `PerformanceRecord.maxBytes`; the value is its size.
    case tooLarge(bytes: Int)
    /// The text is not JSON or its top level is not an object.
    case corrupt(reason: String)
    /// The record was written by a later version; the value is that version.
    case newerVersion(Int)
    /// The version is below 1; the value is that version.
    case unknownVersion(Int)
    /// A required key is missing; the value is the key (`pacing.<key>` inside the pacing object).
    case missingField(String)
    /// A key that is not in the table of version 1 is present; the value is the key.
    case unknownField(String)
    /// A value has the wrong type or is outside its range; the value is the key.
    case invalidValue(String)

    /// The stable code of the error, for logs and tests.
    public var code: String {
        switch self {
        case .tooLarge: return "performance.too-large"
        case .corrupt: return "performance.corrupt"
        case .newerVersion: return "performance.newer-version"
        case .unknownVersion: return "performance.unknown-version"
        case .missingField: return "performance.missing-field"
        case .unknownField: return "performance.unknown-field"
        case .invalidValue: return "performance.invalid-value"
        }
    }
}

/// The performance record of one experience session (version 1).
///
/// The encoded form is UTF-8 JSON with sorted keys. It holds the experience id, quality, device conditions, frame
/// pacing, resource counters and stage times, and nothing else.
public struct PerformanceRecord: Sendable, Equatable {
    /// The record version this build writes and reads.
    public static let version = 1
    /// The largest encoded record, in bytes.
    public static let maxBytes = 65_536

    /// The keys every record has, sorted (without `version`).
    public static let requiredKeys: [String] = [
        "experience", "gpu_bytes", "gpu_peak_bytes", "late_compilations", "low_power",
        "memory_events", "pacing", "presented", "quality_level", "quality_levels", "quality_pinned", "rebuilds",
        "steps_down", "steps_up", "thermal",
    ]
    /// The keys a record has only when the measurement exists, sorted.
    public static let optionalKeys: [String] = [
        "first_launch", "first_present_ms", "frame_cap_fps", "launch_ms", "memory_footprint_bytes", "prepare_ms",
        "programs_compiled", "render_scale", "setup_ms",
    ]

    /// The experience id (`experience`).
    public var experience: String
    /// Whether frames reached a display (`presented`).
    public var presented: Bool
    /// The quality level in force, 0 = best (`quality_level`).
    public var qualityLevel: Int
    /// Whether the level is pinned instead of automatic (`quality_pinned`).
    public var qualityPinned: Bool
    /// The number of levels of the quality profile, 1…8 (`quality_levels`).
    public var qualityLevels: Int
    /// The steps towards a lower quality in the session (`steps_down`).
    public var stepsDown: Int
    /// The steps towards a higher quality in the session (`steps_up`).
    public var stepsUp: Int
    /// The thermal state, written as its case name (`thermal`).
    public var thermal: FramePacing.Thermal
    /// Whether Low Power Mode was on (`low_power`).
    public var lowPower: Bool
    /// The frame pacing's cap in frames per second (`frame_cap_fps`); nil when no render host existed.
    public var frameCapFPS: Int?
    /// The frame pacing's render scale, above 0 and at most 1 (`render_scale`); nil when no render host existed.
    public var renderScale: Double?
    /// The frame pacing summary (`pacing`).
    public var pacing: PacingSummary
    /// The graphics bytes of the resource ledger (`gpu_bytes`).
    public var gpuBytes: Int
    /// The peak graphics bytes of the resource ledger (`gpu_peak_bytes`).
    public var gpuPeakBytes: Int
    /// The shader compilations after the set-up (`late_compilations`).
    public var lateCompilations: Int
    /// The rebuilds of graphics resources (`rebuilds`).
    public var rebuilds: Int
    /// The memory warnings received (`memory_events`).
    public var memoryEvents: Int
    /// The launch time in milliseconds, when measured (`launch_ms`).
    public var launchMs: Double?
    /// Whether it was the first launch, when known (`first_launch`).
    public var firstLaunch: Bool?
    /// The prepare stage in milliseconds, when measured (`prepare_ms`).
    public var prepareMs: Double?
    /// The set-up stage in milliseconds, when measured (`setup_ms`).
    public var setupMs: Double?
    /// The time to the first presented frame in milliseconds, when measured (`first_present_ms`).
    public var firstPresentMs: Double?
    /// The programs compiled at the end of the set-up, when counted (`programs_compiled`).
    public var programsCompiled: Int?
    /// The memory footprint of the process in bytes, when the platform reports it (`memory_footprint_bytes`).
    public var memoryFootprintBytes: Int?

    /// Creates a record; the optional measurements default to absent.
    public init(experience: String, presented: Bool, qualityLevel: Int, qualityPinned: Bool, qualityLevels: Int,
                stepsDown: Int, stepsUp: Int, thermal: FramePacing.Thermal, lowPower: Bool, frameCapFPS: Int?,
                renderScale: Double?, pacing: PacingSummary, gpuBytes: Int, gpuPeakBytes: Int,
                lateCompilations: Int, rebuilds: Int, memoryEvents: Int, launchMs: Double? = nil,
                firstLaunch: Bool? = nil, prepareMs: Double? = nil, setupMs: Double? = nil,
                firstPresentMs: Double? = nil, programsCompiled: Int? = nil, memoryFootprintBytes: Int? = nil) {
        self.experience = experience
        self.presented = presented
        self.qualityLevel = qualityLevel
        self.qualityPinned = qualityPinned
        self.qualityLevels = qualityLevels
        self.stepsDown = stepsDown
        self.stepsUp = stepsUp
        self.thermal = thermal
        self.lowPower = lowPower
        self.frameCapFPS = frameCapFPS
        self.renderScale = renderScale
        self.pacing = pacing
        self.gpuBytes = gpuBytes
        self.gpuPeakBytes = gpuPeakBytes
        self.lateCompilations = lateCompilations
        self.rebuilds = rebuilds
        self.memoryEvents = memoryEvents
        self.launchMs = launchMs
        self.firstLaunch = firstLaunch
        self.prepareMs = prepareMs
        self.setupMs = setupMs
        self.firstPresentMs = firstPresentMs
        self.programsCompiled = programsCompiled
        self.memoryFootprintBytes = memoryFootprintBytes
    }

    /// False when a shader was compiled after the set-up (`late_compilations > 0`).
    public var passes: Bool { lateCompilations == 0 }

    /// Reads an encoded record.
    ///
    /// The checks run in this order: size (`tooLarge`); JSON with an object at the top (`corrupt`); `version`
    /// present (`missingField`), an integer (`invalidValue`), not above 1 (`newerVersion`), not below 1
    /// (`unknownVersion`); no key outside the table (`unknownField`, the alphabetically first); every required
    /// key present (`missingField`, the alphabetically first); then every value (`invalidValue` with the key): the
    /// type, numbers finite and not negative, integers without a fraction, a known thermal name, `quality_levels`
    /// in 1…8, `quality_level` in `0..<quality_levels`, `render_scale` above 0 and at most 1. Inside the pacing
    /// object the same rules apply and the keys are reported as `pacing.<key>`.
    public init(data: Data) throws(PerformanceRecordError) {
        guard data.count <= Self.maxBytes else { throw .tooLarge(bytes: data.count) }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw .corrupt(reason: "the text is not JSON")
        }
        guard let object = parsed as? [String: Any] else {
            throw .corrupt(reason: "the top level is not an object")
        }

        guard let versionValue = object[Self.versionKey] else { throw .missingField(Self.versionKey) }
        guard let version = Self.wholeNumber(versionValue) else { throw .invalidValue(Self.versionKey) }
        guard version <= Self.version else { throw .newerVersion(version) }
        guard version >= Self.version else { throw .unknownVersion(version) }

        let known = Set(Self.requiredKeys).union(Self.optionalKeys).union([Self.versionKey])
        if let unknown = object.keys.filter({ !known.contains($0) }).min() { throw .unknownField(unknown) }
        if let missing = Self.requiredKeys.first(where: { object[$0] == nil }) { throw .missingField(missing) }

        experience = try Self.string(object, "experience")
        presented = try Self.bool(object, "presented")
        qualityLevels = try Self.count(object, "quality_levels")
        guard (1...8).contains(qualityLevels) else { throw .invalidValue("quality_levels") }
        qualityLevel = try Self.count(object, "quality_level")
        guard qualityLevel < qualityLevels else { throw .invalidValue("quality_level") }
        qualityPinned = try Self.bool(object, "quality_pinned")
        stepsDown = try Self.count(object, "steps_down")
        stepsUp = try Self.count(object, "steps_up")
        let thermalName = try Self.string(object, "thermal")
        guard let thermal = Self.thermal(named: thermalName) else { throw .invalidValue("thermal") }
        self.thermal = thermal
        lowPower = try Self.bool(object, "low_power")
        frameCapFPS = try Self.optionalCount(object, "frame_cap_fps")
        renderScale = try Self.optionalMeasure(object, "render_scale")
        if let renderScale, !(renderScale > 0 && renderScale <= 1) { throw .invalidValue("render_scale") }
        pacing = try Self.readPacing(object["pacing"])
        gpuBytes = try Self.count(object, "gpu_bytes")
        gpuPeakBytes = try Self.count(object, "gpu_peak_bytes")
        lateCompilations = try Self.count(object, "late_compilations")
        rebuilds = try Self.count(object, "rebuilds")
        memoryEvents = try Self.count(object, "memory_events")

        launchMs = try Self.optionalMeasure(object, "launch_ms")
        firstLaunch = try Self.optionalBool(object, "first_launch")
        prepareMs = try Self.optionalMeasure(object, "prepare_ms")
        setupMs = try Self.optionalMeasure(object, "setup_ms")
        firstPresentMs = try Self.optionalMeasure(object, "first_present_ms")
        programsCompiled = try Self.optionalCount(object, "programs_compiled")
        memoryFootprintBytes = try Self.optionalCount(object, "memory_footprint_bytes")
    }

    /// The record as deterministic JSON: sorted keys, `version` 1, no key for an absent measurement.
    ///
    /// Throws `PerformanceRecordError.invalidValue` with the key when a number of the record is not finite and
    /// `PerformanceRecordError.tooLarge` when the result is larger than `maxBytes`.
    public func encoded() throws(PerformanceRecordError) -> Data {
        var pacingObject: [String: Any] = [
            "samples": pacing.samples, "on_time": pacing.onTime, "missed": pacing.missed,
            "invalid": pacing.invalid,
        ]
        if let value = pacing.medianMs { pacingObject["median_ms"] = try Self.finite(value, "pacing.median_ms") }
        if let value = pacing.p95Ms { pacingObject["p95_ms"] = try Self.finite(value, "pacing.p95_ms") }
        if let value = pacing.p99Ms { pacingObject["p99_ms"] = try Self.finite(value, "pacing.p99_ms") }

        try checkRanges()
        var object: [String: Any] = [
            Self.versionKey: Self.version,
            "experience": experience,
            "presented": presented,
            "quality_level": qualityLevel,
            "quality_pinned": qualityPinned,
            "quality_levels": qualityLevels,
            "steps_down": stepsDown,
            "steps_up": stepsUp,
            "thermal": Self.name(of: thermal),
            "low_power": lowPower,
            "pacing": pacingObject,
            "gpu_bytes": gpuBytes,
            "gpu_peak_bytes": gpuPeakBytes,
            "late_compilations": lateCompilations,
            "rebuilds": rebuilds,
            "memory_events": memoryEvents,
        ]
        if let value = frameCapFPS { object["frame_cap_fps"] = value }
        if let value = renderScale { object["render_scale"] = try Self.finite(value, "render_scale") }
        if let value = launchMs { object["launch_ms"] = try Self.finite(value, "launch_ms") }
        if let value = firstLaunch { object["first_launch"] = value }
        if let value = prepareMs { object["prepare_ms"] = try Self.finite(value, "prepare_ms") }
        if let value = setupMs { object["setup_ms"] = try Self.finite(value, "setup_ms") }
        if let value = firstPresentMs { object["first_present_ms"] = try Self.finite(value, "first_present_ms") }
        if let value = programsCompiled { object["programs_compiled"] = value }
        if let value = memoryFootprintBytes { object["memory_footprint_bytes"] = value }

        guard JSONSerialization.isValidJSONObject(object) else {
            throw .corrupt(reason: "the record cannot be written as JSON")
        }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        } catch {
            throw .corrupt(reason: "the record cannot be written as JSON")
        }
        guard data.count <= Self.maxBytes else { throw .tooLarge(bytes: data.count) }
        return data
    }

    // MARK: - Reading helpers

    private static let versionKey = "version"
    private static let pacingRequiredKeys = ["invalid", "missed", "on_time", "samples"]
    private static let pacingOptionalKeys = ["median_ms", "p95_ms", "p99_ms"]
    /// Whole numbers up to here are exact in a `Double` (2^53).
    private static let largestWholeNumber = 9_007_199_254_740_992.0

    /// Whether the JSON value is `true` or `false` (JSONSerialization gives booleans and numbers as `NSNumber`).
    private static func isBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        #if canImport(Darwin)
        return CFGetTypeID(number) == CFBooleanGetTypeID()
        #else
        return type(of: number) == type(of: NSNumber(value: true))
        #endif
    }

    /// The JSON number as a finite `Double`, or `nil` for a boolean, another type or a non-finite number.
    private static func number(_ value: Any) -> Double? {
        guard !isBoolean(value), let number = value as? NSNumber else { return nil }
        // Where the parser keeps the digits of the text as a decimal number, its own conversion to a `Double` is
        // not always the nearest value; Swift converts the digits exactly. A number the parser already holds as
        // a `Double` is taken as it is.
        let double: Double
        if let decimal = number as? NSDecimalNumber {
            double = Double(decimal.stringValue) ?? decimal.doubleValue
        } else {
            double = number.doubleValue
        }
        return double.isFinite ? double : nil
    }

    /// The JSON number as an integer (negative allowed), or `nil` when it is no number or has a fraction.
    private static func wholeNumber(_ value: Any) -> Int? {
        guard let double = number(value), double == double.rounded(),
              abs(double) <= largestWholeNumber else { return nil }
        return Int(double)
    }

    /// The key as it is reported: with the prefix of the nested object.
    private static func label(_ key: String, _ prefix: String) -> String { prefix + key }

    /// A string value.
    private static func string(_ object: [String: Any], _ key: String,
                               prefix: String = "") throws(PerformanceRecordError) -> String {
        guard let value = object[key] as? String else { throw .invalidValue(label(key, prefix)) }
        return value
    }

    /// A boolean value; a number is refused.
    private static func bool(_ object: [String: Any], _ key: String,
                             prefix: String = "") throws(PerformanceRecordError) -> Bool {
        guard let value = object[key], isBoolean(value), let number = value as? NSNumber else {
            throw .invalidValue(label(key, prefix))
        }
        return number.boolValue
    }

    /// An integer that is not negative; a boolean or a fraction is refused.
    private static func count(_ object: [String: Any], _ key: String,
                              prefix: String = "") throws(PerformanceRecordError) -> Int {
        guard let value = object[key], let whole = wholeNumber(value), whole >= 0 else {
            throw .invalidValue(label(key, prefix))
        }
        return whole
    }

    /// A finite number that is not negative; a boolean is refused.
    private static func measure(_ object: [String: Any], _ key: String,
                                prefix: String = "") throws(PerformanceRecordError) -> Double {
        guard let value = object[key], let double = number(value), double >= 0 else {
            throw .invalidValue(label(key, prefix))
        }
        return double
    }

    /// A measure when the key is present, `nil` when it is absent.
    private static func optionalMeasure(_ object: [String: Any], _ key: String,
                                        prefix: String = "") throws(PerformanceRecordError) -> Double? {
        guard object[key] != nil else { return nil }
        return try measure(object, key, prefix: prefix)
    }

    /// A count when the key is present, `nil` when it is absent.
    private static func optionalCount(_ object: [String: Any], _ key: String) throws(PerformanceRecordError) -> Int? {
        guard object[key] != nil else { return nil }
        return try count(object, key)
    }

    /// A boolean when the key is present, `nil` when it is absent.
    private static func optionalBool(_ object: [String: Any], _ key: String) throws(PerformanceRecordError) -> Bool? {
        guard object[key] != nil else { return nil }
        return try bool(object, key)
    }

    /// The nested pacing object, with the same rules and keys reported as `pacing.<key>`.
    private static func readPacing(_ value: Any?) throws(PerformanceRecordError) -> PacingSummary {
        guard let object = value as? [String: Any] else { throw .invalidValue("pacing") }
        let prefix = "pacing."
        let known = Set(pacingRequiredKeys).union(pacingOptionalKeys)
        if let unknown = object.keys.filter({ !known.contains($0) }).min() { throw .unknownField(prefix + unknown) }
        if let missing = pacingRequiredKeys.first(where: { object[$0] == nil }) {
            throw .missingField(prefix + missing)
        }
        let samples = try count(object, "samples", prefix: prefix)
        let onTime = try count(object, "on_time", prefix: prefix)
        let missed = try count(object, "missed", prefix: prefix)
        let invalid = try count(object, "invalid", prefix: prefix)
        let medianMs = try optionalMeasure(object, "median_ms", prefix: prefix)
        let p95Ms = try optionalMeasure(object, "p95_ms", prefix: prefix)
        let p99Ms = try optionalMeasure(object, "p99_ms", prefix: prefix)
        return PacingSummary(samples: samples, onTime: onTime, missed: missed, invalid: invalid,
                             medianMs: medianMs, p95Ms: p95Ms, p99Ms: p99Ms)
    }

    // MARK: - Writing helpers

    /// The range rules of reading, applied before writing: a record that could not be read back is not written.
    private func checkRanges() throws(PerformanceRecordError) {
        guard (1...8).contains(qualityLevels) else { throw .invalidValue("quality_levels") }
        guard qualityLevel >= 0, qualityLevel < qualityLevels else { throw .invalidValue("quality_level") }
        let counts: [(String, Int?)] = [
            ("steps_down", stepsDown), ("steps_up", stepsUp), ("gpu_bytes", gpuBytes),
            ("gpu_peak_bytes", gpuPeakBytes), ("late_compilations", lateCompilations), ("rebuilds", rebuilds),
            ("memory_events", memoryEvents), ("frame_cap_fps", frameCapFPS), ("programs_compiled", programsCompiled),
            ("memory_footprint_bytes", memoryFootprintBytes), ("pacing.samples", pacing.samples),
            ("pacing.on_time", pacing.onTime), ("pacing.missed", pacing.missed), ("pacing.invalid", pacing.invalid),
        ]
        for (key, value) in counts {
            if let value, value < 0 { throw .invalidValue(key) }
        }
        let measures: [(String, Double?)] = [
            ("launch_ms", launchMs), ("prepare_ms", prepareMs), ("setup_ms", setupMs),
            ("first_present_ms", firstPresentMs), ("pacing.median_ms", pacing.medianMs),
            ("pacing.p95_ms", pacing.p95Ms), ("pacing.p99_ms", pacing.p99Ms),
        ]
        for (key, value) in measures {
            if let value, !(value >= 0) { throw .invalidValue(key) }
        }
        if let renderScale, !(renderScale > 0 && renderScale <= 1) { throw .invalidValue("render_scale") }
    }

    /// The value as a JSON number that reads back to exactly the same `Double`, when it is finite; otherwise
    /// `invalidValue` with the key (also for a magnitude below 1e-100 or above 1e100). The number is written with the digits of Swift's shortest exact text of the
    /// value: the serializer's own formatting of a `Double` shortens some values (0.0007909999999999998 became
    /// 0.000791), and the record must read back equal (FR-U06-041).
    private static func finite(_ value: Double, _ key: String) throws(PerformanceRecordError) -> NSDecimalNumber {
        guard value.isFinite else { throw .invalidValue(key) }
        // No measurement of this record is that small or that large; the decimal form used below cannot hold it.
        let size = abs(value)
        guard size == 0 || (size >= 1e-100 && size <= 1e100) else { throw .invalidValue(key) }
        let exact = NSDecimalNumber(string: "\(value)", locale: Locale(identifier: "en_US_POSIX"))
        guard exact != NSDecimalNumber.notANumber else { throw .invalidValue(key) }
        return exact
    }

    /// The case name written for a thermal state.
    private static func name(of thermal: FramePacing.Thermal) -> String {
        switch thermal {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        }
    }

    /// The thermal state with this case name, or `nil`.
    private static func thermal(named name: String) -> FramePacing.Thermal? {
        FramePacing.Thermal.allCases.first { Self.name(of: $0) == name }
    }
}
