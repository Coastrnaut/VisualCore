// RenderView.swift — the CAMetalLayer-backed view that hosts a window surface (feature 003 T-F209).
// Same layer configuration as the audited reference MetalLayerView (BGRA8, opaque, black background).
import QuartzCore
import UIKit

final class RenderView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
    var onLayout: (() -> Void)?
    var onWindowChange: ((Bool) -> Void)?
    /// UIKit touches → PointerEvents (RenderView+Touches.swift, feature 006).
    let touchTranslator = TouchTranslator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        metalLayer.isOpaque = true
        metalLayer.pixelFormat = .bgra8Unorm
        isOpaque = true
        backgroundColor = .black
        isAccessibilityElement = false   // apps describe the scene with native accessibility (Constitution VII)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { touchTranslator.cancelAll(timestamp: ProcessInfo.processInfo.systemUptime) }
        onWindowChange?(window != nil)
    }
}
