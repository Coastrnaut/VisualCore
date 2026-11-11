// SystemAccessibilityObserver.swift — the system's Reduce Motion and Dim Flashing Lights flags, kept current from their
// public change notifications (feature 016 T-A01-502; gap G-UI; FR-A01-506; research R8). Combine with
// VisualCoreSimulation.AccessibilityPreferences.resolve to get the effective settings. No permission is involved.
import Foundation
import MediaAccessibility
import Observation
import UIKit
import VisualCoreSimulation

/// Observes the system accessibility flags that matter for animated scenes; the value source can be replaced in tests.
@MainActor
@Observable
public final class SystemAccessibilityObserver {
    /// The latest system values.
    public private(set) var current: SystemAccessibility
    @ObservationIgnored private let source: @MainActor () -> SystemAccessibility
    @ObservationIgnored private var tokens: [NSObjectProtocol] = []

    /// The notifications that trigger a refresh: Reduce Motion and Dim Flashing Lights changes.
    public static let changeNotifications: [Notification.Name] = [
        UIAccessibility.reduceMotionStatusDidChangeNotification,
        Notification.Name(kMADimFlashingLightsChangedNotification as String),
    ]

    /// Reads the system values now; refreshes on each change notification.
    public init(source: @escaping @MainActor () -> SystemAccessibility = SystemAccessibilityObserver.systemValues) {
        self.source = source
        current = source()
        for name in Self.changeNotifications {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    isolated deinit {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
    }

    /// The system flags from public APIs: `UIAccessibility.isReduceMotionEnabled` and `MADimFlashingLightsEnabled()`.
    public static func systemValues() -> SystemAccessibility {
        SystemAccessibility(reduceMotion: UIAccessibility.isReduceMotionEnabled, dimFlashingLights: MADimFlashingLightsEnabled())
    }

    /// Re-reads the source; observers see a change only when the values differ.
    public func refresh() {
        let latest = source()
        if latest != current { current = latest }
    }
}
