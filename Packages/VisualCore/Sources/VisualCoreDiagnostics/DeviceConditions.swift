// DeviceConditions.swift — one reader for the thermal state and Low Power Mode (feature 034 A04-P02 T-A04-204; gap
// G-PQUALITY; research R5). Public `ProcessInfo` API only; apps pass the snapshot to `QualityPolicy.decide`.
#if canImport(Darwin)
import Foundation
#endif

/// The device conditions a quality policy reacts to.
public struct DeviceConditions: Sendable, Equatable {
    /// The thermal state.
    public var thermal: FramePacing.Thermal
    /// Whether Low Power Mode is on.
    public var lowPower: Bool

    /// Creates a snapshot.
    public init(thermal: FramePacing.Thermal, lowPower: Bool) {
        self.thermal = thermal
        self.lowPower = lowPower
    }

    /// Nominal thermal state, Low Power Mode off.
    public static let nominal = DeviceConditions(thermal: .nominal, lowPower: false)

    /// The current conditions from `ProcessInfo.thermalState` and `isLowPowerModeEnabled` (nominal where unavailable).
    public static func current() -> DeviceConditions {
        #if canImport(Darwin)
        let info = ProcessInfo.processInfo
        return DeviceConditions(thermal: FramePacing.Thermal(rawValue: info.thermalState.rawValue) ?? .nominal,
                                lowPower: info.isLowPowerModeEnabled)
        #else
        return .nominal
        #endif
    }
}
