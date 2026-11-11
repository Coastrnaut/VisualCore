// ContentSwipeBack.swift — keep drawing gestures from navigating back (feature 020 T-A02-213). Since iOS 26 a
// navigation stack also pops on a horizontal swipe anywhere in the content
// (`UINavigationController.interactiveContentPopGestureRecognizer`). On a canvas where people paint with drags, a
// rightward stroke would leave the screen (observed on the iOS 26.5 simulator). The modifier turns only that content
// gesture off while the screen is visible; the edge swipe and the back button keep working. Public UIKit API only.
import SwiftUI
import UIKit

extension View {
    /// Disables the full-width content swipe-back of the enclosing navigation stack while this view is on screen,
    /// restoring the previous setting when it disappears. The edge swipe and the back button are unaffected.
    public func contentSwipeBackDisabled(_ disabled: Bool = true) -> some View {
        background(ContentSwipeBackBlocker(disabled: disabled).frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

struct ContentSwipeBackBlocker: UIViewControllerRepresentable {
    let disabled: Bool

    func makeUIViewController(context: Context) -> Controller { Controller(disabled: disabled) }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.disabled = disabled
        controller.apply()
    }

    final class Controller: UIViewController {
        var disabled: Bool
        private var previous: Bool?

        init(disabled: Bool) {
            self.disabled = disabled
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        /// The content pop gesture of the nearest navigation controller, if any.
        var contentPopGesture: UIGestureRecognizer? {
            var controller: UIViewController? = self
            while let c = controller {
                if let nav = c.navigationController { return nav.interactiveContentPopGestureRecognizer }
                controller = c.parent
            }
            return nil
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            restore()
        }

        func apply() {
            guard let gesture = contentPopGesture, viewIfLoaded?.window != nil else { return }
            if previous == nil { previous = gesture.isEnabled }
            gesture.isEnabled = !disabled && (previous ?? true)
        }

        func restore() {
            guard let gesture = contentPopGesture, let previous else { return }
            gesture.isEnabled = previous
            self.previous = nil
        }
    }
}
