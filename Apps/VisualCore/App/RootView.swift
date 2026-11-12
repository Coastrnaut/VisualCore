// RootView — feature 190 T-U04-011 (FR-U04-030 to FR-U04-033, FR-U04-035, FR-U04-040, FR-U04-012; research R5).
// The root of the shell: the welcome on a first start, otherwise a split view with the launcher as the sidebar and
// the current route as the detail. In a compact width the split view is a stack: the launcher first, the route
// on top of it. A premium tile is answered with a plain notice.
import SwiftUI
import VisualCoreExperience

/// The accessibility identifiers of the shell (data-model section 6).
enum ShellID {
    static let routeCatalog = "vc.route.catalog"
    static let routeExperience = "vc.route.experience"
    static let routeSettings = "vc.route.settings"
    static let routeAbout = "vc.route.about"
    static let navSettings = "vc.nav.settings"
    static let navAbout = "vc.nav.about"
    static let navDone = "vc.nav.done"
    static let search = "vc.search"
    static let searchClear = "vc.search.clear"
    static let empty = "vc.empty"
    static let noMatch = "vc.nomatch"
    static let error = "vc.error"
    static let sectionPrefix = "vc.section."
    static let welcome = "vc.welcome"
    static let welcomeStart = "vc.welcome.start"
    static let premiumNotice = "vc.premium.notice"
    static let premiumDismiss = "vc.premium.dismiss"
    static let experienceBack = "vc.experience.back"
    static let settingsQuality = "vc.settings.quality"
    static let settingsPrefix = "vc.settings"
    static let settingsResetAll = "vc.settings.reset.all"
    static let settingsResetPrefix = "vc.settings.reset."
    static let settingsResetConfirm = "vc.settings.reset.confirm"
    static let settingsResetCancel = "vc.settings.reset.cancel"
    static let settingsPrivacy = "vc.settings.privacy"
    static let aboutAcknowledgements = "vc.about.acknowledgements"
    static let diagnostics = "vc.diagnostics"
    #if DEBUG
    /// The text of the last performance record, in the debug diagnostics of the settings (UA-F06).
    static let performance = "vc.performance"
    #endif
}

extension View {
    /// Marks the root of a route: one accessibility container with `identifier` that keeps its children.
    func routeRoot(_ identifier: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
    }
}

/// The way back from a route, as a row of the content and not as a bar button: a navigation bar keeps its
/// buttons 36 points high and clips their text at the largest sizes; this row is at least 44 points high and
/// wraps its text (FR-U04-035).
struct RouteBackRow: View {
    let title: String
    let identifier: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.backward")
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(uiColor: .label))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }
}

/// The root view: welcome, or the launcher beside (or below) the current route.
struct RootView: View {
    let model: AppModel
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if model.showWelcome {
                WelcomeView(model: model)
            } else {
                shell
            }
        }
        .onAppear { model.noteLauncherUsable() }
        .task {
            #if DEBUG
            await DebugLaunch.start(model)
            #endif
            await model.restoreRoute()
        }
    }

    private var shell: some View {
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: compactColumn) {
            LauncherView(model: model)
        } detail: {
            NavigationStack {
                detail
            }
            .id(model.route)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: premiumNoticeShown) {
            PremiumNoticeView { model.dismissPremiumNotice() }
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.route {
        case .catalog:
            Text(AppStrings.text(.catalogChoose))
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
        case .experience(let id):
            ExperienceRouteView(model: model, id: id)
        case .settings:
            SettingsView(model: model)
        case .about:
            AboutView(model: model)
        }
    }

    /// The column a compact width shows: the launcher for the catalog route, the detail for every other route.
    /// The system's own way back to the sidebar ends the route as well.
    private var compactColumn: Binding<NavigationSplitViewColumn> {
        Binding(get: { model.route == .catalog ? .sidebar : .detail }, set: { column in
            if column == .sidebar, model.route != .catalog { model.go(.catalog) }
        })
    }

    private var premiumNoticeShown: Binding<Bool> {
        Binding(get: { model.premiumNotice }, set: { shown in
            if !shown { model.dismissPremiumNotice() }
        })
    }
}

/// The plain statement a premium tile opens: premium experiences are not yet available in this build.
struct PremiumNoticeView: View {
    let onDismiss: @MainActor () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppStrings.text(.premiumTitle))
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(AppStrings.text(.premiumBody))
                    .font(.body)
                    .accessibilityIdentifier(ShellID.premiumNotice)
                Button(action: onDismiss) {
                    Text(AppStrings.text(.premiumDismiss))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(ShellID.premiumDismiss)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .presentationDetents([.medium, .large])
    }
}
