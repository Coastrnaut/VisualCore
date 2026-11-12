// VisualCoreApp — feature 190 T-U04-001 (UA-F04; ADR-0009 D-01). The app type of the unified app, the only shippable
// target of the repository. The launcher, the routes and the settings arrive with T-U04-011.
import SwiftUI

/// The VisualCore app.
@main
struct VisualCoreApp: App {
    var body: some Scene {
        WindowGroup {
            Text(verbatim: "VisualCore")
                .accessibilityIdentifier("vc.route.catalog")
        }
    }
}
