// RenderView+Touches.swift — UIKit touches → PointerEvents (feature 006 T-F518; FR-F502).
// Each UITouch gets a stable integer id for its lifetime; locations are view points (origin top-left),
// timestamps are UITouch.timestamp (seconds, monotonic). Recognition happens in VisualCoreScenes.
import UIKit
import VisualCoreMath
import VisualCoreScenes

/// Assigns stable ids to touches and produces PointerEvents (UIKit-free core, unit-testable).
@MainActor
final class TouchTranslator {
    private var ids: [ObjectIdentifier: Int] = [:]
    private var nextID = 1
    var handler: ((PointerEvent) -> Void)?

    var activeCount: Int { ids.count }

    func translate(_ phase: PointerPhase, _ samples: [(key: ObjectIdentifier, location: CGPoint, timestamp: TimeInterval)]) {
        for s in samples {
            let id: Int
            if let known = ids[s.key] { id = known }
            else {
                guard phase == .began else { continue }   // a move/end for a touch we never saw
                id = nextID; nextID += 1; ids[s.key] = id
            }
            if phase == .ended || phase == .cancelled { ids[s.key] = nil }
            handler?(PointerEvent(id: id, phase: phase, location: Vec2(Double(s.location.x), Double(s.location.y)),
                                  timestamp: s.timestamp))
        }
    }

    /// Cancels every active touch (view left the window, app went to the background).
    func cancelAll(timestamp: TimeInterval) {
        for (_, id) in ids.sorted(by: { $0.value < $1.value }) {
            handler?(PointerEvent(id: id, phase: .cancelled, location: .zero, timestamp: timestamp))
        }
        ids.removeAll()
    }
}

extension RenderView {
    private func forward(_ phase: PointerPhase, _ touches: Set<UITouch>) {
        let samples = touches.sorted { $0.timestamp < $1.timestamp }
            .map { (key: ObjectIdentifier($0), location: $0.location(in: self), timestamp: $0.timestamp) }
        touchTranslator.translate(phase, samples)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { forward(.began, touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { forward(.moved, touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { forward(.ended, touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { forward(.cancelled, touches) }
}

extension RenderHost {
    /// Receives every touch on the host's view as a PointerEvent (main thread). Setting it enables multi-touch.
    public var pointerHandler: ((PointerEvent) -> Void)? {
        get { renderView.touchTranslator.handler }
        set {
            renderView.isMultipleTouchEnabled = newValue != nil
            renderView.touchTranslator.handler = newValue
        }
    }
}
