// FrameScheduler.swift — CADisplayLink frame loop with thermal / Low Power pacing (feature 003 T-F215;
// FR-F206). Same structure as the audited reference: a display link on the main run loop in common
// mode, a weak proxy to break the retain cycle, and caps from the QualityGovernor table (FramePacing).
import Foundation
import QuartzCore
import VisualCoreDiagnostics

@MainActor
final class FrameScheduler {
    private var link: CADisplayLink?
    private var observers: [NSObjectProtocol] = []
    private let requestedMaxFPS: Int
    private let tick: (CADisplayLink) -> Void
    private(set) var pacing: FramePacing
    var onPacingChange: ((FramePacing) -> Void)?

    init(requestedMaxFPS: Int, tick: @escaping (CADisplayLink) -> Void) {
        self.requestedMaxFPS = requestedMaxFPS
        self.tick = tick
        pacing = Self.currentPacing(requestedMaxFPS)
        let center = NotificationCenter.default
        for name in [ProcessInfo.thermalStateDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshPacing() }
            })
        }
    }

    static func currentPacing(_ requested: Int) -> FramePacing {
        let info = ProcessInfo.processInfo
        let thermal = FramePacing.Thermal(rawValue: info.thermalState.rawValue) ?? .nominal
        return FramePacing(thermal: thermal, lowPower: info.isLowPowerModeEnabled, requestedMaxFPS: requested)
    }

    func refreshPacing() {
        let next = Self.currentPacing(requestedMaxFPS)
        guard next != pacing else { return }
        pacing = next
        link?.preferredFrameRateRange = Self.range(next)
        onPacingChange?(next)
    }

    static func range(_ p: FramePacing) -> CAFrameRateRange {
        let r = p.range
        return CAFrameRateRange(minimum: Float(r.minimum), maximum: Float(r.maximum), preferred: Float(r.preferred))
    }

    var isRunning: Bool { link != nil }
    var isPaused: Bool { link?.isPaused ?? true }

    func start(paused: Bool) {
        guard link == nil else { link?.isPaused = paused; return }
        let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.fire(_:)))
        link.preferredFrameRateRange = Self.range(pacing)
        link.isPaused = paused
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func setPaused(_ paused: Bool) { link?.isPaused = paused }

    func stop() {
        link?.invalidate()
        link = nil
    }

    func shutdown() {
        stop()
        for o in observers { NotificationCenter.default.removeObserver(o) }
        observers.removeAll()
    }

    fileprivate func fired(_ link: CADisplayLink) { tick(link) }
}

/// Breaks the CADisplayLink → target retain cycle (reference ANGLEDisplayLinkProxy).
private final class DisplayLinkProxy: NSObject {
    weak var scheduler: FrameScheduler?
    init(_ scheduler: FrameScheduler) { self.scheduler = scheduler }
    @MainActor @objc func fire(_ link: CADisplayLink) { scheduler?.fired(link) }
}
