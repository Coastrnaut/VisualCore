// MoleculeOverlay — feature 112 (A15-P03) T-A15-306 (FR-A15-320; clarification Q4; edge case "A selected atom behind
// others"; SC-A15-303; contracts/selection.md). The view Molecular Explorer draws over its canvas through the host's
// overlay slot (`ExperiencePresenter.makeCanvasOverlay(_:)`), modelled on Solar System Explorer's `SolarOverlay`:
//   - the element symbols at the points `LabelLayout` placed for the last drawn frame: small caption text in white on a
//     dark, partly opaque backing, each in its 24 × 18 pt box whose bottom-left corner is the label's point;
//   - a white ring 2 pt wide around the selected atom's projected outline (its projected centre and radius), drawn
//     even when other atoms cover the atom, so a selection behind others is still marked.
// It reads the presenter's mirror only and sends nothing; the host draws it with hit testing off and its elements
// hidden from assistive technology (the panel and the canvas description speak the selection instead). The labels are
// laid out in the mirror's canvas size in points; the overlay reports its own size to the mirror (the presenter then
// lays the next frame out in exactly that size) and scales the points by its size over the mirror's, so a label stays
// on its atom even in the frame before the sizes agree. Nothing moves except with the drawn molecule; nothing flashes;
// no information is carried by colour alone (the symbols are text, the ring is a shape).
import MolecularExplorerCore
import SwiftUI
import VisualCoreMath

/// The element labels and the selection ring drawn over the canvas.
struct MoleculeOverlay: View {
    /// What the overlay shows.
    let mirror: MoleculeMirror

    /// The width of the selection ring's stroke, points.
    static let ringWidth = 2.0

    /// The overlay.
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let canvas = mirror.canvasSize
            let sx = canvas.x > 0 ? Double(size.width) / canvas.x : 1
            let sy = canvas.y > 0 ? Double(size.height) / canvas.y : 1
            ZStack(alignment: .topLeading) {
                if let ring = mirror.ring {
                    let diameter = max(ring.radius * 2 * min(sx, sy), Self.ringWidth * 2)
                    Circle()
                        .stroke(Color.white, lineWidth: Self.ringWidth)
                        .frame(width: diameter, height: diameter)
                        .position(x: ring.centre.x * sx, y: ring.centre.y * sy)
                }
                ForEach(mirror.labels, id: \.index) { label in
                    Text(verbatim: label.symbol)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Color.white)
                        .frame(width: LabelLayout.boxWidth, height: LabelLayout.boxHeight)
                        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                        .position(x: label.point.x * sx + LabelLayout.boxWidth / 2,
                                  y: label.point.y * sy - LabelLayout.boxHeight / 2)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .onAppear { report(size) }
            .onChange(of: size) { _, newSize in report(newSize) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Tells the mirror the overlay's size in points (only when it changed).
    private func report(_ size: CGSize) {
        let points = Vec2(Double(size.width), Double(size.height))
        if mirror.overlaySize != points { mirror.overlaySize = points }
    }
}
