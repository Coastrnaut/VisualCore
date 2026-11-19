// ReportSource — feature 175 (A24-P03) T-A24-309 (FR-A24-307; clarification Q5; data-model.md "RunReport"). Builds a
// run's `RunReport` from public sources only:
//
//   - device model: the `utsname` machine identifier (a model name such as "iPhone17,1", not unique to a device); on
//     the simulator, where `utsname` gives the host's architecture, the simulator's `SIMULATOR_MODEL_IDENTIFIER`
//     environment value when present;
//   - OS version: `ProcessInfo.operatingSystemVersion` as "major.minor.patch";
//   - app version and build: the main bundle's `CFBundleShortVersionString` and `CFBundleVersion`, "unknown" when
//     absent (tests run inside an xctest bundle);
//   - renderer and GL version: the context's `RenderCapabilities`; "unknown" when empty;
//   - quality tier: "level-<tier>";
//   - thermal state and Low Power Mode at the start and the end: two `DeviceConditions.current()` snapshots, the
//     thermal state named "nominal", "fair", "serious" or "critical";
//   - timing sources: `TimingSources.standard(gpuMeasured:)`;
//   - the case id, version and fingerprint.
//
// Every string is cut to `RunReport.maxFieldLength` characters. No per-device or per-person identifier (vendor or
// advertising identifiers, the device's user-given name), no private framework and no dynamic loading is used; the
// scan specs/175-gbl-p03-runner-probe/scan-identifiers.sh checks it.
import Foundation
import GraphicsBenchmarkLabCore
import VisualCoreDiagnostics
import VisualCoreRendering

/// The public sources of a run report (see the file header).
enum ReportSource {
    /// The text of a field whose source gave nothing.
    static let unknown = "unknown"

    /// The device's model identifier: the simulator's `SIMULATOR_MODEL_IDENTIFIER` when present, otherwise the
    /// `utsname` machine; "unknown" when both are empty.
    static func deviceModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return bounded(simulated)
        }
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return bounded(machine)
    }

    /// The operating-system version as "major.minor.patch".
    static func osVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    /// The main bundle's short version, or "unknown".
    static func appVersion() -> String {
        bundleValue("CFBundleShortVersionString")
    }

    /// The main bundle's build number, or "unknown".
    static func appBuild() -> String {
        bundleValue("CFBundleVersion")
    }

    /// The thermal state's name in ``RunReport/thermalStates``.
    static func thermalName(_ thermal: FramePacing.Thermal) -> String {
        switch thermal {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        }
    }

    /// The report of a run of `benchmarkCase` drawn at quality `tier` on a renderer with `capabilities`, under
    /// `start` and `end` conditions, with the GPU timer named as a source only when `gpuMeasured`. Not checked; see
    /// ``RunReport/validate()``.
    static func report(case benchmarkCase: BenchmarkCase, capabilities: RenderCapabilities, tier: Int,
                       start: DeviceConditions, end: DeviceConditions, gpuMeasured: Bool) -> RunReport {
        let fingerprint = (try? benchmarkCase.fingerprint().hex) ?? ""
        return RunReport(deviceModel: deviceModel(), osVersion: osVersion(), appVersion: appVersion(),
                         appBuild: appBuild(), renderer: bounded(capabilities.renderer),
                         glVersion: bounded(capabilities.glVersion), qualityTier: "level-\(tier)",
                         thermalStart: thermalName(start.thermal), thermalEnd: thermalName(end.thermal),
                         lowPowerStart: start.lowPower, lowPowerEnd: end.lowPower,
                         timingSources: TimingSources.standard(gpuMeasured: gpuMeasured),
                         caseID: benchmarkCase.id, caseVersion: benchmarkCase.version, caseFingerprint: fingerprint)
    }

    /// `value` cut to ``RunReport/maxFieldLength`` characters, or "unknown" when empty.
    static func bounded(_ value: String) -> String {
        guard !value.isEmpty else { return unknown }
        return String(value.prefix(RunReport.maxFieldLength))
    }

    /// The main bundle's string for `key`, bounded, or "unknown".
    private static func bundleValue(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return unknown }
        return bounded(value)
    }
}
