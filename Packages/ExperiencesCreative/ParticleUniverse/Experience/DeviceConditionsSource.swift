// DeviceConditionsSource.swift — where the sandbox reads heat and Low Power Mode (feature 034 A04-P02 T-A04-211;
// FR-A04-205; spec clarification 5; research R9). Release builds read VisualCore's DeviceConditions.current()
// (public ProcessInfo API) only; DEBUG builds also accept the UI-test launch arguments `-uitestThermal
// nominal|fair|serious|critical` and `-uitestLowPower YES`, `-uitestRendererFailure YES` (US4 AC3) `-uitestReduceMotion YES` (T-A04-218) and `-uitestReduceFlashing YES` (feature 035).
import Foundation
import VisualCoreDiagnostics

enum DeviceConditionsSource {
    /// The conditions the quality controller should react to now.
    static func current() -> DeviceConditions {
        var c = DeviceConditions.current()
        #if DEBUG
        let d = UserDefaults.standard
        if let raw = d.string(forKey: "uitestThermal"),
           let t = ["nominal": FramePacing.Thermal.nominal, "fair": .fair, "serious": .serious, "critical": .critical][raw] {
            c.thermal = t
        }
        if d.object(forKey: "uitestLowPower") != nil { c.lowPower = d.bool(forKey: "uitestLowPower") }
        #endif
        return c
    }

    /// DEBUG only: behave as if Reduce Motion were on (UI tests of the paused start, spec edge cases CHK020).
    static var forcedReduceMotion: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "uitestReduceMotion")
        #else
        false
        #endif
    }

    /// DEBUG only: behave as if Reduce Flashing were on (UI tests of the brightness cap, feature 035 T-A04-312).
    static var forcedReduceFlashing: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "uitestReduceFlashing")
        #else
        false
        #endif
    }

    /// DEBUG only: start in the CPU preview as if the GPU path had failed (UI tests of the fallback note).
    static var forcedRendererFailure: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "uitestRendererFailure")
        #else
        false
        #endif
    }
}
