// BrushPreview — feature 146 (A20-P02) T-A20-206 (FR-A20-204; clarification Q4; data-model.md "BrushPreviewState";
// contracts/experience.md "Preview"; gap G-PREVIEW). While a finger rakes, the canvas overlay draws the rake's outline
// at the touch: a rectangle of the rake's width (in tray widths, scaled to the fitted tray) across the drag direction,
// with one line per tine at the tine's offset from the centre line. The presenter keeps the state (position and
// direction in view points, the rake style, visible); the overlay only reads it. It disappears when the finger lifts or
// the pointers are cancelled and it never changes the experience's state. The host never lets the overlay take touches
// and hides it from assistive technology (the canvas label speaks the state).
import DigitalZenGardenCore
import Observation
import SwiftUI
import VisualCoreMath

/// What the brush preview shows (feature 146).
struct BrushPreviewState: Equatable, Sendable {
    /// The touch in view points (origin top-left).
    var position = Vec2(0, 0)
    /// The unit drag direction in view points (x to the right, y down); the x axis before the finger moves.
    var direction = Vec2(1, 0)
    /// The rake style index (0 fine, 1 wide).
    var rakeStyle = 0
    /// The width of the fitted tray in view points.
    var trayWidth = 0.0
    /// Whether the preview is drawn.
    var visible = false

    /// The rake style.
    var style: GardenPalette.RakeStyle { GardenCore.rake(index: rakeStyle) }

    /// The rake's width across the drag, in view points.
    var widthPoints: Double { style.width * trayWidth }

    /// The rectangle's length along the drag, in view points (a fifth of the width, at least 4 points).
    var lengthPoints: Double { max(widthPoints * 0.2, 4) }

    /// The number of tine lines (the style's tines).
    var tineCount: Int { style.tines }

    /// The signed offsets of the tine lines from the centre line, in view points, evenly spread across the width:
    /// ((k + 0.5)/tines − 0.5) × width for k in 0 ..< tines.
    var tineOffsets: [Double] {
        let tines = max(style.tines, 1)
        return (0..<tines).map { (Double($0) + 0.5) / Double(tines) * widthPoints - widthPoints / 2 }
    }

    /// The unit vector across the drag (the direction turned a quarter).
    var across: Vec2 { Vec2(-direction.y, direction.x) }

    /// The four corners of the outline in view points, in drawing order.
    var corners: [Vec2] {
        let halfAlong = direction * (lengthPoints / 2)
        let halfAcross = across * (widthPoints / 2)
        return [position - halfAlong - halfAcross, position + halfAlong - halfAcross,
                position + halfAlong + halfAcross, position - halfAlong + halfAcross]
    }

    /// The tine lines as pairs of end points in view points, one per tine, each along the drag.
    var tineLines: [(Vec2, Vec2)] {
        let halfAlong = direction * (lengthPoints / 2)
        return tineOffsets.map { offset in
            let centre = position + across * offset
            return (centre - halfAlong, centre + halfAlong)
        }
    }
}

/// The observable holder of the preview the overlay reads (feature 146).
@MainActor
@Observable
final class BrushPreviewModel {
    /// The current preview; `visible` false while no finger rakes.
    var state = BrushPreviewState()

    /// Shows the preview at `position` along `direction` (normalized when it has a length) with `rakeStyle` over a
    /// tray `trayWidth` points wide.
    func show(at position: Vec2, direction: Vec2?, rakeStyle: Int, trayWidth: Double) {
        var next = state
        next.position = position
        if let direction, direction.isFinite, direction.length > 1e-9 { next.direction = direction / direction.length }
        next.rakeStyle = rakeStyle
        next.trayWidth = trayWidth
        next.visible = true
        if next != state { state = next }
    }

    /// Hides the preview and resets its direction to the x axis.
    func hide() {
        guard state.visible || state.direction != Vec2(1, 0) else { return }
        var next = state
        next.visible = false
        next.direction = Vec2(1, 0)
        state = next
    }
}

/// The canvas overlay: the rake's outline and its tine lines at the touch while it is visible.
struct BrushPreview: View {
    /// The preview to draw.
    let model: BrushPreviewModel

    /// The outline.
    var body: some View {
        let state = model.state
        return Canvas { context, _ in
            guard state.visible else { return }
            var outline = Path()
            let corners = state.corners.map { CGPoint(x: $0.x, y: $0.y) }
            outline.addLines(corners)
            outline.closeSubpath()
            context.stroke(outline, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
            var tines = Path()
            for line in state.tineLines {
                tines.move(to: CGPoint(x: line.0.x, y: line.0.y))
                tines.addLine(to: CGPoint(x: line.1.x, y: line.1.y))
            }
            context.stroke(tines, with: .color(.white.opacity(0.65)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
