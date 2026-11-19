// RunReport — feature 175 (A24-P03) T-A24-306 (clarification Q5; data-model.md "RunReport"). The conditions a run was
// measured under, stored inside the run file (version 2): the device model identifier (a model name, not unique to a
// device), the operating-system and app versions, the renderer and GL version strings, the quality tier, the thermal
// state and Low Power Mode at the start and the end, which timing sources were used, and the case reference. The
// thermal states are stored as the names of `FramePacing.Thermal` ("nominal", "fair", "serious", "critical") so the
// core needs no diagnostics import. `flags` is derived: `thermal-changed` when the thermal state at the end differs
// from the one at the start. Validation: every string 1…128 characters, the thermal names, the timing sources from
// a fixed set, a case version of at least 1, a 64-digit lower-case hexadecimal fingerprint and the derived flags.
// Pure Foundation; no UIKit, no clock.
import Foundation

/// Which timing source produced each measured duration.
public struct TimingSources: Codable, Equatable, Sendable {
    /// The frame-interval source; always ``frameTime``.
    public var interval: String
    /// The CPU-time source; always ``presenterCPUTime``.
    public var cpu: String
    /// The GPU-time source: ``gpuTimer`` when GPU times were measured, otherwise nil.
    public var gpu: String?

    /// The interval source name: "frame time".
    public static let frameTime = "frame time"
    /// The CPU source name: "presenter CPU time".
    public static let presenterCPUTime = "presenter CPU time"
    /// The GPU source name: "GPU timer".
    public static let gpuTimer = "GPU timer"

    /// The given sources (not checked; see ``RunReport/validate()``).
    public init(interval: String = TimingSources.frameTime, cpu: String = TimingSources.presenterCPUTime,
                gpu: String? = nil) {
        self.interval = interval
        self.cpu = cpu
        self.gpu = gpu
    }

    /// The fixed sources, with the GPU timer when `gpuMeasured`.
    public static func standard(gpuMeasured: Bool) -> TimingSources {
        TimingSources(gpu: gpuMeasured ? gpuTimer : nil)
    }
}

/// Why a run report is invalid.
public enum RunReportError: Error, Equatable, Sendable {
    /// The named field (for example `osVersion` or `timingSources.gpu`) is outside its allowed values.
    case invalid(field: String)
}

/// The conditions a run was measured under.
public struct RunReport: Codable, Equatable, Sendable {
    /// The longest string a report field may hold, in characters.
    public static let maxFieldLength = 128
    /// The thermal state names, in order of `FramePacing.Thermal`.
    public static let thermalStates = ["nominal", "fair", "serious", "critical"]
    /// The flag set when the thermal state changed during the run.
    public static let thermalChangedFlag = "thermal-changed"

    /// The device's model identifier (`utsname` machine), a model name, not unique to a device.
    public var deviceModel: String
    /// The operating-system version.
    public var osVersion: String
    /// The app's short version.
    public var appVersion: String
    /// The app's build number.
    public var appBuild: String
    /// The renderer string of the GL context.
    public var renderer: String
    /// The GL version string of the GL context.
    public var glVersion: String
    /// The quality tier the run drew at (for example "level-0").
    public var qualityTier: String
    /// The thermal state at the start, one of ``thermalStates``.
    public var thermalStart: String
    /// The thermal state at the end, one of ``thermalStates``.
    public var thermalEnd: String
    /// Whether Low Power Mode was on at the start.
    public var lowPowerStart: Bool
    /// Whether Low Power Mode was on at the end.
    public var lowPowerEnd: Bool
    /// Which timing sources were used.
    public var timingSources: TimingSources
    /// The id of the case run.
    public var caseID: String
    /// The version of the case run.
    public var caseVersion: Int
    /// The hex of the case's fingerprint (64 lower-case hexadecimal digits).
    public var caseFingerprint: String
    /// The report's flags, sorted and unique: ``thermalChangedFlag`` when ``thermalStart`` and ``thermalEnd`` differ.
    public private(set) var flags: [String]

    /// A report with the given values and the flags derived from them (not checked; see ``validate()``).
    public init(deviceModel: String, osVersion: String, appVersion: String, appBuild: String, renderer: String,
                glVersion: String, qualityTier: String, thermalStart: String, thermalEnd: String, lowPowerStart: Bool,
                lowPowerEnd: Bool, timingSources: TimingSources, caseID: String, caseVersion: Int,
                caseFingerprint: String) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.renderer = renderer
        self.glVersion = glVersion
        self.qualityTier = qualityTier
        self.thermalStart = thermalStart
        self.thermalEnd = thermalEnd
        self.lowPowerStart = lowPowerStart
        self.lowPowerEnd = lowPowerEnd
        self.timingSources = timingSources
        self.caseID = caseID
        self.caseVersion = caseVersion
        self.caseFingerprint = caseFingerprint
        self.flags = Self.derivedFlags(thermalStart: thermalStart, thermalEnd: thermalEnd)
    }

    /// The flags of a run whose thermal state went from `thermalStart` to `thermalEnd`, sorted and unique.
    public static func derivedFlags(thermalStart: String, thermalEnd: String) -> [String] {
        thermalStart == thermalEnd ? [] : [thermalChangedFlag]
    }

    /// Throws ``RunReportError/invalid(field:)`` naming the first invalid field, in declaration order: a string
    /// outside 1…``maxFieldLength`` characters, a thermal state outside ``thermalStates``, a timing source outside
    /// the fixed set, a case version below 1, a fingerprint that is not 64 lower-case hexadecimal digits, or flags
    /// that differ from ``derivedFlags(thermalStart:thermalEnd:)``.
    public func validate() throws(RunReportError) {
        let strings: [(String, String)] = [
            ("deviceModel", deviceModel), ("osVersion", osVersion), ("appVersion", appVersion),
            ("appBuild", appBuild), ("renderer", renderer), ("glVersion", glVersion), ("qualityTier", qualityTier),
        ]
        for (field, value) in strings where !Self.isBounded(value) { throw .invalid(field: field) }
        guard Self.thermalStates.contains(thermalStart) else { throw .invalid(field: "thermalStart") }
        guard Self.thermalStates.contains(thermalEnd) else { throw .invalid(field: "thermalEnd") }
        guard timingSources.interval == TimingSources.frameTime else {
            throw .invalid(field: "timingSources.interval")
        }
        guard timingSources.cpu == TimingSources.presenterCPUTime else { throw .invalid(field: "timingSources.cpu") }
        if let gpu = timingSources.gpu, gpu != TimingSources.gpuTimer { throw .invalid(field: "timingSources.gpu") }
        guard Self.isBounded(caseID) else { throw .invalid(field: "caseID") }
        guard caseVersion >= 1 else { throw .invalid(field: "caseVersion") }
        guard Self.isLowerHexDigest(caseFingerprint) else { throw .invalid(field: "caseFingerprint") }
        guard flags == Self.derivedFlags(thermalStart: thermalStart, thermalEnd: thermalEnd) else {
            throw .invalid(field: "flags")
        }
    }

    /// True when `value` has 1…``maxFieldLength`` characters.
    private static func isBounded(_ value: String) -> Bool {
        let count = value.count
        return count >= 1 && count <= maxFieldLength
    }

    /// True when `value` is exactly 64 digits of `0`–`9` and `a`–`f`.
    private static func isLowerHexDigest(_ value: String) -> Bool {
        let bytes = value.utf8
        return bytes.count == 64 && bytes.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
