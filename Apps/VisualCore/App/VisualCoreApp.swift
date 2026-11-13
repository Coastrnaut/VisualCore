// VisualCoreApp — feature 190 T-U04-011 (UA-F04; ADR-0009 D-01; FR-U04-001, FR-U04-030, FR-U04-043). The app type
// of the unified app, the only shippable target of the repository. It creates the one app model and shows the
// root view. In builds made for testing the environment passes through the debug launch arguments; a release
// build contains none of that handling.
import SwiftUI
import VisualCoreExperience
import VisualCoreUI

/// The start of the app's own code: the launch time counts from here (UA-F06, FR-U06-024). The value is taken
/// when the app type is created, which is the first code of the app that runs.
enum AppLaunch {
    /// The instant the app type was created.
    static let start = ContinuousClock.now
}

/// The VisualCore app.
@main
struct VisualCoreApp: App {
    @State private var model: AppModel?
    #if DEBUG || VISUALCORE_AUTOMATION
    /// The launch environment of a scenario run (feature 195); nil for a normal start.
    private let scenarioEnvironment: [String: String]?
    #endif

    /// Creates the app with its one model. A scenario run (only in builds made for testing or for automation)
    /// creates no model, so it neither reads nor writes the person's preferences.
    init() {
        _ = AppLaunch.start
        #if DEBUG || VISUALCORE_AUTOMATION
        let processEnvironment = ProcessInfo.processInfo.environment
        if ScenarioRequest.parse(processEnvironment) != nil {
            scenarioEnvironment = processEnvironment
            _model = State(initialValue: nil)
            return
        }
        scenarioEnvironment = nil
        #endif
        #if DEBUG
        let environment = DebugLaunch.environment(base: AppEnvironment.live())
        #else
        let environment = AppEnvironment.live()
        #endif
        _model = State(initialValue: AppModel(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            content
                // The contrast-checked accent of the framework, not the system default (accessibility audit).
                .tint(AccessibleColors.accent)
        }
    }

    @ViewBuilder private var content: some View {
        #if DEBUG || VISUALCORE_AUTOMATION
        if let scenarioEnvironment {
            ScenarioHostView(environment: scenarioEnvironment) { code in Darwin.exit(code) }
        } else if let model {
            RootView(model: model)
        }
        #else
        if let model {
            RootView(model: model)
        }
        #endif
    }
}
